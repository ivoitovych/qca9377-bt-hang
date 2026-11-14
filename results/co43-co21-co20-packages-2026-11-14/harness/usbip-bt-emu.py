#!/usr/bin/env python3
"""usbip-bt-emu.py - a USB Bluetooth controller in userspace, attached through
the kernel's usbip vhci_hcd, so that the real btusb driver binds to it in a guest.

It runs inside a QEMU guest whose kernel has CONFIG_USBIP_VHCI_HCD=y. It
  * makes a socket pair and hands one end to vhci_hcd (the sysfs attach file),
    then speaks the usbip URB protocol on the other end;
  * presents the descriptors of the laptop's controller (class e0/01/01, an
    interrupt IN endpoint, two bulk endpoints, and interface 1 with isochronous
    endpoints 0x83/0x03 in alternate settings 0 to 5 of 0, 9, 17, 25, 33, 49 bytes);
  * answers HCI commands on the control endpoint with events on the interrupt
    endpoint (enough of a controller for hci0 to come up and for SCO/eSCO setups);
  * logs every SET_INTERFACE with the time, every isochronous URB submission
    and what the kernel reads from sysfs (the interface's bAlternateSetting).
It simulates the controller only: nothing here is measured on the laptop.

Usage: usbip-bt-emu.py <scenario> [--tcp]
"""
import ctypes
import errno
import fcntl
import os
import select
import socket
import struct
import sys
import threading
import time
from collections import deque

T0 = time.time()
LOG_LOCK = threading.Lock()


def log(msg):
    with LOG_LOCK:
        print("%7.3f %s" % (time.time() - T0, msg), flush=True)


# ---------------------------------------------------------------- descriptors
def ep(addr, attr, mps, ival):
    return struct.pack("<BBBBHB", 7, 5, addr, attr, mps, ival)


def iface(num, alt, neps):
    return struct.pack("<BBBBBBBBB", 9, 4, num, alt, neps, 0xE0, 1, 1, 0)


def config_desc():
    body = iface(0, 0, 3) + ep(0x81, 3, 16, 1) + ep(0x82, 2, 64, 0) + ep(0x02, 2, 64, 0)
    for alt, mps in enumerate((0, 9, 17, 25, 33, 49)):
        body += iface(1, alt, 2) + ep(0x83, 1, mps, 1) + ep(0x03, 1, mps, 1)
    total = 9 + len(body)
    return struct.pack("<BBHBBBBB", 9, 2, total, 2, 1, 0, 0xE0, 50) + body


DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0200, 0xE0, 1, 1, 64,
                       0x1234, 0x5678, 0x0100, 0, 0, 0, 1)

# ---------------------------------------------------------------- the controller
BDADDR = bytes([0x00, 0x00, 0x00, 0xDE, 0xAD, 0x00])
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])


