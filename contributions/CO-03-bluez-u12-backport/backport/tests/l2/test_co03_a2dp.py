# SPDX-License-Identifier: GPL-2.0-or-later
"""
CO-03 L2: A2DP transport Acquire()/Release() orderings between two VMs.

host0: the bluetoothd under test ($CO03_HOST0_BLUETOOTHD), A2DP source
       (or sink in the T23x role-swap tests), with MediaApp.
host1: the test-fixture bluetoothd ($CO03_HOST1_BLUETOOTHD, built from the
       same base with the CO03_SINK_* fixture), the remote device, its
       behaviour chosen per test ("mode", see MODES).

Each test appends one JSON line per run to $CO03_RESULTS and fails if one
of its stated invariants does not hold. The same file runs unchanged on
every host0 build.
"""

import json
import os
import re
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Bluetoothctl, host_config

from .co03_plugins import (
    A2DP_SINK_UUID,
    A2DP_SOURCE_UUID,
    CoBluetoothd,
    MediaApp,
)

pytestmark = [pytest.mark.vm]

VM_MEM = "784M"
REPS = int(os.environ.get("CO03_REPS", "1"))

# host1 behaviours (test fixture, see co03_fixture_cmd() in the fixture
# tree's profiles/audio/avdtp.c)
MODES = {
    # MOMENTUM 4 model: START answered after 200 ms, ABORT never answered
    "silent": {"CO03_SINK_START_DELAY_MS": "200", "CO03_SINK_DROP_ABORT": "1"},
    # START answered after 200 ms, ABORT answered
    "slow": {"CO03_SINK_START_DELAY_MS": "200"},
    # stock behaviour: everything answered at once
    "plain": {},
    # START answered at once, ABORT never answered
    "silent0": {"CO03_SINK_DROP_ABORT": "1"},
    # SUSPEND answered after 300 ms
    "slowsusp": {"CO03_SINK_SUSPEND_DELAY_MS": "300"},
    # START rejected (BAD_STATE)
    "reject": {"CO03_SINK_REJECT_START": "1"},
    # START never answered, ABORT answered
    "nostart": {"CO03_SINK_DROP_START": "1"},
    # START and ABORT never answered
    "nostart_silent": {"CO03_SINK_DROP_START": "1", "CO03_SINK_DROP_ABORT": "1"},
    # START answered after 1000 ms, ABORT never answered
    "slow1000": {"CO03_SINK_START_DELAY_MS": "1000", "CO03_SINK_DROP_ABORT": "1"},
    # START answered after 300 ms, ABORT answered
    "slow300": {"CO03_SINK_START_DELAY_MS": "300"},
}


def hosts_for(mode, swap=False):
    if not swap:
        h0 = [CoBluetoothd("CO03_HOST0_BLUETOOTHD"), Bluetoothctl(),
              MediaApp((A2DP_SOURCE_UUID,))]
        h1 = [CoBluetoothd("CO03_HOST1_BLUETOOTHD", env=MODES[mode]), Bluetoothctl(),
              MediaApp((A2DP_SINK_UUID,))]
    else:
        h0 = [CoBluetoothd("CO03_HOST0_BLUETOOTHD"), Bluetoothctl(),
              MediaApp((A2DP_SINK_UUID,))]
        h1 = [CoBluetoothd("CO03_HOST1_BLUETOOTHD", env=MODES[mode]), Bluetoothctl(),
              MediaApp((A2DP_SOURCE_UUID,))]
    return host_config(h0, h1, mem=VM_MEM)


def reps():
    return pytest.mark.parametrize("rep", range(REPS))


# --- logs ----------------------------------------------------------------

LOST = re.compile(r"profile a2dp-(sink|source) state changed: connected -> disconnected")
CONN_LOST = re.compile(r"avdtp\.c:connection_lost\(\) Disconnected")
ABORT_SENT = re.compile(r"a2dp_cancel\(\) aborting setup")
AVDTP_ABORT_TIMEOUT = re.compile(r"Abort: Connection timed out")
START_CANCELED = re.compile(r"cancel_request\(\) Start: Operation canceled")
LABEL_MISMATCH = re.compile(r"Transaction label doesn't match")
SANITIZER = re.compile(r"AddressSanitizer|LeakSanitizer|UndefinedBehaviorSanitizer|runtime error:")
FIX_DROP_ABORT = re.compile(r"CO03 fixture: dropping ABORT")
FIX_DEFER_START = re.compile(r"CO03 fixture: deferring signal 7 ")
FIX_HANDLE_START = re.compile(r"CO03 fixture: handling deferred signal 7 ")
ABORT_IND = re.compile(r"abort_ind|Abort_Ind")


