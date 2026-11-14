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
import os
import socket
import struct
import sys
import threading
import time
from collections import deque

T0 = time.time()
LOG_LOCK = threading.Lock()


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

    def note(self, what):
        self.events.append((mono(), what))
        log("EMU " + what)

    # -- usbip
    def attach(self):
        base = "/sys/devices/platform/vhci_hcd.0"
        kfd, self.sock = socket.socketpair()
        with open(base + "/attach", "w") as f:
            f.write("0 %d %d 2" % (kfd.fileno(), (1 << 16) | 2))   # full speed
        log("attached to vhci_hcd port 0")
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
        if victim in self.held:
            what = self.held.pop(victim)
            hit = True
            self.note("host gave up on held %s (unlink)" % what)
            if self.state == "wedged":
                if self.recover:
                    # task1 fix 1: not healthy yet. The device answers again only after a USB
                    # reset, which shows as the first device-descriptor read (control())
                    self.state = "lost"
                    self.note("device unresponsive until a USB reset (--recover)")
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
                self.ret_submit(seq, 0, buflen)
            elif self.state in ("dead", "lost"):
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
        if self.state == "lost" and bm == 0x80 and br == 6 and (wv >> 8) == 1 \
                and "--mutate-no-reset" not in sys.argv:
            # the USB core reads the device descriptor only after it has reset the port (vhci_hcd
            # handles the reset itself and never forwards it): this is the reset signal. A reset
            # brings the device back, with its pending event bytes gone.
            self.state = "healthy"
            self.intr_out.clear()
            self.reset_seen.append(mono())
            self.note("reset seen (device-descriptor read); device recovers (--recover)")
        if self.state in ("dead", "lost"):
            self.note("%s -> -71 (%s)" % (desc, self.state))
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
            self.ret_submit(seq, 0, len(chunk), chunk)

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci_cmd(self, op, p):
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
        raise RuntimeError("no hci0 after bring-up")
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
    if arg("--reset-delay-ms"):
        # task 1 step 3: needs a kernel with the debug-only usbcore parameter, which delays the
        # work that carries a queued reset (usb_queue_reset_device()); the autosuspend delay is
        # lowered so the device can suspend again before that work runs
        with open("/sys/module/usbcore/parameters/bt17_reset_delay_ms", "w") as f:
            f.write(arg("--reset-delay-ms"))
        with open(os.path.join(dev, "power", "autosuspend_delay_ms"), "w") as f:
            f.write("500")
        log("bt17_reset_delay_ms = %s, autosuspend_delay_ms = %s" %
            (rd("/sys/module/usbcore/parameters/bt17_reset_delay_ms"),
             rd(os.path.join(dev, "power", "autosuspend_delay_ms"))))
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
    if "--mutate-legacy-judge" in sys.argv and emu.recover:
        return back                     # self-test only: the old judgement, "hci0 reappeared"
    if "--expect-rebind" in sys.argv and not gone:
        # a queued reset must have run: the reset unbinds btusb, so hci0 goes away and comes back
        log("expected a rebinding (hci0 removed after the recovery), none happened")
        return False
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
        if arg("--inject"):
            # task 2: needs a kernel with the debug-only fault injection in btusb
            # (1: the interrupt URB submission at resume fails; 2: play_deferred()'s submit fails)
            with open("/sys/module/btusb/parameters/bt_inject", "w") as f:
                f.write(arg("--inject"))
            log("bt_inject = %s" % rd("/sys/module/btusb/parameters/bt_inject"))
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
    if "--expect-no-leak" in sys.argv and (len(objs) or len(hits)):
        log("expected no unreferenced objects, found %d (%d Bluetooth related)" % (len(objs), len(hits)))
        return False
    return ok


def scenario_bt24(emu, m, dev, delay_ms):
    """BT-24: a deferred send racing the failure path of btusb_resume(). Needs the debug-only
    kernel (bt_inject = 1 fails the interrupt URB submission at resume; bt24_delay_ms widens the
    window after the scuttle, or, with the fix, before the locked scuttle). The first class
    write is deferred and its resume fails; a second one is sent once the first has timed out,
    while the failure path is still running. The kernel then logs 'bt24-dbg: deferred anchor
    empty|NOT empty'. Pass = empty (nothing left parked)."""
    if not wait_suspended(dev):
        log("RESULT bt24 SKIP device never autosuspended")
        return False
    time.sleep(0.5)
    with open("/sys/module/btusb/parameters/bt_inject", "w") as f:
        f.write("1")
    with open("/sys/module/btusb/parameters/bt24_delay_ms", "w") as f:
        f.write(str(delay_ms))
    log("bt_inject = %s bt24_delay_ms = %s" % (rd("/sys/module/btusb/parameters/bt_inject"),
                                              rd("/sys/module/btusb/parameters/bt24_delay_ms")))
    t1 = class_write(m, 0x0C)
    r1 = m.wait_reply(0x000E, 8)
    log("first class write: %.3f s %s" % ((r1[0] - t1) if r1 else -1, r1))
    t2 = class_write(m, 0x10)
    r2 = m.wait_reply(0x000E, 8)
    log("second class write: %.3f s %s" % ((r2[0] - t2) if r2 else -1, r2))
    time.sleep(1.0)
    kl = kernel_lines("bt24-dbg", "tx timeout")
    for ts, l in kl:
        log("KERNEL %s" % l)
    states = ["NOT empty" if "NOT empty" in l else "empty" for ts, l in kl if "bt24-dbg" in l]
    log("RESULT bt24 delay_ms=%d first=%s second=%s deferred_anchor_after_failure=%s" %
        (delay_ms, ("0x%02x" % r1[3]) if r1 else "none", ("0x%02x" % r2[3]) if r2 else "none",
         ",".join(states) or "no-line"))
    return bool(states) and all(s == "empty" for s in states)


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


def main():
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
    ok = False
    try:
        dev = bring_up(emu, m)          # raises if btusb did not bind: a FAIL, not a bare exit
        ok = True                       # scenarios without a success condition (provoke, up)
        if sc == "mutate-raise":        # harness self-test: a scenario that raises must fail the run
            raise RuntimeError("deliberate")
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
        elif sc == "bt24":
            ok = scenario_bt24(emu, m, dev, int(arg("--delay", "2500")))
        elif sc == "kml":
            ok = scenario_kml(emu, m, dev, arg("--mode", "healthy"))
        elif sc in ("dropcmd", "dropcmd-wedge"):
            emu.wedge_until_reset = emu.wedge_until_reset or sc == "dropcmd-wedge"
            ok = scenario_dropcmd(emu, m, dev, int(arg("--drop-hci-event", "0x0c24"), 0),
                                  int(arg("--autosuspend-ms", "500")), int(arg("--settle", "15")))
        elif sc == "up":
            log("RESULT up ok")
        else:
            raise ValueError("unknown scenario %r" % sc)
    except Exception as e:
        import traceback
        for l in traceback.format_exc().splitlines():
            log("scenario raised: " + l)
        ok = False
    log("unhandled HCI opcodes: %s" % sorted("0x%04x" % o for o in emu.unknown))
    log("---- kernel log ----")
    os.system("dmesg")
    # only a scenario that returned True passed (None, 0 or an exception are failures).
    # --mutate-swallow is for the harness self-test: it restores the old behaviour that a
    # failed case did not fail the run.
    passed = ok is True
    if "--mutate-swallow" in sys.argv:
        passed = True
    log("%s %s" % ("PASS" if passed else "FAIL", sc))
    # the host reads this line: run-guest.sh ends with it
    log("BT17-EXIT %d" % (0 if passed else 1))
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
