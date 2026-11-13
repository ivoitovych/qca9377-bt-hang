#!/usr/bin/env python3
"""bt17-provoke.py - drive many runtime suspend/resume cycles of the laptop's Bluetooth
controller (USB 13d3:3503) to measure how often a host-initiated resume fails (BT-17).

FOR THE OPERATOR ONLY. It talks to the real controller. If BT-17 reproduces, Bluetooth is
gone until a full power-off. Run it only when that is acceptable, with no headset in use,
and preferably after scripts/bt17-arm-usb-debug.sh --usbmon, so that a failure is recorded
in full.

What it does, per cycle:
  1. waits until the controller's USB device is runtime-suspended (power/runtime_status),
     which btusb's 2 s autosuspend delay brings about when nothing is sent;
  2. sends one harmless read command, HCI Read Local Name (0x0c14), on a raw HCI socket:
     the command wakes the device through btusb_waker(), as Write Class of Device did at
     the incident;
  3. waits up to 3 s for its Command Complete and records the latency.
It stops at the first command without an answer, saves the kernel log tail and the sysfs
power state next to its log, and prints what to do next (nothing: leave the machine as is
for the record, then power it off).

It sends no reset, writes nothing to sysfs, loads or unloads nothing. Device addresses are
never read or printed.

Usage (root): bt17-provoke.py --yes [--interval 6] [--hours 1] [--log DIR]
"""
import ctypes
import os
import socket
import struct
import subprocess
import sys
import time

AF_BLUETOOTH, BTPROTO_HCI, SOL_HCI, HCI_FILTER = 31, 1, 0, 2
HCI_CHANNEL_RAW = 0
OP_READ_LOCAL_NAME = 0x0C14


def arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def usb_dev():
    base = "/sys/bus/usb/devices"
    for d in sorted(os.listdir(base)):
        try:
            if open(os.path.join(base, d, "idVendor")).read().strip() == "13d3" and \
               open(os.path.join(base, d, "idProduct")).read().strip() == "3503":
                return os.path.join(base, d)
        except OSError:
            pass
    return None


def rd(p):
    try:
        return open(p).read().strip()
    except OSError as e:
        return "<%s>" % e.strerror


def raw_socket(dev_id=0):
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "socket")
    addr = struct.pack("<HHH", AF_BLUETOOTH, dev_id, HCI_CHANNEL_RAW)
    if libc.bind(fd, addr, len(addr)) < 0:
        raise OSError(ctypes.get_errno(), "bind")
    s = socket.socket(fileno=fd)
    # receive HCI events only (type 4), every event code; struct hci_ufilter is 16 bytes
    # with its padding, and the kernel refuses a shorter option (EINVAL)
    flt = struct.pack("<IIIHxx", 1 << 4, 0xFFFFFFFF, 0xFFFFFFFF, 0)
    s.setsockopt(SOL_HCI, HCI_FILTER, flt)
    return s


def command(s, op, timeout=3.0):
    s.send(struct.pack("<BHB", 1, op, 0))
    t0 = time.monotonic()
    s.settimeout(0.2)
    while time.monotonic() - t0 < timeout:
        try:
            b = s.recv(300)
        except socket.timeout:
            continue
        if len(b) >= 6 and b[0] == 4 and b[1] == 0x0E and struct.unpack("<H", b[4:6])[0] == op:
            return time.monotonic() - t0, b[6]
    return None, None


def main():
    if "--yes" not in sys.argv:
        print(__doc__)
        sys.exit("refusing without --yes (see the warning above)")
    interval = float(arg("--interval", "6"))
    hours = float(arg("--hours", "1"))
    logdir = arg("--log", "/var/log/bt-health/bt17-provoke")
    os.makedirs(logdir, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    logf = open(os.path.join(logdir, "provoke-%s.log" % stamp), "w")

    def log(msg):
        line = "%s %s" % (time.strftime("%H:%M:%S"), msg)
        print(line, flush=True)
        logf.write(line + "\n")
        logf.flush()

    dev = usb_dev()
    if not dev:
        sys.exit("no 13d3:3503 on USB")
    pw = {k: rd(os.path.join(dev, "power", k)) for k in
          ("control", "autosuspend_delay_ms", "runtime_status", "persist")}
    log("device %s power %s" % (dev, pw))
    if pw["control"] != "auto":
        sys.exit("power/control is %s: the device cannot runtime-suspend, nothing to test" % pw["control"])
    if not os.path.exists("/sys/class/bluetooth/hci0"):
        sys.exit("no hci0")
    s = raw_socket(0)
    end = time.monotonic() + hours * 3600
    n = 0
    lat = []
    while time.monotonic() < end:
        t = time.monotonic()
        while rd(os.path.join(dev, "power", "runtime_status")) != "suspended" and time.monotonic() - t < 10:
            time.sleep(0.05)
        st = rd(os.path.join(dev, "power", "runtime_status"))
        if st != "suspended":
            log("cycle %d: device %s after 10 s (something keeps it awake); waiting" % (n, st))
            time.sleep(interval)
            continue
        d, status = command(s, OP_READ_LOCAL_NAME)
        n += 1
        if d is None:
            log("FAILURE at cycle %d: Read Local Name got no answer in 3 s" % n)
            with open(os.path.join(logdir, "provoke-%s-dmesg.txt" % stamp), "w") as f:
                f.write(subprocess.run(["dmesg", "-T"], capture_output=True, text=True).stdout[-200000:])
            log("power now %s" % {k: rd(os.path.join(dev, "power", k)) for k in
                                 ("control", "runtime_status")} if os.path.exists(dev) else "device gone")
            log("leave the machine as it is until the evidence is collected, then power it off")
            break
        lat.append(d)
        if n % 50 == 0:
            ls = sorted(lat)
            log("%d cycles, latency median %.3f s max %.3f s" % (n, ls[len(ls) // 2], ls[-1]))
        time.sleep(max(0.0, interval - (time.monotonic() - t)))
    log("done: %d cycles, %d answered" % (n, len(lat)))


if __name__ == "__main__":
    main()