class Emu:
    def __init__(self, use_tcp=False):
        self.use_tcp = use_tcp
        self.lock = threading.Lock()
        self.intr_pending = deque()      # (seq, buflen)
        self.iso_in_pending = deque()    # (seq, npackets, descs, due)
        self.intr_out = bytearray()
        self.next_handle = 0x0100
        self.alt = 0
        self.cmd_log = []
        self.sets = []                   # (time, alt)
        self.iso_urbs = 0
        self.sync_delay = 0.05
        self.acl_fail = set()
        self.links = {}                  # sco handle -> acl handle
        self.sco_data_for = {}           # sco handle -> bool, feed SCO data
        self.unknown = set()
        self.feed_on = False
        self.residue_n = 0
        self.feed = {}                   # sco handle -> True: send SCO data for it
        self.inject = deque()            # handles to send one packet for, ahead of the feed
        self.rx_sent = {}
        self.sock = None
        self.running = True

    # -- usbip
    def attach(self):
        base = "/sys/devices/platform/vhci_hcd.0"
        if self.use_tcp:
            srv = socket.socket()
            srv.bind(("127.0.0.1", 0))
            srv.listen(1)
            cli = socket.create_connection(srv.getsockname())
            self.sock, _ = srv.accept()
            kfd = cli
        else:
            kfd, self.sock = socket.socketpair()
        with open(base + "/attach", "w") as f:
            # port sockfd devid speed (2 = full speed, as the laptop's controller)
            f.write("0 %d %d 2" % (kfd.fileno(), (1 << 16) | 2))
        log("attached to vhci_hcd port 0")
        t = threading.Thread(target=self.loop, daemon=True)
        t.start()
        t2 = threading.Thread(target=self.iso_timer, daemon=True)
        t2.start()
        self.kfd = kfd

    def recvn(self, n):
        b = b""
        while len(b) < n:
            c = self.sock.recv(n - len(b))
            if not c:
                raise EOFError
            b += c
        return b

    def send(self, data):
        with self.lock:
            self.sock.sendall(data)

    def ret_submit(self, seq, status=0, actual=0, data=b"", nump=0, descs=b"", start=0, errc=0):
        h = struct.pack(">IIIII", 3, seq, 0, 0, 0)
        h += struct.pack(">iiiii", status, actual, start, nump, errc)
        h += b"\0" * 8
        self.send(h + data + descs)

    def ret_unlink(self, seq, status):
        h = struct.pack(">IIIII", 4, seq, 0, 0, 0) + struct.pack(">i", status) + b"\0" * 24
        self.send(h)

    def loop(self):
        try:
            while self.running:
                hdr = self.recvn(48)
                cmd, seq, devid, direction, epn = struct.unpack(">IIIII", hdr[:20])
                u = hdr[20:]
                if cmd == 1:
                    flags, buflen, start, nump, ival = struct.unpack(">IiiiI", u[:20])
                    nump = struct.unpack(">i", u[12:16])[0]
                    setup = u[20:28]
                    data = b""
                    if direction == 0 and buflen > 0:
                        data = self.recvn(buflen)
                    descs = []
                    if nump > 0:
                        raw = self.recvn(16 * nump)
                        for i in range(nump):
                            descs.append(list(struct.unpack(">IIII", raw[16 * i:16 * i + 16])))
                        if direction == 0 and False:
                            pass
                    self.submit(seq, direction, epn, buflen, start, nump, setup, data, descs)
                elif cmd == 2:
                    victim = struct.unpack(">I", u[:4])[0]
                    self.unlink(seq, victim)
                else:
                    log("unknown usbip command %d" % cmd)
        except (EOFError, OSError) as e:
            log("usbip socket ended: %r" % (e,))

    def unlink(self, seq, victim):
        with self.lock:
            hit = False
            for q in (self.intr_pending, self.iso_in_pending):
                for item in list(q):
                    if item[0] == victim:
                        q.remove(item)
                        hit = True
        self.ret_unlink(seq, -104 if hit else 0)

    # -- URB handling
    def submit(self, seq, direction, epn, buflen, start, nump, setup, data, descs):
        if epn == 0:
            self.control(seq, direction, buflen, setup, data)
        elif epn == 1 and direction == 1:
            with self.lock:
                self.intr_pending.append((seq, buflen))
            self.pump()
        elif epn == 2 and direction == 1:
            # bulk IN (ACL): nothing to deliver; keep it pending forever
            pass
        elif epn == 2 and direction == 0:
            self.ret_submit(seq, 0, buflen)
        elif epn == 3 and direction == 1:
            self.iso_urbs += 1
            if self.iso_urbs <= 3 or self.iso_urbs % 500 == 0:
                log("isoc IN URB #%d submitted (%d packets, alt %d)" % (self.iso_urbs, nump, self.alt))
            with self.lock:
                self.iso_in_pending.append((seq, nump, descs, time.time() + 0.01 * nump / 10.0, start))
        elif epn == 3 and direction == 0:
            for d in descs:
                d[2] = d[1]
                d[3] = 0
            self.ret_submit(seq, 0, buflen, b"", nump, b"".join(struct.pack(">IIII", *d) for d in descs), start)
        else:
            log("URB for unexpected ep %d dir %d" % (epn, direction))
            self.ret_submit(seq, -32, 0)

    def iso_timer(self):
        while self.running:
            time.sleep(0.005)
            now = time.time()
            ready = []
            with self.lock:
                for item in list(self.iso_in_pending):
                    if item[3] <= now:
                        self.iso_in_pending.remove(item)
                        ready.append(item)
            for item in ready:
                self.complete_iso(item)

    def flush_iso(self, n):
        """complete up to n pending isochronous IN URBs now (data in flight)"""
        for _ in range(n):
            with self.lock:
                if not self.iso_in_pending:
                    return
                item = self.iso_in_pending.popleft()
            self.complete_iso(item)

    def complete_iso(self, item):
        """answer one isochronous IN URB: SCO packets of the fed links and any injected handle,
        whole packets (header, length, payload) filling each frame"""
        seq, nump, descs, due, start = item
        payload = b""
        out = []
        with self.lock:
            feed = list(self.feed)
            inject = self.inject.popleft() if self.inject else None
        for i, d in enumerate(descs):
            flen = d[1]
            h = None
            if i == 0 and inject is not None:
                h = inject
            elif feed:
                h = feed[i % len(feed)]
            if h is not None and flen > 3:
                pkt = struct.pack("<HB", h, flen - 3) + b"\x55" * (flen - 3)
                payload += pkt
                d[2] = len(pkt)
                self.rx_sent[h] = self.rx_sent.get(h, 0) + 1
            else:
                d[2] = 0
            d[3] = 0
            out.append(struct.pack(">IIII", *d))
        self.ret_submit(seq, 0, len(payload), payload, nump, b"".join(out), start)

    def control(self, seq, direction, buflen, setup, data):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        if bm == 0x80 and br == 6:                       # GET_DESCRIPTOR
            t, idx = wv >> 8, wv & 0xFF
            if t == 1:
                d = DEV_DESC
            elif t == 2:
                d = config_desc()
            else:
                self.ret_submit(seq, -32, 0)
                return
            d = d[:wl]
            self.ret_submit(seq, 0, len(d), d)
        elif bm == 0x00 and br == 9:                     # SET_CONFIGURATION
            log("SET_CONFIGURATION %d" % wv)
            self.ret_submit(seq, 0, 0)
        elif bm == 0x01 and br == 11:                    # SET_INTERFACE
            if wi == 1:
                self.alt = wv
                self.sets.append((time.time() - T0, wv))
                log("SET_INTERFACE interface 1 alt %d" % wv)
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 5:                     # SET_ADDRESS
            self.ret_submit(seq, 0, 0)
        elif bm == 0x20 and br == 0:                     # HCI command
            self.ret_submit(seq, 0, len(data))
            op, plen = struct.unpack("<HB", data[:3])
            self.hci_cmd(op, data[3:3 + plen])
        elif bm & 0x60 == 0 and br in (1, 3):            # CLEAR/SET_FEATURE
            self.ret_submit(seq, 0, 0)
        elif bm == 0x80 and br == 8:                     # GET_CONFIGURATION
            self.ret_submit(seq, 0, 1, b"\x01")
        elif bm == 0x81 and br == 10:                    # GET_INTERFACE
            self.ret_submit(seq, 0, 1, bytes([self.alt]))
        elif bm == 0x80 and br == 0:                     # GET_STATUS
            self.ret_submit(seq, 0, 2, b"\x01\x00")
        else:
            log("control request %02x %02x %04x %04x %04x not handled" % (bm, br, wv, wi, wl))
            self.ret_submit(seq, -32, 0)

    # -- events out
    def event(self, code, params):
        pkt = bytes([code, len(params)]) + params
        with self.lock:
            self.intr_out += pkt
        self.pump()

    def pump(self):
        while True:
            with self.lock:
                if not self.intr_pending or not self.intr_out:
                    return
                seq, buflen = self.intr_pending.popleft()
                chunk = bytes(self.intr_out[:min(buflen, 16)])
                del self.intr_out[:len(chunk)]
            self.ret_submit(seq, 0, len(chunk), chunk)

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def cs(self, op, status=0):
        self.event(0x0F, struct.pack("<BBH", status, 1, op))

    def hci_cmd(self, op, p):
        self.cmd_log.append(op)
        log("HCI cmd 0x%04x %s" % (op, p.hex()))
        if op == 0x0C03:                                  # Reset
            self.cc(op)
        elif op == 0x1001:                                # Read Local Version
            self.cc(op, struct.pack("<BBHBHH", 0, 9, 0x100, 9, 0xFFFF, 0x100))
        elif op == 0x1002:                                # Read Local Supported Commands
            cmds = bytearray(64)
            cmds[9] = 0x04            # Read Voice Setting: without it the core sets sco_pkts to 0
            self.cc(op, b"\0" + bytes(cmds))
        elif op == 0x1003:                                # Read Local Features
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:                                # Read Buffer Size
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:                                # Read BD_ADDR
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:                                # Read Class of Device
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:                                # Read Local Name
            self.cc(op, b"\0" + b"usbip-emu".ljust(248, b"\0"))
        elif op == 0x0C25:                                # Read Voice Setting
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:                                # Read Num Supported IAC
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:                                # Read Current IAC LAP
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        elif op == 0x0405:                                # Create Connection
            addr = p[:6]
            self.cs(op)
            threading.Thread(target=self.acl_connect, args=(bytes(addr),), daemon=True).start()
        elif op == 0x041B:                                # Read Remote Supported Features
            h = struct.unpack("<H", p[:2])[0]
            self.cs(op)
            self.event(0x0B, struct.pack("<BH", 0, h) + FEATURES)
        elif op == 0x0428:                                # Setup Synchronous Connection
            h, txbw, rxbw, lat, voice, retr, pkt = struct.unpack("<HIIHHBH", p[:17])
            self.cs(op)
            threading.Thread(target=self.sco_connect, args=(h, voice), daemon=True).start()
        elif op == 0x0406:                                # Disconnect
            h, reason = struct.unpack("<HB", p[:3])
            self.cs(op)
            with self.lock:
                had = self.feed.pop(h, None)
                if had and self.residue_n:
                    self.inject.extend([h] * self.residue_n)
            self.event(0x05, struct.pack("<BHB", 0, h, 0x16))
            if had and self.residue_n:
                self.flush_iso(self.residue_n)       # data the controller had queued for h
            self.links.pop(h, None)
        elif op == 0x0408:                                # Create Connection Cancel
            self.cc(op, b"\0" + p[:6])
        else:
            if op not in self.unknown:
                self.unknown.add(op)
                log("HCI command 0x%04x (%s): generic Command Complete" % (op, p.hex()))
            self.cc(op)

    def acl_connect(self, addr):
        time.sleep(0.02)
        if addr in self.acl_fail:
            self.event(0x03, struct.pack("<BH6sBB", 0x04, 0, addr, 1, 0))
            return
        h = self.next_handle
        self.next_handle += 1
        self.acl_handles = getattr(self, "acl_handles", {})
        self.acl_handles[h] = addr
        self.event(0x03, struct.pack("<BH6sBB", 0, h, addr, 1, 0))

    def sco_connect(self, acl, voice):
        time.sleep(self.sync_delay)
        h = self.next_handle
        self.next_handle += 1
        air = 3 if voice & 3 == 3 else 2
        self.links[h] = acl
        addr = self.acl_handles[acl]
        log("SCO link handle 0x%04x up on ACL 0x%04x, voice 0x%04x, air mode %d" % (h, acl, voice, air))
        self.event(0x2C, struct.pack("<BH6sBBBHHB", 0, h, addr, 2, 12, 4, 60, 60, air))
        self.last_sco = h
        if self.feed_on:
            with self.lock:
                self.feed[h] = True


