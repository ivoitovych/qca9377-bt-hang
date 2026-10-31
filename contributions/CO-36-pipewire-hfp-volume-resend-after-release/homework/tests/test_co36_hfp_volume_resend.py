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


def record(name, report):
    path = Path(os.environ.get("CO36_RESULTS", "co36-results.jsonl"))
    entry = dict(test=name, build=os.environ.get("CO36_BUILD", ""), **report)
    with open(path, "a") as f:
        f.write(json.dumps(entry) + "\n")


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


def one_link(host0, host1, caplog, name, end, profile=MSBC, exact=False):
    """Connect, open one link on <profile>, call end(host0, host1) at once,
    observe WINDOW_S, record and return the report"""
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
