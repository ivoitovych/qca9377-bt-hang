# SPDX-License-Identifier: GPL-2.0-or-later
"""
CO-03 L3: the U12 trigger as the desktop makes it, PipeWire and WirePlumber
driving the A2DP transport. Runs inside PipeWire's test/bluezenv/, next to
test_streaming.py (mounted there; not part of PipeWire).

host0: bluetoothd under test ($CO03_HOST0_BLUETOOTHD), PipeWire as A2DP
       source and HFP AG.
host1: the test-fixture bluetoothd ($CO03_HOST1_BLUETOOTHD), PipeWire as
       A2DP sink and HFP HF; its AVDTP behaviour from MODES.

Timing: under ASan, PipeWire in the guest takes ~0.6 s from pw-play to the
Acquire, and a profile switch by pw-cli some 0.1-0.3 s; so the remote
answers START after 1 s ("slow1000") to give the switch a window, and the
switch is issued a set time after playback starts. Whether the Release
landed while the Acquire was pending is read from host0's bluetoothd log
(transport state REQUESTING -> SUSPENDING) and recorded per run.
"""

import json
import os
import re
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Bluetoothctl, host_config

from .co03_plugins import CoBluetoothd
from .test_streaming import (
    VM_MEM,
    PipeWire,
    check_pipewire_devices_exist,
    no_profile_autoswitch_config,
)

pytestmark = [pytest.mark.vm]

REPS = int(os.environ.get("CO03_REPS", "1"))
SWITCH_AFTER_S = float(os.environ.get("CO03_SWITCH_AFTER_S", "0.8"))

MODES = {
    "plain": {},
    "slow1000": {"CO03_SINK_START_DELAY_MS": "1000", "CO03_SINK_DROP_ABORT": "1"},
}

AG_UUIDS = ("0000110a-0000-1000-8000-00805f9b34fb", "0000111f-0000-1000-8000-00805f9b34fb")
HF_UUIDS = ("0000110b-0000-1000-8000-00805f9b34fb", "0000111e-0000-1000-8000-00805f9b34fb")


def hosts_for(mode, autoswitch=False):
    ag = PipeWire(roles="a2dp_source hfp_ag", uuids=AG_UUIDS,
                  config=None if autoswitch else no_profile_autoswitch_config)
    hf = PipeWire(roles="a2dp_sink hfp_hf", uuids=HF_UUIDS)
    h0 = [CoBluetoothd("CO03_HOST0_BLUETOOTHD"), Bluetoothctl(), ag]
    h1 = [CoBluetoothd("CO03_HOST1_BLUETOOTHD", env=MODES[mode]), Bluetoothctl(), hf]
    return host_config(h0, h1, mem=VM_MEM)


def reps():
    return pytest.mark.parametrize("rep", range(REPS))


ACQ_ADD = re.compile(r"media_owner_add\(\) Owner \S+ Request Acquire")
REQ_TO_SUSP = re.compile(r"TRANSPORT_STATE_REQUESTING -> TRANSPORT_STATE_SUSPENDING")
ABORT_SENT = re.compile(r"a2dp_cancel\(\) aborting setup")
LOST = re.compile(r"profile a2dp-sink state changed: connected -> disconnected")
SANITIZER = re.compile(r"AddressSanitizer|LeakSanitizer|UndefinedBehaviorSanitizer|runtime error:")


def lines(caplog, idx, name="bluetoothd"):
    pat = re.compile(rf"^host\.\d+\.{idx}\.{name}$")
    return [(getattr(r, "nsec", int(r.created * 1e9)), r.getMessage())
            for r in list(caplog.records) if pat.match(r.name)]


def first(caplog, idx, pattern, after=0):
    for t, m in lines(caplog, idx):
        if t >= after and pattern.search(m):
            return t
    return None


def count(caplog, idx, pattern, after=0):
    return sum(1 for t, m in lines(caplog, idx) if t >= after and pattern.search(m))


def ms(t, t0):
    return None if t is None or t0 is None else round((t - t0) / 1e6, 1)


def record(name, mode, rep, data):
    path = Path(os.environ.get("CO03_RESULTS", "co03-results.jsonl"))
    entry = dict(test=name, variant=os.environ.get("CO03_VARIANT", ""), mode=mode,
                 rep=rep, **data)
    with open(path, "a") as f:
        f.write(json.dumps(entry) + "\n")