# ---------------------------------------------------------------- the kernel side
def sysfs_alt():
    base = "/sys/bus/usb/devices"
    try:
        for d in sorted(os.listdir(base)):
            if d.endswith(":1.1"):
                with open(os.path.join(base, d, "bAlternateSetting")) as f:
                    return int(f.read().strip())
    except OSError:
        pass
    return None


AF_BLUETOOTH, BTPROTO_SCO, BTPROTO_HCI, SOL_BLUETOOTH, BT_VOICE = 31, 2, 1, 274, 11
HCIDEVUP = 0x400448C9


def wait_hci0(timeout=15):
    t = time.time()
    while time.time() - t < timeout:
        if os.path.exists("/sys/class/bluetooth/hci0"):
            return True
        time.sleep(0.1)
    return False


def hci_up():
    s = socket.socket(AF_BLUETOOTH, socket.SOCK_RAW, BTPROTO_HCI)
    for i in range(50):
        try:
            fcntl.ioctl(s.fileno(), HCIDEVUP, 0)
            log("hci0 up")
            return True
        except OSError as e:
            if e.errno == errno.EALREADY:
                log("hci0 already up")
                return True
            time.sleep(0.2)
    log("hci0 could not be brought up")
    return False


def sco_open(addr, voice):
    s = socket.socket(AF_BLUETOOTH, socket.SOCK_SEQPACKET, BTPROTO_SCO)
    s.setsockopt(SOL_BLUETOOTH, BT_VOICE, struct.pack("<H", voice))
    s.connect(addr.encode())
    return s