def lines(caplog, idx, name="bluetoothd"):
    pat = re.compile(rf"^host\.\d+\.{idx}\.{name}$")
    return [
        (getattr(r, "nsec", int(r.created * 1e9)), r.getMessage())
        for r in list(caplog.records)
        if pat.match(r.name)
    ]


def first(caplog, idx, pattern, after=0, name="bluetoothd"):
    for t, m in lines(caplog, idx, name):
        if t >= after and pattern.search(m):
            return t
    return None


def count(caplog, idx, pattern, after=0, name="bluetoothd"):
    return sum(1 for t, m in lines(caplog, idx, name) if t >= after and pattern.search(m))


def ms(t, t0):
    return None if t is None or t0 is None else round((t - t0) / 1e6, 1)


def sanitizer_lines(caplog):
    out = []
    for idx in (0, 1):
        for t, m in lines(caplog, idx):
            if SANITIZER.search(m):
                out.append(f"host{idx}: {m}")
    return out


def record(name, mode, rep, data):
    path = Path(os.environ.get("CO03_RESULTS", "co03-results.jsonl"))
    entry = dict(test=name, variant=os.environ.get("CO03_VARIANT", ""), mode=mode,
                 rep=rep, **data)
    with open(path, "a") as f:
        f.write(json.dumps(entry) + "\n")


# --- steps ---------------------------------------------------------------


def connect(host0, host1):
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    tp0 = host0.media.wait_transport(30)
    tp1 = host1.media.wait_transport(30)
    time.sleep(1.0)
    return tp0, tp1


def wait_state(host, path, state, timeout=5.0):
    end = time.monotonic() + timeout
    props = {}
    while time.monotonic() < end:
        props = host.media.transport_props(path)
        if props.get("State") == state:
            return True
        time.sleep(0.05)
    return False


def probe(host0, host1, tp0, tp1, client="probe"):
    """A later Acquire on host0 works and media packets reach host1.
    Works for either direction: the acquiring host writes, the other
    reads."""
    out = {}
    ids = host0.media.seq([(client, "Acquire", tp0, 0)])
    r = host0.media.results(ids, 10)[0]
    out["acquire"] = _op(r)
    if not r.get("ok"):
        out["flowed"] = False
        return out
    # the remote side's transport goes pending when the stream starts
    out["remote_pending"] = wait_state(host1, tp1, "pending", 5)
    ids1 = host1.media.seq([(client, "TryAcquire", tp1, 0)])
    r1 = host1.media.results(ids1, 10)[0]
    out["remote_tryacquire"] = _op(r1)
    written = host0.media.write_media(tp0, 50, 0.01)
    packets, nbytes = host1.media.read_media(tp1, 2.0)
    out.update(written=written, read_packets=packets, read_bytes=nbytes)
    out["flowed"] = bool(r1.get("ok")) and packets > 0
    # clean up: the acquiring side releases first (a release by the
    # remote suspends the stream and removes host0's owner)
    host1.media.close_fd(tp1)
    host0.media.close_fd(tp0)
    rel = host0.media.results(host0.media.seq([(client, "Release", tp0, 0)]), 10)[0]
    out["release"] = _op(rel)
    if r1.get("ok"):
        rel1 = host1.media.results(host1.media.seq([(client, "Release", tp1, 0)]), 10)[0]
        out["remote_release"] = _op(rel1)
    return out


def _op(r):
    d = {"method": r.get("method"), "delay_ms": r.get("delay_ms")}
    if "t_reply" not in r:
        d["reply"] = "none"
    elif r.get("ok"):
        d["reply"] = "ok"
    else:
        d["reply"] = r.get("error")
        d["message"] = r.get("message")
    if "t_reply" in r and "t_call" in r:
        d["latency_ms"] = ms(r["t_reply"], r["t_call"])
    d["t_call"] = r.get("t_call")
    return d


def transport_alive(host, tp):
    return "_error" not in host.media.transport_props(tp)


# --- the trigger: Release() while Acquire() (AVDTP START) is pending ------

