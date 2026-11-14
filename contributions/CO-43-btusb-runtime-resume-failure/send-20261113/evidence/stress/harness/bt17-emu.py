#!/usr/bin/env python3
"""bt17-emu.py - an emulated QCA9377 Bluetooth controller (13d3:3503) for the BT-17 incident,
attached through the kernel's usbip vhci_hcd so that the real btusb binds to it in a QEMU guest.

Derived from results/laptop-only-work-2026-11-11/.../usbip-bt-emu.py (CO-21). What is new:
  * the laptop's identity: 13d3:3503, bcdUSB 1.10, full speed, remote wakeup in
    bmAttributes, so btusb takes the BTUSB_QCA_ROME path (hdev->reset = btusb_qca_reset);
  * the two QCA vendor requests of btusb_setup_qca(): QCA_GET_TARGET_VERSION answers
    ROM 0x302 / patch 0x3e8, QCA_CHECK_STATUS answers 0xc0 (patch and NVM already loaded),
    so no firmware download is attempted;
  * suspend/resume accounting: a SET_FEATURE(DEVICE_REMOTE_WAKEUP) marks a device suspend,
    the next device GET_STATUS marks the resume check (finish_port_resume());
  * a fault, --fail-at N: at the N-th resume the device stops answering. Its GET_STATUS and
    every later request are held (a device that NAKs). When the host gives up on a held URB
    (unlink), the device turns 'dead': every control transfer then fails with -71 (EPROTO),
    as the laptop's controller did after its first reset. --recover makes it healthy again
    instead (a device that a reset brings back);
  * a driver for the incident: MGMT Set Powered, wait for the runtime autosuspend, then
    MGMT Set Device Class (the kernel writes the Class of Device, as at the laptop's login),
    MGMT events logged with their status, the kernel log and the USB core debug lines
    collected at the end.
It emulates the device only: nothing here is measured on the laptop.

Usage: bt17-emu.py <scenario> [--fail-at N] [--recover] [--cycles N] [--hold-hci]
       [--drop-hci-event OPCODE] [--autosuspend-ms N]   (dropcmd)
Exit status: 0 if the scenario's success condition held, 1 if not or if it raised.
Scenarios: bt17 (fault at a resume, then the class write), cycles (healthy suspend/resume
cycles with a class write each), up (bring-up only).
"""
import ctypes
import errno
import os
import random
import socket
import struct
import sys
import threading
import time
from collections import deque

T0 = time.time()
LOG_LOCK = threading.Lock()
# stress (co43-ea-send-20261113): the packets the emulated device received, from every emulator
# instance of the run (a USB disconnect and re-attach makes a new one): (kind, key) -> (mono, emu, resumes)
RX = {}
EMUS = []


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOG_LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def arg(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        return sys.argv[i + 1]
    return default


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
    # bmAttributes 0xe0: self-powered and remote wakeup, as the laptop's controller
    return struct.pack("<BBHBBBBB", 9, 2, total, 2, 1, 0, 0xE0, 50) + body


# bcdUSB 1.10, class e0/01/01, ep0 64, 13d3:3503, bcdDevice 0.01
DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0110, 0xE0, 1, 1, 64,
                       0x13D3, 0x3503, 0x0001, 0, 0, 0, 1)

# struct qca_version: rom_version, patch_version, ram_version, chip_id, platform_id, flag, rsvd
QCA_VERSION = struct.pack("<IIIBBH4s", 0x00000302, 0x000003E8, 0x00000302, 0, 0, 0, b"\0" * 4)

BDADDR = bytes([0x00, 0x00, 0x00, 0x77, 0x17, 0x00])
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])