def snapshot(emu, label, expect):
    time.sleep(0.4)
    a = sysfs_alt()
    ok = "ok" if a == expect else "WRONG"
    log("STATE %-46s alt(sysfs)=%s alt(emu)=%d expect=%d  %s" % (label, a, emu.alt, expect, ok))
    return a == expect


MSBC, CVSD = 0x0003, 0x0060


def scenario_two_links(emu, voice, first_down):
    """two SCO links up, hang up one, read the alternate setting"""
    res = []
    a1, a2 = "00:11:22:33:44:01", "00:11:22:33:44:02"
    s1 = sco_open(a1, voice)
    res.append(snapshot(emu, "link 1 up", 1 if voice == MSBC else 2))
    s2 = sco_open(a2, voice)
    res.append(snapshot(emu, "link 2 up", 1 if voice == MSBC else 4))
    down, stay = (s1, s2) if first_down == 1 else (s2, s1)
    down.close()
    res.append(snapshot(emu, "link %d hung up, the other stays" % first_down,
                        1 if voice == MSBC else 2))
    stay.close()
    res.append(snapshot(emu, "last link hung up", 0))
    return res


def scenario_single_race(emu, voice):
    """one link whose setup is pending while another connection is added and deleted"""
    res = []
    emu.sync_delay = 1.0
    a1, a3 = "00:11:22:33:44:01", "00:11:22:33:44:03"
    emu.acl_fail.add(bytes(int(x, 16) for x in a3.split(":"))[::-1])
    box = {}

    def go():
        box["s"] = sco_open(a1, voice)

    t = threading.Thread(target=go)
    t.start()
    time.sleep(0.4)                       # link 1's setup is pending in the controller
    try:
        sco_open(a3, voice)               # another connection is added, then fails and is deleted
    except OSError as e:
        log("second connection failed as arranged: %r" % (e,))
    t.join()
    res.append(snapshot(emu, "single link up after the add/delete race", 1 if voice == MSBC else 2))
    box["s"].close()
    res.append(snapshot(emu, "link hung up", 0))
    return res


