# SPDX-License-Identifier: GPL-2.0-or-later
"""
U29 patch, second round (runs-v2).

Arms (env U29_ARM):
  P1    pairing arm that reaches the device-found path: BR/EDR link up, the
        DUT agent holds its confirmation for PAIR_DELAY s, a second mgmt
        client (btmgmt find -l) keeps LE scanning going in the DUT, the peer
        advertises flags 0x18 every ADV_PERIOD s.
  P2    connecting phase: the peer is not connectable, so the DUT's Pair()
        stays in "Create Connection" until it fails; scanner and advertising
        as in P1, and advertising goes on after the failure.
  BNF   arm B (flags 0x18) with FilterDiscoverable = false.
  GNF   arm G (no Flags AD) with FilterDiscoverable = false.
  GDL   arm G with a D-Bus discovery client without filter (same set-up as
        arm G of runs/; repeated here under the v2 harness).
"""

import os
import signal
import subprocess
import threading
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Agent, Btmon, host_config, utils

from .u29_common import (ADV_PERIOD, FLAGS_NOT_DISC, NO_FLAGS, POST_WAIT, Run,
                         vm_async_poll, vm_async_start)
from .u29_plugins import DbusRec, U29Profile, UBluetoothd

pytestmark = [pytest.mark.vm]

ARM = os.environ.get("U29_ARM", "P1")
RUNDIR = Path(os.environ.get("U29_RUNDIR", "/tmp/u29v2-run"))

ADV_PHASE = 120
PAIR_DELAY = 40
P2_ADV = 150           # s of advertising after Pair() was called (P2)
V2_PERIOD = 5          # s between advertisements in P1/P2
CONF_NF = "[General]\nFilterDiscoverable = false\n"

SCAN = {}


def _scan_thread():
    exe = utils.find_exe("tools", "btmgmt")
    while not SCAN["stop"]:
        t0 = time.time_ns()
        p = subprocess.Popen([exe, "--index", "0", "find", "-l"],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             stdin=subprocess.DEVNULL, text=True)
        SCAN["proc"] = p
        try:
            out, _ = p.communicate(timeout=14)
        except subprocess.TimeoutExpired:
            p.send_signal(signal.SIGINT)
            out, _ = p.communicate(timeout=10)
        SCAN["runs"].append((t0, time.time_ns(), out))
        time.sleep(0.3)
    SCAN["done"] = True


def vm_scan_start():
    """DUT guest: a second mgmt client (btmgmt find -l), restarted whenever
    the kernel ends its 10 s LE discovery, until vm_scan_stop()"""
    SCAN.clear()
    SCAN.update(stop=False, done=False, runs=[], proc=None)
    threading.Thread(target=_scan_thread, daemon=True).start()
    return time.time_ns()


def vm_scan_stop():
    SCAN["stop"] = True
    p = SCAN.get("proc")
    if p is not None and p.poll() is None:
        p.send_signal(signal.SIGINT)
    for _ in range(300):
        if SCAN.get("done"):
            break
        time.sleep(0.1)
    return time.time_ns(), list(SCAN.get("runs", []))


def advertise_until(r, adv_data, period, until, k0=0):
    """Peer advertisements every <period> s until the wall clock <until>"""
    k = k0
    start = time.time()
    while time.time() < until:
        r.adv(adv_data, k)
        k += 1
        nxt = start + (k - k0) * period
        while time.time() < min(nxt, until):
            r.check_removed(r.t_ref)
            time.sleep(0.2)
    return k


def pair_poll(r, key):
    res = r.dut.call(vm_async_poll, key)
    return res if res and res["done"] else None


def pair_kind(res):
    return ("org.bluez.Device1.Pair:reply" if "method return" in res["out"]
            else "org.bluez.Device1.Pair:error")


# ---------------------------------------------------------------- B-nf, B-dl

def simple_body(hosts, caplog, adv_data, disc):
    dut, peer = hosts
    RUNDIR.mkdir(parents=True, exist_ok=True)
    r = Run(dut, peer)
    r.prologue(disc[0], disc[1], False)
    r.inbound_connection()
    time.sleep(2)
    r.summary["adv_data"] = adv_data
    advertise_until(r, adv_data, ADV_PERIOD, time.time() + ADV_PHASE)
    r.summary["removed_during_adv_phase"] = bool(r.check_removed(r.t_ref))
    r.wait_removed(POST_WAIT)
    r.mark("dut_interfaces_removed", recv_ns=r.removed)
    time.sleep(1)
    r.dump(caplog)
    assert r.t_added, "device object was not created by the inbound connection"


@pytest.mark.skipif(ARM not in ("BNF", "GNF"), reason="other arm")
@host_config(
    [UBluetoothd("U29_BLUETOOTHD", conf=CONF_NF), DbusRec(), Btmon()],
    [Btmon()],
    mem="784M",
)
def test_filter_off(hosts, caplog):
    simple_body(hosts, caplog,
                FLAGS_NOT_DISC if ARM == "BNF" else NO_FLAGS, ("none", "none"))