class Emu:
    def __init__(self, fail_at=0, recover=False, hold_hci=False):
        self.lock = threading.Lock()
        self.intr_pending = deque()
        self.intr_out = bytearray()
        self.unknown = set()
        self.sock = None
        self.running = True
        self.fail_at = fail_at
        self.recover = recover
        self.hold_hci = hold_hci
        self.drop_op = None              # --drop-hci-event: opcode armed once, by the scenario
        self.wedge_until_reset = "--wedge-until-reset" in sys.argv
        self.hci_wedged = False          # after the drop: transfers complete, no events
        self.reset_seen = []             # mono times of the reset signal
        self.watch = False               # log control requests and note reset signals (sysfs-reset)
        self.desc_seen = []              # mono times of device-descriptor reads while watching
        self.state = "healthy"          # healthy | wedged | dead
        self.suspended = False
        self.suspends = 0
        self.resumes = 0
        self.held = {}                   # seq -> description
        self.events = []                 # (mono, what)
        self.hci_cmds = []               # (mono, opcode)
        self.quiet = "stress" in sys.argv  # stress: no per-command log lines
        self.intr_sent = {}              # seq -> event bytes completed on that interrupt URB
        self.fix_unlinked_intr = "--keep-unlink-loss" not in sys.argv
        self.ident = len(EMUS)           # stress: one emulator per attach
        EMUS.append(self)

    def note(self, what):
        self.events.append((mono(), what))
        log("EMU " + what)

    # -- usbip
    def attach(self):
        base = "/sys/devices/platform/vhci_hcd.0"
        kfd, self.sock = socket.socketpair()
        for attempt in range(40):          # after a detach the port is free again only shortly later
            try:
                with open(base + "/attach", "w") as f:
                    f.write("0 %d %d 2" % (kfd.fileno(), (1 << 16) | 2))   # full speed
                break
            except OSError as e:
                if attempt == 39:
                    raise
                log("attach refused (%r), retrying" % (e,))
                time.sleep(0.25)
        log("attached to vhci_hcd port 0 (emulator %d)" % self.ident)
        self.kfd = kfd
        threading.Thread(target=self.loop, daemon=True).start()

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

    def ret_submit(self, seq, status=0, actual=0, data=b""):
        h = struct.pack(">IIIII", 3, seq, 0, 0, 0)
        h += struct.pack(">iiiii", status, actual, 0, 0, 0)
        h += b"\0" * 8
        self.send(h + data)

    def ret_unlink(self, seq, status):
        self.send(struct.pack(">IIIII", 4, seq, 0, 0, 0) + struct.pack(">i", status) + b"\0" * 24)

    def loop(self):
        try:
            while self.running:
                hdr = self.recvn(48)
                cmd, seq, devid, direction, epn = struct.unpack(">IIIII", hdr[:20])
                u = hdr[20:]
                if cmd == 1:
                    flags, buflen, start, nump, ival = struct.unpack(">IiiiI", u[:20])
                    setup = u[20:28]
                    data = b""
                    if direction == 0 and buflen > 0:
                        data = self.recvn(buflen)
                    if nump > 0:
                        self.recvn(16 * nump)
                    self.submit(seq, direction, epn, buflen, setup, data)
                elif cmd == 2:
                    self.unlink(seq, struct.unpack(">I", u[:4])[0])
                else:
                    log("unknown usbip command %d" % cmd)
        except (EOFError, OSError) as e:
            log("usbip socket ended: %r" % (e,))

    def unlink(self, seq, victim):
        hit = False
        with self.lock:
            for item in list(self.intr_pending):
                if item[0] == victim:
                    self.intr_pending.remove(item)
                    hit = True
            # co43-ea-send-20261113: an interrupt IN URB this emulator already completed with event
            # bytes, unlinked by the host (a suspend killing it) before vhci processed that
            # completion: vhci then gives the URB back with the unlink status and btusb drops the
            # bytes. A real device would still hold the event (it NAKs until polled), so put the
            # bytes back in front, for the next interrupt URB. Without this the event is lost and
            # the command it answers times out (an emulator artifact, seen in the first stress runs).
            requeued = None
            if not hit and victim in self.intr_sent and self.fix_unlinked_intr:
                requeued = self.intr_sent.pop(victim)
                self.intr_out[:0] = requeued
        if requeued is not None:
            self.note("unlink of completed interrupt URB %d: %d event bytes put back" % (victim, len(requeued)))
        if victim in self.held:
            what = self.held.pop(victim)
            hit = True
            self.note("host gave up on held %s (unlink)" % what)
            if self.state == "wedged":
                if self.recover:
                    self.state = "healthy"
                    self.note("device recovers (--recover)")
                else:
                    self.state = "dead"
                    self.note("device dead: control transfers now fail -71")
        self.ret_unlink(seq, -104 if hit else 0)

    def submit(self, seq, direction, epn, buflen, setup, data):
        if epn == 0:
            self.control(seq, direction, buflen, setup, data)
        elif epn == 1 and direction == 1:
            with self.lock:
                self.intr_pending.append((seq, buflen))
            self.pump()
        elif epn == 2 and direction == 1:
            pass                                    # bulk IN: kept pending
        elif epn == 2 and direction == 0:
            if self.state == "healthy":
                if len(data) >= 10 and data[4:6] == b"EA":        # stress ACL packet
                    RX[("acl", struct.unpack("<I", data[6:10])[0])] = (mono(), self.ident, self.resumes)
                self.ret_submit(seq, 0, buflen)
            elif self.state == "dead":
                self.ret_submit(seq, -71, 0)
            else:
                self.held[seq] = "bulk OUT"
        elif epn == 3:
            self.ret_submit(seq, -71 if self.state != "healthy" else 0, 0)
        else:
            self.ret_submit(seq, -32, 0)

    def control(self, seq, direction, buflen, setup, data):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        desc = "control %02x %02x %04x %04x %04x" % (bm, br, wv, wi, wl)
        if self.hci_wedged or self.watch:
            # reset signal: SET_CONFIGURATION (usb_reset_and_verify_device() sends it to restore
            # the configuration after every reset; vhci_hcd handles the port reset and
            # SET_ADDRESS itself and never forwards them)
            self.note("ctl while watched: " + desc)
            if bm == 0x80 and br == 6 and (wv >> 8) == 1:
                self.desc_seen.append(mono())
            if bm == 0x00 and br == 9:
                self.hci_wedged = False
                self.intr_out.clear()
                self.reset_seen.append(mono())
                self.note("reset seen (SET_CONFIGURATION value %d)" % wv)
        if self.state == "dead":
            self.note("%s -> -71 (dead)" % desc)
            self.ret_submit(seq, -71, 0)
            return
        if self.state == "wedged":
            self.held[seq] = desc
            self.note("%s held (wedged)" % desc)
            return
        if bm == 0x80 and br == 0 and getattr(self, "arm_status", False):   # armed (system sleep)
            self.arm_status = False
            self.resumes += 1
            self.state = "wedged"
            self.held[seq] = "GET_STATUS (armed)"
            self.note("armed GET_STATUS held, device wedged")
            return
        if bm == 0x80 and br == 0 and self.suspended:          # resume check
            self.resumes += 1
            self.suspended = False
            if self.fail_at and self.resumes == self.fail_at:
                self.state = "wedged"
                self.held[seq] = "GET_STATUS of resume #%d" % self.resumes
                self.note("resume #%d: GET_STATUS held, device wedged" % self.resumes)
                return
            self.note("resume #%d: GET_STATUS answered" % self.resumes)
        if bm == 0x80 and br == 6:
            t = wv >> 8
            d = DEV_DESC if t == 1 else config_desc() if t == 2 else None
            if d is None:
                self.ret_submit(seq, -32, 0)
                return
            d = d[:wl]
            self.ret_submit(seq, 0, len(d), d)
        elif bm == 0x00 and br == 9:
            self.ret_submit(seq, 0, 0)
        elif bm == 0x01 and br == 11:
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 3 and wv == 1:               # SET_FEATURE(REMOTE_WAKEUP)
            self.suspends += 1
            self.suspended = True
            self.note("suspend #%d (SET_FEATURE remote wakeup)" % self.suspends)
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 1 and wv == 1:               # CLEAR_FEATURE(REMOTE_WAKEUP)
            self.ret_submit(seq, 0, 0)
        elif bm & 0x60 == 0 and br in (1, 3):
            self.ret_submit(seq, 0, 0)
        elif bm == 0x80 and br == 0:
            self.ret_submit(seq, 0, 2, b"\x03\x00")            # self-powered, remote wakeup on
        elif bm == 0x80 and br == 8:
            self.ret_submit(seq, 0, 1, b"\x01")
        elif bm == 0x81 and br == 10:
            self.ret_submit(seq, 0, 1, b"\x00")
        elif bm == 0xC0 and br == 0x09:                        # QCA_GET_TARGET_VERSION
            self.ret_submit(seq, 0, min(wl, len(QCA_VERSION)), QCA_VERSION[:wl])
        elif bm == 0xC0 and br == 0x05:                        # QCA_CHECK_STATUS
            self.ret_submit(seq, 0, 1, b"\xc0")
        elif bm == 0x20 and br == 0:                           # HCI command
            op, plen = struct.unpack("<HB", data[:3])
            self.hci_cmds.append((mono(), op))
            if op == 0x0C18 and plen == 2:                     # stress: Write Page Timeout, key in it
                RX[("cmd", struct.unpack("<H", data[3:5])[0])] = (mono(), self.ident, self.resumes)
            elif op == 0xFC55 and plen == 4:                   # stress: vendor command, no event
                RX[("vnd", struct.unpack("<I", data[3:7])[0])] = (mono(), self.ident, self.resumes)
                self.ret_submit(seq, 0, len(data))
                return
            if self.hold_hci and self.suspends and self.resumes >= self.fail_at > 0:
                self.held[seq] = "HCI 0x%04x" % op
                return
            self.ret_submit(seq, 0, len(data))
            if self.drop_op == op:                             # transfer done, event never sent
                self.drop_op = None
                self.note("HCI 0x%04x: control transfer completed, event dropped" % op)
                if self.wedge_until_reset:
                    self.hci_wedged = True
                    self.note("wedged: later HCI commands complete their transfer, no events, until a reset")
                return
            if self.hci_wedged:
                self.note("HCI 0x%04x: control transfer completed, no event (wedged)" % op)
                return
            self.hci_cmd(op, data[3:3 + plen])
        else:
            log("%s not handled" % desc)
            self.ret_submit(seq, -32, 0)

    # -- events
    def event(self, code, params):
        if self.hci_wedged:
            return
        with self.lock:
            self.intr_out += bytes([code, len(params)]) + params
        self.pump()

    def pump(self):
        while True:
            with self.lock:
                if self.state != "healthy" or not self.intr_pending or not self.intr_out:
                    return
                seq, buflen = self.intr_pending.popleft()
                chunk = bytes(self.intr_out[:min(buflen, 16)])
                del self.intr_out[:len(chunk)]
                self.intr_sent[seq] = chunk
                if len(self.intr_sent) > 256:
                    self.intr_sent.pop(next(iter(self.intr_sent)))
            self.ret_submit(seq, 0, len(chunk), chunk)

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci_cmd(self, op, p):
        if not (self.quiet and op in (0x0C18, 0x0C24)):
            log("HCI cmd 0x%04x %s" % (op, p.hex()))
        if op == 0x1001:
            self.cc(op, struct.pack("<BBHBHH", 0, 6, 0x0302, 6, 0x0045, 0x0302))  # QCA, 4.0
        elif op == 0x1002:
            cmds = bytearray(64)
            cmds[9] = 0x04
            self.cc(op, b"\0" + bytes(cmds))
        elif op == 0x1003:
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:
            self.cc(op, b"\0" + b"bt17-emu".ljust(248, b"\0"))
        elif op == 0x0C25:
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        else:
            if op not in self.unknown:
                self.unknown.add(op)
                log("HCI command 0x%04x: generic Command Complete" % op)
            self.cc(op)