def dmesg_counts():
    import subprocess
    t = subprocess.run(["dmesg"], capture_output=True, text=True).stdout.splitlines()
    pats = {"corrupted SCO packet": "corrupted SCO packet",
            "unknown handle dropped": "SCO packet for unknown handle",
            "no memory": "no memory for SCO packet",
            "closed handle (debug)": "SCO packet for closed handle",
            "core: unknown connection handle": "SCO packet for unknown connection handle",
            "set USB alt failed": "set USB alt"}
    return {k: sum(1 for l in t if v in l) for k, v in pats.items()}


def judge_counts(c, sc):
    """task 3 (CO-20): judge the kernel's SCO receive messages. --expect clean: the residue of the
    closed links is not reported as an error (rx-cycles: no 'corrupted SCO packet', no 'unknown
    handle dropped', the debug line present; rx-unknown: the five injected packets for a handle that
    never was a link are still reported, as 'unknown handle dropped', and not as 'corrupted').
    --expect noisy: the unpatched kernel's behaviour (the residue / the injected packets are
    'corrupted SCO packet' errors). Without --expect nothing is judged (the original)."""
    mode = None
    if "--expect" in sys.argv:
        mode = sys.argv[sys.argv.index("--expect") + 1]
    if mode is None:
        return []
    cor = c["corrupted SCO packet"]
    unk = c["unknown handle dropped"]
    dbg = c["closed handle (debug)"]
    if sc == "rx-cycles":
        ok = (cor == 0 and unk == 0 and dbg > 0) if mode == "clean" else (cor > 0)
    else:
        # at least the five injected packets: with two links up, data of the first link to close that
        # follows a packet of the other is still an unknown handle (stated in the patch), so 6 occurs
        ok = (unk >= 5 and cor == 0) if mode == "clean" else (cor >= 5)
    log("JUDGE %s expect=%s corrupted=%d unknown_dropped=%d closed_debug=%d -> %s" %
        (sc, mode, cor, unk, dbg, "ok" if ok else "WRONG"))
    return [ok]


