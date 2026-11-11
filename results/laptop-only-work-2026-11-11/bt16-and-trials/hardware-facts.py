#!/usr/bin/env python3
"""hardware-facts.py <outfile>: sysfs/procfs/file reads only. Never opens the device node, never usbfs.
Excluded on purpose: any serial attribute, any Bluetooth device address."""
import hashlib
import os
import struct
import sys

USB = "/sys/bus/usb/devices/3-3"
out = []


def rd(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode(errors="replace").strip()
    except OSError as e:
        return f"<unreadable: {e.strerror}>"


def say(s=""):
    out.append(s)


say("# Hardware fact sheet, laptop controller 13d3:3503 (sysfs, procfs and files only)")
say("# NO Bluetooth device address and NO serial number in this file: none was read.")
say("# Method per line: [measured] = read from the path shown at the time of the run.")
say()
real = os.path.realpath(USB)
say(f"## USB device attributes  (path {real})")
for a in ["idVendor", "idProduct", "bcdDevice", "bDeviceClass", "bDeviceSubClass", "bDeviceProtocol", "bMaxPacketSize0",
          "bNumConfigurations", "bConfigurationValue", "bNumInterfaces", "bmAttributes", "bMaxPower", "speed", "version",
          "busnum", "devnum", "devpath", "removable", "quirks", "avoid_reset_quirk", "authorized", "maxchild"]:
    say(f"[measured] {a} = {rd(os.path.join(USB, a))}")
say()
say("## Interfaces as currently bound (sysfs shows only the active alt setting's endpoints)")
for name in sorted(os.listdir(USB)):
    d = os.path.join(USB, name)
    if name.startswith("3-3:") and os.path.isdir(d):
        say(f"[measured] {name}: class {rd(d+'/bInterfaceClass')} sub {rd(d+'/bInterfaceSubClass')} proto {rd(d+'/bInterfaceProtocol')} "
            f"alt {rd(d+'/bAlternateSetting')} nep {rd(d+'/bNumEndpoints')} driver {os.path.basename(os.path.realpath(d+'/driver')) if os.path.exists(d+'/driver') else 'none'}")
        for ep in sorted(os.listdir(d)):
            if ep.startswith("ep_"):
                e = os.path.join(d, ep)
                say(f"[measured]   {ep}: type {rd(e+'/type')} dir {rd(e+'/direction')} wMaxPacketSize 0x{rd(e+'/wMaxPacketSize')} bInterval {rd(e+'/bInterval')} interval {rd(e+'/interval')}")
say()
say("## All alt settings, parsed from the kernel's cached copy /sys/bus/usb/devices/3-3/descriptors (a sysfs file; the device is not asked)")
raw = open(USB + "/descriptors", "rb").read()
say(f"[measured] cached descriptor bytes: {len(raw)}")
i = 0
cur = None
while i + 2 <= len(raw):
    ln, ty = raw[i], raw[i + 1]
    if ln == 0:
        break
    b = raw[i:i + ln]
    if ty == 1 and ln >= 18:
        bcdusb, cls, sub, pro, mps, vid, pid, bcd, im, ip, isn, nc = struct.unpack("<HBBBBHHHBBBB", b[2:18])
        say(f"[measured] device descriptor: bcdUSB {bcdusb:04x} class {cls:02x}/{sub:02x}/{pro:02x} maxpkt0 {mps} idVendor {vid:04x} idProduct {pid:04x} bcdDevice {bcd:04x} iManufacturer {im} iProduct {ip} iSerialNumber {isn} nconf {nc}")
    elif ty == 2:
        tl, ni, cv, ic, bm, mp = struct.unpack("<HBBBBB", b[2:9])
        say(f"[measured] configuration: wTotalLength {tl} nInterfaces {ni} value {cv} bmAttributes 0x{bm:02x} bMaxPower {mp*2} mA")
    elif ty == 4:
        n, alt, ne, c, s, p = struct.unpack("<BBBBBB", b[2:8])
        say(f"[measured] interface {n} alt {alt}: {ne} endpoints, class {c:02x}/{s:02x}/{p:02x}")
    elif ty == 5:
        ad, at, mp, iv = struct.unpack("<BBHB", b[2:7])
        kind = {0: "Control", 1: "Isoc", 2: "Bulk", 3: "Interrupt"}[at & 3]
        say(f"[measured]     endpoint 0x{ad:02x} {'IN' if ad & 0x80 else 'OUT'} {kind} wMaxPacketSize {mp} bInterval {iv}")
    i += ln
say()
say("## Power chain, leaf to root (control / runtime_status / wakeup / d3cold where the file exists)")
p = real
while p.startswith("/sys/devices") and p != "/sys/devices":
    parts = []
    for a in ["power/control", "power/runtime_status", "power/wakeup", "power/autosuspend_delay_ms", "d3cold_allowed", "vendor", "device",
              "power/runtime_active_time", "power/runtime_suspended_time", "power/connected_duration", "power/active_duration"]:
        if os.path.exists(os.path.join(p, a)):
            parts.append(f"{a}={rd(os.path.join(p, a))}")
    drv = os.path.basename(os.path.realpath(p + "/driver")) if os.path.exists(p + "/driver") else "-"
    say(f"[measured] {p}: driver {drv}; " + "; ".join(parts))
    p = os.path.dirname(p)
say()
say("## /proc/acpi/wakeup")
for l in rd("/proc/acpi/wakeup").splitlines():
    say("[measured] " + l)
say()
say("## DMI identification (no serial, no UUID)")
for a in ["sys_vendor", "product_name", "product_version", "product_family", "board_vendor", "board_name", "board_version", "bios_vendor",
          "bios_version", "bios_date", "chassis_type"]:
    say(f"[measured] {a} = {rd('/sys/class/dmi/id/' + a)}")
say()
say("## Firmware files named by the kernel log (sha256 of the file as installed, and of its decompressed content)")
import subprocess
for n in ["rampatch_usb_00000302.bin", "nvm_usb_00000302.bin", "nvm_usb_00000302_eu.bin"]:
    f = "/lib/firmware/qca/" + n + ".zst"
    if os.path.exists(f):
        c = open(f, "rb").read()
        d = subprocess.run(["zstd", "-dcq", f], capture_output=True).stdout
        say(f"[measured] {f}: {len(c)} bytes sha256 {hashlib.sha256(c).hexdigest()}; decompressed {len(d)} bytes sha256 {hashlib.sha256(d).hexdigest()}")
    else:
        say(f"[not found] {f}")
with open(sys.argv[1], "w") as fo:
    fo.write("\n".join(out) + "\n")
