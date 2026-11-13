#!/usr/bin/env python3
"""rg-emu.py - the emulated 13d3:3503 of bt17-emu.py on a second bus: USB Raw Gadget on
dummy_hcd (both in the guest kernel), for what usbip cannot do. vhci_hcd refuses system
suspend while a device is attached; dummy_hcd suspends once its root hub has.

Scenario sysfreeze [--reset-resume]: a system sleep transition (pm_test=devices, freeze) of
the running controller. With --reset-resume the device is given USB_QUIRK_RESET_RESUME
(usbcore.quirks "13d3:3503:b") before it enumerates, as btusb_check_needs_reset_resume() gives
the QCA ROME devices of its DMI table: the USB core then resets it at every resume. That is the
system-resume path CO-43 D changes. Then: does Bluetooth work?

Usage: rg-emu.py sysfreeze [--reset-resume]
"""
import ctypes
import fcntl
import os
import queue
import socket
import struct
import sys
import threading
import time

T0 = time.time()
LOCK = threading.Lock()


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def _ioc(d, nr, size):
    return (d << 30) | (size << 16) | (ord("U") << 8) | nr


RAW_INIT = _ioc(1, 0, 257)
RAW_RUN = _ioc(0, 1, 0)
RAW_EVENT_FETCH = _ioc(2, 2, 8)
RAW_EP0_WRITE = _ioc(1, 3, 8)
RAW_EP0_READ = _ioc(3, 4, 8)
RAW_EP_ENABLE = _ioc(1, 5, 9)
RAW_EP_WRITE = _ioc(1, 7, 8)
RAW_CONFIGURE = _ioc(0, 9, 0)
RAW_VBUS_DRAW = _ioc(1, 10, 4)
RAW_EP0_STALL = _ioc(0, 12, 0)
EV = {1: "CONNECT", 2: "CONTROL", 3: "SUSPEND", 4: "RESUME", 5: "RESET", 6: "DISCONNECT"}

# dummy_udc's fixed endpoints: ep1in-bulk, ep2out-bulk, ep3in-iso, ep4out-iso, ep5in-int
EP_INT_IN, EP_BULK_IN, EP_BULK_OUT, EP_ISO_IN, EP_ISO_OUT = 0x85, 0x81, 0x02, 0x83, 0x04


def epd(addr, attr, mps, ival):
    return struct.pack("<BBBBHB", 7, 5, addr, attr, mps, ival)


def iface(num, alt, neps):
    return struct.pack("<BBBBBBBBB", 9, 4, num, alt, neps, 0xE0, 1, 1, 0)


def config_desc():
    body = iface(0, 0, 3) + epd(EP_INT_IN, 3, 16, 1) + epd(EP_BULK_IN, 2, 64, 0) + epd(EP_BULK_OUT, 2, 64, 0)
    for alt, mps in enumerate((0, 9, 17, 25, 33, 49)):
        body += iface(1, alt, 2) + epd(EP_ISO_IN, 1, mps, 1) + epd(EP_ISO_OUT, 1, mps, 1)
    return struct.pack("<BBHBBBBB", 9, 2, 9 + len(body), 2, 1, 0, 0xE0, 50) + body


DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0110, 0xE0, 1, 1, 64,
                       0x13D3, 0x3503, 0x0001, 0, 0, 0, 1)
QCA_VERSION = struct.pack("<IIIBBH4s", 0x302, 0x3E8, 0x302, 0, 0, 0, b"\0" * 4)
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])
BDADDR = bytes([0x00, 0x00, 0x00, 0x77, 0x17, 0x01])