# ---------------------------------------------------------------- MGMT (control channel)
AF_BLUETOOTH, BTPROTO_HCI = 31, 1
HCI_CHANNEL_CONTROL, HCI_DEV_NONE = 3, 0xFFFF
MGMT_EV = {1: "Command Complete", 2: "Command Status", 4: "Index Added", 5: "Index Removed",
           6: "New Settings", 7: "Class Of Device Changed"}


class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "mgmt socket")
        addr = struct.pack("<HHH", AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.replies = []        # (mono, event, opcode, status, index)
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        log("MGMT send opcode 0x%04x index %d params %s" % (op, index, params.hex()))
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while True:
            try:
                b = os.read(self.fd, 1024)
            except OSError as e:
                log("mgmt read ended: %r" % (e,))
                return
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            name = MGMT_EV.get(ev, "event 0x%04x" % ev)
            if ev in (1, 2):
                op, st = struct.unpack("<HB", p[:3])
                self.replies.append((mono(), ev, op, st, index))
                log("MGMT %s opcode 0x%04x status 0x%02x index %d" % (name, op, st, index))
            else:
                self.replies.append((mono(), ev, None, None, index))
                log("MGMT %s index %d %s" % (name, index, p.hex()))

    def wait_reply(self, op, timeout):
        t = time.time()
        while time.time() - t < timeout:
            for r in self.replies:
                if r[2] == op and r[1] in (1, 2):
                    self.replies.remove(r)
                    return r
            time.sleep(0.02)
        return None


# ---------------------------------------------------------------- the guest side
def usb_dev():
    base = "/sys/bus/usb/devices"
    for d in sorted(os.listdir(base)):
        p = os.path.join(base, d, "idVendor")
        try:
            if open(p).read().strip() == "13d3":
                return os.path.join(base, d)
        except OSError:
            pass
    return None


def rd(path):
    try:
        return open(path).read().strip()
    except OSError as e:
        return "<%s>" % e.strerror


def power_state(dev):
    return {k: rd(os.path.join(dev, "power", k)) for k in
            ("control", "runtime_status", "autosuspend_delay_ms", "persist", "wakeup")}


def wait_for(cond, timeout, step=0.05):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(step)
    return False


def dyndbg(lines):
    try:
        with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
            for l in lines:
                f.write(l + "\n")
        log("dyndbg: " + " | ".join(lines))
    except OSError as e:
        log("dyndbg failed: %r" % (e,))


def kmsg_mark(text):
    try:
        with open("/dev/kmsg", "w") as f:
            f.write("bt17-emu: %s\n" % text)
    except OSError:
        pass


def bring_up(emu, m):
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        log("no hci0: btusb did not bind")
        os.system("dmesg | tail -n 60")
        sys.exit(2)
    log("hci0 present")
    # Set Powered only after the MGMT index exists (status 0x11 Invalid Index before it), and
    # before the kernel's 2 s auto-off closes the device again
    wait_for(lambda: any(r[1] == 4 for r in m.replies), 10)
    for attempt in range(20):
        m.send(0x0005, 0, b"\x01")                # Set Powered
        r = m.wait_reply(0x0005, 15)
        log("Set Powered reply: %s" % (r,))
        if r and r[3] == 0:
            break
        time.sleep(0.2)
    dev = usb_dev()
    log("usb device %s power %s" % (dev, power_state(dev)))
    return dev


def wait_suspended(dev, timeout=15):
    ok = wait_for(lambda: rd(os.path.join(dev, "power", "runtime_status")) == "suspended", timeout)
    log("runtime_status %s after waiting (ok=%s)" % (rd(os.path.join(dev, "power", "runtime_status")), ok))
    return ok


def class_write(m, minor):
    """MGMT Set Device Class: major 1 (Computer), minor varies, so the class really changes"""
    t = mono()
    kmsg_mark("Set Device Class minor %d sent at mono %.6f" % (minor, t))
    m.send(0x000E, 0, bytes([1, minor]))
    return t


def scenario_bt17(emu, m, dev):
    res = {}
    if not wait_suspended(dev):
        log("RESULT bt17 SKIP device never autosuspended")
        return False
    time.sleep(1.0)
    t_send = class_write(m, 0x0C)
    r = m.wait_reply(0x000E, 25)
    res["reply"] = r
    log("Set Device Class reply after %.3f s: %s" % ((r[0] - t_send) if r else -1, r))
    # what bluetoothd would do next on the laptop: more class writes (Remove UUID)
    for minor in (0x04, 0x08):
        t2 = class_write(m, minor)
        r2 = m.wait_reply(0x000E, 6)
        log("follow-up class write minor %d reply after %.3f s: %s" % (minor, (r2[0] - t2) if r2 else -1, r2))
    gone = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 25)
    log("hci0 removed: %s; usb device now %s" % (gone, usb_dev()))
    back = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15) if emu.recover else False
    powered, cw = False, None
    if emu.recover:
        log("hci0 back after recovery: %s" % back)
        if back:
            powered = power_on(m)
            if powered:
                t3 = class_write(m, 0x10)
                r3 = m.wait_reply(0x000E, 10)
                log("class write after recovery: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
                cw = ("0x%02x" % r3[3]) if r3 else "none"
    log("EMU suspends %d resumes %d state %s held %s" % (emu.suspends, emu.resumes, emu.state, list(emu.held.values())))
    st = ("0x%02x" % r[3]) if r else "none"
    log("RESULT bt17 fail_at=%d recover=%s class-write-status=%s hci0_removed=%s back=%s powered=%s class_write_after=%s" %
        (emu.fail_at, emu.recover, st, gone, back, powered, cw or "none"))
    # success: the dead device is removed; the recovering one is back, powered, and writes the class
    return (back and powered and cw == "0x00") if emu.recover else gone


def power_on(m, tries=20):
    """MGMT Set Powered on, retried while the MGMT index is not there yet"""
    for attempt in range(tries):
        m.send(0x0005, 0, b"\x01")
        r = m.wait_reply(0x0005, 15)
        log("Set Powered reply: %s" % (r,))
        if r and r[3] == 0:
            return True
        time.sleep(0.5)
    return False


def kernel_lines(*patterns):
    """(kernel time, line) of the dmesg lines that contain one of the patterns"""
    import re
    out = []
    for l in os.popen("dmesg --color=never").read().splitlines():
        if any(p in l for p in patterns):
            m_ = re.search(r"\[\s*([0-9.]+)\]", l)
            out.append((float(m_.group(1)) if m_ else -1.0, l))
    return out


def wedge_tail(emu, m, op, delay_ms, t_send, st, drop, sus):
    """after the settle time: MGMT Set Powered off, then on, then a class write. Usable = that
    class write returns 0x00. Records the emulator's reset sightings and the kernel's lines."""
    hci_up = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15)
    t_off = mono()
    m.send(0x0005, 0, b"\x00")
    r_off = m.wait_reply(0x0005, 15)
    log("Set Powered off: %.3f s %s" % ((r_off[0] - t_off) if r_off else -1, r_off))
    powered = power_on(m, tries=3)
    cw = None
    if powered:
        t3 = class_write(m, 0x10)
        r3 = m.wait_reply(0x000E, 10)
        log("final class write: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
        cw = ("0x%02x" % r3[3]) if r3 else "none"
    kl = kernel_lines("tx timeout", "Resetting usb device", "not resetting", "Failed usb_autopm",
                      "reset full-speed", "USB disconnect")
    for ts, l in kl:
        log("KERNEL %s" % l)
    n_skip = len([1 for ts, l in kl if "not resetting" in l])
    n_reset = len([1 for ts, l in kl if "Resetting usb device" in l])
    tmo = [ts for ts, l in kl if "tx timeout" in l]
    seen = ",".join("%.6f" % x for x in emu.reset_seen) or "none"
    usable = cw == "0x00"
    log("RESULT dropcmd-wedge op=0x%04x delay_ms=%d send=%.6f transfer_done=%s autosuspended=%s "
        "class-write-status=%s reset_seen=%s tx_timeouts=%d (%s) not_resetting_lines=%d "
        "resetting_usb_device_lines=%d hci0=%s set_powered_off=%s powered_on=%s final_class_write=%s usable=%s desc_read=%s kernel_reset_line=%s" %
        (op, delay_ms, t_send, ",".join("%.6f" % x for x in drop) or "none",
         ",".join("%.6f" % x for x in sus) or "none", st, seen, len(tmo),
         ",".join("%.3f" % x for x in tmo), n_skip, n_reset, hci_up,
         ("0x%02x" % r_off[3]) if r_off else "none", powered, cw or "none", usable,
         ",".join("%.6f" % x for x in emu.desc_seen) or "none",
         ",".join("%.3f" % ts for ts, l in kl if "reset full-speed" in l) or "none"))
    return usable


def scenario_dropcmd(emu, m, dev, op, delay_ms, settle=15):
    """a command whose USB transfer completes but whose HCI event never comes. The runtime
    autosuspend delay is lowered (the default 2000 ms equals the 2 s HCI command timeout), the
    device is made awake by a successful class write, the drop is armed, and the next class
    write is sent at once. Does the device autosuspend before the timeout, what does
    btusb_reset() do, and does Bluetooth work afterwards?"""
    with open(os.path.join(dev, "power", "autosuspend_delay_ms"), "w") as f:
        f.write(str(delay_ms))
    log("autosuspend_delay_ms = %s" % rd(os.path.join(dev, "power", "autosuspend_delay_ms")))
    t = class_write(m, 0x04)
    r = m.wait_reply(0x000E, 10)
    log("warm-up class write: %.3f s %s; runtime_status %s" %
        ((r[0] - t) if r else -1, r, rd(os.path.join(dev, "power", "runtime_status"))))
    if not r or r[3] != 0:
        log("RESULT dropcmd SKIP warm-up class write failed")
        return False
    susp0 = emu.suspends
    emu.drop_op = op
    t_send = class_write(m, 0x08)
    r = m.wait_reply(0x000E, 25)
    t_reply = r[0] if r else None
    st = ("0x%02x" % r[3]) if r else "none"
    log("Set Device Class with dropped event: reply after %.3f s: %s" % ((t_reply - t_send) if r else -1, r))
    # the device's suspends after the send, from the emulator's own notes
    sus = [e[0] for e in emu.events if e[0] >= t_send and e[1].startswith("suspend #")]
    drop = [e[0] for e in emu.events if e[0] >= t_send and "event dropped" in e[1]]
    log("EMU send %.6f transfer_done %s autosuspend %s (suspends %d -> %d)" %
        (t_send, ["%.6f" % x for x in drop], ["%.6f" % x for x in sus], susp0, emu.suspends))
    # long enough for a reset and the rebinding that follows it
    time.sleep(settle)
    if emu.wedge_until_reset:
        return wedge_tail(emu, m, op, delay_ms, t_send, st, drop, sus)
    kl = kernel_lines("tx timeout", "Resetting usb device", "not resetting", "not resumed",
                      "Failed usb_autopm", "reset full-speed", "USB disconnect")
    for ts, l in kl:
        log("KERNEL %s" % l)
    reset = [l for ts, l in kl if "Resetting usb device" in l]
    skipped = [l for ts, l in kl if "not resetting" in l]
    tmo = [ts for ts, l in kl if "tx timeout" in l]
    hci_up = os.path.exists("/sys/class/bluetooth/hci0")
    powered, cw = False, None
    if hci_up:
        powered = power_on(m)
        if powered:
            t3 = class_write(m, 0x10)
            r3 = m.wait_reply(0x000E, 10)
            log("final class write: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
            cw = ("0x%02x" % r3[3]) if r3 else "none"
    usable = cw == "0x00"
    log("RESULT dropcmd op=0x%04x delay_ms=%d send=%.6f transfer_done=%s autosuspended=%s tx_timeout=%s "
        "class-write-status=%s btusb_reset=%s hci0=%s powered=%s final_class_write=%s usable=%s" %
        (op, delay_ms, t_send, ",".join("%.6f" % x for x in drop) or "none",
         ",".join("%.6f" % x for x in sus) or "none", ",".join("%.3f" % x for x in tmo) or "none", st,
         "resetting" if reset else "skipped(not resumed)" if skipped else "none", hci_up, powered, cw or "none", usable))
    return usable


def scenario_close_recover(emu, m, dev):
    """the resume that fails is started by closing hci0 (MGMT Set Powered off: btusb_close()
    takes a runtime PM reference), not by a command; the device comes back after the
    reset-resume (--recover). Then power on again and write the class: does Bluetooth work?"""
    if not wait_suspended(dev):
        log("RESULT close-recover SKIP device never autosuspended")
        return False
    time.sleep(1.0)
    t = mono()
    kmsg_mark("Set Powered off sent at mono %.6f" % t)
    m.send(0x0005, 0, b"\x00")
    r = m.wait_reply(0x0005, 25)
    log("Set Powered off reply after %.3f s: %s" % ((r[0] - t) if r else -1, r))
    wait_for(lambda: emu.state == "healthy" and emu.resumes >= 1, 15)
    time.sleep(1.0)
    log("power after recovery: %s" % power_state(usb_dev() or dev))
    t = mono()
    kmsg_mark("Set Powered on sent at mono %.6f" % t)
    m.send(0x0005, 0, b"\x01")
    r = m.wait_reply(0x0005, 30)
    log("Set Powered on reply after %.3f s: %s" % ((r[0] - t) if r else -1, r))
    ok = False
    if r and r[3] == 0:
        t = class_write(m, 0x10)
        r2 = m.wait_reply(0x000E, 10)
        log("class write after recovery: %.3f s %s" % ((r2[0] - t) if r2 else -1, r2))
        ok = bool(r2 and r2[3] == 0)
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT close-recover bluetooth_works_after=%s" % ok)
    return ok


def scenario_sysfreeze(emu, m, dev, fault):
    """a system sleep transition (pm_test=devices, freeze: devices suspended, 5 s, resumed),
    with the device kept runtime-active before it; with fault, the GET_STATUS of the system
    resume is held (and --recover makes the device answer after the reset-resume). Then:
    does Bluetooth work?"""
    with open(os.path.join(dev, "power", "control"), "w") as f:
        f.write("on")
    time.sleep(0.5)
    log("power before sleep: %s" % power_state(dev))
    emu.arm_status = fault
    with open("/sys/power/pm_test", "w") as f:
        f.write("devices")
    t = mono()
    kmsg_mark("freeze (pm_test devices) at mono %.6f" % t)
    try:
        with open("/sys/power/state", "w") as f:
            f.write("freeze")
    except OSError as e:
        log("freeze write: %r" % (e,))
    log("back from freeze after %.3f s" % (mono() - t))
    ok_hci = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20)
    time.sleep(2.0)
    ok = False
    if ok_hci:
        for attempt in range(10):
            m.send(0x0005, 0, b"\x01")
            r = m.wait_reply(0x0005, 15)
            log("Set Powered after resume: %s" % (r,))
            if r and r[3] == 0:
                break
            time.sleep(0.5)
        t = class_write(m, 0x14)
        r2 = m.wait_reply(0x000E, 10)
        log("class write after resume: %.3f s %s" % ((r2[0] - t) if r2 else -1, r2))
        ok = bool(r2 and r2[3] == 0)
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT sysfreeze fault=%s recover=%s hci0=%s bluetooth_works_after=%s" % (fault, emu.recover, ok_hci, ok))
    return ok


def scenario_bt23(emu, m, dev, delay_ms):
    """BT-23: a resume that completes between btusb's suspend decision and its anchoring of
    the URB. A debug-only module parameter (bt23_delay_ms) widens that window; the resume is
    forced meanwhile by writing power/control=on. Is the command answered?"""
    if not wait_suspended(dev):
        log("RESULT bt23 SKIP device never autosuspended")
        return False
    time.sleep(0.5)
    p = "/sys/module/btusb/parameters/bt23_delay_ms"
    with open(p, "w") as f:
        f.write(str(delay_ms))
    log("bt23_delay_ms = %s" % rd(p))
    box = {}

    def go():
        box["t"] = class_write(m, 0x18)
    th = threading.Thread(target=go)
    th.start()
    time.sleep(0.1)
    t = mono()
    with open(os.path.join(dev, "power", "control"), "w") as f:
        f.write("on")
    log("power/control=on written (resume forced) in %.3f s; runtime_status %s" %
        (mono() - t, rd(os.path.join(dev, "power", "runtime_status"))))
    th.join()
    r = m.wait_reply(0x000E, 8)
    with open(p, "w") as f:
        f.write("0")
    lat = (r[0] - box["t"]) if r else -1
    log("class write reply after %.3f s: %s" % (lat, r))
    st = ("0x%02x" % r[3]) if r else "none"
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT bt23 delay=%d status=%s latency=%.3f" % (delay_ms, st, lat))
    return st == "0x00"


def scenario_sysfs_reset(emu, m, dev):
    """the manual reset: hci0 up and the device suspended, then 1 is written to
    /sys/class/bluetooth/hci0/reset (hdev->reset(), the second caller of the driver's reset hook).
    Expect a USB reset (seen by the emulator and by the kernel) and a usable Bluetooth afterwards."""
    if not wait_suspended(dev):
        log("RESULT sysfs-reset SKIP device never autosuspended")
        return False
    time.sleep(0.5)
    emu.watch = True
    if "--while-deferred" in sys.argv:
        # a command parked on the deferred anchor (its resume hangs, --fail-at 1), then the manual reset
        class_write(m, 0x0C)
        time.sleep(1.0)
    t = mono()
    kmsg_mark("sysfs reset written at mono %.6f" % t)
    with open("/sys/class/bluetooth/hci0/reset", "w") as f:
        f.write("1")
    log("sysfs reset written: returned after %.3f s" % (mono() - t))
    seen = wait_for(lambda: len(emu.reset_seen) > 0, 15)
    time.sleep(3)
    back = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15)
    powered, cw = False, None
    if back:
        powered = power_on(m, tries=30)
        if powered:
            t3 = class_write(m, 0x10)
            r3 = m.wait_reply(0x000E, 10)
            log("final class write: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
            cw = ("0x%02x" % r3[3]) if r3 else "none"
    kl = kernel_lines("tx timeout", "Resetting usb device", "not resetting", "Failed usb_autopm",
                      "reset full-speed", "USB disconnect")
    for ts, l in kl:
        log("KERNEL %s" % l)
    usable = cw == "0x00"
    log("RESULT sysfs-reset write=%.6f reset_seen=%s desc_read=%s kernel_reset_line=%s "
        "not_resetting_lines=%d resetting_usb_device_lines=%d hci0=%s powered_on=%s final_class_write=%s usable=%s" %
        (t, ",".join("%.6f" % x for x in emu.reset_seen) or "none",
         ",".join("%.6f" % x for x in emu.desc_seen) or "none",
         ",".join("%.3f" % ts for ts, l in kl if "reset full-speed" in l) or "none",
         len([1 for ts, l in kl if "not resetting" in l]),
         len([1 for ts, l in kl if "Resetting usb device" in l]), back, powered, cw or "none", usable))
    return seen and usable


KML = "/sys/kernel/debug/kmemleak"


def kml_scan(label):
    """kmemleak: scan twice, 10 s apart, then read the report. Returns the report text."""
    for i in range(2):
        with open(KML, "w") as f:
            f.write("scan")
        if i == 0:
            time.sleep(10)
    rep = open(KML).read()
    n = rep.count("unreferenced object")
    log("KMEMLEAK %s: %d unreferenced objects" % (label, n))
    for l in rep.splitlines():
        log("KMEMLEAK %s | %s" % (label, l))
    return rep


def scenario_kml(emu, m, dev, mode):
    """kmemleak after a close with URBs left on btusb's deferred anchor.
    healthy: the device is suspended, one class write is answered (the deferred URB is played),
             then hci0 is powered off.
    dead:    --fail-at 1; the BT-17 sequence (suspended device, class writes, the resume hangs)
             until the USB core disconnects the device and hci_unregister_dev() closes hci0.
    dead-off: as dead, but hci0 is powered off (MGMT) one second after the first class write.
    The kernel log shows how many commands it timed out; the emulator logs the HCI command
    transfers it received: a command that timed out without a transfer was still deferred."""
    with open(KML, "w") as f:
        f.write("scan")
    time.sleep(10)
    with open(KML, "w") as f:
        f.write("scan")
    base_n = open(KML).read().count("unreferenced object")
    with open(KML, "w") as f:
        f.write("clear")
    log("KMEMLEAK baseline before the scenario: %d objects (cleared)" % base_n)
    n_cmds0 = len(emu.hci_cmds)
    if mode == "healthy":
        wait_suspended(dev)
        t = class_write(m, 0x0C)
        r = m.wait_reply(0x000E, 10)
        log("class write after suspend: %s" % (r,))
        m.send(0x0005, 0, b"\x00")
        r = m.wait_reply(0x0005, 15)
        log("Set Powered off: %s" % (r,))
        ok = bool(r and r[3] == 0)
    elif mode == "dead":
        ok = scenario_bt17(emu, m, dev) is True
    else:
        if not wait_suspended(dev):
            return False
        time.sleep(1.0)
        class_write(m, 0x0C)
        time.sleep(1.0)
        m.send(0x0005, 0, b"\x00")
        r = m.wait_reply(0x0005, 25)
        log("Set Powered off reply: %s" % (r,))
        ok = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 25)
    time.sleep(3)
    sent = len(emu.hci_cmds) - n_cmds0
    log("EMU HCI command transfers received during the scenario: %d: %s" %
        (sent, ["0x%04x" % o for t_, o in emu.hci_cmds[n_cmds0:]]))
    tmo = kernel_lines("tx timeout")
    log("kernel tx timeout lines: %d" % len(tmo))
    rep = kml_scan("after " + mode)
    objs = rep.split("unreferenced object")[1:]
    hits = [o for o in objs if any(k in o for k in ("alloc_ctrl_urb", "__alloc_skb", "bt_skb_alloc",
                                                    "hci_prepare_cmd", "btusb", "hci_send_cmd"))]
    log("RESULT kml mode=%s scenario_ok=%s objects=%d bluetooth_related=%d hci_transfers_received=%d tx_timeouts=%d" %
        (mode, ok, len(objs), len(hits), sent, len(tmo)))
    return ok


