# SPDX-License-Identifier: GPL-2.0-or-later
"""
U29 patch regression matrix: lifetime of an unpaired temporary device object
in bluetoothd, after the peer's own inbound BR/EDR connection, with and
without LE advertisements from the same public address.

host0: device under test (bluetoothd -d, empty main.conf, discovery running)
host1: the peer. Arms A-G and J: a bare btvirt dual-mode controller driven
       with btmgmt (no bluetoothd). Arms H and I: the peer runs bluetoothd
       with an agent, so that pairing is possible.

One test = one arm = one repetition (fresh guests). Environment:
U29_ARM, U29_RUNDIR, U29_BLUETOOTHD, U29_VM_DISCOVERY.
"""

import json
import os
import re
import subprocess
import threading
import time
from pathlib import Path

import pytest

from pytest_bluezenv import Agent, Btmon, host_config, utils

from .u29_plugins import DbusRec, U29Profile, UBluetoothd

pytestmark = [pytest.mark.vm]

ARM = os.environ.get("U29_ARM", "A")
RUNDIR = Path(os.environ.get("U29_RUNDIR", "/tmp/u29-run"))

FLAGS_NOT_DISC = "020118"
FLAGS_DISC = "02011a"
NO_FLAGS = "050954455354"          # Complete Local Name "TEST", no Flags AD

# arm -> (AD data hex or None, (discovery Transport, discovery Discoverable))
ARMS = {
    "A": (None, ("none", "none")),
    "B": (FLAGS_NOT_DISC, ("none", "none")),
    "C": (FLAGS_DISC, ("none", "none")),
    "D": (FLAGS_NOT_DISC, ("none", "true")),
    "E": (FLAGS_NOT_DISC, ("le", "none")),
    "G": (NO_FLAGS, ("none", "none")),
    "H": (FLAGS_NOT_DISC, ("none", "none")),
    "I": (FLAGS_NOT_DISC, ("none", "none")),
    "J": (FLAGS_NOT_DISC, ("none", "none")),
}
SIMPLE_ARMS = ("A", "B", "C", "D", "E", "G")
ADV_PERIOD = 10          # s between advertisements
ADV_PHASE = 120          # s of advertising (simple arms)
HOLD = 5                 # s connected (SDP link) before the peer disconnects
POST_WAIT = 75           # s to wait for removal after the last advertisement
J_HOLD = 65              # s the ACL is held in arm J
PAIR_DELAY = 40          # s the DUT agent delays its confirmation (arm I)
H_ADV = 60               # s of advertising before Connect() (arm H)

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def vm_tool(subdir, name, args):
    """Runs in a guest: a BlueZ tool; returns (t_start_ns, t_end_ns, output)"""
    exe = utils.find_exe(subdir, name)
    t0 = time.time_ns()
    res = subprocess.run([exe] + list(args), stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, encoding="utf-8",
                         timeout=20)
    return t0, time.time_ns(), res.stdout


def vm_dbus_send(args):
    """Runs in a guest: dbus-send on the system bus"""
    exe = utils.find_exe("", "dbus-send")
    t0 = time.time_ns()
    res = subprocess.run([exe, "--system", "--print-reply"] + list(args),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         encoding="utf-8", timeout=20)
    return t0, time.time_ns(), res.stdout


ASYNC = {}


def _async_thread(key, args):
    ASYNC[key] = dict(done=False)
    exe = utils.find_exe("", "dbus-send")
    t0 = time.time_ns()
    res = subprocess.run([exe, "--system", "--print-reply",
                          "--reply-timeout=120000"] + list(args),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         encoding="utf-8")
    ASYNC[key] = dict(done=True, t0=t0, t1=time.time_ns(), out=res.stdout,
                      rc=res.returncode)


def vm_async_start(key, args):
    """Runs in a guest: a dbus-send call with a 120 s reply timeout (the
    python agent helper's calls time out after 25 s), in a thread"""
    ASYNC[key] = dict(done=False)
    threading.Thread(target=_async_thread, args=(key, args),
                     daemon=True).start()


def vm_async_poll(key):
    return ASYNC.get(key)


def vm_l2cap_hold(addr, hold_s):
    """Peer guest: an unauthenticated BR/EDR link to <addr> (L2CAP to the
    SDP PSM 1, no pairing), held for <hold_s> s, then closed."""
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


HOLDSTATE = {}


