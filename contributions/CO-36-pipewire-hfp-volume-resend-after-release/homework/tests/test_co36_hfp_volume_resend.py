# -*- coding: utf-8; mode: python; eval: (blacken-mode); -*-
# SPDX-License-Identifier: MIT
"""
CO-36 homework, not part of PipeWire: the delayed HFP volume resend
(backend-native.c, volume_sync_start_timer, 1.5 s) and the SCO link it
was scheduled for.

The AG (host0) sends +VGS/+VGM when a link is ready ("acquire complete")
and again 1.5 s later.  These tests time those frames against the end of
the link, all from host0's own WirePlumber log, so every comparison uses
one clock.  Each test appends what it saw to $CO36_RESULTS (JSON lines).

Run inside PipeWire's test/bluezenv/, next to test_streaming.py.
"""

import json
import os
import re
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Bluetoothctl, host_config

from .test_streaming import (
    VM_MEM,
    PipeWire,
    a2dp_hfp_ag_host,
    a2dp_hfp_hf_host,
    check_pipewire_devices_exist,
    no_profile_autoswitch_config,
)


def ag_host(codecs):
    """a2dp_hfp_ag_host with only <codecs> enabled (bluez5.codecs also
    covers the HFP codecs).  Unused: with "sbc msbc" the links were still
    CVSD (run p0-4, AT+BCS=1), since pw_set_profile's prefix match took
    headset-head-unit-cvsd.  The tests name the codec profile instead."""
    return [
        Bluetoothctl(),
        PipeWire(
            roles="a2dp_source hfp_ag",
            uuids=(
                "0000110a-0000-1000-8000-00805f9b34fb",
                "0000111f-0000-1000-8000-00805f9b34fb",
            ),
            config=no_profile_autoswitch_config
            + f"""
monitor.bluez.properties = {{
  bluez5.codecs = [ {codecs} ]
}}
""",
        ),
    ]


# With every codec enabled, LC3-SWB has the plain "headset-head-unit" name
# and the others carry their codec (bluez5-device.c, "Give base name to
# highest priority profile"), so this prefix is exact
MSBC = "headset-head-unit-msbc"

RESEND_DELAY_NS = 1_500_000_000
# An immediate send leaves in the same sco_ready() call as "acquire complete"
IMMEDIATE_NS = 500_000_000
# Observation after the link is seen up: past the resend deadline, with margin
WINDOW_S = 4.0

# backend-native.c only: bluez5-dbus.c logs "Transport ... released" for A2DP
LINK_UP = re.compile(r"backend-native\.c:\d+:\w+: transport \S+: acquire complete")
LINK_DOWN = re.compile(
    r"backend-native\.c:\d+:\w+: "
    r"(Transport \S+ released|transport \S+: SCO socket (hangup|error)"
    r"|lost RFCOMM connection\.|transport \S+ destroy$"
    # the whole connection, on the AG's request: rfcomm_free() removes the
    # transport listener before freeing it, so no "destroy" line (run p0-6)
    r"|dbus: path=\S+, interface=org\.bluez\.Profile1, "
    r"member=RequestDisconnection)"
)
# Frames the HF (host1) sent as an AG would, and AG frames it received.
# The HF logs "RFCOMM << <buffer>" and the buffer starts with \r\n, so each
# received frame is a log line of its own (backend-native.c L2595)
HF_SENT_AG_FRAME = re.compile(r"RFCOMM >> \+VG[SM]")
HF_GOT = re.compile(r"^\s*\+(VGS|VGM)[:=] ?(\d+)\s*$")
VOLUME = re.compile(r"RFCOMM >> \+(VGS|VGM)[:=] ?(\d+)")
# The codec the HF confirmed; 1 CVSD, 2 mSBC, 3 LC3-SWB (HFP codec IDs)
CODEC = re.compile(r"RFCOMM << AT\+BCS=(\d+)")


def host_events(caplog, idx):
    """(VM nsec, message) of host <idx>'s WirePlumber log, in order"""
    name = re.compile(rf"^host\.\d+\.{idx}\.wireplumber$")
    return [
        (getattr(r, "nsec", int(r.created * 1e9)), r.getMessage())
        for r in list(caplog.records)
        if name.match(r.name)
    ]


def poll_event(caplog, idx, pattern, after_ns=0, timeout=60.0):
    """First host <idx> event matching <pattern> after <after_ns>, polled
    every 20 ms (wait_until polls about once a second, too coarse here)"""
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        for t, msg in host_events(caplog, idx):
            if t > after_ns and pattern.search(msg):
                return t, msg
        time.sleep(0.02)
    raise TimeoutError(f"no {pattern.pattern!r} on host{idx}")


def volume_frames(events, origin_ns, start_ns, end_ns=None):
    """+VGS/+VGM in [start_ns, end_ns), times in ms from origin_ns"""
    out = []
    for t, msg in events:
        if t < start_ns or (end_ns is not None and t >= end_ns):
            continue
        m = VOLUME.search(msg)
        if m:
            out.append({"ms": round((t - origin_ns) / 1e6, 1), "frame": m.group(1)})
    return out


def link_report(caplog, t_up):
    """Split host0's +VGS/+VGM frames around the link that came up at t_up"""
    events = host_events(caplog, 0)

    downs = [t for t, msg in events if t > t_up and LINK_DOWN.search(msg)]
    t_down = downs[0] if downs else None
    ups = [t for t, msg in events if t > t_up and LINK_UP.search(msg)]
    t_next_up = ups[0] if ups else None

    immediate = volume_frames(events, t_up, t_up, t_up + IMMEDIATE_NS)
    active_end = t_down if t_down is not None else t_next_up
    while_active = volume_frames(events, t_up, t_up + IMMEDIATE_NS, active_end)
    late = (
        volume_frames(events, t_up, t_down, t_next_up) if t_down is not None else []
    )

    codecs = [CODEC.search(msg) for t, msg in events if t <= t_up]
    codecs = [int(m.group(1)) for m in codecs if m]

    return {
        "codec": codecs[-1] if codecs else None,
        "down_ms": None if t_down is None else round((t_down - t_up) / 1e6, 1),
        "next_up_ms": None
        if t_next_up is None
        else round((t_next_up - t_up) / 1e6, 1),
        "immediate": immediate,
        "while_active": while_active,
        "after_down": late,
        "lines": [
            msg
            for t, msg in events
            if t >= t_up
            and (
                LINK_UP.search(msg)
                or LINK_DOWN.search(msg)
                or VOLUME.search(msg)
                or CODEC.search(msg)
            )
        ],
    }


def hf_summary(caplog):
    """host1's side, whole test: AG-style frames it sent (none expected)
    and the +VGS/+VGM it received, in order"""
    events = host_events(caplog, 1)
    return {
        "hf_sent_ag_frames": sum(1 for t, m in events if HF_SENT_AG_FRAME.search(m)),
        "hf_received": [m.group(1) for t, msg in events for m in [HF_GOT.search(msg)] if m],
    }


