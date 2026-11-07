# SPDX-License-Identifier: GPL-2.0-or-later
"""
U29 experiment: lifetime of an unpaired temporary device object in BlueZ
5.72 (the laptop's build), after the peer's own inbound BR/EDR connection,
with and without LE advertisements from the same public address.

host0: device under test (bluetoothd -d, empty main.conf, discovery running)
host1: the peer: a bare btvirt dual-mode controller driven with hcitool
       (BR/EDR connect/disconnect) and btmgmt add-adv (LE advertising).
       No bluetoothd runs on host1.

One test = one arm = one repetition (fresh guests). Arm and run directory
come from the environment: U29_ARM, U29_RUNDIR.
"""

import json
import os
import re
import subprocess
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Btmon, host_config, utils

from .u29_plugins import DbusRec, UBluetoothd

pytestmark = [pytest.mark.vm]

ARM = os.environ.get("U29_ARM", "A")
RUNDIR = Path(os.environ.get("U29_RUNDIR", "/tmp/u29-run"))

# arm -> (AD data hex or None, (discovery Transport, discovery Discoverable))
ARMS = {
    # A, B, C: plain StartDiscovery, no filter (regular discovery)
    "A": (None, ("none", "none")),
    "B": ("020118", ("none", "none")),
    "C": ("02011a", ("none", "none")),
    # D: GNOME-style filter {Discoverable: true} only (an "empty" filter
    # that adapter.c treats as regular discovery)
    "D": ("020118", ("none", "true")),
    # E: extra, not in the brief: transport-restricted filter {Transport: le}
    # (adapter.c then runs filtered discovery, filtered_discovery = true)
    "E": ("020118", ("le", "none")),
}
ADV_PERIOD = 10          # s between advertisements
# F: extra arm, as B but one advertisement every 4 s, so that the scanner's
# duty cycle (unfiltered discovery is interleaved with BR/EDR inquiry)
# misses fewer of them
ARMS["F"] = ("020118", ("none", "none"))
ARM_PERIOD = {"F": 4}
ADV_PHASE = 120          # s of advertising
HOLD = 5                 # s connected, as the headset (11:16:09 to 11:16:14)
POST_WAIT = 75           # s to wait for removal after the last advertisement

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def vm_tool(subdir, name, args):
    """Runs in a guest: a BlueZ tool; returns (t_start_ns, t_end_ns, output)"""
    exe = utils.find_exe(subdir, name)
    t0 = time.time_ns()
    res = subprocess.run([exe] + list(args), stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, encoding="utf-8",
                         timeout=20)
    return t0, time.time_ns(), res.stdout


def vm_l2cap_hold(addr, hold_s):
    """Peer guest: an unauthenticated BR/EDR link to <addr> (L2CAP to the
    SDP PSM 1, no pairing), held for <hold_s> s, then closed. Returns the
    timestamps (ns) and any error."""
    import socket

    out = dict(t_start=time.time_ns(), err=None)
    s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET,
                      socket.BTPROTO_L2CAP)
    s.settimeout(10)
    try:
        s.connect((addr, 1))
        out["t_connected"] = time.time_ns()
        time.sleep(hold_s)
    except OSError as exc:
        out["err"] = repr(exc)
    out["t_close"] = time.time_ns()
    s.close()
    return out


def vm_dut_info():
    """DUT guest: connectable on, then settings"""
    return vm_tool("tools", "btmgmt", ["--index", "0", "connectable", "on"])


def hlines(caplog, idx, name):
    pat = re.compile(rf"^host\.\d+\.{idx}\.{name}$")
    return [(getattr(r, "nsec", int(r.created * 1e9)), r.getMessage())
            for r in list(caplog.records) if pat.match(r.name)]