def scenario_cycles(emu, m, dev, n):
    lat = []
    bad = 0
    for i in range(n):
        if not wait_suspended(dev):
            log("cycle %d: not suspended" % i)
            bad += 1
            continue
        t = class_write(m, (i % 3 + 1) * 4)
        r = m.wait_reply(0x000E, 10)
        if r is None or r[3] != 0:
            bad += 1
            log("cycle %d: reply %s" % (i, r))
        else:
            lat.append(r[0] - t)
    if lat:
        lat.sort()
        log("class write latency after a suspend: n=%d min %.3f median %.3f max %.3f s" %
            (len(lat), lat[0], lat[len(lat) // 2], lat[-1]))
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT cycles n=%d failures=%d" % (n, bad))
    return bad == 0


# ---------------------------------------------------------------- stress (co43-ea-send-20261113)
# Many concurrent senders against a device that autosuspends with a short delay and is resumed by
# force (power/control on/auto) while they send, with hci0 power cycles and a USB disconnect in the
# middle. Every packet carries a key the emulator records on arrival. At the end of each normal
# cycle power/control is set to "on", so the device cannot suspend again: a packet that has not
# arrived 2.5 s later is parked on the deferred anchor of an active device (BT-23's symptom).
HCI_CHANNEL_RAW = 0
VHCI = "/sys/devices/platform/vhci_hcd.0"
REPORT_PATTERNS = ("BUG:", "WARNING:", "KASAN", "possible circular locking", "possible recursive locking",
                   "inconsistent lock state", "blocked for more than", "soft lockup", "workqueue lockup",
                   "general protection fault", "Oops", "suspicious RCU usage", "UBSAN", "refcount_t:",
                   "list_add corruption", "list_del corruption", "use-after-free", "INFO: task",
                   "kernel BUG", "DEADLOCK", "lock held when returning", "sleeping function called")


class Kmsg:
    """every kernel record, read from /dev/kmsg as it is written (the guest's ring buffer is 128 KiB
    and its console is quiet, so a dmesg at the end could lose early lines); printed as KMSG lines"""

    def __init__(self):
        self.lines = []
        self.fd = os.open("/dev/kmsg", os.O_RDONLY)
        threading.Thread(target=self.run, daemon=True).start()

    def run(self):
        while True:
            try:
                b = os.read(self.fd, 8192)
            except OSError as e:
                if e.errno == errno.EPIPE:
                    self.lines.append((-1.0, "<kmsg overrun: records lost>"))
                    log("KMSG <overrun: records lost>")
                    continue
                log("kmsg read ended: %r" % (e,))
                return
            s = b.decode("utf-8", "replace")
            head, _, rest = s.partition(";")
            f = head.split(",")
            try:
                ts = int(f[2]) / 1e6
            except (IndexError, ValueError):
                ts = -1.0
            msg = rest.split("\n")[0]          # later lines starting with a space are the dictionary
            self.lines.append((ts, msg))
            log("KMSG [%12.6f] %s" % (ts, msg))

    def matching(self, *pats):
        return [(ts, l) for ts, l in list(self.lines) if any(p in l for p in pats)]


class RawHci:
    """an HCI raw socket bound to hci<dev>: commands (to cmd_q, or raw_q for OGF 0x3f) and ACL data
    (raw_q), both sent by the kernel through btusb_send_frame()"""

    def __init__(self, dev_id=0):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "raw socket")
        addr = struct.pack("<HHH", AF_BLUETOOTH, dev_id, HCI_CHANNEL_RAW)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            e = ctypes.get_errno()
            os.close(self.fd)
            raise OSError(e, "raw bind")

    def close(self):
        try:
            os.close(self.fd)
        except OSError:
            pass


KINDS = ["cmd"] * 3 + ["vnd"] * 2 + ["acl"] * 2   # one raw socket and one thread each
PER_SENDER = 2                                     # packets per sender thread and burst
WAVES = 3                                          # bursts per normal cycle


def in_windows(ts, windows):
    """a kernel time inside one of the (start, end) windows of a USB disconnect: from the detach
    write until hci0 was seen removed, plus 1 s"""
    return any(a - 0.2 <= ts <= b + 1.0 for a, b in windows)


def kml_classify(rep):
    """kmemleak objects: 'bt25' = the skb or the setup packet that a deferred URB owns (BT-25's
    signature: allocated by the HCI socket or command path, or by btusb's alloc_ctrl_urb()), else 'other'"""
    n_bt25, other = 0, []
    for o in rep.split("unreferenced object")[1:]:
        if "alloc_ctrl_urb" in o or ("__alloc_skb" in o and any(k in o for k in (
                "hci_sock_sendmsg", "hci_cmd_sync_alloc", "hci_prepare_cmd", "bt_skb_send_alloc",
                "hci_send_cmd"))):
            n_bt25 += 1
        else:
            other.append(o.strip().splitlines()[0] if o.strip() else "?")
    return n_bt25, other


class Stress:
    def __init__(self, m, dev, seed):
        self.m = m
        self.dev = dev
        self.rng = random.Random(seed)
        self.seq = 0
        self.seq_lock = threading.Lock()
        self.socks = []
        self.forced = 0
        self.windows = []            # (detach write, hci0 seen removed), mono
        self.open_socks()

    def open_socks(self):
        for s in self.socks:
            s.close()
        self.socks = []
        for k in KINDS:
            try:
                self.socks.append(RawHci(0))
            except OSError as e:
                log("raw socket for %s: %r" % (k, e))

    def next_key(self):
        with self.seq_lock:
            self.seq += 1
            return self.seq

    def ctl(self, value):
        try:
            with open(os.path.join(self.dev, "power", "control"), "w") as f:
                f.write(value)
            return True
        except OSError:
            return False

    def set_delay(self, ms):
        try:
            with open(os.path.join(self.dev, "power", "autosuspend_delay_ms"), "w") as f:
                f.write(str(ms))
        except OSError as e:
            log("autosuspend_delay_ms: %r" % (e,))

    def status(self):
        return rd(os.path.join(self.dev, "power", "runtime_status"))

    # -- the threads of one burst
    def sender(self, sock, kind, n, barrier, sent):
        try:
            barrier.wait(10)
        except threading.BrokenBarrierError:
            return
        for j in range(n):
            time.sleep(self.rng.uniform(0, 0.04))
            key = self.next_key()
            if kind == "cmd":
                key &= 0xFFFF
                pkt = b"\x01" + struct.pack("<HBH", 0x0C18, 2, key)          # Write Page Timeout
            elif kind == "vnd":
                pkt = b"\x01" + struct.pack("<HBI", 0xFC55, 4, key)          # vendor, raw_q
            else:
                payload = b"EA" + struct.pack("<I", key) + b"\0\0"
                pkt = b"\x02" + struct.pack("<HH", 0x2001, len(payload)) + payload
            t = mono()
            try:
                os.write(sock.fd, pkt)
                sent.append((kind, key, t, None))
            except OSError as e:
                sent.append((kind, key, t, e.errno))

    def forcer(self, barrier, stop):
        try:
            barrier.wait(10)
        except threading.BrokenBarrierError:
            return
        while not stop.is_set():
            time.sleep(self.rng.uniform(0, 0.025))
            if self.ctl("on"):
                self.forced += 1
            time.sleep(self.rng.uniform(0, 0.01))
            self.ctl("auto")
            time.sleep(self.rng.uniform(0, 0.06))

    def mgmt_writer(self, barrier, box, minor):
        try:
            barrier.wait(10)
        except threading.BrokenBarrierError:
            return
        time.sleep(self.rng.uniform(0, 0.03))
        t = class_write(self.m, minor)
        box["mgmt"] = (t, self.m.wait_reply(0x000E, 5))

    def disruptor(self, barrier, what, box):
        try:
            barrier.wait(10)
        except threading.BrokenBarrierError:
            return
        time.sleep(self.rng.uniform(0, 0.05))
        box["t_" + what] = mono()
        if what == "power":
            kmsg_mark("stress: Set Powered off during the burst")
            self.m.send(0x0005, 0, b"\x00")
            box["off"] = self.m.wait_reply(0x0005, 15)
        else:
            kmsg_mark("stress: usbip detach during the burst")
            try:
                with open(VHCI + "/detach", "w") as f:
                    f.write("0")
            except OSError as e:
                box["detach_err"] = repr(e)

    def burst(self, i, disrupt=None, sent=None):
        sent = [] if sent is None else sent
        box = {}
        stop = threading.Event()
        pairs = list(zip(self.socks, KINDS))
        n = len(pairs) + 2 + (1 if disrupt else 0)
        barrier = threading.Barrier(n)
        ths = [threading.Thread(target=self.sender, args=(s, k, PER_SENDER, barrier, sent)) for s, k in pairs]
        self.minor = getattr(self, "minor", 0) + 1     # a new class each time, so a command goes out
        ths.append(threading.Thread(target=self.mgmt_writer, args=(barrier, box, (self.minor % 3 + 1) * 4)))
        if disrupt:
            ths.append(threading.Thread(target=self.disruptor, args=(barrier, disrupt, box)))
        f = threading.Thread(target=self.forcer, args=(barrier, stop))
        for th in ths:
            th.start()
        f.start()
        for th in ths:
            th.join(30)
        stop.set()
        f.join(10)
        return sent, box

    # -- one cycle
    def cycle(self, i, disrupt=None):
        delay = self.rng.choice((20, 50, 100, 250))
        self.set_delay(delay)
        self.ctl("auto")
        susp = wait_for(lambda: self.status() == "suspended", 5, 0.01)
        e0 = EMUS[-1]
        s0, r0 = e0.suspends, e0.resumes
        if disrupt:
            sent, box = self.burst(i, disrupt)
            mgmt = []
        else:
            # WAVES bursts, each started on a suspended device, so that every wave's first packets
            # are deferred and race the resume they start (and the forced one)
            sent, mgmt = [], []
            for w_ in range(WAVES):
                if w_:
                    self.ctl("auto")
                    wait_for(lambda: self.status() == "suspended", 2, 0.01)
                _, box = self.burst(i, None, sent)
                mgmt.append(box.get("mgmt"))
        good = [x for x in sent if x[3] is None]
        errs = [x for x in sent if x[3] is not None]
        res = {"i": i, "kind": disrupt or "normal", "delay": delay, "suspended_before": susp,
               "sent": len(good), "send_errors": len(errs)}
        if disrupt == "power":
            r_off = box.get("off")
            res["power_off"] = ("0x%02x" % r_off[3]) if r_off else "none"
            res["ok"] = power_on(self.m, tries=10)
            res["recovered"] = res["ok"]
        elif disrupt == "detach":
            res["ok"] = self.reattach(box)
            res["recovered"] = res["ok"]
        else:
            self.ctl("on")              # no suspend from here on: what has not arrived is parked
            wait_for(lambda: all((k, key) in RX for k, key, t, er in good), 2.5, 0.01)
            missing = [(k, key, t) for k, key, t, er in good if (k, key) not in RX]
            late = []
            if missing:
                # a parked URB goes out only at the next resume: allow one, and see whether it then arrives
                time.sleep(0.5)
                self.ctl("auto")
                wait_for(lambda: self.status() == "suspended", 5, 0.01)
                self.ctl("on")
                time.sleep(0.5)
                late = [(k, key, t) for k, key, t in missing if (k, key) in RX]
                for k, key, t in missing:
                    rx = RX.get((k, key))
                    log("PARKED cycle %d: %s key %d sent %.6f %s" %
                        (i, k, key, t, ("arrived %.6f after the next resume" % rx[0]) if rx else "never arrived"))
            lat = [RX[(k, key)][0] - t for k, key, t, er in good if (k, key) in RX]
            sts = [("0x%02x" % mg[1][3]) if mg and mg[1] else "none" for mg in mgmt]
            mst = "0x00" if sts and all(s == "0x00" for s in sts) else ",".join(sts) or "none"
            res.update({"parked": len(missing), "parked_late": len(late), "mgmt": mst,
                        "max_latency": round(max(lat), 3) if lat else -1})
            res["ok"] = not missing and not errs and mst == "0x00"
        e1 = EMUS[-1]
        res["device_suspends"] = (e1.suspends - s0) if e1 is e0 else "new-emu"
        res["device_resumes"] = (e1.resumes - r0) if e1 is e0 else "new-emu"
        log("CYCLE %s" % " ".join("%s=%s" % (k, v) for k, v in res.items()))
        return res

    def reattach(self, box):
        if "detach_err" in box:
            log("detach failed: %s" % box["detach_err"])
            return False
        gone = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 20)
        self.windows.append((box.get("t_detach", mono()), mono()))
        log("after detach: hci0 removed=%s" % gone)
        for s in self.socks:
            s.close()
        self.socks = []
        time.sleep(0.5)
        emu = Emu(fail_at=0)
        emu.attach()
        back = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 30)
        powered = power_on(self.m, tries=20) if back else False
        self.dev = usb_dev() or self.dev
        self.open_socks()
        log("re-attached: hci0=%s powered=%s usb device %s raw sockets %d" % (back, powered, self.dev, len(self.socks)))
        return bool(gone and back and powered and len(self.socks) == len(KINDS))