def vm_set_profile_exact(exe_dump, exe_cli, devenv, name):
    """Runs in a VM (host.call): set the bluez5 device's profile to exactly
    <name>; the plugin's pw_set_profile() matches by prefix"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=5
    ).stdout
    for item in json.loads(out):
        if item.get("type") != "PipeWire:Interface:Device":
            continue
        if item["info"]["props"].get("device.api") != "bluez5":
            continue
        for entry in item["info"]["params"].get("EnumProfile", []):
            if entry["name"] != name:
                continue
            subprocess.run(
                [
                    exe_cli,
                    "set-param",
                    str(item["id"]),
                    "Profile",
                    json.dumps({"index": entry["index"], "save": False}),
                ],
                env=env,
                check=True,
                timeout=30,
            )
            return name
    raise ValueError(f"no profile {name} on the bluez5 device")


def set_profile_exact(host, plugin, name):
    """<plugin>: the host-side PipeWire plugin object of that host's
    host_config list, whose presetup() found the executables"""
    return host.call(
        vm_set_profile_exact, plugin.exe_dump, plugin.exe_cli, plugin.devenv, name
    )


_REP = {"rep": 0, "nodeid": ""}


def record(name, report):
    path = Path(os.environ.get("CO36_RESULTS", "co36-results.jsonl"))
    entry = dict(
        test=name,
        build=os.environ.get("CO36_BUILD", ""),
        run=os.environ.get("CO36_RUN", ""),
        rep=_REP["rep"],
        nodeid=_REP["nodeid"],
        **report,
    )
    with open(path, "a") as f:
        f.write(json.dumps(entry) + "\n")


# --- Repeats and the per-test ledger (agent-work/co36 additions) -----------
#
# CO36_REPEAT=n runs every selected test n times (a "co36_rep" parameter),
# so a rate is measured from n independent VM pairs, not from pytest's one
# rerun of a failure.


def pytest_generate_tests(metafunc):
    n = int(os.environ.get("CO36_REPEAT", "1") or "1")
    if "co36_rep" in metafunc.fixturenames:
        metafunc.parametrize("co36_rep", list(range(n)), indirect=True)


AG_SENT = re.compile(r"RFCOMM >> \+(VGS|VGM)[:=] ?(\d+)")
SANITIZER = re.compile(
    r"AddressSanitizer|LeakSanitizer|UndefinedBehaviorSanitizer|runtime error:"
)


def gain_ledger(caplog_records, ag_idx=0, hf_idxs=(1,)):
    """T233: every +VGS/+VGM host <ag_idx> wrote, and every one each HF
    logged as received, with values, in order"""
    ag = re.compile(rf"^host\.\d+\.{ag_idx}\.wireplumber$")
    out = {"ag_sent": [], "hf_received": {}}
    for r in caplog_records:
        if ag.match(r.name):
            m = AG_SENT.search(r.getMessage())
            if m:
                out["ag_sent"].append(f"{m.group(1)}:{m.group(2)}")
    for idx in hf_idxs:
        hf = re.compile(rf"^host\.\d+\.{idx}\.wireplumber$")
        got = []
        for r in caplog_records:
            if hf.match(r.name):
                m = HF_GOT.search(r.getMessage())
                if m:
                    got.append(f"{m.group(1)}:{m.group(2)}")
        out["hf_received"][str(idx)] = got
    return out


@pytest.fixture(autouse=True)
def co36_rep(request, caplog):
    """Repeat index (CO36_REPEAT), and after the test one "ledger" line:
    the AG's sent gains against each HF's received ones (T233) and any
    sanitizer line seen in the setup and call phases (T236)"""
    rep = getattr(request, "param", 0)
    _REP["rep"] = rep
    _REP["nodeid"] = request.node.nodeid
    yield rep
    records = caplog.get_records("setup") + caplog.get_records("call")
    nhosts = getattr(request.node, "co36_nhosts", 2)
    ledger = gain_ledger(records, 0, tuple(range(1, nhosts)))
    ledger["sanitizer_lines"] = [
        f"{r.name}: {r.getMessage()}" for r in records if SANITIZER.search(r.getMessage())
    ][:20]
    record("ledger", ledger)


def connect_hfp(host0, host1, profile="headset-head-unit"):
    """Connect and switch host0 to a hands-free profile.  pw_set_profile()
    matches by prefix, so the default takes the first listed, CVSD here;
    each record says which codec was used"""
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send(f"scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")

    host0.pipewire.pw_set_profile(profile)
    check_pipewire_devices_exist(host0, "hfp")


def check_short_link(report):
    """The common verdict of a link meant to end before the resend"""
    require_immediate_volume(report)
    if report["down_ms"] is None:
        pytest.fail(f"link did not end: {report['lines']}")
    if report["down_ms"] >= RESEND_DELAY_NS / 1e6:
        pytest.skip(f"link ended at {report['down_ms']} ms, not before the resend")

    late_vgm = [f for f in report["after_down"] if f["frame"] == "VGM"]
    assert not late_vgm, f"+VGM after the link ended: {report}"


def sco_disconnect(dev_id=0):
    """
    Runs in a VM (host.call): HCI Disconnect, reason Remote User Terminated,
    of every SCO/eSCO link of hci<dev_id>, as a headset ending the audio
    while keeping RFCOMM.  Returns the handles.
    """
    import fcntl
    import socket
    import struct

    HCIGETCONNLIST = 0x800448D4  # _IOR('H', 212, int)
    SCO_LINK, ESCO_LINK = 0x00, 0x02
    max_conn = 16

    with socket.socket(
        socket.AF_BLUETOOTH, socket.SOCK_RAW, socket.BTPROTO_HCI
    ) as s:
        s.bind((dev_id,))

        # struct hci_conn_list_req + max_conn struct hci_conn_info (16 bytes)
        req = bytearray(struct.pack("<HH", dev_id, max_conn) + bytes(16 * max_conn))
        fcntl.ioctl(s.fileno(), HCIGETCONNLIST, req)
        _, num = struct.unpack_from("<HH", req, 0)

        handles = []
        for i in range(num):
            handle, _, link_type = struct.unpack_from("<H6sB", req, 4 + 16 * i)
            if link_type in (SCO_LINK, ESCO_LINK):
                handles.append(handle)

        for handle in handles:
            # HCI command packet: Disconnect (0x0406), handle, reason 0x13
            s.send(struct.pack("<BHBHB", 0x01, 0x0406, 3, handle, 0x13))

    return handles


def require_immediate_volume(report):
    """Without hardware gain on this link nothing is sent at all, and a
    test of the resend would pass without exercising it"""
    frames = {f["frame"] for f in report["immediate"]}
    if frames != {"VGS", "VGM"}:
        pytest.skip(f"no immediate +VGS/+VGM on link up: {report['lines']}")


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_short_link(paired_hosts, caplog):
    """
    The AG ends the link well inside 1.5 s, with the RFCOMM link kept up: a
    profile switch releases the transport at once (release_now), unlike a
    stream stop, which keeps it 1 s longer.  Records which frames of the
    resend leave after the link ended; fails if a +VGM does.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)

    host0.pipewire.pw_set_profile("a2dp-sink")
    time.sleep(WINDOW_S)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    record("short_link", report)
    check_short_link(report)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_short_link_msbc(paired_hosts, caplog):
    """As test_co36_short_link, on the mSBC profile"""
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)

    host0.pipewire.pw_set_profile("a2dp-sink")
    time.sleep(WINDOW_S)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    record("short_link_msbc", report)
    if report["codec"] != 2:
        pytest.fail(f"not mSBC: codec {report['codec']}")
    check_short_link(report)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_stream_stop(paired_hosts, caplog):
    """
    The stream ends at once and the profile stays: the plain "stopped
    using the headset" case.  Records when the transport is released (run
    p0-4: not within 4 s; the node is suspended only after it idles, and
    the generic layer delays an active transport's release by
    TRANSPORT_RELEASE_TIMEOUT_MSEC) and which frames leave after that.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)

    host0.pipewire.pw_stop_streams()
    poll_event(caplog, 0, LINK_DOWN, after_ns=t_up, timeout=20.0)
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    record("stream_stop", report)
    check_short_link(report)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_reacquire(paired_hosts, caplog):
    """
    A new link inside 1.5 s of the first: the first link's resend should be
    replaced by the second's (one timer per RFCOMM link, re-armed by
    sco_ready), so nothing leaves between the links, and the second link
    gets its own resend while it is up.  CVSD, the quicker to reconnect
    here (run p0-4: second link at 1465 ms).
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)

    host0.pipewire.pw_set_profile("a2dp-sink")
    t_down, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    host0.pipewire.pw_set_profile("headset-head-unit")
    t_up2, _ = poll_event(caplog, 0, LINK_UP, after_ns=t_down)

    time.sleep(WINDOW_S)
    host0.pipewire.pw_set_profile("a2dp-sink")
    poll_event(caplog, 0, LINK_DOWN, after_ns=t_up2)
    host0.pipewire.pw_stop_streams()

    first = link_report(caplog, t_up)
    second = link_report(caplog, t_up2)
    record("reacquire", dict(first=first, second=second))

    require_immediate_volume(first)
    require_immediate_volume(second)
    if first["next_up_ms"] is None or first["next_up_ms"] >= RESEND_DELAY_NS / 1e6:
        pytest.skip(f"second link at {first['next_up_ms']} ms, not before the resend")

    assert not first["after_down"], f"frames between the links: {first}"
    resent = {f["frame"] for f in second["while_active"]}
    assert resent == {"VGS", "VGM"}, f"second link's resend missing: {second}"


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_remote_hangup(paired_hosts, caplog):
    """
    The headset (host1) ends the link inside 1.5 s, RFCOMM kept up: the AG
    sees a hang-up on its SCO socket (sco_event), not a release.  Records
    which frames of the resend leave after that; fails if a +VGM does.
    A new link before the deadline re-arms the timer, so it is not counted.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)

    handles = host1.call(sco_disconnect)
    time.sleep(WINDOW_S)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    report["handles"] = handles
    record("remote_hangup", report)

    require_immediate_volume(report)
    if not handles:
        pytest.fail("host1 had no SCO/eSCO link to disconnect")
    if report["down_ms"] is None:
        pytest.fail(f"link did not end: {report['lines']}")
    if report["down_ms"] >= RESEND_DELAY_NS / 1e6:
        pytest.skip(f"link ended at {report['down_ms']} ms, not before the resend")
    if (
        report["next_up_ms"] is not None
        and report["next_up_ms"] < RESEND_DELAY_NS / 1e6
    ):
        pytest.skip(f"new link at {report['next_up_ms']} ms re-armed the timer")

    late_vgm = [f for f in report["after_down"] if f["frame"] == "VGM"]
    assert not late_vgm, f"+VGM after the link ended: {report}"


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_long_link(paired_hosts, caplog):
    """
    Control: the link outlives the delay, so the resend leaves while it is
    active, as intended.  A change that drops the resend fails here.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)

    time.sleep(WINDOW_S)
    host0.pipewire.pw_set_profile("a2dp-sink")
    poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    record("long_link", report)

    require_immediate_volume(report)
    resent = {f["frame"] for f in report["while_active"]}
    assert resent == {"VGS", "VGM"}, f"resend missing while active: {report}"
    assert not report["after_down"], f"frames after the link ended: {report}"


# --- Batch 2 (TEST-PLAN.md L2: T210-T235) ---------------------------------

AG = a2dp_hfp_ag_host[1]  # host-side PipeWire plugin of host0, for set_profile_exact