def scenario_rx_cycles(emu, n):
    """n times: one mSBC link up with SCO data flowing, hung up with data still in flight"""
    emu.feed_on = True
    emu.residue_n = 3
    per = []
    for i in range(n):
        s = sco_open("00:11:22:33:44:01", MSBC)
        s.settimeout(0.2)
        cnt = 0
        t = time.time()
        while time.time() - t < 0.4:
            try:
                s.recv(512)
                cnt += 1
            except OSError:
                pass
        per.append(cnt)
        s.close()
        time.sleep(0.3)
    c = dmesg_counts()
    log("RX packets read per cycle: %s (total %d); packets sent by the controller %s" %
        (per, sum(per), emu.rx_sent))
    log("COUNTS " + " | ".join("%s: %d" % kv for kv in c.items()))
    return [sum(per) > 0] + judge_counts(c, "rx-cycles")


def scenario_rx_unknown(emu):
    """two mSBC links up with data, a packet for a handle that is no link injected five times"""
    emu.feed_on = True
    emu.residue_n = 3
    s1 = sco_open("00:11:22:33:44:01", MSBC)
    s2 = sco_open("00:11:22:33:44:02", MSBC)
    time.sleep(0.3)
    for i in range(5):
        emu.inject.append(0x0777)
        time.sleep(0.15)
    s1.close()
    time.sleep(0.4)
    s2.close()
    time.sleep(0.4)
    c = dmesg_counts()
    log("COUNTS " + " | ".join("%s: %d" % kv for kv in c.items()))
    return [True] + judge_counts(c, "rx-unknown")


def main():
    sc = sys.argv[1]
    emu = Emu(use_tcp="--tcp" in sys.argv)
    emu.attach()
    if not wait_hci0():
        log("no hci0: btusb did not bind")
        os.system("dmesg | tail -n 40")
        sys.exit(2)
    log("hci0 present; btusb bound")
    if not hci_up():
        os.system("dmesg | tail -n 40")
        sys.exit(2)
    time.sleep(0.5)
    if "--debug" in sys.argv:
        with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
            for fn in ("hci_conn.c", "sco.c", "hci_event.c", "btusb_main.c", "hci_core.c"):
                f.write("file %s +p\n" % fn)
    try:
        with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
            f.write('format "SCO packet for closed handle" +p\n')
    except OSError as e:
        log("dyndbg for the closed-handle line: %r" % (e,))
    try:
        run_scenario(emu, sc)
    except Exception as e:
        log("scenario raised %r" % (e,))
        os.system("dmesg | tail -n 60")
        sys.exit(3)


def run_scenario(emu, sc):
    if sc == "up":
        log("alt after power on: %s" % sysfs_alt())
        res = [True]
    elif sc == "msbc-two-links-first":
        res = scenario_two_links(emu, MSBC, 1)
    elif sc == "msbc-two-links-second":
        res = scenario_two_links(emu, MSBC, 2)
    elif sc == "cvsd-two-links-first":
        res = scenario_two_links(emu, CVSD, 1)
    elif sc == "watch-test":
        import subprocess
        w = subprocess.Popen(["/root/exp/agent-work/laptop-btusb-modules-20261111/scripts/alt-watch.sh",
                              "1234", "5678", "7"], stdout=subprocess.PIPE, text=True)
        res = scenario_two_links(emu, MSBC, 1)
        out = w.communicate()[0]
        for line in out.splitlines():
            log("WATCH " + line)
    elif sc == "rx-cycles":
        res = scenario_rx_cycles(emu, 20)
    elif sc == "rx-unknown":
        res = scenario_rx_unknown(emu)
    elif sc == "msbc-single-race":
        res = scenario_single_race(emu, MSBC)
    elif sc == "cvsd-single-race":
        res = scenario_single_race(emu, CVSD)
    else:
        sys.exit("unknown scenario")
    finish(emu, sc, res)


def finish(emu, sc, res):
    log("SET_INTERFACE sequence: %s" % [a for _, a in emu.sets])
    log("unhandled-opcode list: %s" % sorted("0x%04x" % o for o in emu.unknown))
    log("RESULT %s %s" % (sc, "PASS" if all(res) else "FAIL"))
    os.system("dmesg | grep -i -E 'Bluetooth|btusb|corrupted|unknown' | tail -n 30")
    # task 3: the verdict as the exit status, read by run-guest.sh (the original exited 0 on FAIL)
    log("BT17-EXIT %d" % (0 if all(res) else 1))
    sys.exit(0 if all(res) else 1)


if __name__ == "__main__":
    main()