def _hold_thread(addr, hold_s, period, adv_data):
    """Peer guest, background thread: SDP link held for hold_s while an
    advertisement is sent every <period> s (arm J)"""
    import socket

    st = HOLDSTATE
    st["t_start"] = time.time_ns()
    st["advs"] = []
    st["err"] = None
    s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET,
                      socket.BTPROTO_L2CAP)
    s.settimeout(10)
    try:
        s.connect((addr, 1))
        st["t_connected"] = time.time_ns()
        t0 = time.time()
        k = 0
        while time.time() - t0 < hold_s:
            r = vm_tool("tools", "btmgmt",
                        ["--index", "0", "add-adv", "-d", adv_data, "-c",
                         "-t", "2", "1"])
            st["advs"].append(r[0])
            k += 1
            while time.time() < t0 + k * period and time.time() - t0 < hold_s:
                time.sleep(0.2)
    except OSError as exc:
        st["err"] = repr(exc)
    st["t_close"] = time.time_ns()
    s.close()
    st["done"] = True


def vm_hold_start(addr, hold_s, period, adv_data):
    HOLDSTATE.clear()
    HOLDSTATE["done"] = False
    threading.Thread(target=_hold_thread,
                     args=(addr, hold_s, period, adv_data),
                     daemon=True).start()


def vm_hold_poll():
    return dict(HOLDSTATE)


def vm_dut_info():
    """DUT guest: connectable on"""
    return vm_tool("tools", "btmgmt", ["--index", "0", "connectable", "on"])


def hlines(caplog, idx, name):
    pat = re.compile(rf"^host\.\d+\.{idx}\.{name}$")
    return [(getattr(r, "nsec", int(r.created * 1e9)), r.getMessage())
            for r in list(caplog.records) if pat.match(r.name)]


class Run:
    """The state of one run: event list, addresses, helpers"""

    def __init__(self, dut, peer):
        self.dut, self.peer = dut, peer
        self.ev = []
        self.dut_addr = dut.bdaddr.upper()
        self.peer_addr = peer.bdaddr.upper()
        self.dev_path = "dev_" + self.peer_addr.replace(":", "_")
        self.full_path = "/org/bluez/hci0/" + self.dev_path
        self.advs = []
        self.removed = None
        self.summary = {}

    def mark(self, name, **kw):
        self.ev.append(dict(t_ns=time.time_ns(), event=name, **kw))

    def adv(self, adv_data, k):
        r = self.peer.call(vm_tool, "tools", "btmgmt",
                           ["--index", "0", "add-adv", "-d", adv_data, "-c",
                            "-t", "2", "1"])
        self.advs.append(r[0])
        self.mark("peer_add_adv", n=k, t_start=r[0], t_end=r[1], out=r[2])

    def check_removed(self, after):
        if self.removed is None:
            self.removed = self.dut.dbusrec.find(
                ["member=InterfacesRemoved", self.dev_path], after)
        return self.removed

    def prologue(self, transport, discoverable, peer_bluetoothd):
        dut, peer = self.dut, self.peer
        self.mark("addresses", dut=self.dut_addr, peer=self.peer_addr,
                  arm=ARM, disc_transport=transport,
                  disc_discoverable=discoverable)
        if peer_bluetoothd:
            peer.agent.adapter_set("Pairable", True)
        # A peer controller that is connectable (page scan) also answers the
        # DUT's inquiry, which would give the DUT legitimate BR/EDR reports;
        # so the bare peer of arms A-G, J stays non-connectable. With
        # bluetoothd (H, I) it must be connectable to be paired.
        cmds = [["--index", "0", "power", "on"], ["--index", "0", "le", "on"]]
        if peer_bluetoothd:
            cmds.append(["--index", "0", "connectable", "on"])
        cmds.append(["--index", "0", "info"])
        for a in cmds:
            r = peer.call(vm_tool, "tools", "btmgmt", a)
            self.mark("peer_btmgmt", args=a, out=r[2])
        r = dut.call(vm_dut_info)
        self.mark("dut_connectable_on", out=r[2])
        dut.dbusrec.start_discovery(os.environ["U29_VM_DISCOVERY"],
                                    transport, discoverable)
        time.sleep(3)
        self.mark("discovery_started", lines=dut.dbusrec.discovery_lines())
        t_a = time.time_ns()
        g0 = dut.dbusrec.now()
        g1 = peer.call(vm_tool, "tools", "btmgmt", ["--index", "0", "info"])[0]
        t_b = time.time_ns()
        self.mark("clock_check", tester_before=t_a, dut_now=g0, peer_t0=g1,
                  tester_after=t_b)

    def inbound_connection(self, hold=HOLD):
        """Peer connects BR/EDR (SDP link), disconnects. Returns t_disc."""
        dut, peer = self.dut, self.peer
        self.t_cc = dut.dbusrec.now()
        r = peer.call(vm_l2cap_hold, self.dut_addr, hold)
        self.mark("peer_l2cap_hold", result=r)
        self.t_added = dut.dbusrec.find(
            ["member=InterfacesAdded", self.dev_path], self.t_cc)
        self.mark("dut_interfaces_added", recv_ns=self.t_added)
        r = peer.call(vm_tool, "tools", "btmgmt",
                      ["--index", "0", "disconnect", self.dut_addr])
        self.mark("peer_btmgmt_disconnect", out=r[2], t_start=r[0], t_end=r[1])
        self.wait_disconnected()
        return self.t_disc

    def wait_disconnected(self):
        self.t_disc = None
        for _ in range(150):
            self.t_disc = self.dut.dbusrec.find(
                ["member=PropertiesChanged", self.dev_path,
                 "string \"Connected\""], self.t_cc)
            if self.t_disc:
                break
            time.sleep(0.1)
        self.mark("dut_disconnected", recv_ns=self.t_disc)
        self.t_ref = self.t_disc or self.t_cc

    def wait_removed(self, secs):
        end = time.time() + secs
        while time.time() < end and not self.check_removed(self.t_ref):
            time.sleep(0.25)

    def dump(self, caplog):
        dut = self.dut
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
            for e in self.ev:
                f.write(json.dumps(e, default=str) + "\n")
        summary = dict(arm=ARM, dut=self.dut_addr, peer=self.peer_addr,
                       t_connect_req=self.t_cc, t_added=self.t_added,
                       t_disconnected=self.t_disc, adv_starts=self.advs,
                       last_adv=self.advs[-1] if self.advs else None,
                       removed=self.removed)
        summary.update(self.summary)
        with open(RUNDIR / "summary.json", "w") as f:
            json.dump(summary, f, indent=1, default=str)