def one_link(host0, host1, caplog, name, end, profile=MSBC, exact=False, extra=None):
    """Connect, open one link on <profile>, call end(host0, host1) at once,
    observe WINDOW_S, record and return the report (<extra> merged in)"""
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send(f"scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    if exact:
        set_profile_exact(host0, AG, profile)
    else:
        host0.pipewire.pw_set_profile(profile)
    check_pipewire_devices_exist(host0, "hfp")

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    end(host0, host1)
    time.sleep(WINDOW_S)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    report.update(hf_summary(caplog))
    if extra:
        report.update(extra)
    record(name, report)
    return report


def end_switch(host0, host1):
    host0.pipewire.pw_set_profile("a2dp-sink")


def end_hangup(host0, host1):
    assert host1.call(sco_disconnect), "host1 had no SCO/eSCO link"


def end_hf_disconnect(host0, host1):
    host1.bluetoothctl.send(f"disconnect {host0.bdaddr}\n")


def end_ag_disconnect(host0, host1):
    host0.bluetoothctl.send(f"disconnect {host1.bdaddr}\n")


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t210_short_link_lc3swb(paired_hosts, caplog):
    """T210: short link on the best codec's profile (plain name)"""
    report = one_link(
        *paired_hosts, caplog, "t210_short_lc3swb", end_switch,
        profile="headset-head-unit", exact=True,
    )
    check_short_link(report)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t211_long_link_msbc(paired_hosts, caplog):
    """T211: long link, mSBC: resend while up, nothing after"""

    def end(host0, host1):
        time.sleep(WINDOW_S)
        host0.pipewire.pw_set_profile("a2dp-sink")

    report = one_link(*paired_hosts, caplog, "t211_long_msbc", end)
    require_immediate_volume(report)
    assert report["codec"] == 2, f"not mSBC: {report['codec']}"
    assert {f["frame"] for f in report["while_active"]} == {"VGS", "VGM"}, report
    assert not report["after_down"], report


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t213_remote_hangup_msbc(paired_hosts, caplog):
    """T213: the headset hangs up an mSBC link, RFCOMM kept"""
    report = one_link(*paired_hosts, caplog, "t213_hangup_msbc", end_hangup)
    assert report["codec"] == 2, f"not mSBC: {report['codec']}"
    check_short_link(report)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t217_hf_disconnects(paired_hosts, caplog):
    """T217: the headset drops the whole connection within 1.5 s: the
    RFCOMM connection is freed with its timer; nothing may be written and
    the AG must not crash"""
    report = one_link(*paired_hosts, caplog, "t217_hf_disconnect", end_hf_disconnect)
    require_immediate_volume(report)
    assert report["down_ms"] is not None, report
    assert not report["after_down"], report
    paired_hosts[0].pipewire.check_running()


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t218_ag_disconnects(paired_hosts, caplog):
    """T218: the AG drops the whole connection within 1.5 s"""
    report = one_link(*paired_hosts, caplog, "t218_ag_disconnect", end_ag_disconnect)
    require_immediate_volume(report)
    assert report["down_ms"] is not None, report
    assert not report["after_down"], report
    paired_hosts[0].pipewire.check_running()


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t220_codec_switch(paired_hosts, caplog):
    """T220: codec switch (mSBC to CVSD) within 1.5 s of link up:
    AT+BCS= stops the timer today, so no frame between the links"""

    def end(host0, host1):
        set_profile_exact(host0, AG, "headset-head-unit-cvsd")

    report = one_link(*paired_hosts, caplog, "t220_codec_switch", end)
    require_immediate_volume(report)
    assert report["codec"] == 2, f"first link not mSBC: {report['codec']}"
    assert report["down_ms"] is not None, report
    assert not report["after_down"], f"frames between the links: {report}"


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t223_duration_sweep(paired_hosts, caplog):
    """T222/T223: one connection, links of set lengths (switch away after
    a sleep), 2.5 s apart so each link's resend falls in its own gap.
    Fails if any link that ended before 1.5 s is followed by a +VGM."""
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    host0.pipewire.pw_set_profile("a2dp-sink")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    host0.pipewire.pw_play()

    holds = [0.1, 0.3, 0.6, 0.9, 1.2, 1.4, 1.6, 2.0, 0.1, 0.1, 0.1, 0.1, 0.1]
    links = []
    t_last = 0
    for hold in holds:
        host0.pipewire.pw_set_profile(MSBC)
        t_up, _ = poll_event(caplog, 0, LINK_UP, after_ns=t_last)
        time.sleep(hold)
        host0.pipewire.pw_set_profile("a2dp-sink")
        t_last, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
        time.sleep(2.5)
        links.append((hold, t_up))
    host0.pipewire.pw_stop_streams()

    reports = []
    for hold, t_up in links:
        r = link_report(caplog, t_up)
        r["hold_s"] = hold
        del r["lines"]
        reports.append(r)
    record("t223_sweep", dict(links=reports, **hf_summary(caplog)))

    leaked = [
        r for r in reports
        if r["down_ms"] is not None and r["down_ms"] < RESEND_DELAY_NS / 1e6
        and any(f["frame"] == "VGM" for f in r["after_down"])
    ]
    assert not leaked, f"{len(leaked)} short links leaked: {reports}"


hsp_ag_host = [
    Bluetoothctl(),
    PipeWire(
        roles="hsp_ag",
        uuids=("00001112-0000-1000-8000-00805f9b34fb",),
        config=no_profile_autoswitch_config,
    ),
]

hsp_hs_host = [
    Bluetoothctl(),
    PipeWire(roles="hsp_hs", uuids=("00001108-0000-1000-8000-00805f9b34fb",)),
]


@host_config(hsp_ag_host, hsp_hs_host, mem=VM_MEM)
def test_co36_t229_hsp(paired_hosts, caplog):
    """T229/T230: HSP. The HS reports its gains only once audio connects
    (backend-native.c L3068), so link 1 (long) makes them active and
    link 2 (short) is the one judged."""
    host0, host1 = paired_hosts
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send(f"scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "device")
    # the device lists only "off" until the HSP connection is up (run p0-6)
    end = time.monotonic() + 30
    while True:
        try:
            host0.pipewire.pw_set_profile("headset-head-unit")
            break
        except Exception:
            if time.monotonic() > end:
                # run p0-7: HSP connected (profiles 00000020) but WirePlumber
                # found "0 available" and the device offers only "off"
                pytest.skip("blocked: the HSP device offers no headset-head-unit profile")
            time.sleep(0.5)
    check_pipewire_devices_exist(host0, "hfp")

    host0.pipewire.pw_play()
    t_up1, _ = poll_event(caplog, 0, LINK_UP)
    time.sleep(WINDOW_S)
    host0.pipewire.pw_set_profile("off")
    t_down1, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up1)
    time.sleep(2.0)

    host0.pipewire.pw_set_profile("headset-head-unit")
    t_up2, _ = poll_event(caplog, 0, LINK_UP, after_ns=t_down1)
    host0.pipewire.pw_set_profile("off")
    # HSP's first link has no immediate send: the HS reports its gains only
    # after audio connects; the second link is the one judged
    time.sleep(WINDOW_S)
    host0.pipewire.pw_stop_streams()

    first = link_report(caplog, t_up1)
    second = link_report(caplog, t_up2)
    record("t229_hsp", dict(first=first, second=second, **hf_summary(caplog)))
    check_short_link(second)


hw_volume_off_ag_host = [
    Bluetoothctl(),
    PipeWire(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
        config=no_profile_autoswitch_config
        + """
monitor.bluez.properties = {
  bluez5.enable-hw-volume = false
}
""",
    ),
]


@host_config(hw_volume_off_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t232_hw_volume_off(paired_hosts, caplog):
    """T232: hardware volume off on the AG: no +VGS/+VGM on any link, the
    timer notwithstanding.  Checks the setting took (hw-volume-profiles:0)"""
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_set_profile("a2dp-sink")
    time.sleep(WINDOW_S)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    report.update(hf_summary(caplog))
    hw = [m for t, m in host_events(caplog, 0) if "hw-volume-profiles:" in m]
    report["hw_volume_lines"] = hw
    record("t232_hw_volume_off", report)

    assert hw and all(m.endswith("hw-volume-profiles:00000000") for m in hw), hw
    frames = report["immediate"] + report["while_active"] + report["after_down"]
    assert not frames, report


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t235_a2dp_after_short_link(paired_hosts, caplog):
    """T235: A2DP audio flows after a short HFP link (and its late frames)"""
    host0, host1 = paired_hosts
    report = one_link(host0, host1, caplog, "t235_a2dp_after", end_switch)
    host0.pipewire.pw_play()
    host1.pipewire.pw_record()
    assert host1.pipewire.pw_record_wait_signal(), report


# --- Batch 3: user volume (T225-T228) and WirePlumber policy (T301-T307) ---

HF = a2dp_hfp_hf_host[1]  # host-side PipeWire plugin of host1


def vm_pw_dump(exe_dump, devenv):
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=5
    ).stdout
    return json.loads(out)


def vm_set_node_volume(exe_dump, exe_cli, devenv, factory, volume):
    """Runs in a VM: set channelVolumes of the node made by <factory>
    (api.bluez5.sco.sink = speaker, TX; api.bluez5.sco.source = mic, RX)"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    for item in vm_pw_dump(exe_dump, devenv):
        if item.get("type") != "PipeWire:Interface:Node":
            continue
        if item["info"]["props"].get("factory.name") != factory:
            continue
        subprocess.run(
            [
                exe_cli,
                "set-param",
                str(item["id"]),
                "Props",
                json.dumps({"channelVolumes": [volume]}),
            ],
            env=env,
            check=True,
            timeout=30,
        )
        return item["id"]
    raise ValueError(f"no node from {factory}")


def set_node_volume(host, plugin, factory, volume):
    return host.call(
        vm_set_node_volume, plugin.exe_dump, plugin.exe_cli, plugin.devenv,
        factory, volume,
    )


_CAPTURES = {}


def vm_capture_start(exe_dump, exe_record, devenv):
    """Runs in a VM: record from the device's WirePlumber loopback source
    (bluez_input.*), as an app opening the headset microphone would"""
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    names = [
        item["info"]["props"]["node.name"]
        for item in vm_pw_dump(exe_dump, devenv)
        if item.get("type") == "PipeWire:Interface:Node"
        and item["info"]["props"].get("node.name", "").startswith("bluez_input.")
    ]
    if not names:
        raise ValueError("no bluez_input.* loopback source")
    proc = subprocess.Popen(
        [exe_record, "--target", names[0], "/tmp/co36-capture.wav"],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    _CAPTURES[proc.pid] = proc
    return proc.pid


def vm_capture_stop(pid):
    proc = _CAPTURES.pop(pid)
    proc.terminate()
    proc.wait(timeout=10)


def capture_start(host, plugin):
    return host.call(vm_capture_start, plugin.exe_dump, plugin.exe_record, plugin.devenv)


def capture_stop(host, pid):
    host.call(vm_capture_stop, pid)


def ag_frames(caplog, start_ns, end_ns=None):
    return volume_frames(host_events(caplog, 0), start_ns, start_ns, end_ns)


def now_ns(caplog, idx=0):
    """Latest VM time seen in host <idx>'s log: "now" on that VM's clock,
    to within the log's latency"""
    events = host_events(caplog, idx)
    return events[-1][0] if events else 0


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t225_user_volume_no_link(paired_hosts, caplog):
    """T225/T226: a user volume change on the AG reaches the headset with no
    audio link (HFP profile, no stream) and during one"""
    # run p0-8: node Props channelVolumes never reached hardware volume (no
    # +VGS at all); the change has to go through the device's Route param
    pytest.skip("method invalid: node Props do not reach hardware volume")
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    time.sleep(2.0)

    t0 = now_ns(caplog)
    set_node_volume(host0, AG, "api.bluez5.sco.sink", 0.3)
    time.sleep(1.0)
    no_link = ag_frames(caplog, t0)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP, after_ns=t0)
    time.sleep(0.3)
    t1 = now_ns(caplog)
    set_node_volume(host0, AG, "api.bluez5.sco.sink", 0.7)
    time.sleep(1.0)
    during = ag_frames(caplog, t1)
    host0.pipewire.pw_stop_streams()

    record("t225_user_volume", dict(no_link=no_link, during=during, **hf_summary(caplog)))
    assert [f["frame"] for f in no_link] == ["VGS"], no_link
    assert "VGS" in [f["frame"] for f in during], during


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t227_user_volume_after_short_link(paired_hosts, caplog):
    """T227: a user volume change 200 ms after a short link ended, resend
    still pending: the change is sent at once (I4), whatever happens to
    the pending resend"""
    # run p0-8 passed only by counting the late resend as the change; same
    # method problem as T225
    pytest.skip("method invalid: node Props do not reach hardware volume")
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_set_profile("a2dp-sink")
    t_down, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    # stream off first: with it playing, the switch back would open a new
    # link and re-arm the timer
    host0.pipewire.pw_stop_streams()
    host0.pipewire.pw_set_profile(MSBC)
    check_pipewire_devices_exist(host0, "hfp")
    t1 = now_ns(caplog)
    set_node_volume(host0, AG, "api.bluez5.sco.sink", 0.3)
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    report["user_change_from_ms"] = round((t1 - t_up) / 1e6, 1)
    report["frames_after_change"] = ag_frames(caplog, t1)
    for f in report["frames_after_change"]:
        f["ms"] = round(f["ms"] + (t1 - t_up) / 1e6, 1)
    report.update(hf_summary(caplog))
    record("t227_user_volume_after_short", report)
    assert "VGS" in [f["frame"] for f in report["frames_after_change"]], report


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t228_hf_volume_change(paired_hosts, caplog):
    """T228: the headset changes its own speaker volume after a short
    link: it sends AT+VGS=, the AG takes it (I5)"""
    # run p0-8: the HF had no api.bluez5.sco.source node at that point
    pytest.skip("method invalid: no HF node to set; to be reworked")
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_set_profile("a2dp-sink")
    t_down, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    host0.pipewire.pw_stop_streams()
    time.sleep(2.0)

    t1 = now_ns(caplog)
    set_node_volume(host1, HF, "api.bluez5.sco.source", 0.3)
    got = poll_event(caplog, 0, re.compile(r"RFCOMM << AT\+VGS=\d+"), after_ns=t1, timeout=10)

    report = link_report(caplog, t_up)
    report["ag_received"] = got[1]
    report.update(hf_summary(caplog))
    record("t228_hf_volume_change", report)


autoswitch_ag_host = [
    Bluetoothctl(),
    PipeWire(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
    ),
]
AS_AG = autoswitch_ag_host[1]

restore_zero_ag_host = [
    Bluetoothctl(),
    PipeWire(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
        config="""
wireplumber.settings = {
  bluetooth.autoswitch-restore-timeout = 0
}
""",
    ),
]
RZ_AG = restore_zero_ag_host[1]