@pytest.mark.skipif(ARM not in ("GDL",), reason="other arm")
@host_config(
    [UBluetoothd("U29_BLUETOOTHD"), DbusRec(), Btmon()],
    [Btmon()],
    mem="784M",
)
def test_noflags_discovery(hosts, caplog):
    simple_body(hosts, caplog, NO_FLAGS, ("none", "none"))


# ------------------------------------------------------------------ P1, P2

@pytest.mark.skipif(ARM not in ("P1",), reason="other arm")
@host_config(
    [UBluetoothd("U29_BLUETOOTHD", args=("-P", "midi")), DbusRec(), Btmon(),
     Agent(), U29Profile("client")],
    [UBluetoothd("U29_BLUETOOTHD", args=("-P", "midi")), Btmon(), Agent(),
     U29Profile("server")],
    mem="784M",
)
def test_pair_link_up(hosts, caplog):
    dut, peer = hosts
    RUNDIR.mkdir(parents=True, exist_ok=True)
    r = Run(dut, peer)
    r.prologue("none", "none", True)
    r.inbound_connection()
    assert r.t_added, "device object was not created by the inbound connection"
    time.sleep(2)

    dut.call(vm_async_start, "pair", ["--dest=org.bluez", r.full_path,
                                      "org.bluez.Device1.Pair"])
    t_pair = time.time_ns()
    r.mark("pair_called", t=t_pair)
    c0 = dut.agent.expect("org.bluez.Agent1.RequestConfirmation")
    c1 = peer.agent.expect("org.bluez.Agent1.RequestConfirmation")
    r.mark("confirmations", dut=c0.passkey, peer=c1.passkey)
    peer.agent.reply()
    r.mark("peer_confirmed")
    t_scan = dut.call(vm_scan_start)
    r.mark("scanner_started", t=t_scan)
    advertise_until(r, FLAGS_NOT_DISC, V2_PERIOD, time.time() + PAIR_DELAY)
    t_conf = time.time_ns()
    dut.agent.reply()
    r.mark("dut_confirmed", t=t_conf)
    res = None
    for _ in range(300):
        res = pair_poll(r, "pair")
        if res:
            break
        time.sleep(0.2)
    t_scan_end, runs = dut.call(vm_scan_stop)
    r.mark("scanner_stopped", t=t_scan_end, runs=runs)
    kind = pair_kind(res)
    r.mark("pair_done", kind=kind, t=res["t1"], err=res["out"])
    r.summary.update(pair_start=t_pair, pair_end=res["t1"], pair_result=kind,
                     pair_out=res["out"].strip(), dut_confirmed=t_conf,
                     scan_start=t_scan, scan_end=t_scan_end,
                     removed_during_pairing=bool(
                         r.removed and t_pair <= r.removed <= res["t1"]))
    time.sleep(5)
    r.check_removed(r.t_ref)
    r.mark("dut_interfaces_removed", recv_ns=r.removed)
    time.sleep(1)
    r.dump(caplog)


@pytest.mark.skipif(ARM not in ("P2",), reason="other arm")
@host_config(
    [UBluetoothd("U29_BLUETOOTHD"), DbusRec(), Btmon(), Agent()],
    [Btmon()],
    mem="784M",
)
def test_pair_connecting(hosts, caplog):
    dut, peer = hosts
    RUNDIR.mkdir(parents=True, exist_ok=True)
    r = Run(dut, peer)
    r.prologue("none", "none", False)
    r.inbound_connection()
    assert r.t_added, "device object was not created by the inbound connection"
    time.sleep(2)

    dut.call(vm_async_start, "pair", ["--dest=org.bluez", r.full_path,
                                      "org.bluez.Device1.Pair"])
    t_pair = time.time_ns()
    r.mark("pair_called", t=t_pair)
    t_scan = dut.call(vm_scan_start)
    r.mark("scanner_started", t=t_scan)
    end = time.time() + P2_ADV
    k = 0
    res = None
    start = time.time()
    while time.time() < end:
        r.adv(FLAGS_NOT_DISC, k)
        k += 1
        nxt = start + k * V2_PERIOD
        while time.time() < min(nxt, end):
            r.check_removed(r.t_ref)
            if res is None:
                res = pair_poll(r, "pair")
                if res:
                    r.mark("pair_done", kind=pair_kind(res), t=res["t1"],
                           err=res["out"])
            time.sleep(0.2)
    t_scan_end, runs = dut.call(vm_scan_stop)
    r.mark("scanner_stopped", t=t_scan_end, runs=runs)
    r.summary["removed_during_adv_phase"] = bool(r.check_removed(r.t_ref))
    r.summary.update(pair_start=t_pair, scan_start=t_scan, scan_end=t_scan_end)
    if res:
        r.summary.update(pair_end=res["t1"], pair_result=pair_kind(res),
                         pair_out=res["out"].strip())
    else:
        r.summary["pair_result"] = "still pending at end of advertising"
    r.wait_removed(POST_WAIT)
    r.mark("dut_interfaces_removed", recv_ns=r.removed)
    time.sleep(1)
    r.dump(caplog)