def sanitizer(caplog):
    return [f"host{i}: {m}" for i in (0, 1) for t, m in lines(caplog, i) if SANITIZER.search(m)]


def vm_profile_index(exe_dump, devenv, prefix):
    """Runs in a VM: (device id, profile index) of the bluez5 device's
    first profile named <prefix>*"""
    import json
    import os
    import subprocess

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run([exe_dump], stdout=subprocess.PIPE, encoding="utf-8",
                         env=env, timeout=10).stdout
    for item in json.loads(out):
        if item.get("type") != "PipeWire:Interface:Device":
            continue
        if item["info"]["props"].get("device.api") != "bluez5":
            continue
        for entry in item["info"]["params"].get("EnumProfile", []):
            if entry["name"].startswith(prefix):
                return item["id"], entry["index"], entry["name"]
    raise ValueError(f"no profile {prefix}")


def vm_set_profile_after(exe_cli, devenv, dev_id, index, delay):
    """Runs in a VM: after <delay> s, set the device's profile by index;
    returns the VM time (ns) the pw-cli command was started"""
    import json
    import os
    import subprocess
    import time

    env = dict(os.environ)
    env.update(devenv)
    time.sleep(delay)
    t = time.time_ns()
    subprocess.run([exe_cli, "set-param", str(dev_id), "Profile",
                    json.dumps({"index": index, "save": False})],
                   env=env, check=True, timeout=30)
    return t


def vm_unpair(peer):
    """Runs in a VM: drop the kernel's link key for <peer>. With BlueZ 5.72
    in the reused guests, the kernel still holds the previous test's key
    when the next test pairs, and Pair() fails with AlreadyExists."""
    import subprocess

    from pytest_bluezenv import utils

    exe = utils.find_exe("tools", "btmgmt")
    res = subprocess.run([exe, "--index", "0", "unpair", peer],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         encoding="utf-8", timeout=10)
    return res.stdout


@pytest.fixture
def paired_hosts(hosts):
    """PipeWire's paired_hosts (BR/EDR), after dropping stale link keys"""
    from .conftest import _pair_bredr

    host0, host1 = hosts
    host0.call(vm_unpair, host1.bdaddr)
    host1.call(vm_unpair, host0.bdaddr)
    yield from _pair_bredr(hosts)


def plugin_of(host_setup, idx):
    return [p for p in host_setup["setup"][idx] if isinstance(p, PipeWire)][0]


def connect(host0, host1):
    host1.bluetoothctl.send(f"trust {host0.bdaddr}\n")
    host0.bluetoothctl.send("scan off\n")
    host0.bluetoothctl.send(f"connect {host1.bdaddr}\n")
    check_pipewire_devices_exist(host0, "a2dp-sink")
    time.sleep(1.0)


def after_check(host0, host1, caplog, t0, data):
    """Back to A2DP and play: the profile must still be offered and audio
    must reach host1"""
    data["abort_sent"] = count(caplog, 0, ABORT_SENT, t0)
    data["lost_ms"] = ms(first(caplog, 0, LOST, t0), t0)
    data["release_while_requesting"] = count(caplog, 0, REQ_TO_SUSP, t0)
    host0.pipewire.pw_stop_streams()
    try:
        host0.pipewire.pw_set_profile("a2dp-sink")
        check_pipewire_devices_exist(host0, "a2dp-sink")
        data["a2dp_profile"] = True
    except Exception as exc:
        data["a2dp_profile"] = False
        data["a2dp_profile_error"] = str(exc)[:200]
        return False
    host1.pipewire.pw_record()
    host0.pipewire.pw_play()
    ok = host1.pipewire.pw_record_wait_signal(timeout=40)
    data["audio"] = bool(ok)
    return bool(ok)