# ---------------------------------------------------------------------------

@pytest.mark.skipif(ARM not in SIMPLE_ARMS + ("J",), reason="other arm")
@host_config(
    [UBluetoothd("U29_BLUETOOTHD"), DbusRec(), Btmon()],
    [Btmon()],
    mem="784M",
)
def test_simple(hosts, caplog):
    dut, peer = hosts
    adv_data, (d_transport, d_disc) = ARMS[ARM]
    RUNDIR.mkdir(parents=True, exist_ok=True)
    r = Run(dut, peer)
    r.prologue(d_transport, d_disc, False)

    if ARM == "J":
        # ACL held for J_HOLD s with an advertisement every ADV_PERIOD s
        r.t_cc = dut.dbusrec.now()
        peer.call(vm_hold_start, r.dut_addr, J_HOLD, ADV_PERIOD, adv_data)
        st = {}
        while not st.get("done"):
            time.sleep(1)
            st = peer.call(vm_hold_poll)
            r.check_removed(r.t_cc)
        r.advs = st.get("advs", [])
        r.mark("peer_hold", result=st)
        r.t_added = dut.dbusrec.find(
            ["member=InterfacesAdded", r.dev_path], r.t_cc)
        r.mark("dut_interfaces_added", recv_ns=r.t_added)
        r.summary["hold"] = st
        rr = peer.call(vm_tool, "tools", "btmgmt",
                       ["--index", "0", "disconnect", r.dut_addr])
        r.mark("peer_btmgmt_disconnect", out=rr[2], t_start=rr[0], t_end=rr[1])
        r.wait_disconnected()
        # (removed may already be set: removal while connected is a result)
        r.removed_before_disc = bool(r.removed and r.t_disc
                                     and r.removed < r.t_disc)
        r.summary["removed_before_disconnect"] = r.removed_before_disc
        r.wait_removed(POST_WAIT)
    else:
        r.inbound_connection()
        if adv_data is None:
            r.wait_removed(POST_WAIT)
        else:
            time.sleep(2)
            start = time.time()
            k = 0
            while time.time() - start < ADV_PHASE:
                t_beat = start + k * ADV_PERIOD
                while time.time() < t_beat:
                    r.check_removed(r.t_ref)
                    time.sleep(0.2)
                r.adv(adv_data, k)
                k += 1
            # advertising stopped (instance timeout 2 s); wait for removal
            r.summary["removed_during_adv_phase"] = bool(r.check_removed(r.t_ref))
            r.wait_removed(POST_WAIT)
    r.mark("dut_interfaces_removed", recv_ns=r.removed)
    time.sleep(1)
    r.dump(caplog)
    assert r.t_added, "device object was not created by the inbound connection"


# ---------------------------------------------------------------------------