def u12_case(paired_hosts, caplog, name, mode, rep, gap_ms, settle=4.5,
             expect_fixed=True):
    """Acquire, then Release <gap_ms> later from the same client; observe
    <settle> s; then probe. Invariants (fixed behaviour):
      I1 A2DP stays connected (no a2dp-* disconnected, transport kept)
      I2 a later Acquire works and media packets flow
      I3 the Acquire gets an answer (an error) within 5 s
      I4 no AVDTP ABORT is sent for the cancelled START
      I8 no sanitizer report"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)

    ids = host0.media.seq([("app", "Acquire", tp0, 0), ("app", "Release", tp0, gap_ms)])
    res = host0.media.results(ids, 5.0)
    t0 = res[0].get("t_call")
    time.sleep(settle)

    data = {
        "gap_ms": gap_ms,
        "acquire": _op(res[0]),
        "release": _op(res[1]),
        "abort_sent": count(caplog, 0, ABORT_SENT, t0),
        "start_canceled": count(caplog, 0, START_CANCELED, t0),
        "label_mismatch": count(caplog, 0, LABEL_MISMATCH, t0),
        "abort_timeout_ms": ms(first(caplog, 0, AVDTP_ABORT_TIMEOUT, t0), t0),
        "lost_ms": ms(first(caplog, 0, LOST, t0), t0),
        "conn_lost_ms": ms(first(caplog, 0, CONN_LOST, t0), t0),
        "sink_dropped_abort": count(caplog, 1, FIX_DROP_ABORT, t0),
        "sink_start_answered_ms": ms(first(caplog, 1, FIX_HANDLE_START, t0), t0),
        "transport_alive": transport_alive(host0, tp0),
    }
    data["probe"] = probe(host0, host1, tp0, tp1) if data["transport_alive"] else {"flowed": False}
    data["sanitizer"] = sanitizer_lines(caplog)
    record(name, mode, rep, data)

    failed = []
    if data["lost_ms"] is not None or not data["transport_alive"]:
        failed.append(f"I1 A2DP lost at {data['lost_ms']} ms")
    if not data["probe"].get("flowed"):
        failed.append(f"I2 later Acquire/media failed: {data['probe']}")
    if data["acquire"]["reply"] in ("none", "ok"):
        failed.append(f"I3 Acquire reply: {data['acquire']['reply']}")
    if data["abort_sent"]:
        failed.append(f"I4 ABORT sent ({data['abort_sent']})")
    if data["sanitizer"]:
        failed.append(f"I8 sanitizer: {data['sanitizer'][:3]}")
    assert not failed, "; ".join(failed)


@hosts_for("silent")
@reps()
def test_t201_silent_release_same_tick(paired_hosts, caplog, rep):
    """T201 silent sink, Release in the same main-loop turn as Acquire"""
    u12_case(paired_hosts, caplog, "t201", "silent", rep, 0)


@hosts_for("silent")
@reps()
def test_t202_silent_release_87ms(paired_hosts, caplog, rep):
    """T202 silent sink, Release 87 ms after Acquire (EX-084's gap)"""
    u12_case(paired_hosts, caplog, "t202", "silent", rep, 87)


@hosts_for("slow")
@reps()
def test_t203_slow_release_same_tick(paired_hosts, caplog, rep):
    """T203 sink answers ABORT; Release in the same turn"""
    u12_case(paired_hosts, caplog, "t203", "slow", rep, 0)


@hosts_for("slow")
@reps()
def test_t204_slow_release_87ms(paired_hosts, caplog, rep):
    """T204 sink answers ABORT; Release after 87 ms"""
    u12_case(paired_hosts, caplog, "t204", "slow", rep, 87)


@hosts_for("plain")
@reps()
def test_t205_plain_release_same_tick(paired_hosts, caplog, rep):
    """T205 stock sink (START answered at once): the race as it falls"""
    u12_case(paired_hosts, caplog, "t205", "plain", rep, 0)


@hosts_for("silent0")
@reps()
def test_t206_silent0_release_same_tick(paired_hosts, caplog, rep):
    """T206 START answered at once, ABORT never answered"""
    u12_case(paired_hosts, caplog, "t206", "silent0", rep, 0)


@hosts_for("silent", swap=True)
@reps()
def test_t207_sink_role_silent_release_same_tick(paired_hosts, caplog, rep):
    """T207 roles swapped: host0 is the sink and acquires (it sends
    START); the remote source answers START late and never ABORT"""
    u12_case(paired_hosts, caplog, "t207", "silent", rep, 0)


# --- normal orderings (keep) ----------------------------------------------

def no_loss_checks(caplog, data, t0, failed):
    data["lost_ms"] = ms(first(caplog, 0, LOST, t0), t0)
    data["abort_sent"] = count(caplog, 0, ABORT_SENT, t0)
    data["sanitizer"] = sanitizer_lines(caplog)
    if data["lost_ms"] is not None:
        failed.append(f"A2DP lost at {data['lost_ms']} ms")
    if data["abort_sent"]:
        failed.append(f"ABORT sent ({data['abort_sent']})")
    if data["sanitizer"]:
        failed.append(f"sanitizer: {data['sanitizer'][:3]}")


@hosts_for("plain")
@reps()
def test_t220_plain_acquire_stream_release(paired_hosts, caplog, rep):
    """T220 Acquire, media flows, Release; twice; A2DP kept"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    p1 = probe(host0, host1, tp0, tp1, "c1")
    p2 = probe(host0, host1, tp0, tp1, "c2")
    time.sleep(1.0)
    data = {"probe1": p1, "probe2": p2}
    failed = []
    for p in (p1, p2):
        if not p.get("flowed") or p.get("release", {}).get("reply") != "ok":
            failed.append(f"cycle: {p}")
    no_loss_checks(caplog, data, t0, failed)
    record("t220", "plain", rep, data)
    assert not failed, failed


@hosts_for("silent")
@reps()
def test_t221_silent_release_after_start(paired_hosts, caplog, rep):
    """T221 slow/silent sink, Release only after the Acquire completed
    (normal order): no ABORT, A2DP kept"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    ids = host0.media.seq([("app", "Acquire", tp0, 0)])
    a = host0.media.results(ids, 5)[0]
    t0 = a.get("t_call")
    time.sleep(0.3)
    r = host0.media.results(host0.media.seq([("app", "Release", tp0, 0)]), 5)[0]
    time.sleep(3.0)
    data = {"acquire": _op(a), "release": _op(r)}
    failed = []
    if a.get("ok") is not True:
        failed.append(f"Acquire {data['acquire']}")
    if r.get("ok") is not True:
        failed.append(f"Release {data['release']}")
    no_loss_checks(caplog, data, t0, failed)
    data["probe"] = probe(host0, host1, tp0, tp1)
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    record("t221", "silent", rep, data)
    assert not failed, failed


@hosts_for("plain")
@reps()
def test_t222_two_quick_cycles(paired_hosts, caplog, rep):
    """T222 two Acquire/Release cycles back to back, each waiting for its
    replies"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    out = []
    for i in range(2):
        a = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
        host0.media.close_fd(tp0)
        r = host0.media.results(host0.media.seq([("app", "Release", tp0, 0)]), 5)[0]
        out.append({"acquire": _op(a), "release": _op(r)})
    data = {"cycles": out}
    failed = [f"cycle {c}" for c in out if c["acquire"]["reply"] != "ok" or c["release"]["reply"] != "ok"]
    time.sleep(1.0)
    no_loss_checks(caplog, data, t0, failed)
    data["probe"] = probe(host0, host1, tp0, tp1)
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    record("t222", "plain", rep, data)
    assert not failed, failed


def cancel_cycles(paired_hosts, caplog, name, mode, rep, n=2):
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    out = []
    for i in range(n):
        ids = host0.media.seq([("app", "Acquire", tp0, 0), ("app", "Release", tp0, 0)])
        res = host0.media.results(ids, 5)
        out.append({"acquire": _op(res[0]), "release": _op(res[1])})
        host0.media.close_fd(tp0)
    time.sleep(4.5)
    data = {"cycles": out, "transport_alive": transport_alive(host0, tp0)}
    failed = []
    no_loss_checks(caplog, data, t0, failed)
    if not data["transport_alive"]:
        failed.append("transport gone")
    data["probe"] = probe(host0, host1, tp0, tp1) if data["transport_alive"] else {"flowed": False}
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    record(name, mode, rep, data)
    assert not failed, failed


@hosts_for("slow")
@reps()
def test_t223_two_cancel_cycles_slow(paired_hosts, caplog, rep):
    """T223 (Acquire, Release at once) twice back to back, sink answers
    START late and ABORT normally"""
    cancel_cycles(paired_hosts, caplog, "t223", "slow", rep)


@hosts_for("silent")
@reps()
def test_t224_two_cancel_cycles_silent(paired_hosts, caplog, rep):
    """T224 as T223 with the silent sink"""
    cancel_cycles(paired_hosts, caplog, "t224", "silent", rep)


@hosts_for("slowsusp")
@reps()
def test_t225_release_while_suspending(paired_hosts, caplog, rep):
    """T225 active stream; Release (SUSPEND answered after 300 ms); a
    second Release and an Acquire meanwhile: InProgress, NotAuthorized;
    the first Release succeeds; A2DP kept"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    a = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
    t0 = a.get("t_call")
    host0.media.close_fd(tp0)
    ids = host0.media.seq([("app", "Release", tp0, 0), ("app", "Release", tp0, 50),
                           ("app", "Acquire", tp0, 100)])
    res = host0.media.results(ids, 5)
    data = {"acquire": _op(a), "release": _op(res[0]), "release2": _op(res[1]),
            "acquire2": _op(res[2])}
    failed = []
    if data["release"]["reply"] != "ok":
        failed.append(f"Release {data['release']}")
    if data["release2"]["reply"] != "org.bluez.Error.InProgress":
        failed.append(f"second Release {data['release2']}")
    if data["acquire2"]["reply"] != "org.bluez.Error.NotAuthorized":
        failed.append(f"Acquire while suspending {data['acquire2']}")
    time.sleep(1.0)
    no_loss_checks(caplog, data, t0, failed)
    data["probe"] = probe(host0, host1, tp0, tp1)
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    record("t225", "slowsusp", rep, data)
    assert not failed, failed


@hosts_for("plain")
@reps()
def test_t226_api_refusals(paired_hosts, caplog, rep):
    """T226 refusals unchanged: Release with no owner, TryAcquire on idle,
    Acquire twice, Release by another client"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    r0 = host0.media.results(host0.media.seq([("app", "Release", tp0, 0)]), 5)[0]
    ta = host0.media.results(host0.media.seq([("app", "TryAcquire", tp0, 0)]), 5)[0]
    a1 = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
    a2 = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
    ro = host0.media.results(host0.media.seq([("other", "Release", tp0, 0)]), 5)[0]
    host0.media.close_fd(tp0)
    r1 = host0.media.results(host0.media.seq([("app", "Release", tp0, 0)]), 5)[0]
    data = {k: _op(v) for k, v in dict(release_no_owner=r0, tryacquire_idle=ta,
                                       acquire=a1, acquire_again=a2,
                                       release_other=ro, release=r1).items()}
    want = dict(release_no_owner="org.bluez.Error.NotAuthorized",
                tryacquire_idle="org.bluez.Error.NotAvailable",
                acquire="ok", acquire_again="org.bluez.Error.NotAuthorized",
                release_other="org.bluez.Error.NotAuthorized", release="ok")
    failed = [f"{k}: {data[k]['reply']} != {v}" for k, v in want.items() if data[k]["reply"] != v]
    no_loss_checks(caplog, data, t0, failed)
    record("t226", "plain", rep, data)
    assert not failed, failed


@hosts_for("plain")
@reps()
def test_t227_remote_suspends(paired_hosts, caplog, rep):
    """T227 the remote (sink) releases its side while host0 streams:
    host0's transport loses its owner, A2DP kept, a new Acquire works"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    a = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
    t0 = a.get("t_call")
    pending = wait_state(host1, tp1, "pending", 5)
    ta = host1.media.results(host1.media.seq([("app", "TryAcquire", tp1, 0)]), 5)[0]
    host1.media.close_fd(tp1)
    r1 = host1.media.results(host1.media.seq([("app", "Release", tp1, 0)]), 5)[0]
    idle = wait_state(host0, tp0, "idle", 5)
    host0.media.close_fd(tp0)
    data = {"acquire": _op(a), "remote_pending": pending, "remote_tryacquire": _op(ta),
            "remote_release": _op(r1), "host0_idle_after": idle}
    failed = []
    if a.get("ok") is not True or ta.get("ok") is not True:
        failed.append("setup")
    no_loss_checks(caplog, data, t0, failed)
    data["probe"] = probe(host0, host1, tp0, tp1, "app2")
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    record("t227", "plain", rep, data)
    assert not failed, failed


@hosts_for("plain")
@reps()
def test_t228_rapid_cycles(paired_hosts, caplog, rep):
    """T228 20 Acquire/Release cycles in normal order (stress)"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    bad = []
    for i in range(20):
        a = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
        host0.media.close_fd(tp0)
        r = host0.media.results(host0.media.seq([("app", "Release", tp0, 0)]), 5)[0]
        if not a.get("ok") or not r.get("ok"):
            bad.append((i, _op(a), _op(r)))
    data = {"bad_cycles": bad}
    failed = [f"bad cycles {bad[:3]}"] if bad else []
    time.sleep(1.0)
    no_loss_checks(caplog, data, t0, failed)
    record("t228", "plain", rep, data)
    assert not failed, failed


@hosts_for("plain")
@reps()
def test_t229_transport_properties(paired_hosts, caplog, rep):
    """T229 MediaTransport1 property set of an A2DP source transport,
    recorded (must be identical across builds); Delay is not part of
    the backport"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    p0 = host0.media.transport_props(tp0)
    p1 = host1.media.transport_props(tp1)
    data = {"host0_keys": sorted(p0), "host1_keys": sorted(p1),
            "host0_state": p0.get("State"), "sanitizer": sanitizer_lines(caplog)}
    record("t229", "plain", rep, data)
    assert "_error" not in p0 and not data["sanitizer"], data


@hosts_for("plain", swap=True)
@reps()
def test_t230_sink_role_acquire_release(paired_hosts, caplog, rep):
    """T230 roles swapped: host0 is the sink, acquires (sends START),
    reads media written by the source, releases"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    a = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
    pending = wait_state(host1, tp1, "pending", 5)
    ta = host1.media.results(host1.media.seq([("app", "TryAcquire", tp1, 0)]), 5)[0]
    written = host1.media.write_media(tp1, 50, 0.01)
    packets, nbytes = host0.media.read_media(tp0, 2.0)
    host0.media.close_fd(tp0)
    host1.media.close_fd(tp1)
    r = host0.media.results(host0.media.seq([("app", "Release", tp0, 0)]), 5)[0]
    data = {"acquire": _op(a), "remote_pending": pending, "remote_tryacquire": _op(ta),
            "written": written, "read_packets": packets, "release": _op(r)}
    failed = []
    if a.get("ok") is not True or packets <= 0 or r.get("ok") is not True:
        failed.append(f"flow {data}")
    time.sleep(1.0)
    no_loss_checks(caplog, data, t0, failed)
    record("t230", "plain", rep, data)
    assert not failed, failed


# --- failure paths (record; keep where stated) -----------------------------

def observe(paired_hosts, caplog, name, mode, rep, steps, settle, action=None):
    """Run <steps> on host0 (seq), optionally <action>(host0, host1, tp0,
    tp1) right after, observe <settle> s; return data and a probe"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    steps = [(c, m, tp0, d) for c, m, d in steps]
    ids = host0.media.seq(steps)
    extra = action(host0, host1, tp0, tp1) if action else None
    res = host0.media.results(ids, settle)
    t0 = res[0].get("t_call")
    time.sleep(max(0.0, settle - (host0.call(time.time_ns) - t0) / 1e9))
    data = {
        "ops": [_op(r) for r in res],
        "action": extra,
        "abort_sent": count(caplog, 0, ABORT_SENT, t0),
        "abort_timeout_ms": ms(first(caplog, 0, AVDTP_ABORT_TIMEOUT, t0), t0),
        "lost_ms": ms(first(caplog, 0, LOST, t0), t0),
        "sink_dropped_abort": count(caplog, 1, FIX_DROP_ABORT, t0),
        "transport_alive": transport_alive(host0, tp0),
        "sanitizer": sanitizer_lines(caplog),
    }
    return host0, host1, tp0, tp1, data


@hosts_for("reject")
@reps()
def test_t240_start_rejected(paired_hosts, caplog, rep):
    """T240 sink rejects START, Acquire alone: Acquire error, A2DP kept"""
    host0, host1, tp0, tp1, data = observe(
        paired_hosts, caplog, "t240", "reject", rep, [("app", "Acquire", 0)], 3.0)
    record("t240", "reject", rep, data)
    failed = []
    if data["ops"][0]["reply"] in ("ok", "none"):
        failed.append(f"Acquire {data['ops'][0]}")
    if data["lost_ms"] is not None or data["sanitizer"]:
        failed.append(f"lost {data['lost_ms']} san {data['sanitizer'][:2]}")
    assert not failed, failed


@hosts_for("reject")
@reps()
def test_t241_start_rejected_release_pending(paired_hosts, caplog, rep):
    """T241 sink rejects START while Release is pending: outcome
    recorded; invariant: A2DP kept, no sanitizer report, Release
    answered"""
    host0, host1, tp0, tp1, data = observe(
        paired_hosts, caplog, "t241", "reject", rep,
        [("app", "Acquire", 0), ("app", "Release", 0)], 4.5)
    record("t241", "reject", rep, data)
    failed = []
    if data["lost_ms"] is not None or not data["transport_alive"]:
        failed.append(f"A2DP lost at {data['lost_ms']}")
    if data["ops"][1]["reply"] == "none":
        failed.append("Release unanswered")
    if data["sanitizer"]:
        failed.append(f"sanitizer {data['sanitizer'][:2]}")
    assert not failed, failed


@hosts_for("nostart")
@reps()
def test_t242_start_unanswered(paired_hosts, caplog, rep):
    """T242 START never answered, Acquire alone: AVDTP's own 6 s request
    timeout; recorded (both builds alike)"""
    host0, host1, tp0, tp1, data = observe(
        paired_hosts, caplog, "t242", "nostart", rep, [("app", "Acquire", 0)], 9.0)
    record("t242", "nostart", rep, data)
    assert not data["sanitizer"], data["sanitizer"]


@hosts_for("nostart")
@reps()
def test_t243_start_unanswered_release_pending(paired_hosts, caplog, rep):
    """T243 START never answered, Release at once (ABORT answered):
    recorded; invariant: Release answered, no sanitizer report"""
    host0, host1, tp0, tp1, data = observe(
        paired_hosts, caplog, "t243", "nostart", rep,
        [("app", "Acquire", 0), ("app", "Release", 0)], 9.0)
    record("t243", "nostart", rep, data)
    failed = []
    if data["ops"][1]["reply"] == "none":
        failed.append("Release unanswered")
    if data["sanitizer"]:
        failed.append(f"sanitizer {data['sanitizer'][:2]}")
    assert not failed, failed


@hosts_for("nostart_silent")
@reps()
def test_t244_start_and_abort_unanswered(paired_hosts, caplog, rep):
    """T244 neither START nor ABORT answered, Release at once: A2DP is
    lost on every build (AVDTP gives up); recorded with timing"""
    host0, host1, tp0, tp1, data = observe(
        paired_hosts, caplog, "t244", "nostart_silent", rep,
        [("app", "Acquire", 0), ("app", "Release", 0)], 11.0)
    record("t244", "nostart_silent", rep, data)
    assert not data["sanitizer"], data["sanitizer"]


def disconnect_from(host_from, host_to):
    host_from.bluetoothctl.send(f"disconnect {host_to.bdaddr}\n")


def reconnect_probe(host0, host1, tp0_old):
    """After a disconnect: reconnect, wait for a new transport, probe"""
    time.sleep(2.0)
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    try:
        tp0 = host0.media.wait_transport(30, exclude=())
        tp1 = host1.media.wait_transport(30, exclude=())
    except TimeoutError:
        return {"reconnected": False, "flowed": False}
    time.sleep(1.0)
    p = probe(host0, host1, tp0, tp1, "after")
    p["reconnected"] = True
    return p


def disconnect_case(paired_hosts, caplog, name, mode, rep, steps, who):
    def action(host0, host1, tp0, tp1):
        time.sleep(0.1)
        if who == "host0":
            disconnect_from(host0, host1)
        else:
            disconnect_from(host1, host0)
        return {"disconnect_by": who}

    host0, host1, tp0, tp1, data = observe(paired_hosts, caplog, name, mode, rep,
                                           steps, 3.0, action)
    data["after"] = reconnect_probe(host0, host1, tp0)
    data["sanitizer"] = sanitizer_lines(caplog)
    record(name, mode, rep, data)
    failed = []
    if any(o["reply"] == "none" for o in data["ops"]):
        failed.append(f"unanswered call {data['ops']}")
    if data["sanitizer"]:
        failed.append(f"sanitizer {data['sanitizer'][:2]}")
    if not data["after"].get("flowed"):
        failed.append(f"after reconnect {data['after']}")
    assert not failed, failed


@hosts_for("slow1000")
@reps()
def test_t245_disconnect_during_acquire(paired_hosts, caplog, rep):
    """T245 host0 disconnects the device while Acquire waits for START:
    every call answered, no sanitizer report, reconnect works"""
    disconnect_case(paired_hosts, caplog, "t245", "slow1000", rep,
                    [("app", "Acquire", 0)], "host0")


@hosts_for("slow1000")
@reps()
def test_t246_disconnect_during_release_of_pending(paired_hosts, caplog, rep):
    """T246 as T245 with Release already called (the waiting Release)"""
    disconnect_case(paired_hosts, caplog, "t246", "slow1000", rep,
                    [("app", "Acquire", 0), ("app", "Release", 0)], "host0")


@hosts_for("slow1000")
@reps()
def test_t247_remote_disconnect_during_release_of_pending(paired_hosts, caplog, rep):
    """T247 the remote disconnects while Release waits for START"""
    disconnect_case(paired_hosts, caplog, "t247", "slow1000", rep,
                    [("app", "Acquire", 0), ("app", "Release", 0)], "host1")


def owner_exit_case(paired_hosts, caplog, name, mode, rep, steps, wait_ok_first=False,
                    settle=4.5):
    def action(host0, host1, tp0, tp1):
        time.sleep(0.05)
        return {"closed_at": host0.media.close_client("app")}

    host0, host1, tp0, tp1, data = observe(paired_hosts, caplog, name, mode, rep,
                                           steps, settle, action)
    data["probe"] = probe(host0, host1, tp0, tp1) if data["transport_alive"] else {"flowed": False}
    data["sanitizer"] = sanitizer_lines(caplog)
    record(name, mode, rep, data)
    return data


@hosts_for("silent")
@reps()
def test_t248_owner_exit_during_acquire(paired_hosts, caplog, rep):
    """T248 the owner's D-Bus connection closes while Acquire waits for
    START (silent sink): recorded; invariant: no sanitizer report"""
    data = owner_exit_case(paired_hosts, caplog, "t248", "silent", rep,
                           [("app", "Acquire", 0)])
    assert not data["sanitizer"], data["sanitizer"]


@hosts_for("silent")
@reps()
def test_t249_owner_exit_during_release_of_pending(paired_hosts, caplog, rep):
    """T249 the owner exits while its Release waits for START (silent
    sink): recorded; invariant: no sanitizer report"""
    data = owner_exit_case(paired_hosts, caplog, "t249", "silent", rep,
                           [("app", "Acquire", 0), ("app", "Release", 0)])
    assert not data["sanitizer"], data["sanitizer"]


@hosts_for("slowsusp")
@reps()
def test_t250_owner_exit_during_suspend(paired_hosts, caplog, rep):
    """T250 the owner exits while its Release of an active stream waits
    for SUSPEND (answered after 300 ms): recorded (both builds cancel the
    SUSPEND); invariant: no sanitizer report"""

    def action(host0, host1, tp0, tp1):
        return None

    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    a = host0.media.results(host0.media.seq([("app", "Acquire", tp0, 0)]), 5)[0]
    t0 = a.get("t_call")
    host0.media.close_fd(tp0)
    host0.media.seq([("app", "Release", tp0, 0)])
    time.sleep(0.05)
    host0.media.close_client("app")
    time.sleep(4.5)
    data = {"acquire": _op(a),
            "abort_sent": count(caplog, 0, ABORT_SENT, t0),
            "lost_ms": ms(first(caplog, 0, LOST, t0), t0),
            "transport_alive": transport_alive(host0, tp0),
            "sanitizer": sanitizer_lines(caplog)}
    data["probe"] = probe(host0, host1, tp0, tp1) if data["transport_alive"] else {"flowed": False}
    record("t250", "slowsusp", rep, data)
    assert not data["sanitizer"], data["sanitizer"]


def remote_sep(host0, host1):
    dev = "/org/bluez/hci0/dev_" + host1.bdaddr.upper().replace(":", "_")
    seps = host0.media.remote_seps(dev)
    return seps[0] if seps else None


@hosts_for("plain")
@reps()
def test_t251_reconfigure_idle(paired_hosts, caplog, rep):
    """T251 SetConfiguration on the remote SEP while idle (reconfigure):
    a new transport appears and works"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    t0 = host0.call(time.time_ns)
    sep = remote_sep(host0, host1)
    op = host0.media.set_configuration(sep)
    res = host0.media.results([op], 10)[0]
    try:
        ntp0 = host0.media.wait_transport(10, exclude=(tp0,))
        ntp1 = host1.media.wait_transport(10, exclude=(tp1,))
    except TimeoutError:
        ntp0 = ntp1 = None
    time.sleep(1.0)
    data = {"sep": sep, "setconf": _op(res), "new_transport": ntp0 is not None}
    data["probe"] = probe(host0, host1, ntp0, ntp1) if ntp0 and ntp1 else {"flowed": False}
    failed = []
    # A reconfigure closes the stream, and 5.72's sink.c reports the
    # a2dp-sink service disconnected when the stream goes IDLE, before the
    # new configuration: recorded, not a failure here (V0 run v0-l2)
    data["lost_ms"] = ms(first(caplog, 0, LOST, t0), t0)
    data["abort_sent"] = count(caplog, 0, ABORT_SENT, t0)
    data["sanitizer"] = sanitizer_lines(caplog)
    if data["sanitizer"]:
        failed.append(f"sanitizer: {data['sanitizer'][:3]}")
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    record("t251", "plain", rep, data)
    assert not failed, failed


@hosts_for("slow300")
@reps()
def test_t252_reconfigure_during_release_of_pending(paired_hosts, caplog, rep):
    """T252 SetConfiguration while Release waits for a START answered
    after 300 ms (the 664a5d3785a1 path): recorded; invariant: no
    sanitizer report, every call answered, A2DP usable afterwards"""
    host0, host1 = paired_hosts
    tp0, tp1 = connect(host0, host1)
    sep = remote_sep(host0, host1)
    ids = host0.media.seq([("app", "Acquire", tp0, 0), ("app", "Release", tp0, 0)])
    time.sleep(0.05)
    op = host0.media.set_configuration(sep)
    res = host0.media.results(ids + [op], 10)
    t0 = res[0].get("t_call")
    time.sleep(3.0)
    cur0 = host0.media.current_transports()
    cur1 = host1.media.current_transports()
    data = {"ops": [_op(r) for r in res], "transports0": cur0, "transports1": cur1,
            "abort_sent": count(caplog, 0, ABORT_SENT, t0),
            "lost_ms": ms(first(caplog, 0, LOST, t0), t0),
            "sanitizer": sanitizer_lines(caplog)}
    if cur0 and cur1:
        data["probe"] = probe(host0, host1, cur0[-1], cur1[-1])
    else:
        data["probe"] = {"flowed": False}
    record("t252", "slow300", rep, data)
    failed = []
    if any(o["reply"] == "none" for o in data["ops"]):
        failed.append(f"unanswered {data['ops']}")
    if data["sanitizer"]:
        failed.append(f"sanitizer {data['sanitizer'][:2]}")
    if not data["probe"].get("flowed"):
        failed.append(f"probe {data['probe']}")
    assert not failed, failed