def switch_case(paired_hosts, host_setup, caplog, name, mode, rep):
    host0, host1 = paired_hosts
    ag = plugin_of(host_setup, 0)
    connect(host0, host1)
    dev_id, index, pname = host0.call(vm_profile_index, ag.exe_dump, ag.devenv,
                                      "headset-head-unit")
    t_start = host0.call(time.time_ns)
    host0.pipewire.pw_play()
    t_sw = host0.call(vm_set_profile_after, ag.exe_cli, ag.devenv, dev_id, index,
                      SWITCH_AFTER_S)
    try:
        check_pipewire_devices_exist(host0, "hfp")
        hfp = True
    except AssertionError:
        hfp = False
    time.sleep(4.0)
    data = {"profile": pname, "acquire_seen_ms": ms(first(caplog, 0, ACQ_ADD, t_start), t_start),
            "switch_ms": ms(t_sw, t_start), "hfp": hfp}
    ok = after_check(host0, host1, caplog, t_start, data)
    data["sanitizer"] = sanitizer(caplog)
    host0.pipewire.pw_stop_streams()
    host1.pipewire.pw_stop_streams()
    record(name, mode, rep, data)
    return ok, data


@hosts_for("slow1000")
@reps()
def test_t310_switch_during_start(paired_hosts, host_setup, caplog, rep):
    """T310 play, switch to HFP while START is pending (remote answers
    START after 1 s, never ABORT), then back to A2DP: profile offered and
    audio flows"""
    ok, data = switch_case(paired_hosts, host_setup, caplog, "t310", "slow1000", rep)
    assert ok and not data["sanitizer"], data


@hosts_for("plain")
@reps()
def test_t311_switch_during_start_plain(paired_hosts, host_setup, caplog, rep):
    """T311 as T310 with the stock remote (recorded)"""
    ok, data = switch_case(paired_hosts, host_setup, caplog, "t311", "plain", rep)
    assert not data["sanitizer"], data


_CAPTURES = {}


def vm_capture_start_after(exe_dump, exe_record, devenv, delay):
    """Runs in a VM: after <delay> s, record from the device's WirePlumber
    loopback source (bluez_input.*), as an application opening the headset
    microphone; returns (pid, VM time ns)"""
    import json
    import os
    import subprocess
    import time

    env = dict(os.environ)
    env.update(devenv)
    out = subprocess.run([exe_dump], stdout=subprocess.PIPE, encoding="utf-8",
                         env=env, timeout=10).stdout
    names = [item["info"]["props"]["node.name"] for item in json.loads(out)
             if item.get("type") == "PipeWire:Interface:Node"
             and item["info"]["props"].get("node.name", "").startswith("bluez_input.")]
    if not names:
        raise ValueError("no bluez_input.* loopback source")
    time.sleep(delay)
    t = time.time_ns()
    proc = subprocess.Popen([exe_record, "--target", names[0], "/tmp/co03-capture.wav"],
                            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _CAPTURES[proc.pid] = proc
    return proc.pid, t


def vm_capture_stop(pid):
    proc = _CAPTURES.pop(pid)
    proc.terminate()
    proc.wait(timeout=10)


@hosts_for("slow1000", autoswitch=True)
@reps()
def test_t312_autoswitch_capture_during_start(paired_hosts, host_setup, caplog, rep):
    """T312 WirePlumber's autoswitch: playback starts, and a capture on
    host0's Bluetooth source opens at once (remote answers START after 1 s,
    never ABORT); the capture ends after 3 s and the policy restores A2DP:
    profile offered and audio flows"""
    host0, host1 = paired_hosts
    ag = plugin_of(host_setup, 0)
    connect(host0, host1)
    t_start = host0.call(time.time_ns)
    host0.pipewire.pw_play()
    pid, t_cap = host0.call(vm_capture_start_after, ag.exe_dump, ag.exe_record,
                            ag.devenv, 0.0)
    time.sleep(3.0)
    host0.call(vm_capture_stop, pid)
    time.sleep(6.0)  # past the restore timeout
    data = {"acquire_seen_ms": ms(first(caplog, 0, ACQ_ADD, t_start), t_start),
            "capture_ms": ms(t_cap, t_start)}
    ok = after_check(host0, host1, caplog, t_start, data)
    data["sanitizer"] = sanitizer(caplog)
    host0.pipewire.pw_stop_streams()
    host1.pipewire.pw_stop_streams()
    record("t312", "slow1000", rep, data)
    assert ok and not data["sanitizer"], data
