#!/usr/bin/env python3
"""mesh-removal.py <scenario> [--n N] [--cnt C] [--remove-after-ms D] [--iterations K] - CO-14: mesh sends
queued at controller removal (task 4). Runs inside a QEMU guest (the host's root), kernel with KASAN,
lockdep and kmemleak. The controller is BlueZ's btvirt (a virtual LE/BR-EDR controller on /dev/vhci);
removing it is terminating btvirt, which closes vhci and unregisters the hci device. Nothing here
touches the host.

Scenarios:
  backlog   open a mgmt socket, enable Mesh (experimental feature), Set LE, power on, queue N Mesh Send
            (Count C: each takes C * 25 ms on air), wait D ms, remove the controller, wait, close the
            mgmt socket; K iterations (default 1); then check what is left: kmemleak (3 scans), the
            kmalloc slab counts before and after, the Mesh Packet Complete events that arrived.
  complete  as backlog, but wait until every send has completed before the removal (control)
  nosend    as backlog with no Mesh Send (control)
Verdict (BT17-EXIT line, as the other harnesses): 0 when nothing from the mesh paths is left in kmemleak
and no kernel report other than a lockdep cycle; 1 otherwise. Lockdep cycles are counted apart.
"""
import ctypes
import os
import signal
import socket
import struct
import subprocess
import sys
import threading
import time

T0 = time.time()
LOCK = threading.Lock()
BTVIRT = "/root/exp/agent-work/co44-send-20261113/bluez/emulator/btvirt"
AF_BLUETOOTH, BTPROTO_HCI, HCI_CHANNEL_CONTROL, HCI_DEV_NONE = 31, 1, 3, 0xFFFF
MESH_UUID = bytes([0x76, 0x6e, 0xf3, 0xe8, 0x24, 0x5f, 0x05, 0xbf, 0x8d, 0x4d, 0x03, 0x7a, 0xd7, 0x63, 0xe4, 0x2c])
EV = {1: "Command Complete", 2: "Command Status", 4: "Index Added", 5: "Index Removed",
      6: "New Settings", 0x20: "Ext Index Added", 0x21: "Ext Index Removed", 0x32: "Mesh Packet Complete"}