def d_state_tasks():
    out = []
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            st = open("/proc/%s/stat" % pid).read()
            comm = st[st.index("(") + 1:st.rindex(")")]
            state = st[st.rindex(")") + 2]
            if state == "D":
                out.append("%s/%s wchan=%s" % (pid, comm, rd("/proc/%s/wchan" % pid)))
        except (OSError, ValueError):
            pass
    return out


def scenario_stress(m, dev, kmsg, n_cycles, seed):
    with open("/proc/sys/kernel/hung_task_timeout_secs", "w") as f:
        f.write("20")
    log("hung_task_timeout_secs %s, seed %d" % (rd("/proc/sys/kernel/hung_task_timeout_secs"), seed))
    if arg("--bt23-delay"):
        # positive control, debug-only kernels: widen BT-23's window during the whole run
        p = "/sys/module/btusb/parameters/bt23_delay_ms"
        with open(p, "w") as f:
            f.write(arg("--bt23-delay"))
        log("bt23_delay_ms = %s (debug-only kernel, positive control)" % rd(p))
    have_kml = os.path.exists(KML)
    if have_kml:
        with open(KML, "w") as f:
            f.write("scan")
        with open(KML, "w") as f:
            f.write("clear")
        log("kmemleak: boot objects cleared")
    st = Stress(m, dev, seed)
    plan = {n_cycles * 10 // 100: "power", n_cycles * 30 // 100: "power", n_cycles // 2: "detach",
            n_cycles * 70 // 100: "power", n_cycles * 90 // 100: "power"}
    results = []
    for i in range(n_cycles):
        results.append(st.cycle(i, plan.get(i)))
    # the end: one more burst with a USB disconnect in it, nothing re-attached (teardown with traffic)
    st.set_delay(50)
    st.ctl("auto")
    wait_for(lambda: st.status() == "suspended", 5, 0.01)
    sent, box = st.burst(n_cycles, "detach")
    gone = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 20)
    st.windows.append((box.get("t_detach", mono()), mono()))
    log("final burst with detach: sent %d, hci0 removed=%s %s" %
        (len([x for x in sent if x[3] is None]), gone, box.get("detach_err", "")))
    t_end = mono()
    kml_n, kml_bt, kml_other = -1, -1, []
    if have_kml:
        rep = kml_scan("after stress")
        kml_n = rep.count("unreferenced object")
        kml_bt, kml_other = kml_classify(rep)
        for o in kml_other:
            log("KMEMLEAK-OTHER %s" % o)
    # give the hung-task detector (20 s) time to see a task blocked by the last cycles
    while mono() - t_end < 25:
        time.sleep(1)
    dst = d_state_tasks()
    log("tasks in D state at the end: %d %s" % (len(dst), dst))
    normal = [r for r in results if r["kind"] == "normal"]
    disr = [r for r in results if r["kind"] != "normal"]
    reports = kmsg.matching(*REPORT_PATTERNS)
    tmo_all = kmsg.matching("tx timeout", "Resetting usb device")
    # a command outstanding when the device is detached times out before the USB core has
    # disconnected btusb (vhci reports the disconnect about 2.4 s later): expected, reported apart
    tmo = [(ts, l) for ts, l in tmo_all if not in_windows(ts, st.windows)]
    tmo_teardown = [(ts, l) for ts, l in tmo_all if in_windows(ts, st.windows)]
    log("detach windows: %s" % ["%.3f-%.3f" % w_ for w_ in st.windows])
    for ts, l in reports:
        log("KERNEL-REPORT [%12.6f] %s" % (ts, l))
    for ts, l in tmo:
        log("KERNEL-TIMEOUT [%12.6f] %s" % (ts, l))
    for ts, l in tmo_teardown:
        log("TEARDOWN-TIMEOUT [%12.6f] %s" % (ts, l))
    n_sent = sum(r["sent"] for r in results)
    parked = sum(r.get("parked", 0) for r in results)
    lat = [r["max_latency"] for r in normal if r.get("max_latency", -1) >= 0]
    ok = (all(r["ok"] for r in results) and gone and not reports and not tmo)
    log("RESULT stress cycles=%d normal=%d normal_ok=%d parked=%d mgmt_not_ok=%d send_errors_normal=%d "
        "not_suspended_before=%d disruptions=%d recovered=%d final_detach_removed=%s packets_sent=%d "
        "max_latency=%.3f forced_resume_writes=%d kernel_reports=%d tx_timeouts=%d teardown_timeouts=%d "
        "kmemleak_objects=%d kmemleak_bt25_signature=%d kmemleak_other=%d d_state_end=%d kmsg_overruns=%d "
        "device_suspends=%d device_resumes=%d seed=%d" %
        (n_cycles, len(normal), len([r for r in normal if r["ok"]]), parked,
         len([r for r in normal if r.get("mgmt") != "0x00"]), sum(r["send_errors"] for r in normal),
         len([r for r in results if not r["suspended_before"]]), len(disr),
         len([r for r in disr if r["recovered"]]), gone, n_sent, max(lat) if lat else -1, st.forced,
         len(reports), len(tmo), len(tmo_teardown), kml_n, kml_bt, len(kml_other), len(dst),
         len([1 for ts, l in kmsg.lines if l.startswith("<kmsg overrun")]),
         sum(e.suspends for e in EMUS), sum(e.resumes for e in EMUS), seed))
    return ok