def policy_captures(host0, host1, caplog, name, plugin, holds, gap=3.0):
    """Captures of <holds> seconds each, <gap> s apart, the policy doing
    every profile switch; one report per link seen"""
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send(f"scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    time.sleep(2.0)

    t_start = now_ns(caplog)
    for hold in holds:
        pid = capture_start(host0, plugin)
        time.sleep(hold)
        capture_stop(host0, pid)
        time.sleep(gap)
    time.sleep(6.0)  # past the restore timeout and a resend

    ups = [t for t, m in host_events(caplog, 0) if t > t_start and LINK_UP.search(m)]
    reports = []
    for t_up in ups:
        r = link_report(caplog, t_up)
        del r["lines"]
        reports.append(r)
    record(name, dict(holds=holds, links=reports, **hf_summary(caplog)))
    return reports


def leaked_links(reports):
    return [
        r for r in reports
        if r["down_ms"] is not None and r["down_ms"] < RESEND_DELAY_NS / 1e6
        and any(f["frame"] == "VGM" for f in r["after_down"])
    ]


@host_config(autoswitch_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t301_policy_capture(paired_hosts, caplog):
    """T301/T302/T304: an app records from the headset for 3 s, the policy
    switches to HFP and back (restore after 4 s on master); then a capture
    restarted inside the restore timeout"""
    reports = policy_captures(
        *paired_hosts, caplog, "t301_policy_capture", AS_AG, [3.0, 0.5, 0.5], gap=1.0
    )
    assert reports, "the policy opened no link"
    assert not leaked_links(reports), reports


@host_config(autoswitch_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t303_policy_brief_captures(paired_hosts, caplog):
    """T303/T307: captures of 0.2 and 0.6 s, 5 s apart (past the restore),
    as an app probing the microphone"""
    reports = policy_captures(
        *paired_hosts, caplog, "t303_policy_brief", AS_AG, [0.2, 0.6, 0.2, 0.6], gap=5.0
    )
    assert not leaked_links(reports), reports


@host_config(restore_zero_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t305_policy_restore_zero(paired_hosts, caplog):
    """T305: restore timeout 0 (a user setting): short captures make short
    links, the policy itself ending them"""
    reports = policy_captures(
        *paired_hosts, caplog, "t305_policy_restore_zero", RZ_AG, [0.3, 0.6, 1.0], gap=4.0
    )
    assert reports, "the policy opened no link"
    assert not leaked_links(reports), reports


# --- Batch 4 (agent-work/co36, 2026-10-31): the plan's tests not yet run
# on master (T212-T239), T225/T227/T228 redone through the device's Route
# param, and T306-T308 ------------------------------------------------------

import math

from .test_streaming import BluetoothdWithRestart

# bluez5-device.c:3111 node_set_volume(), the AG's side of a user change
USER_VOL = re.compile(r"node_set_volume: node (\d+) volume ([0-9.]+)")
# The AG received a gain report from the HF (backend-native.c L1385-L1401)
AG_GOT_VGS = re.compile(r"RFCOMM << AT\+VGS=(\d+)")
AG_GOT_VG = re.compile(r"RFCOMM << AT\+(VGS|VGM)=(\d+)")
VOLUME_CHANGED = re.compile(r"rfcomm_emit_volume_changed: volume changed (-?\d+)")


def hw_gain(linear, hw_max=15):
    """spa_bt_volume_linear_to_hw() (defs.h:805): lround(cbrt(v) * max)"""
    if linear <= 0:
        return 0
    if linear >= 1:
        return hw_max
    return int(math.floor(math.cbrt(linear) * hw_max + 0.5))


def frames_with_values(caplog, idx, origin_ns, start_ns, end_ns=None):
    """+VGS/+VGM written by host <idx> in [start_ns, end_ns), with values,
    times in ms from origin_ns"""
    out = []
    for t, msg in host_events(caplog, idx):
        if t < start_ns or (end_ns is not None and t >= end_ns):
            continue
        m = VOLUME.search(msg)
        if m:
            out.append(
                {"ms": round((t - origin_ns) / 1e6, 1), "frame": m.group(1), "value": int(m.group(2))}
            )
    return out


def wait_hf_gains(caplog, timeout=30.0):
    """The HF reports AT+VGS (and AT+VGM) once the SLC is up; until then
    no gain is active and nothing would be sent"""
    return poll_event(caplog, 0, AG_GOT_VGS, timeout=timeout)


def vm_route_param(exe_dump, devenv, direction, address=None):
    """Runs in a VM: (device id, Route param JSON skeleton, current route
    props) for the active route of <direction> ("Output" = speaker, the
    HFP sink, TX, +VGS; "Input" = microphone, RX, +VGM) of the bluez5
    device (of <address>, if given)"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=10
    ).stdout
    for item in json.loads(out):
        if item.get("type") != "PipeWire:Interface:Device":
            continue
        props = item["info"]["props"]
        if props.get("device.api") != "bluez5":
            continue
        if address and props.get("api.bluez5.address", "").lower() != address.lower():
            continue
        for route in item["info"]["params"].get("Route", []):
            if route.get("direction") != direction:
                continue
            nch = len(route.get("props", {}).get("channelVolumes", [])) or 1
            return {
                "device_id": item["id"],
                "index": route["index"],
                "device": route["device"],
                "name": route.get("name"),
                "nch": nch,
                "props_before": route.get("props", {}),
            }
    raise ValueError(f"no active {direction} route on the bluez5 device {address}")


def vm_set_route_volume(exe_cli, devenv, route, volume):
    """Runs in a VM: pw-cli set-param <device> Route { index, device,
    props: { channelVolumes } }: the path a user's volume change takes
    (bluez5-device.c:3373 -> apply_device_props -> node_set_volume ->
    spa_bt_transport_set_volume -> sco_set_volume_cb)"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    param = {
        "index": route["index"],
        "device": route["device"],
        "props": {"channelVolumes": [volume] * route["nch"]},
        "save": False,
    }
    res = subprocess.run(
        [exe_cli, "set-param", str(route["device_id"]), "Route", json.dumps(param)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        env=env,
        timeout=30,
    )
    return {"rc": res.returncode, "out": res.stdout[-500:], "param": param}


def route_of(host, plugin, direction, address=None):
    return host.call(vm_route_param, plugin.exe_dump, plugin.devenv, direction, address)


def set_route_volume(host, plugin, route, volume):
    return host.call(vm_set_route_volume, plugin.exe_cli, plugin.devenv, route, volume)


def user_change(caplog, host0, route, volume, frame, settle=1.0):
    """One user volume change on the AG through the Route param; returns
    what the AG wrote after it, timed from its node_set_volume line"""
    t0 = now_ns(caplog)
    cli = set_route_volume(host0, AG, route, volume)
    anchor_t, anchor_msg = poll_event(caplog, 0, USER_VOL, after_ns=t0, timeout=10)
    time.sleep(settle)
    frames = frames_with_values(caplog, 0, anchor_t, anchor_t)
    want = hw_gain(volume)
    first = next((f for f in frames if f["frame"] == frame), None)
    return {
        "volume": volume,
        "want": {"frame": frame, "value": want},
        "anchor_t": anchor_t,
        "anchor": anchor_msg,
        "cli": cli,
        "frames_after": frames,
        "first_ms": first["ms"] if first else None,
        "first_value": first["value"] if first else None,
    }


def hf_volume_changes(caplog, idx=1):
    return [int(m.group(1)) for t, msg in host_events(caplog, idx) for m in [VOLUME_CHANGED.search(msg)] if m]


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t225r_route_volume(paired_hosts, caplog):
    """
    T225/T226, redone: a user volume change on the AG goes through the
    device's Route param, as a desktop's volume control does (pw-cli here;
    pipewire-pulse and wpctl end in the same set-param).  No link: speaker
    then microphone; then during a link, after its resend.  Each change
    must leave at once with the converted gain, and the HF must take it.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    wait_hf_gains(caplog)
    time.sleep(1.0)

    out_route = route_of(host0, AG, "Output")
    in_route = route_of(host0, AG, "Input")
    hf_before = len(hf_volume_changes(caplog))

    no_link_spk = user_change(caplog, host0, out_route, 0.3, "VGS")
    no_link_mic = user_change(caplog, host0, in_route, 0.3, "VGM")

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP, after_ns=no_link_mic["anchor_t"])
    time.sleep(2.0)  # past the link's own resend
    during_spk = user_change(caplog, host0, out_route, 0.6, "VGS")
    downs_before_change = [
        t for t, m in host_events(caplog, 0) if t > t_up and LINK_DOWN.search(m) and t < during_spk["anchor_t"]
    ]
    host0.pipewire.pw_stop_streams()

    hf_after = hf_volume_changes(caplog)[hf_before:]
    report = {
        "routes": {"Output": out_route, "Input": in_route},
        "no_link_speaker": no_link_spk,
        "no_link_mic": no_link_mic,
        "during_link_speaker": dict(during_spk, link_up_ms_before=round((during_spk["anchor_t"] - t_up) / 1e6, 1)),
        "link_ended_before_change": bool(downs_before_change),
        "hf_volume_changed": hf_after,
    }
    report.update(hf_summary(caplog))
    record("t225r_route_volume", report)

    for step in (no_link_spk, no_link_mic, during_spk):
        assert step["cli"]["rc"] == 0, step
        assert step["first_value"] == step["want"]["value"], step
        assert step["first_ms"] is not None and step["first_ms"] < 200, step
    assert not downs_before_change, "link ended before the change during it"
    for step in (no_link_spk, no_link_mic, during_spk):
        assert step["want"]["value"] in hf_after, (step, hf_after)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t227r_route_volume_after_short_link(paired_hosts, caplog):
    """
    T227, redone: a user change while a short link's resend is pending.
    The link is ended by the headset (HCI Disconnect), so the profile and
    its routes stay; the change goes through the Route param at once.
    I4: the change leaves at once with its value, before the resend
    deadline.  Recorded besides: the pending resend (master: late, after
    the link ended, carrying the new value).
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    wait_hf_gains(caplog)
    time.sleep(1.0)
    out_route = route_of(host0, AG, "Output")

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    handles = host1.call(sco_disconnect)
    t_down, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up, timeout=10)
    change = user_change(caplog, host0, out_route, 0.3, "VGS", settle=0.0)
    host0.pipewire.pw_stop_streams()
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    report["handles"] = handles
    change["frames_after"] = frames_with_values(caplog, 0, change["anchor_t"], change["anchor_t"])
    first = next((f for f in change["frames_after"] if f["frame"] == "VGS"), None)
    change["first_ms"] = first["ms"] if first else None
    change["first_value"] = first["value"] if first else None
    report["change"] = change
    report["change_from_up_ms"] = round((change["anchor_t"] - t_up) / 1e6, 1)
    report["frames_from_up"] = frames_with_values(caplog, 0, t_up, t_up)
    report.update(hf_summary(caplog))
    report["hf_volume_changed"] = hf_volume_changes(caplog)
    valid = (
        report["down_ms"] is not None
        and report["down_ms"] < RESEND_DELAY_NS / 1e6
        and report["change_from_up_ms"] < RESEND_DELAY_NS / 1e6
        and (report["next_up_ms"] is None or report["next_up_ms"] > report["change_from_up_ms"])
    )
    report["valid_window"] = valid
    record("t227r_route_volume_after_short_link", report)

    assert change["cli"]["rc"] == 0, change
    if not valid:
        pytest.skip(f"not inside the pending-resend window: {report['down_ms']}, {report['change_from_up_ms']}, {report['next_up_ms']}")
    assert change["first_value"] == change["want"]["value"], change
    assert change["first_ms"] is not None and change["first_ms"] < 200, change
    assert report["change_from_up_ms"] + change["first_ms"] < RESEND_DELAY_NS / 1e6, report


def vm_hf_set_gain(name, value):
    """Runs in the HF VM: set the PipeWire HF's own gain through its
    telephony service (org.pipewire.Telephony.AudioGateway1 <name>,
    telephony.c:905), which sends AT+VGS=/AT+VGM= (backend-native.c:1925,
    hfp_hf_set_speaker_volume).  A Route change on the HF does not: its
    sco_set_volume_cb() returns -ENOTSUP for an AG remote (L3165-L3168)."""
    import re
    import subprocess

    objs = subprocess.run(
        [
            "gdbus", "call", "--session", "--dest", "org.pipewire.Telephony",
            "--object-path", "/org/pipewire/Telephony",
            "--method", "org.freedesktop.DBus.ObjectManager.GetManagedObjects",
        ],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", timeout=15,
    )
    paths = sorted(set(re.findall(r"/org/pipewire/Telephony/ag\d+", objs.stdout)))
    if not paths:
        return {"error": objs.stdout[-1000:]}
    res = subprocess.run(
        [
            "gdbus", "call", "--session", "--dest", "org.pipewire.Telephony",
            "--object-path", paths[0],
            "--method", "org.freedesktop.DBus.Properties.Set",
            "org.pipewire.Telephony.AudioGateway1", name, f"<byte {int(value)}>",
        ],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", timeout=15,
    )
    return {"path": paths[0], "rc": res.returncode, "out": res.stdout[-500:]}


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t228r_hf_volume_change(paired_hosts, caplog):
    """
    T228, redone: the headset changes its speaker gain (AT+VGS=9) right
    after a short link the AG ended; the AG takes it (I5): stores it,
    answers OK, and any later +VGS carries 9.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    wait_hf_gains(caplog)
    time.sleep(1.0)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_set_profile("a2dp-sink")
    t_down, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    host0.pipewire.pw_stop_streams()
    hf = host1.call(vm_hf_set_gain, "SpeakerVolume", 9)
    try:
        t_got, got = poll_event(caplog, 0, re.compile(r"RFCOMM << AT\+VGS=9"), after_ns=t_down, timeout=10)
    except TimeoutError:
        t_got, got = None, None
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    report["hf_call"] = hf
    report["ag_received"] = got
    report["ag_received_ms"] = None if t_got is None else round((t_got - t_up) / 1e6, 1)
    after = [(t, m) for t, m in host_events(caplog, 0) if t_got is not None and t >= t_got]
    report["ag_ok_after"] = any("RFCOMM >> OK" in m for t, m in after[:20])
    report["ag_volume_changed_after"] = [
        int(mm.group(1)) for t, m in after for mm in [VOLUME_CHANGED.search(m)] if mm
    ]
    report["frames_from_up"] = frames_with_values(caplog, 0, t_up, t_up)
    report.update(hf_summary(caplog))
    record("t228r_hf_volume_change", report)

    assert "error" not in hf and hf["rc"] == 0, hf
    assert got is not None, "the AG never received AT+VGS=9"
    assert report["ag_ok_after"], report
    assert 9 in report["ag_volume_changed_after"], report
    later_vgs = [f["value"] for f in report["frames_from_up"] if f["frame"] == "VGS" and f["ms"] > report["ag_received_ms"]]
    assert all(v == 9 for v in later_vgs), report


def vm_hangup_and_set_gain(name, value):
    """Runs in the HF VM: hang up the SCO link (as sco_disconnect), then at
    once change the HF's own gain (as vm_hf_set_gain): a headset whose user
    presses a volume key right after the audio stops"""
    handles = sco_disconnect()
    res = vm_hf_set_gain(name, value)
    res["handles"] = handles
    return res


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t228w_hf_volume_change_in_window(paired_hosts, caplog):
    """
    T228, inside the pending-resend window.  Run r02's t228r ended the
    link by a profile switch that took until 2070 ms, and the HF's change
    reached the AG at 3388 ms, after the resend: I5 held, but not in the
    window the plan means.  Here the HF hangs up and changes its speaker
    gain in one VM call, so AT+VGS=9 reaches the AG while the resend is
    still pending.  I5: the AG stores 9, answers OK; the pending resend
    (master: late) must carry 9, not the old gain.
    """
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    wait_hf_gains(caplog)
    time.sleep(1.0)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    hf = host1.call(vm_hangup_and_set_gain, "SpeakerVolume", 9)
    try:
        t_got, got = poll_event(caplog, 0, re.compile(r"RFCOMM << AT\+VGS=9"), after_ns=t_up, timeout=10)
    except TimeoutError:
        t_got, got = None, None
    host0.pipewire.pw_stop_streams()
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    report["hf_call"] = hf
    report["ag_received"] = got
    report["ag_received_ms"] = None if t_got is None else round((t_got - t_up) / 1e6, 1)
    after = [(t, m) for t, m in host_events(caplog, 0) if t_got is not None and t >= t_got]
    report["ag_ok_after"] = any("RFCOMM >> OK" in m for t, m in after[:20])
    report["ag_volume_changed_after"] = [
        int(mm.group(1)) for t, m in after for mm in [VOLUME_CHANGED.search(m)] if mm
    ]
    report["frames_from_up"] = frames_with_values(caplog, 0, t_up, t_up)
    report.update(hf_summary(caplog))
    valid = (
        report["down_ms"] is not None
        and report["down_ms"] < RESEND_DELAY_NS / 1e6
        and report["ag_received_ms"] is not None
        and report["ag_received_ms"] < RESEND_DELAY_NS / 1e6
        and (report["next_up_ms"] is None or report["next_up_ms"] > RESEND_DELAY_NS / 1e6)
    )
    report["valid_window"] = valid
    record("t228w_hf_volume_change_in_window", report)

    assert "error" not in hf and hf["rc"] == 0, hf
    assert got is not None, "the AG never received AT+VGS=9"
    assert report["ag_ok_after"], report
    assert 9 in report["ag_volume_changed_after"], report
    later_vgs = [f["value"] for f in report["frames_from_up"] if f["frame"] == "VGS" and f["ms"] > report["ag_received_ms"]]
    assert all(v == 9 for v in later_vgs), report
    if not valid:
        pytest.skip(f"not inside the window: down {report['down_ms']}, AT+VGS=9 at {report['ag_received_ms']}, next up {report['next_up_ms']}")


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t212_long_link_lc3swb(paired_hosts, caplog):
    """T212: long link, LC3-SWB (the plain profile name): resend while up,
    nothing after"""

    def end(host0, host1):
        time.sleep(WINDOW_S)
        host0.pipewire.pw_set_profile("a2dp-sink")

    report = one_link(
        *paired_hosts, caplog, "t212_long_lc3swb", end, profile="headset-head-unit", exact=True
    )
    require_immediate_volume(report)
    assert report["codec"] == 3, f"not LC3-SWB: {report['codec']}"
    assert {f["frame"] for f in report["while_active"]} == {"VGS", "VGM"}, report
    assert not report["after_down"], report


def check_hangup(report):
    """check_short_link for a hang-up: a new link before the deadline
    re-arms the timer, so that run does not count"""
    require_immediate_volume(report)
    if report["down_ms"] is None:
        pytest.fail(f"link did not end: {report['lines']}")
    if report["down_ms"] >= RESEND_DELAY_NS / 1e6:
        pytest.skip(f"link ended at {report['down_ms']} ms, not before the resend")
    if report["next_up_ms"] is not None and report["next_up_ms"] < RESEND_DELAY_NS / 1e6:
        pytest.skip(f"new link at {report['next_up_ms']} ms re-armed the timer")
    late_vgm = [f for f in report["after_down"] if f["frame"] == "VGM"]
    assert not late_vgm, f"+VGM after the link ended: {report}"


# Run r02 used 1.2 s: the hang-up landed at 1585.6 ms, after the deadline
# (poll and RPC latency ~0.4 s).  0.95 s from run r04 on.
T214_DELAY = float(os.environ.get("CO36_T214_DELAY", "0.95"))


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t214_hangup_near_deadline(paired_hosts, caplog):
    """T214: the headset hangs up close to the deadline (aimed at ~1.4 s
    after acquire complete; CO36_T214_DELAY is the sleep after the AG's
    "acquire complete" line is seen).  The actual time is recorded."""

    def end(host0, host1):
        time.sleep(T214_DELAY)
        assert host1.call(sco_disconnect), "host1 had no SCO/eSCO link"

    report = one_link(
        *paired_hosts, caplog, "t214_hangup_near_deadline", end, extra={"sleep_s": T214_DELAY}
    )
    check_hangup(report)


def vm_suspend_sco_nodes(exe_dump, exe_cli, devenv):
    """Runs in a VM: pw-cli send-command <node> Suspend {} on every
    api.bluez5.sco.* node, as a client or the session manager suspending
    an idle node"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=10
    ).stdout
    done = []
    for item in json.loads(out):
        if item.get("type") != "PipeWire:Interface:Node":
            continue
        if not item["info"]["props"].get("factory.name", "").startswith("api.bluez5.sco."):
            continue
        res = subprocess.run(
            [exe_cli, "send-command", str(item["id"]), "Suspend", "{}"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8",
            env=env, timeout=30,
        )
        done.append({"id": item["id"], "factory": item["info"]["props"]["factory.name"],
                     "state": item["info"].get("state"), "rc": res.returncode, "out": res.stdout[-300:]})
    return done


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t215_node_suspend(paired_hosts, caplog):
    """T215: the AG ends the link by suspending its SCO nodes (stream
    stopped first, profile kept), not by a profile switch.  The generic
    layer delays the release of an active transport by 1 s
    (bluez5-dbus.c:3672, TRANSPORT_RELEASE_TIMEOUT_MSEC), so whether the
    link is short depends on how soon the suspend comes; recorded."""
    host0, host1 = paired_hosts
    t_req = {}

    def end(host0, host1):
        host0.pipewire.pw_stop_streams()
        t_req["suspend"] = host0.call(vm_suspend_sco_nodes, AG.exe_dump, AG.exe_cli, AG.devenv)

    report = one_link(host0, host1, caplog, "t215_node_suspend", end, extra=t_req)
    check_short_link(report)


def vm_sco_node_ids(exe_dump, devenv):
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=10
    ).stdout
    return [
        item["id"]
        for item in json.loads(out)
        if item.get("type") == "PipeWire:Interface:Node"
        and item["info"]["props"].get("factory.name", "").startswith("api.bluez5.sco.")
    ]


def vm_suspend_ids(exe_cli, devenv, ids):
    """Runs in a VM: Suspend the nodes <ids>, all pw-cli calls started at
    once"""
    import os
    import subprocess
    import time

    env = dict(os.environ)
    env.update(devenv)
    t0 = time.monotonic()
    procs = [
        subprocess.Popen(
            [exe_cli, "send-command", str(i), "Suspend", "{}"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", env=env,
        )
        for i in ids
    ]
    out = [{"id": i, "rc": p.wait(timeout=30), "out": p.stdout.read()[-200:]} for i, p in zip(ids, procs)]
    return {"elapsed_s": round(time.monotonic() - t0, 3), "nodes": out}


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t215f_node_suspend_fast(paired_hosts, caplog):
    """
    T215, faster.  Run r02's t215 stopped the stream, then looked the
    nodes up and suspended them one by one: the link ended at 3881 ms,
    long.  Here the node ids are found before the link, the stream is
    stopped and every SCO node suspended at once.  The release is still
    delayed by TRANSPORT_RELEASE_TIMEOUT_MSEC (1000 ms, bluez5-dbus.c:283,
    L3672) for an active transport, so the link cannot end sooner than
    1 s after the suspend; recorded per run.
    """
    host0, host1 = paired_hosts
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    host0.pipewire.pw_set_profile(MSBC)
    check_pipewire_devices_exist(host0, "hfp")
    ids = host0.call(vm_sco_node_ids, AG.exe_dump, AG.devenv)

    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_stop_streams()
    t_req = now_ns(caplog)
    sus = host0.call(vm_suspend_ids, AG.exe_cli, AG.devenv, ids)
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    report.update(hf_summary(caplog))
    report["suspend"] = sus
    report["suspend_requested_after_ms"] = round((t_req - t_up) / 1e6, 1)
    report["release_lines"] = [
        m for t, m in host_events(caplog, 0)
        if t >= t_up and ("release" in m.lower() or "Suspend" in m or "suspend" in m)
    ][:30]
    record("t215f_node_suspend_fast", report)
    check_short_link(report)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t216_profile_off(paired_hosts, caplog):
    """T216: the link ends by switching the device's profile to "off"
    (RFCOMM kept)"""

    def end(host0, host1):
        host0.pipewire.pw_set_profile("off")

    report = one_link(*paired_hosts, caplog, "t216_profile_off", end)
    check_short_link(report)


restart_ag_host = [
    BluetoothdWithRestart(),
    Bluetoothctl(),
    PipeWire(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
        config=no_profile_autoswitch_config,
    ),
]

RFCOMM_LINES = re.compile(r"backend-native\.c:\d+:\w+: .*(RFCOMM|rfcomm|transport|Transport|SCO|profile)")


@host_config(restart_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t219_bluetoothd_restart(paired_hosts, caplog):
    """T219: bluetoothd on the AG restarts (SIGUSR1, test_streaming's
    BluetoothdWithRestart) inside 1.5 s of link up.  Nothing may be written
    after the link is gone, and the AG's PipeWire must survive."""
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    t_req = now_ns(caplog)
    host0.bluetoothd.restart()
    time.sleep(WINDOW_S)
    try:
        host0.pipewire.check_running()
        running = True
    except RuntimeError as exc:
        running = str(exc)
    host0.pipewire.pw_stop_streams()

    report = link_report(caplog, t_up)
    report["restart_requested_ms"] = round((t_req - t_up) / 1e6, 1)
    report["pipewire_running"] = running
    report["rfcomm_lines"] = [m for t, m in host_events(caplog, 0) if t >= t_up and RFCOMM_LINES.search(m)][:80]
    report["write_errors"] = [m for t, m in host_events(caplog, 0) if t >= t_up and "RFCOMM write error" in m]
    report["frames_from_up"] = frames_with_values(caplog, 0, t_up, t_up)
    report.update(hf_summary(caplog))
    record("t219_bluetoothd_restart", report)

    require_immediate_volume(report)
    assert running is True, running
    assert report["down_ms"] is not None, report
    assert not report["after_down"], report


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t221_codec_switch_after_short_link(paired_hosts, caplog):
    """T221: a short link ends (switch to A2DP, stream stopped), then the
    HFP profile with another codec (CVSD) is chosen before the deadline:
    the codec negotiation (AT+BCS=) stops the timer (L1241), so on master
    no late frame if AT+BCS= comes before 1.5 s."""
    host0, host1 = paired_hosts
    connect_hfp(host0, host1, MSBC)
    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_set_profile("a2dp-sink")
    t_down, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    host0.pipewire.pw_stop_streams()
    set_profile_exact(host0, AG, "headset-head-unit-cvsd")
    try:
        t_bcs, _ = poll_event(caplog, 0, re.compile(r"RFCOMM << AT\+BCS=1"), after_ns=t_down, timeout=10)
    except TimeoutError:
        t_bcs = None
    time.sleep(WINDOW_S)

    report = link_report(caplog, t_up)
    report["bcs_ms"] = None if t_bcs is None else round((t_bcs - t_up) / 1e6, 1)
    report["frames_from_up"] = frames_with_values(caplog, 0, t_up, t_up)
    report.update(hf_summary(caplog))
    record("t221_codec_switch_after_short", report)

    require_immediate_volume(report)
    assert report["codec"] == 2, f"first link not mSBC: {report['codec']}"
    assert report["down_ms"] is not None, report
    # run r04 rep 4: the switch to A2DP ended the link at 1639 ms; the
    # assert here made that a failure, but it is a run outside the window
    # (the resend left while the link was up), so it skips now
    if report["down_ms"] >= RESEND_DELAY_NS / 1e6:
        pytest.skip(f"link ended at {report['down_ms']} ms, not before the resend")
    assert t_bcs is not None, "no AT+BCS=1 after the switch to CVSD"
    if report["bcs_ms"] >= RESEND_DELAY_NS / 1e6:
        pytest.skip(f"AT+BCS= at {report['bcs_ms']} ms, after the resend")
    assert not report["after_down"], f"frames after the link ended: {report}"


@host_config(hsp_ag_host, hsp_hs_host, mem=VM_MEM)
def test_co36_t230_hsp_long_link(paired_hosts, caplog):
    """T230: HSP long link, resend while up.  Records the AG device's
    profiles first: run p0-7 found only "off" (T229 blocked)."""
    host0, host1 = paired_hosts
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "device")
    time.sleep(10.0)
    hsp_ag = hsp_ag_host[1]
    dump = host0.call(vm_pw_dump, hsp_ag.exe_dump, hsp_ag.devenv)
    devs = [
        {
            "props": {k: v for k, v in item["info"]["props"].items() if k.startswith(("api.bluez5", "bluez5", "device.profile"))},
            "EnumProfile": [p.get("name") for p in item["info"]["params"].get("EnumProfile", [])],
            "Profile": [p.get("name") for p in item["info"]["params"].get("Profile", [])],
        }
        for item in dump
        if item.get("type") == "PipeWire:Interface:Device" and item["info"]["props"].get("device.api") == "bluez5"
    ]
    lines = [m for t, m in host_events(caplog, 0) if "backend-native" in m or "profiles" in m][:120]
    names = [n for d in devs for n in d["EnumProfile"]]
    if not any(n.startswith("headset-head-unit") for n in names):
        record("t230_hsp_long", {"blocked": True, "devices": devs, "ag_lines": lines})
        pytest.skip(f"blocked: the HSP device offers {names}")

    host0.pipewire.pw_set_profile("headset-head-unit")
    check_pipewire_devices_exist(host0, "hfp")
    host0.pipewire.pw_play()
    t_up, _ = poll_event(caplog, 0, LINK_UP)
    time.sleep(WINDOW_S)
    host0.pipewire.pw_set_profile("off")
    poll_event(caplog, 0, LINK_DOWN, after_ns=t_up)
    host0.pipewire.pw_stop_streams()
    report = link_report(caplog, t_up)
    report["devices"] = devs
    record("t230_hsp_long", report)
    assert {f["frame"] for f in report["while_active"]} == {"VGS", "VGM"}, report
    assert not report["after_down"], report


# T232 as planned: bluez5.hw-volume without the HFP profile (a device
# property, bluez5-device.c:3580).  Run p0-6's test_co36_t232_hw_volume_off
# used bluez5.enable-hw-volume = false, which is T239's switch.
hw_volume_no_hfp_ag_host = [
    Bluetoothctl(),
    PipeWire(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
        config=no_profile_autoswitch_config
        + """
monitor.bluez.rules = [
  {
    matches = [ { device.name = "~bluez_card.*" } ]
    actions = { update-props = { bluez5.hw-volume = [ a2dp_sink ] } }
  }
]
""",
    ),
]


def no_volume_frames_test(host0, host1, caplog, name, plugin):
    """One short link and one long link; returns the report of both, with
    every +VGS/+VGM the AG wrote over the whole test.  <plugin>: the AG's
    host-side PipeWire plugin of this test's host config"""
    connect_hfp(host0, host1, MSBC)
    try:
        wait_hf_gains(caplog)
    except TimeoutError:
        pass
    host0.pipewire.pw_play()
    t_up1, _ = poll_event(caplog, 0, LINK_UP)
    host0.pipewire.pw_set_profile("a2dp-sink")
    t_down1, _ = poll_event(caplog, 0, LINK_DOWN, after_ns=t_up1)
    time.sleep(2.5)
    host0.pipewire.pw_set_profile(MSBC)
    t_up2, _ = poll_event(caplog, 0, LINK_UP, after_ns=t_down1)
    time.sleep(WINDOW_S)
    host0.pipewire.pw_set_profile("a2dp-sink")
    poll_event(caplog, 0, LINK_DOWN, after_ns=t_up2)
    time.sleep(2.0)
    host0.pipewire.pw_stop_streams()

    first = link_report(caplog, t_up1)
    second = link_report(caplog, t_up2)
    for r in (first, second):
        del r["lines"]
    all_frames = frames_with_values(caplog, 0, 0, 0)
    dump = host0.call(vm_pw_dump, plugin.exe_dump, plugin.devenv)
    dev_props = [
        {k: v for k, v in item["info"]["props"].items() if k.startswith(("api.bluez5", "bluez5"))}
        for item in dump
        if item.get("type") == "PipeWire:Interface:Device" and item["info"]["props"].get("device.api") == "bluez5"
    ]
    report = dict(first=first, second=second, all_frames_ms_from_boot=all_frames, device_props=dev_props)
    report["ag_got"] = [m for t, m in host_events(caplog, 0) if AG_GOT_VG.search(m)]
    events = host_events(caplog, 0)
    report["hw_volume_lines"] = [m for t, m in events if "hw-volume-profiles:" in m]
    report["mic_quirk_lines"] = [m for t, m in events if "microphone HW volume disabled" in m]
    report["device_quirk_lines"] = [m for t, m in events if "device quirks:" in m][:10]
    report.update(hf_summary(caplog))
    record(name, report)
    return report


@host_config(hw_volume_no_hfp_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t232p_hw_volume_profiles(paired_hosts, caplog):
    """T232 as planned: bluez5.hw-volume = [ a2dp_sink ] on the AG's
    device: no +VGS/+VGM on any link"""
    report = no_volume_frames_test(
        *paired_hosts, caplog, "t232p_hw_volume_profiles", hw_volume_no_hfp_ag_host[1]
    )
    assert any("bluez5.hw-volume" in d for d in report["device_props"]), report["device_props"]
    assert not report["all_frames_ms_from_boot"], report


@host_config(hw_volume_off_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t239_enable_hw_volume_false(paired_hosts, caplog):
    """T239: bluez5.enable-hw-volume = false (quirks.c:230): no +VGS/+VGM
    on a short or a long link; the setting took (hw-volume-profiles:0)"""
    report = no_volume_frames_test(
        *paired_hosts, caplog, "t239_enable_hw_volume_false", hw_volume_off_ag_host[1]
    )
    hw = report["hw_volume_lines"]
    assert hw and all(m.endswith("hw-volume-profiles:00000000") for m in hw), hw
    assert not report["all_frames_ms_from_boot"], report


# T238: a headset without the hw-volume-mic feature.  The AG's quirk
# database is replaced (bluez5.hardware-database, quirks.c:235) by the
# shipped defaults' kernel and adapter rules and one device rule that
# matches every device and removes hw-volume-mic.
no_mic_volume_ag_host = [
    Bluetoothctl(),
    PipeWire(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
        config=no_profile_autoswitch_config
        + """
monitor.bluez.properties = {
  bluez5.hardware-database = {
    bluez5.features.kernel = [ { no-features = [] } ]
    bluez5.features.adapter = [ { no-features = [ msbc-alt1-rtl ] } ]
    bluez5.features.device = [ { no-features = [ hw-volume-mic ] } ]
  }
}
""",
    ),
]


@host_config(no_mic_volume_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t238_no_mic_hw_volume(paired_hosts, caplog):
    """T238: the HF's AT+VGM= is ignored (broken_mic_hw_volume, L733/L1387),
    so +VGM is never active and never sent, on any link; +VGS as usual"""
    report = no_volume_frames_test(
        *paired_hosts, caplog, "t238_no_mic_hw_volume", no_mic_volume_ag_host[1]
    )
    assert report["mic_quirk_lines"], report["device_quirk_lines"]
    assert not [f for f in report["all_frames_ms_from_boot"] if f["frame"] == "VGM"], report
    assert [f for f in report["all_frames_ms_from_boot"] if f["frame"] == "VGS"], report


# --- T234: two headsets on one AG (three VMs) ------------------------------


def vm_device_known(address):
    """Runs in the AG VM: is <address> in bluetoothd's object tree"""
    import subprocess

    path = "dev_" + address.upper().replace(":", "_")
    res = subprocess.run(
        ["gdbus", "introspect", "--system", "--dest", "org.bluez", "--object-path", "/org/bluez/hci0"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", timeout=15,
    )
    return path in res.stdout


def pair_with(host0, hostn):
    hostn.bluetoothctl.send("pairable on\n")
    hostn.bluetoothctl.expect("Changing pairable on succeeded")
    hostn.bluetoothctl.send("discoverable on\n")
    hostn.bluetoothctl.expect(f"Controller {hostn.bdaddr.upper()} Discoverable: yes")
    end = time.monotonic() + 60
    while not host0.call(vm_device_known, hostn.bdaddr):
        if time.monotonic() > end:
            raise TimeoutError(f"{hostn.bdaddr} not discovered")
        time.sleep(0.5)
    host0.bluetoothctl.send(f"pair {hostn.bdaddr}\n")
    idx, m = host0.bluetoothctl.expect(r"Confirm passkey (\d+).*:")
    key = m[0].decode("utf-8")
    hostn.bluetoothctl.expect(f"Confirm passkey {key}")
    host0.bluetoothctl.send("yes\n")
    hostn.bluetoothctl.send("yes\n")
    host0.bluetoothctl.expect("Pairing successful")


def vm_bluez_devices(exe_dump, devenv):
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=10
    ).stdout
    return [
        {
            "id": item["id"],
            "address": item["info"]["props"].get("api.bluez5.address", ""),
            "profiles": [p.get("name") for p in item["info"]["params"].get("EnumProfile", [])],
        }
        for item in json.loads(out)
        if item.get("type") == "PipeWire:Interface:Device"
        and item["info"]["props"].get("device.api") == "bluez5"
    ]


def vm_set_profile_addr(exe_dump, exe_cli, devenv, address, name):
    """As vm_set_profile_exact, for the device of <address>"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=10
    ).stdout
    for item in json.loads(out):
        if item.get("type") != "PipeWire:Interface:Device":
            continue
        props = item["info"]["props"]
        if props.get("device.api") != "bluez5":
            continue
        if props.get("api.bluez5.address", "").lower() != address.lower():
            continue
        for entry in item["info"]["params"].get("EnumProfile", []):
            if entry["name"] != name:
                continue
            subprocess.run(
                [exe_cli, "set-param", str(item["id"]), "Profile",
                 json.dumps({"index": entry["index"], "save": False})],
                env=env, check=True, timeout=30,
            )
            return name
    raise ValueError(f"no profile {name} on {address}")


_PLAYS = {}


def vm_play_to(exe_dump, exe_play, devenv, address):
    """Runs in a VM: play silence to the HFP sink node of <address>"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run(
        [exe_dump], stdout=subprocess.PIPE, encoding="utf-8", env=env, timeout=10
    ).stdout
    tag = address.upper().replace(":", "_")
    names = []
    for item in json.loads(out):
        if item.get("type") != "PipeWire:Interface:Node":
            continue
        props = item["info"]["props"]
        if props.get("factory.name") != "api.bluez5.sco.sink":
            continue
        if props.get("api.bluez5.address", "").lower() == address.lower() or tag in props.get("node.name", ""):
            names.append(props["node.name"])
    if not names:
        raise ValueError(f"no HFP sink for {address}")
    proc = subprocess.Popen(
        [exe_play, "--target", names[0], "--raw", "--rate", "8000", "--channels", "1",
         "--format", "s16", "-"],
        stdin=open("/dev/zero", "rb"), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env,
    )
    _PLAYS[proc.pid] = proc
    return {"pid": proc.pid, "target": names[0]}


def vm_play_stop(pid):
    proc = _PLAYS.pop(pid)
    proc.terminate()
    proc.wait(timeout=10)


@host_config(a2dp_hfp_ag_host, a2dp_hfp_hf_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t234_two_headsets(hosts, caplog, request):
    """
    T234: one AG (host0), two headsets: B (host2) gets a long link, A
    (host1) a short one that starts 0.3 s after B's and ends 0.3 s later.
    One timer per RFCOMM connection (struct rfcomm, L206): B's resend must
    still leave 1.5 s after B's link came up, while it is up, and A's
    after A's (master: after A's link ended).  Each HF's received frames
    are timed on its own clock.
    """
    request.node.co36_nhosts = 3
    host0, host1, host2 = hosts
    host0.bluetoothctl.send("scan on\n")
    host0.bluetoothctl.expect(f"Controller {host0.bdaddr.upper()} Discovering: yes")
    pair_with(host0, host1)
    pair_with(host0, host2)
    host0.bluetoothctl.send("scan off\n")

    a, b = host1.bdaddr, host2.bdaddr
    # run r02: one "connect" per headset right after both pairings left
    # the AG with no bluez5 device at all within 60 s (bluetoothd:
    # "Fallback profile connection failed: Device or resource busy");
    # the connect is now repeated every 10 s
    time.sleep(2.0)
    for h in (host1, host2):
        h.bluetoothctl.send(f"trust {host0.bdaddr}\n")
        end = time.monotonic() + 90
        next_connect = 0
        while True:
            if time.monotonic() > next_connect:
                # run r07: the plain connect got "Connection refused" for
                # A2DP from both headsets, and the second headset's HFP
                # never came up; the HFP (HF role) UUID is named now
                host0.bluetoothctl.send(
                    f"connect {h.bdaddr} 0000111e-0000-1000-8000-00805f9b34fb\n"
                )
                next_connect = time.monotonic() + 10
            devs = host0.call(vm_bluez_devices, AG.exe_dump, AG.devenv)
            mine = [d for d in devs if d["address"].lower() == h.bdaddr.lower()]
            if mine and MSBC in mine[0]["profiles"]:
                break
            if time.monotonic() > end:
                raise TimeoutError(f"no HFP device for {h.bdaddr}: {devs}")
            time.sleep(1.0)
    end = time.monotonic() + 30
    while len([1 for t, m in host_events(caplog, 0) if AG_GOT_VGS.search(m)]) < 2:
        if time.monotonic() > end:
            break
        time.sleep(0.5)
    for addr in (a, b):
        host0.call(vm_set_profile_addr, AG.exe_dump, AG.exe_cli, AG.devenv, addr, MSBC)
    time.sleep(2.0)

    t0 = now_ns(caplog)
    pb = host0.call(vm_play_to, AG.exe_dump, AG.exe_play, AG.devenv, b)
    t_up_b, _ = poll_event(caplog, 0, LINK_UP, after_ns=t0)
    time.sleep(0.3)
    pa = host0.call(vm_play_to, AG.exe_dump, AG.exe_play, AG.devenv, a)
    t_up_a, _ = poll_event(caplog, 0, LINK_UP, after_ns=t_up_b)
    time.sleep(0.3)
    host0.call(vm_set_profile_addr, AG.exe_dump, AG.exe_cli, AG.devenv, a, "a2dp-sink")
    a_tag = "dev_" + a.upper().replace(":", "_")
    t_down_a, _ = poll_event(caplog, 0, re.compile(rf"Transport \S*{a_tag}\S* released"), after_ns=t_up_a)
    time.sleep(WINDOW_S)
    host0.call(vm_set_profile_addr, AG.exe_dump, AG.exe_cli, AG.devenv, b, "a2dp-sink")
    b_tag = "dev_" + b.upper().replace(":", "_")
    t_down_b, _ = poll_event(caplog, 0, re.compile(rf"Transport \S*{b_tag}\S* released"), after_ns=t_up_b)
    for p in (pa, pb):
        host0.call(vm_play_stop, p["pid"])

    def hf_frames(idx):
        ev = [(t, HF_GOT.search(m)) for t, m in host_events(caplog, idx)]
        ev = [(t, m.group(1), int(m.group(2))) for t, m in ev if m]
        if not ev:
            return []
        return [{"t_ns": t, "frame": f, "value": v} for t, f, v in ev]

    def last_two_pairs_gap(frames):
        if len(frames) < 4:
            return None
        return round((frames[-2]["t_ns"] - frames[-4]["t_ns"]) / 1e6, 1)

    hf_a, hf_b = hf_frames(1), hf_frames(2)
    report = {
        "a": a,
        "b": b,
        "plays": [pa, pb],
        "b_up_ms": 0.0,
        "a_up_ms": round((t_up_a - t_up_b) / 1e6, 1),
        "a_down_ms": round((t_down_a - t_up_b) / 1e6, 1),
        "b_down_ms": round((t_down_b - t_up_b) / 1e6, 1),
        "ag_frames_from_b_up": frames_with_values(caplog, 0, t_up_b, t_up_b),
        "hf_a_frames": [dict(f, t_ns=None, ms=round((f["t_ns"] - hf_a[0]["t_ns"]) / 1e6, 1)) for f in hf_a],
        "hf_b_frames": [dict(f, t_ns=None, ms=round((f["t_ns"] - hf_b[0]["t_ns"]) / 1e6, 1)) for f in hf_b],
        "hf_a_last_gap_ms": last_two_pairs_gap(hf_a),
        "hf_b_last_gap_ms": last_two_pairs_gap(hf_b),
    }
    record("t234_two_headsets", report)

    ag = report["ag_frames_from_b_up"]
    b_resend = [f for f in ag if abs(f["ms"] - RESEND_DELAY_NS / 1e6) < 50]
    a_resend = [f for f in ag if abs(f["ms"] - report["a_up_ms"] - RESEND_DELAY_NS / 1e6) < 50]
    assert report["a_up_ms"] < RESEND_DELAY_NS / 1e6, report
    assert {f["frame"] for f in b_resend} == {"VGS", "VGM"}, f"B's resend lost: {report}"
    assert {f["frame"] for f in a_resend} == {"VGS", "VGM"}, f"A's resend lost: {report}"
    assert report["b_down_ms"] > RESEND_DELAY_NS / 1e6, report
    assert report["hf_b_last_gap_ms"] is not None and abs(report["hf_b_last_gap_ms"] - 1500) < 100, report
    assert report["hf_a_last_gap_ms"] is not None and abs(report["hf_a_last_gap_ms"] - 1500) < 100, report


# --- L3: T306, T307 (policy driven), T308 is in its own runner ------------

_CALLS = {}


def vm_call_start(exe_dump, exe_record, exe_play, devenv):
    """Runs in a VM: a call app's streams, the headset microphone (the
    device's bluez_input.* loopback source) and playback to the default
    sink, opened together"""
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    names = [
        item["info"]["props"]["node.name"]
        for item in vm_pw_dump(exe_dump, devenv)
        if item.get("type") == "PipeWire:Interface:Node"
        and item["info"]["props"].get("node.name", "").startswith("bluez_input.")
    ]
    if not names:
        raise ValueError("no bluez_input.* loopback source")
    rec = subprocess.Popen(
        [exe_record, "--target", names[0], "/tmp/co36-call.wav"],
        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    play = subprocess.Popen(
        [exe_play, "--raw", "--rate", "8000", "--channels", "1", "--format", "s16",
         "-P", "media.role=Communication", "-"],
        stdin=open("/dev/zero", "rb"), env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    _CALLS[rec.pid] = (rec, play)
    return rec.pid


def vm_call_stop(pid):
    rec, play = _CALLS.pop(pid)
    for p in (rec, play):
        p.terminate()
    for p in (rec, play):
        p.wait(timeout=10)


def policy_calls(host0, host1, caplog, name, plugin, holds, gap):
    """As policy_captures, with a call app's two streams"""
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    time.sleep(2.0)

    t_start = now_ns(caplog)
    marks = []
    for hold in holds:
        t_a = now_ns(caplog)
        pid = host0.call(vm_call_start, plugin.exe_dump, plugin.exe_record, plugin.exe_play, plugin.devenv)
        time.sleep(hold)
        host0.call(vm_call_stop, pid)
        marks.append({"hold_s": hold, "start_after_ms": round((t_a - t_start) / 1e6, 1)})
        time.sleep(gap)
    time.sleep(6.0)

    ups = [t for t, m in host_events(caplog, 0) if t > t_start and LINK_UP.search(m)]
    reports = []
    for t_up in ups:
        r = link_report(caplog, t_up)
        del r["lines"]
        r["up_from_start_ms"] = round((t_up - t_start) / 1e6, 1)
        reports.append(r)
    profile_lines = [
        m for t, m in host_events(caplog, 0)
        if t > t_start and ("setting profile" in m or "set profile" in m.lower())
    ][:40]
    record(name, dict(holds=holds, gap=gap, marks=marks, links=reports,
                      profile_lines=profile_lines, **hf_summary(caplog)))
    return reports


@host_config(autoswitch_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t306_policy_call(paired_hosts, caplog):
    """T306: a call app (microphone and playback together, ended together),
    the policy switching (restore 4 s on master): 3 s and 0.8 s calls"""
    reports = policy_calls(*paired_hosts, caplog, "t306_policy_call", AS_AG, [3.0, 0.8], gap=7.0)
    assert reports, "the policy opened no link"
    assert not leaked_links(reports), reports


@host_config(restore_zero_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t306z_policy_call_restore_zero(paired_hosts, caplog):
    """T306 with restore timeout 0: the same calls"""
    reports = policy_calls(*paired_hosts, caplog, "t306z_policy_call_restore_zero", RZ_AG, [3.0, 0.8], gap=7.0)
    assert reports, "the policy opened no link"
    assert not leaked_links(reports), reports


@host_config(autoswitch_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t307_policy_probes(paired_hosts, caplog):
    """T307: an app probing the microphone: captures of 1.0-2.0 s (past
    the policy's switch delay; run p0-8's 0.2-0.6 s ones made no link),
    1 s apart, restore 4 s"""
    reports = policy_captures(
        *paired_hosts, caplog, "t307_policy_probes", AS_AG, [1.0, 1.2, 1.5, 2.0], gap=1.0
    )
    assert reports, "the policy opened no link"
    assert not leaked_links(reports), reports


@host_config(restore_zero_ag_host, a2dp_hfp_hf_host, mem=VM_MEM)
def test_co36_t307z_policy_probes_restore_zero(paired_hosts, caplog):
    """T307 with restore timeout 0, gaps of 3 s so each link's resend falls
    in its own gap"""
    reports = policy_captures(
        *paired_hosts, caplog, "t307z_policy_probes_restore_zero", RZ_AG, [1.0, 1.2, 1.5, 2.0], gap=3.0
    )
    assert reports, "the policy opened no link"
    assert not leaked_links(reports), reports


# --- T308: WirePlumber 0.4.17's policy (the laptop's) ----------------------
#
# Runs only on a tree whose subprojects/wireplumber is 0.4.17
# (agent-work/co36/pw-wp0417); skips elsewhere.  WirePlumber 0.4 reads Lua
# config from ONE directory when WIREPLUMBER_CONFIG_DIR is set (lib/wp/wp.c
# L182-L185 of 0.4.17), so the plugin copies the devenv's config dir and
# adds its own files, instead of test_streaming's 0.5 drop-ins.

import shutil
import subprocess as _subprocess
import tempfile as _tempfile

from pytest_bluezenv import find_exe, LogStream, wait_until, mainloop_wrap


class PipeWire04(PipeWire):
    """PipeWire with WirePlumber 0.4.x in the VM"""

    def presetup(self, config):
        try:
            self.exe_pw = find_exe("", "pipewire")
            self.exe_wp = find_exe("", "wireplumber")
            self.exe_dump = find_exe("", "pw-dump")
            self.exe_cli = find_exe("", "pw-cli")
            self.exe_play = find_exe("", "pw-play")
            self.exe_record = find_exe("", "pw-record")
            env = dict(os.environ)
            env["ASAN_OPTIONS"] = "detect_leaks=0:leak_check_at_exit=0"
            res = _subprocess.run(
                [self.exe_wp, "--version"], stdout=_subprocess.PIPE, encoding="utf-8",
                check=True, env=env,
            )
            m = re.search(r"libwireplumber ([0-9.]+)", res.stdout)
            if not m or not m.group(1).startswith("0.4."):
                raise ValueError(f"not WirePlumber 0.4: {res.stdout.strip()}")
        except (FileNotFoundError, ValueError) as exc:
            pytest.skip(reason=f"PipeWire04: {exc}")

    @mainloop_wrap
    def setup(self, impl):
        import dbus
        import logging

        self.play = None
        self.record = None
        self.log = logging.getLogger(self.name)

        self.tmpdir = _tempfile.TemporaryDirectory(prefix="pipewire-", dir="/run")
        base = Path(self.tmpdir.name)
        runtime_dir = base / "runtime"
        state_dir = base / "state"
        runtime_dir.mkdir()
        state_dir.mkdir()

        self.environ = environ = dict(os.environ)
        environ.update(self.devenv)

        wp_conf = base / "wireplumber"
        src = environ.get("WIREPLUMBER_CONFIG_DIR", "").split(":")[0]
        shutil.copytree(src, wp_conf)
        with open(wp_conf / "bluetooth.lua.d" / "51-co36.lua", "w") as f:
            f.write(
                f'bluez_monitor.properties["bluez5.roles"] = "[ {self.roles} ]"\n'
                'bluez_monitor.properties["bluez5.decode-buffer.latency"] = 4096\n'
                # run r03: WirePlumber 0.4.17 exited right after "failed to
                # start systemd logind monitor" (no logind in the VM)
                'bluez_monitor.properties["with-logind"] = false\n'
                'bluez_midi_monitor.properties["with-logind"] = false\n'
                + (self.config or "")
            )

        # run r06: from the second capture on, 0.4.17's restore-stream.lua
        # gave the capture its saved target (bluez_input.*, gone in A2DP
        # mode) and the stream failed with "no target node available"
        # before any link; stream targets are not restored now
        with open(wp_conf / "main.lua.d" / "51-co36.lua", "w") as f:
            f.write('stream_defaults.properties["restore-target"] = false\n')

        environ["WIREPLUMBER_CONFIG_DIR"] = str(wp_conf)
        environ["XDG_CONFIG_HOME"] = str(base / "config")
        environ["XDG_RUNTIME_HOME"] = str(runtime_dir)
        environ["PIPEWIRE_RUNTIME_DIR"] = str(runtime_dir)
        environ["XDG_STATE_HOME"] = str(state_dir)
        environ["PIPEWIRE_DEBUG"] = "2"
        # 0.4 syntax, "level:category,category" (lib/wp/log.c L399)
        # run r03 used "D:spa.bluez5*,..." and WirePlumber's own fatal
        # message, if any, was filtered out; all categories now
        environ["WIREPLUMBER_DEBUG"] = "D"

        self.logger = LogStream("pipewire")
        self.pw = _subprocess.Popen(
            self.exe_pw, env=environ, stdout=self.logger.stream, stderr=_subprocess.STDOUT
        )

        def cond():
            try:
                ret = _subprocess.run(
                    [self.exe_dump], stdout=_subprocess.DEVNULL, env=self.environ, timeout=5
                )
            except _subprocess.TimeoutExpired:
                return False
            return ret.returncode == 0

        wait_until(cond)

        self.wp_logger = LogStream("wireplumber")
        self.wp = _subprocess.Popen(
            self.exe_wp, env=environ, stdout=self.wp_logger.stream, stderr=_subprocess.STDOUT
        )

        bus = dbus.SystemBus()
        bus.set_exit_on_disconnect(False)
        adapter = dbus.Interface(
            bus.get_object("org.bluez", "/org/bluez/hci0"),
            "org.freedesktop.DBus.Properties",
        )

        def cond():
            self.check_running()
            uuids = [str(uuid) for uuid in adapter.Get("org.bluez.Adapter1", "UUIDs")]
            return all(uuid in uuids for uuid in self.uuids)

        wait_until(cond)
        os.environ["PIPEWIRE_RUNTIME_DIR"] = str(runtime_dir)
        # 0.4 has no session.services property to wait for; the endpoints
        # registered above are WirePlumber's bluez monitor at work
        time.sleep(2.0)


# Run r03b: with every codec on, 0.4.17's policy picked the highest
# priority profile with an input route, a2dp-sink-opus_05_duplex (both
# ends are PipeWire), so no HFP link was ever made.  The AG's codecs are
# limited to what a common headset has, so the policy's choice is HFP.
wp04_ag_host = [
    Bluetoothctl(),
    PipeWire04(
        roles="a2dp_source hfp_ag",
        uuids=(
            "0000110a-0000-1000-8000-00805f9b34fb",
            "0000111f-0000-1000-8000-00805f9b34fb",
        ),
        config='bluez_monitor.properties["bluez5.codecs"] = "[ sbc sbc_xq msbc lc3_swb ]"\n',
    ),
]
wp04_hf_host = [
    Bluetoothctl(),
    PipeWire04(
        roles="a2dp_sink hfp_hf",
        uuids=(
            "0000110b-0000-1000-8000-00805f9b34fb",
            "0000111e-0000-1000-8000-00805f9b34fb",
        ),
    ),
]
WP04_AG = wp04_ag_host[1]


def vm_comm_capture_start(exe_record, devenv):
    """Runs in a VM: a capture stream with media.role Communication on the
    default source, the trigger of 0.4.17's policy-bluetooth.lua (L319-L338)"""
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    # run r03c: the stream went away ~40 ms after being linked to the HFP
    # source, before any SCO link; its stderr is kept now
    err = open("/tmp/co36-comm.err", "w")
    proc = subprocess.Popen(
        [exe_record, "-v", "-P", "media.role=Communication", "/tmp/co36-comm.wav"],
        env=env, stdout=subprocess.DEVNULL, stderr=err,
    )
    _CAPTURES[proc.pid] = proc
    return proc.pid


def vm_comm_capture_stop(pid):
    """Stop the capture; returns its exit code and the end of its stderr"""
    proc = _CAPTURES.pop(pid)
    rc = proc.poll()
    if rc is None:
        proc.terminate()
        proc.wait(timeout=10)
    with open("/tmp/co36-comm.err") as f:
        text = f.read()
    return {"exited_before_stop": rc is not None, "rc": rc, "stderr": text[-1500:]}


@host_config(wp04_ag_host, wp04_hf_host, mem=VM_MEM)
def test_co36_t308_wp0417_policy(paired_hosts, caplog):
    """
    T308: WirePlumber 0.4.17's policy on master: a Communication-role
    capture switches to HFP at once; the profile is restored 2000 ms after
    the stream goes (policy-bluetooth.lua L31, L309).  Captures of 0.3,
    0.8, 1.5 and 3 s, 6 s apart.  Records each link's length and late
    frames.
    """
    host0, host1 = paired_hosts
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    time.sleep(3.0)

    holds = [0.3, 0.8, 1.5, 3.0]
    t_start = now_ns(caplog)
    captures = []
    for hold in holds:
        pid = host0.call(vm_comm_capture_start, WP04_AG.exe_record, WP04_AG.devenv)
        time.sleep(hold)
        captures.append(dict(hold_s=hold, **host0.call(vm_comm_capture_stop, pid)))
        time.sleep(6.0)
    time.sleep(2.0)

    ups = [t for t, m in host_events(caplog, 0) if t > t_start and LINK_UP.search(m)]
    reports = []
    for t_up in ups:
        r = link_report(caplog, t_up)
        del r["lines"]
        r["up_from_start_ms"] = round((t_up - t_start) / 1e6, 1)
        reports.append(r)
    policy_lines = [
        m for t, m in host_events(caplog, 0)
        if t > t_start and ("Setting profile" in m or "Restoring profile" in m)
    ][:40]
    wp_version = [m for t, m in host_events(caplog, 0) if "WirePlumber" in m and "0.4" in m][:3]
    record("t308_wp0417_policy", dict(holds=holds, links=reports, policy_lines=policy_lines,
                                      captures=captures, wp_version_lines=wp_version,
                                      **hf_summary(caplog)))
    assert reports, f"the policy opened no link: {policy_lines}"
    assert not leaked_links(reports), reports