def agent_pair(r, delay):
    """DUT Pair() on the temporary device; the DUT agent confirms after
    <delay> s while the peer confirms at once. Advertisements go on every
    ADV_PERIOD s meanwhile (arm I) or not at all (delay 0, arm H)."""
    dut, peer = r.dut, r.peer
    adv_data = ARMS[ARM][0]
    dut.call(vm_async_start, "pair", ["--dest=org.bluez", r.full_path,
                                      "org.bluez.Device1.Pair"])
    t_pair = time.time_ns()
    r.mark("pair_called", t=t_pair)
    c0 = dut.agent.expect("org.bluez.Agent1.RequestConfirmation")
    c1 = peer.agent.expect("org.bluez.Agent1.RequestConfirmation")
    r.mark("confirmations", dut=c0.passkey, peer=c1.passkey)
    peer.agent.reply()
    t0 = time.time()
    k = 0
    while delay and time.time() - t0 < delay:
        r.adv(adv_data, k)
        k += 1
        end = t0 + k * ADV_PERIOD
        while time.time() < min(end, t0 + delay):
            r.check_removed(r.t_ref)
            time.sleep(0.2)
    dut.agent.reply()
    r.mark("dut_confirmed")
    res = None
    for _ in range(300):
        res = dut.call(vm_async_poll, "pair")
        if res and res["done"]:
            break
        time.sleep(0.2)
    kind = ("org.bluez.Device1.Pair:reply" if "method return" in res["out"]
            else "org.bluez.Device1.Pair:error")
    t_end = res["t1"]
    r.mark("pair_done", kind=kind, t=t_end, err=res["out"])
    return t_pair, t_end, kind


@pytest.mark.skipif(ARM not in ("H", "I"), reason="other arm")
@host_config(
    [UBluetoothd("U29_BLUETOOTHD", args=("-P", "midi")), DbusRec(), Btmon(),
     Agent(), U29Profile("client")],
    [UBluetoothd("U29_BLUETOOTHD", args=("-P", "midi")), Btmon(), Agent(),
     U29Profile("server")],
    mem="784M",
)
def test_full(hosts, caplog):
    dut, peer = hosts
    adv_data, (d_transport, d_disc) = ARMS[ARM]
    RUNDIR.mkdir(parents=True, exist_ok=True)
    r = Run(dut, peer)
    r.prologue(d_transport, d_disc, True)
    r.inbound_connection()
    assert r.t_added, "device object was not created by the inbound connection"
    time.sleep(2)

    if ARM == "I":
        t_pair, t_end, kind = agent_pair(r, PAIR_DELAY)
        r.summary.update(pair_start=t_pair, pair_end=t_end, pair_result=kind,
                         removed_during_pairing=bool(
                             r.removed and t_pair <= r.removed <= t_end))
        # the device is paired now; keep watching for a while
        time.sleep(5)
        r.check_removed(r.t_ref)
    else:
        # H: pair at once, trust, disconnect, advertise 0x18, Connect()
        t_pair, t_end, kind = agent_pair(r, 0)
        r.summary.update(pair_start=t_pair, pair_end=t_end, pair_result=kind)
        rr = dut.call(vm_dbus_send, [
            "--dest=org.bluez", r.full_path,
            "org.freedesktop.DBus.Properties.Set", "string:org.bluez.Device1",
            "string:Trusted", "variant:boolean:true"])
        r.mark("trusted", out=rr[2])
        peer.agent.adapter_set("Discoverable", False)
        t_cc = dut.dbusrec.now()
        dut.agent.device_method(r.peer_addr, "Disconnect")
        dut.agent.expect(("org.bluez.Device1.Disconnect:reply",
                          "org.bluez.Device1.Disconnect:error"))
        r.t_cc = t_cc
        r.wait_disconnected()
        r.mark("disconnected_after_pair", recv_ns=r.t_disc)
        time.sleep(2)
        start = time.time()
        k = 0
        while time.time() - start < H_ADV:
            t_beat = start + k * ADV_PERIOD
            while time.time() < t_beat:
                r.check_removed(r.t_ref)
                time.sleep(0.2)
            r.adv(adv_data, k)
            k += 1
        time.sleep(2)
        t_conn = time.time_ns()
        r.mark("connect_called", t=t_conn)
        dut.call(vm_async_start, "connect", ["--dest=org.bluez", r.full_path,
                                             "org.bluez.Device1.Connect"])
        res = None
        for _ in range(300):
            res = dut.call(vm_async_poll, "connect")
            if res and res["done"]:
                break
            time.sleep(0.2)
        kind = ("org.bluez.Device1.Connect:reply"
                if "method return" in res["out"]
                else "org.bluez.Device1.Connect:error")
        r.mark("connect_done", kind=kind, t=res["t1"], err=res["out"])
        r.summary.update(connect_called=t_conn, connect_result=kind,
                         connect_error=res["out"].strip())
        time.sleep(5)
        r.check_removed(r.t_ref)
    r.mark("dut_interfaces_removed", recv_ns=r.removed)
    time.sleep(1)
    r.dump(caplog)