class Gadget:
    def __init__(self):
        self.fd = os.open("/dev/raw-gadget", os.O_RDWR)
        init = b"dummy_udc".ljust(128, b"\0") + b"dummy_udc.0".ljust(128, b"\0") + bytes([2])
        fcntl.ioctl(self.fd, RAW_INIT, init)
        fcntl.ioctl(self.fd, RAW_RUN, 0)
        self.ep_int = None
        self.events = queue.Queue()
        self.counts = {}
        self.configured = False
        threading.Thread(target=self.ep0_loop, daemon=True).start()
        threading.Thread(target=self.int_writer, daemon=True).start()

    def count(self, k):
        self.counts[k] = self.counts.get(k, 0) + 1

    def ep0_write(self, data):
        buf = bytearray(struct.pack("<HHI", 0, 0, len(data)) + data)
        return fcntl.ioctl(self.fd, RAW_EP0_WRITE, buf, True)

    def ep0_read(self, n):
        buf = bytearray(struct.pack("<HHI", 0, 0, n) + b"\0" * n)
        r = fcntl.ioctl(self.fd, RAW_EP0_READ, buf, True)
        return bytes(buf[8:8 + n]), r

    def stall(self):
        fcntl.ioctl(self.fd, RAW_EP0_STALL, 0)

    def ep0_loop(self):
        while True:
            buf = bytearray(struct.pack("<II", 0, 8) + b"\0" * 8)
            try:
                fcntl.ioctl(self.fd, RAW_EVENT_FETCH, buf, True)
            except OSError as e:
                log("event fetch ended: %r" % (e,))
                return
            typ, ln = struct.unpack("<II", buf[:8])
            name = EV.get(typ, str(typ))
            if typ != 2:
                self.count(name)
                log("GADGET event %s" % name)
                continue
            try:
                self.control(bytes(buf[8:16]))
            except OSError as e:
                log("control handling: %r" % (e,))

    def control(self, setup):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        if bm == 0x80 and br == 6:
            t = wv >> 8
            d = DEV_DESC if t == 1 else config_desc() if t == 2 else None
            if d is None:
                self.stall()
                return
            self.ep0_write(d[:wl])
        elif bm == 0x00 and br == 9:                     # SET_CONFIGURATION
            if not self.configured:
                # a mutable buffer, so that ioctl() returns the handle, not the buffer
                self.ep_int = fcntl.ioctl(self.fd, RAW_EP_ENABLE,
                                          bytearray(epd(EP_INT_IN, 3, 16, 1) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_EP_ENABLE, bytearray(epd(EP_BULK_IN, 2, 64, 0) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_EP_ENABLE, bytearray(epd(EP_BULK_OUT, 2, 64, 0) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_CONFIGURE, 0)
                fcntl.ioctl(self.fd, RAW_VBUS_DRAW, 50)
                self.configured = True
                log("GADGET configured, interrupt endpoint handle %d" % self.ep_int)
            self.ep0_read(0)
        elif bm == 0xC0 and br == 0x09:
            self.ep0_write(QCA_VERSION[:wl])
        elif bm == 0xC0 and br == 0x05:
            self.ep0_write(b"\xc0")
        elif bm == 0x20 and br == 0:                     # HCI command
            data, _ = self.ep0_read(wl)
            op, plen = struct.unpack("<HB", data[:3])
            self.hci(op)
        elif bm & 0x80:
            self.ep0_write(b"\0" * min(wl, 2))
        else:                                            # SET_INTERFACE, features: acknowledge
            self.ep0_read(0)

    def event(self, code, params):
        self.events.put(bytes([code, len(params)]) + params)

    def int_writer(self):
        while True:
            ev = self.events.get()
            while self.ep_int is None:
                time.sleep(0.01)
            for i in range(0, len(ev), 16):
                chunk = ev[i:i + 16]
                buf = bytearray(struct.pack("<HHI", self.ep_int, 0, len(chunk)) + chunk)
                try:
                    fcntl.ioctl(self.fd, RAW_EP_WRITE, buf, True)
                except OSError as e:
                    log("interrupt write: %r" % (e,))
                    break

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci(self, op):
        self.count("hci 0x%04x" % op)
        if op == 0x1001:
            self.cc(op, struct.pack("<BBHBHH", 0, 6, 0x0302, 6, 0x0045, 0x0302))
        elif op == 0x1002:
            c = bytearray(64)
            c[9] = 0x04
            self.cc(op, b"\0" + bytes(c))
        elif op == 0x1003:
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:
            self.cc(op, b"\0" + b"rg-emu".ljust(248, b"\0"))
        elif op == 0x0C25:
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        else:
            self.cc(op)


# ---------------------------------------------------------------- MGMT, as in bt17-emu.py
class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(31, socket.SOCK_RAW | socket.SOCK_CLOEXEC, 1)
        addr = struct.pack("<HHH", 31, 0xFFFF, 3)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.replies = []
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while True:
            b = os.read(self.fd, 1024)
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            if ev in (1, 2):
                op, st = struct.unpack("<HB", p[:3])
                self.replies.append((mono(), ev, op, st, index))
                log("MGMT reply opcode 0x%04x status 0x%02x index %d" % (op, st, index))
            else:
                self.replies.append((mono(), ev, None, None, index))
                log("MGMT event 0x%04x index %d" % (ev, index))

    def wait(self, op, timeout):
        t = time.time()
        while time.time() - t < timeout:
            for r in self.replies:
                if r[2] == op:
                    self.replies.remove(r)
                    return r
            time.sleep(0.02)
        return None


def wait_for(cond, timeout):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(0.05)
    return False


def power_on(m):
    for _ in range(20):
        m.send(0x0005, 0, b"\x01")
        r = m.wait(0x0005, 10)
        if r and r[3] == 0:
            return True
        time.sleep(0.3)
    return False


def class_ok(m, minor):
    m.send(0x000E, 0, bytes([1, minor]))
    r = m.wait(0x000E, 8)
    log("class write minor %d: %s" % (minor, r))
    return bool(r and r[3] == 0)


def main():
    rr = "--reset-resume" in sys.argv
    with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
        for l in ("file drivers/usb/core/hub.c +p", "file drivers/usb/core/driver.c +p",
                  "func btusb_suspend +p", "func btusb_resume +p", "func btusb_reset_resume +p",
                  "func btusb_disconnect +p", "func btusb_probe +p"):
            f.write(l + "\n")
    if rr:
        with open("/sys/module/usbcore/parameters/quirks", "w") as f:
            f.write("13d3:3503:b")
        log("usbcore quirks: %s" % open("/sys/module/usbcore/parameters/quirks").read().strip())
    m = Mgmt()
    g = Gadget()
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        log("no hci0")
        os.system("dmesg | tail -n 80")
        sys.exit(2)
    time.sleep(0.5)
    ok0 = power_on(m) and class_ok(m, 0x0C)
    log("before sleep: bluetooth works=%s" % ok0)
    with open("/sys/power/pm_test", "w") as f:
        f.write("devices")
    t = mono()
    try:
        with open("/sys/power/state", "w") as f:
            f.write("freeze")
    except OSError as e:
        log("freeze write: %r" % (e,))
    log("back from freeze after %.3f s; gadget events %s" % (mono() - t, g.counts))
    time.sleep(3.0)
    present = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15)
    time.sleep(1.0)
    ok1 = present and power_on(m) and class_ok(m, 0x10)
    log("gadget events %s" % {k: v for k, v in g.counts.items() if not k.startswith("hci")})
    log("RESULT rg-sysfreeze reset_resume_quirk=%s before=%s after=%s slept=%.1f" %
        (rr, ok0, ok1, 0))
    os.system("dmesg")


if __name__ == "__main__":
    main()