KML = "/sys/kernel/debug/kmemleak"
SLABS = ("kmalloc-96", "kmalloc-128", "kmalloc-192", "kmalloc-256", "kmalloc-512", "kmalloc-1k", "kmalloc-2k",
         "kmalloc-4k", "kmalloc-8k")


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def arg(name, default=None):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "mgmt socket")
        addr = struct.pack("<HHH", AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.events = []        # (mono, ev, opcode, status, index, params)
        self.running = True
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while self.running:
            try:
                b = os.read(self.fd, 4096)
            except OSError:
                return
            if len(b) < 6:
                continue
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            if ev in (1, 2) and len(p) >= 3:
                op, st = struct.unpack("<HB", p[:3])
                self.events.append((mono(), ev, op, st, index, p[3:]))
            else:
                self.events.append((mono(), ev, None, None, index, p))
                if ev in (4, 5, 0x20, 0x21, 0x32):
                    log("MGMT %s index %d %s" % (EV.get(ev, hex(ev)), index, p.hex()))

    def wait_reply(self, op, timeout=10):
        t = time.time()
        while time.time() - t < timeout:
            for e in list(self.events):
                if e[2] == op and e[1] in (1, 2):
                    self.events.remove(e)
                    return e
            time.sleep(0.01)
        return None

    def count(self, ev):
        return len([1 for e in self.events if e[1] == ev])

    def close(self):
        self.running = False
        t = mono()
        os.close(self.fd)
        return mono() - t


def wait_for(cond, timeout, step=0.02):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(step)
    return False


def rd(path):
    try:
        return open(path).read()
    except OSError as e:
        return "<%s>" % e.strerror


def slab_counts():
    out = {}
    for l in rd("/proc/slabinfo").splitlines():
        p = l.split()
        if p and p[0] in SLABS:
            out[p[0]] = int(p[1])
    return out


def kml_scan(rounds=3):
    """scan <rounds> times, 8 s apart (an object is reported only after staying unreferenced and
    unchanged over successive scans), then read the report"""
    for i in range(rounds):
        with open(KML, "w") as f:
            f.write("scan")
        if i < rounds - 1:
            time.sleep(8)
    return rd(KML)


def kernel_reports():
    out = []
    for l in os.popen("dmesg --color=never").read().splitlines():
        if any(k in l for k in ("possible circular locking", "BUG:", "WARNING:", "KASAN:",
                                "possible recursive locking", "inconsistent lock", "blocked for more than")):
            out.append(l)
    return out


def mesh_send_params(cnt, tag):
    adv = bytes([5, 0x2A, tag & 0xFF, 1, 2, 3])
    return b"\0" * 7 + struct.pack("<QHBB", 0, 0, cnt, len(adv)) + adv


def one(sc, n, cnt, after, it):
    """one controller: returns (sends accepted, complete events before the removal, after it, close time)"""
    m = Mgmt()
    m.send(0x0001, HCI_DEV_NONE)          # Read Version: the socket is alive
    m.wait_reply(0x0001, 5)
    bt = subprocess.Popen([BTVIRT, "-l1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        raise RuntimeError("no hci0")
    wait_for(lambda: m.count(4) + m.count(0x20) > 0, 10)
    time.sleep(0.5)
    for op, par, what in ((0x0005, b"\x01", "Set Powered"), (0x000D, b"\x01", "Set LE"),
                          (0x004A, MESH_UUID + b"\x01", "Set Experimental Feature (mesh)")):
        m.send(op, 0, par)
        r = m.wait_reply(op, 10)
        if not r or r[3] != 0:
            raise RuntimeError("%s failed: %s" % (what, r))
    handles = []
    if sc != "nosend":
        for i in range(n):
            m.send(0x0059, 0, mesh_send_params(cnt, i + 1))
            r = m.wait_reply(0x0059, 10)
            handles.append(r[5][0] if r and r[3] == 0 and r[5] else None)
        log("it %d: Mesh Send handles %s" % (it, handles))
    t_sent = mono()
    if sc == "complete":
        wait_for(lambda: m.count(0x32) >= n, n * cnt * 0.025 * 3 + 10)
    elif sc == "hung":
        # a controller that stops answering, then is removed: SIGSTOP btvirt after D ms, send a command that
        # needs an HCI answer (Set Local Name) so that the command-sync worker waits for it, let the mesh
        # transmission end meanwhile (its follow-up is queued behind the stuck command), remove 300 ms later
        time.sleep(after / 1000.0)
        bt.send_signal(signal.SIGSTOP)
        m.send(0x000F, 0, b"hung".ljust(249, b"\0") + b"\0" * 11)
        time.sleep(0.3 + max(0.0, cnt * 0.025 - after / 1000.0))
    else:
        time.sleep(after / 1000.0)
    ev_before = m.count(0x32)
    t_rm = mono()
    bt.send_signal(signal.SIGKILL if sc == "hung" else signal.SIGTERM)   # vhci closes, hci_unregister_dev()
    bt.wait(timeout=20)
    gone = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 15)
    log("it %d: controller removed %.3f s after the removal request, %.3f s after the sends were queued, "
        "%d complete events before: gone=%s" % (it, mono() - t_rm, t_rm - t_sent, ev_before, gone))
    time.sleep(1.0)
    ev_after = m.count(0x32)
    t_close = m.close()
    log("it %d: Mesh Packet Complete %d before the removal, %d after (of %d); Index Removed %d; "
        "close() returned after %.6f s" % (it, ev_before, ev_after - ev_before, len(handles), m.count(5) + m.count(0x21), t_close))
    time.sleep(0.5)
    return len(handles), ev_before, ev_after - ev_before, t_close, gone


def main():
    sc = sys.argv[1]
    n = int(arg("--n", "3"))        # MESH_HANDLES_MAX is 3: a fourth Mesh Send is answered BUSY (0x0a)
    cnt = int(arg("--cnt", "20"))
    afters = [int(x) for x in arg("--remove-after-ms", "300").split(",")]   # cycled over the iterations
    after = afters[0]
    iters = int(arg("--iterations", "1"))
    trailing = int(arg("--trailing", "0"))   # extra iterations without Mesh Send, after the measured ones:
    # kmemleak reports an object only once the memory that pointed to it (a freed hci_dev) is gone, which
    # needs further allocation and freeing; these iterations provide it
    with open(KML, "w") as f:
        f.write("scan")
    time.sleep(1)
    with open(KML, "w") as f:
        f.write("clear")
    s0 = slab_counts()
    log("SLABS before %s" % s0)
    tot = [0, 0, 0]
    gone_all = True
    close_max = 0.0
    for it in range(iters):
        sent, eb, ea, tc, gone = one(sc, n, cnt, afters[it % len(afters)], it)
        tot[0] += sent
        tot[1] += eb
        tot[2] += ea
        gone_all = gone_all and gone
        close_max = max(close_max, tc)
    for it in range(trailing):
        one("nosend", n, cnt, 100, iters + it)
    s1 = slab_counts()
    log("SLABS after %s" % s1)
    log("SLABDIFF %s" % {k: s1.get(k, 0) - s0.get(k, 0) for k in s0})
    # --no-kml: only the kernel reports are wanted (the lockdep hunt), skip the 3 scans
    rep = "" if "--no-kml" in sys.argv else kml_scan()
    objs = rep.split("unreferenced object")[1:]
    mesh = [o for o in objs if "mgmt_mesh_add" in o or "mesh_send" in o]
    sock = [o for o in objs if "hci_sock_create" in o or "sk_alloc" in o]
    log("KMEMLEAK objects %d, from the mesh paths %d, sockets %d" % (len(objs), len(mesh), len(sock)))
    for l in rep.splitlines():
        log("KMEMLEAK | %s" % l)
    kr = kernel_reports()
    for l in kr:
        log("KREPORT %s" % l)
    circ = len([1 for l in kr if "possible circular locking" in l])
    other = [l for l in kr if "circular" not in l]
    log("RESULT %s n=%d cnt=%d remove_after_ms=%s iterations=%d trailing=%d sends=%d gone=%s complete_before=%d "
        "complete_after=%d never_completed=%d kmemleak_mesh=%d kmemleak_sock=%d kmemleak_all=%d close_max_s=%.6f "
        "lockdep_circular=%d other_kernel_reports=%d" %
        (sc, n, cnt, ",".join(str(a) for a in afters), iters, trailing, tot[0], gone_all, tot[1], tot[2],
         tot[0] - tot[1] - tot[2], len(mesh), len(sock), len(objs), close_max, circ, len(other)))
    if "--no-kml" in sys.argv:
        ok = gone_all and not other      # no leak judgement without the scans
    else:
        ok = gone_all and len(mesh) == 0 and len(sock) == 0 and not other
    log("%s %s" % ("PASS" if ok else "FAIL", sc))
    log("---- kernel log ----")
    os.system("dmesg")
    log("BT17-EXIT %d" % (0 if ok else 1))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        import traceback
        for l in traceback.format_exc().splitlines():
            log("scenario raised: " + l)
        log("FAIL %s" % sys.argv[1])
        log("BT17-EXIT 1")
        sys.exit(1)
