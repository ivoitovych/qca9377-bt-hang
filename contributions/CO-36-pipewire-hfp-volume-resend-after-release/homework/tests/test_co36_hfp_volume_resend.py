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
    r"(Transport \S+ released|transport \S+: SCO socket (hangup|error))"
)
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