def watchdog(seconds, kmsg):
    def fire():
        time.sleep(seconds)
        log("WATCHDOG: the scenario did not finish in %d s" % seconds)
        for ts, l in kmsg.matching(*REPORT_PATTERNS):
            log("KERNEL-REPORT [%12.6f] %s" % (ts, l))
        log("tasks in D state: %s" % d_state_tasks())
        try:
            with open("/proc/sysrq-trigger", "w") as f:
                f.write("w")
        except OSError:
            pass
        time.sleep(3)
        log("BT17-EXIT 1")
        os._exit(1)
    threading.Thread(target=fire, daemon=True).start()


def main():
    sc = sys.argv[1]
    if sc == "stress":
        kmsg = Kmsg()
        watchdog(int(arg("--deadline", "840")), kmsg)
        dyndbg(["func btusb_suspend +p", "func btusb_resume +p", "func btusb_disconnect +p"])
        m = Mgmt()
        Emu(fail_at=0).attach()
        dev = bring_up(EMUS[-1], m)
        ok = False
        try:
            ok = scenario_stress(m, dev, kmsg, int(arg("--cycles", "100")), int(arg("--seed", "1")))
        except Exception as e:
            import traceback
            log("scenario raised %r" % (e,))
            for l in traceback.format_exc().splitlines():
                log("TRACE " + l)
            ok = False
        log("BT17-EXIT %d" % (0 if ok else 1))
        sys.exit(0 if ok else 1)
    sc = sys.argv[1]
    emu = Emu(fail_at=int(arg("--fail-at", "0")), recover="--recover" in sys.argv,
              hold_hci="--hold-hci" in sys.argv)
    # USB core resume/reset path (what the laptop lacked), btusb's PM callbacks and the HCI
    # command worker's credit line (what the laptop had), nothing per packet
    dyndbg(["file drivers/usb/core/hub.c +p", "file drivers/usb/core/driver.c +p",
            "func btusb_suspend +p", "func btusb_resume +p", "func btusb_disconnect +p",
            "func btusb_waker +p", "func hci_cmd_work +p", "func hci_cmd_timeout +p"])
    m = Mgmt()
    emu.attach()
    dev = bring_up(emu, m)
    ok = False
    try:
        ok = True                       # scenarios without a success condition (provoke, up)
        if sc == "bt17":
            ok = scenario_bt17(emu, m, dev)
        elif sc == "provoke":
            # the laptop tool, run unchanged against the emulated device
            import subprocess
            p = subprocess.run(["python3", "-I", "/root/exp/qca9377-bt-hang/scripts/bt17-provoke.py",
                                "--yes", "--interval", "3", "--hours", arg("--provoke-hours", "0.01"),
                                "--log", "/tmp/bt17-provoke"], capture_output=True, text=True)
            for line in (p.stdout + p.stderr).splitlines():
                log("PROVOKE " + line)
            log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
            log("RESULT provoke exit=%d failure_seen=%s" % (p.returncode, "FAILURE" in p.stdout))
        elif sc == "close-recover":
            ok = scenario_close_recover(emu, m, dev)
        elif sc == "bt23":
            ok = scenario_bt23(emu, m, dev, int(arg("--delay", "400")))
        elif sc == "sysfreeze":
            ok = scenario_sysfreeze(emu, m, dev, "--fault" in sys.argv)
        elif sc == "cycles":
            ok = scenario_cycles(emu, m, dev, int(arg("--cycles", "10")))
        elif sc == "sysfs-reset":
            ok = scenario_sysfs_reset(emu, m, dev)
        elif sc == "kml":
            ok = scenario_kml(emu, m, dev, arg("--mode", "healthy"))
        elif sc in ("dropcmd", "dropcmd-wedge"):
            emu.wedge_until_reset = emu.wedge_until_reset or sc == "dropcmd-wedge"
            ok = scenario_dropcmd(emu, m, dev, int(arg("--drop-hci-event", "0x0c24"), 0),
                                  int(arg("--autosuspend-ms", "500")), int(arg("--settle", "15")))
        elif sc == "up":
            log("RESULT up ok")
        else:
            sys.exit("unknown scenario")
    except Exception as e:
        log("scenario raised %r" % (e,))
        ok = False
    log("unhandled HCI opcodes: %s" % sorted("0x%04x" % o for o in emu.unknown))
    log("---- kernel log ----")
    os.system("dmesg")
    # the host reads this line: run-guest.sh ends with it
    log("BT17-EXIT %d" % (0 if ok else 1))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