@host_config(
    [UBluetoothd("U29_BLUETOOTHD"), DbusRec(), Btmon()],
    [Btmon()],
    mem="784M",
)
def test_arm(hosts, caplog):
    dut, peer = hosts
    adv_data, (d_transport, d_disc) = ARMS[ARM]
    period = ARM_PERIOD.get(ARM, ADV_PERIOD)
    RUNDIR.mkdir(parents=True, exist_ok=True)
    ev = []

    def mark(name, **kw):
        ev.append(dict(t_ns=time.time_ns(), event=name, **kw))

    dut_addr = dut.bdaddr.upper()
    peer_addr = peer.bdaddr.upper()
    dev_path = "dev_" + peer_addr.replace(":", "_")
    mark("addresses", dut=dut_addr, peer=peer_addr, arm=ARM,
         adv_data=adv_data, disc_transport=d_transport, disc_discoverable=d_disc)

    # peer controller up
    for a in (["--index", "0", "power", "on"], ["--index", "0", "le", "on"],
              ["--index", "0", "info"]):
        r = peer.call(vm_tool, "tools", "btmgmt", a)
        mark("peer_btmgmt", args=a, out=r[2])
    # DUT: connectable (page scan) so the peer can page it
    r = dut.call(vm_dut_info)
    mark("dut_connectable_on", out=r[2])

    # DUT discovery, as the laptop had (GNOME Settings scanning)
    dut.dbusrec.start_discovery(os.environ["U29_VM_DISCOVERY"],
                                d_transport, d_disc)
    time.sleep(3)
    mark("discovery_started", lines=dut.dbusrec.discovery_lines())

    # clock check: guest clocks against the tester
    t_a = time.time_ns()
    g0 = dut.dbusrec.now()
    g1 = peer.call(vm_tool, "tools", "btmgmt", ["--index", "0", "info"])[0]
    t_b = time.time_ns()
    mark("clock_check", tester_before=t_a, dut_now=g0, peer_t0=g1,
         tester_after=t_b)

    # --- BR/EDR connect from the peer, no pairing -------------------------
    t_cc = dut.dbusrec.now()      # DUT guest clock, not the tester's
    r = peer.call(vm_l2cap_hold, dut_addr, HOLD)
    mark("peer_l2cap_hold", result=r)
    t_added = dut.dbusrec.find(["member=InterfacesAdded", dev_path], t_cc)
    mark("dut_interfaces_added", recv_ns=t_added)
    t_dc0 = t_cc
    r = peer.call(vm_tool, "tools", "btmgmt",
                  ["--index", "0", "disconnect", dut_addr])
    mark("peer_btmgmt_disconnect", out=r[2], t_start=r[0], t_end=r[1])
    t_disc = None
    for _ in range(150):
        t_disc =dut.dbusrec.find(["member=PropertiesChanged", dev_path,
                                   "string \"Connected\""], t_dc0)
        if t_disc:
            break
        time.sleep(0.1)
    mark("dut_disconnected", recv_ns=t_disc)
    t_ref = t_disc or t_dc0

    removed = None
    last_adv = None
    adv_times = []
    if adv_data is None:
        end = time.time() + POST_WAIT
        while time.time() < end and not removed:
            removed = dut.dbusrec.find(["member=InterfacesRemoved", dev_path],
                                       t_ref)
            time.sleep(0.25)
    else:
        time.sleep(2)
        start = time.time()
        k = 0
        while time.time() - start < ADV_PHASE and not removed:
            t_beat = start + k * period
            while time.time() < t_beat and not removed:
                removed = dut.dbusrec.find(
                    ["member=InterfacesRemoved", dev_path], t_ref)
                time.sleep(0.2)
            if removed:
                break
            r = peer.call(vm_tool, "tools", "btmgmt",
                          ["--index", "0", "add-adv", "-d", adv_data, "-c",
                           "-t", "2", "1"])
            adv_times.append(r[0])
            last_adv = r[0]
            mark("peer_add_adv", n=k, t_start=r[0], t_end=r[1], out=r[2])
            k += 1
        # advertising stopped (instance timeout 2 s); wait for removal
        end = time.time() + POST_WAIT
        while time.time() < end and not removed:
            removed = dut.dbusrec.find(["member=InterfacesRemoved", dev_path],
                                       t_ref)
            time.sleep(0.25)
    mark("dut_interfaces_removed", recv_ns=removed)
    time.sleep(1)

    # --- raw logs ---------------------------------------------------------
    with open(RUNDIR / "dbus-monitor.log", "w") as f:
        for t, text in dut.dbusrec.dump():
            f.write(f"### recv_ns={t} {time.strftime('%H:%M:%S', time.localtime(t / 1e9))}.{t % 10**9:09d}\n{text}\n")
    with open(RUNDIR / "discovery-client.log", "w") as f:
        for t, line in dut.dbusrec.discovery_lines():
            f.write(f"{t} {line}\n")
    with open(RUNDIR / "bluetoothd-dut.log", "w") as f:
        for t, m in hlines(caplog, 0, "bluetoothd"):
            f.write(f"{t} {m}\n")
    with open(RUNDIR / "btmon-dut.log", "w") as f:
        for t, m in hlines(caplog, 0, "btmon"):
            f.write(f"{t} {ANSI.sub('', m)}\n")
    with open(RUNDIR / "btmon-peer.log", "w") as f:
        for t, m in hlines(caplog, 1, "btmon"):
            f.write(f"{t} {ANSI.sub('', m)}\n")
    with open(RUNDIR / "events.jsonl", "w") as f:
        for e in ev:
            f.write(json.dumps(e) + "\n")
    summary = dict(arm=ARM, dut=dut_addr, peer=peer_addr, t_connect_req=t_cc,
                   t_added=t_added, t_disconnected=t_disc,
                   adv_starts=adv_times, last_adv=last_adv, removed=removed)
    with open(RUNDIR / "summary.json", "w") as f:
        json.dump(summary, f, indent=1)
    assert t_added, "device object was not created by the inbound connection"
