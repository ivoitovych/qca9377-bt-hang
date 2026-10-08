#!/usr/bin/env python3
"""Does a btusb module carry a USB_DEVICE(vid, pid) table entry?

    scripts/btusb-has-device.py <btusb.ko | btusb.ko.zst> [vid pid]   (default 13d3 3503)

Looks for the usb_device_id prefix a USB_DEVICE() entry compiles to on
little-endian: match_flags 0x0003 (vendor + product), idVendor, idProduct.
btusb's quirks table (where the QCA9377 entry lives) is not exported to
modules.alias, so the alias file cannot answer this; the binary can.
Prints FOUND with the count, or ABSENT; exit 0 / 1.
"""
import struct, subprocess, sys

if len(sys.argv) not in (2, 4):
    sys.exit(__doc__)
path = sys.argv[1]
vid, pid = (int(sys.argv[2], 16), int(sys.argv[3], 16)) if len(sys.argv) == 4 else (0x13D3, 0x3503)
if path.endswith(".zst"):
    data = subprocess.run(["zstd", "-dc", path], capture_output=True, check=True).stdout
else:
    with open(path, "rb") as f:
        data = f.read()
needle = struct.pack("<HHH", 0x0003, vid, pid)
n = data.count(needle)
print(f"{'FOUND' if n else 'ABSENT'} {vid:04x}:{pid:04x} x{n}  {path}")
sys.exit(0 if n else 1)
