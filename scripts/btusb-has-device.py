#!/usr/bin/env python3
"""Does a btusb module carry a USB_DEVICE(vid, pid) table entry?

    scripts/btusb-has-device.py <btusb.ko | .ko.zst | .ko.xz | .ko.gz> [vid pid]   (default 13d3 3503)

Looks for the usb_device_id prefix a USB_DEVICE() entry compiles to on
little-endian: match_flags 0x0003 (vendor + product), idVendor, idProduct.
btusb's quirks table (where the QCA9377 entry lives) is not exported to
modules.alias, so the alias file cannot answer this; the binary can.
Prints FOUND with the count, or ABSENT; exit 0 / 1. A file that cannot be read
or decompressed (missing, no zstd, a damaged archive) prints NOT CHECKED on
standard error and exits 2: that is neither FOUND nor ABSENT.
"""
import gzip, lzma, struct, subprocess, sys

if len(sys.argv) not in (2, 4):
    sys.exit(__doc__)
path = sys.argv[1]
try:
    vid, pid = (int(sys.argv[2], 16), int(sys.argv[3], 16)) if len(sys.argv) == 4 else (0x13D3, 0x3503)
except ValueError as e:
    sys.exit(f"NOT CHECKED: vid and pid are hexadecimal numbers ({e})")


def read_module(p):
    if p.endswith(".zst"):
        return subprocess.run(["zstd", "-dc", p], capture_output=True, check=True).stdout
    if p.endswith(".xz"):
        with lzma.open(p, "rb") as f:
            return f.read()
    if p.endswith(".gz"):
        with gzip.open(p, "rb") as f:
            return f.read()
    with open(p, "rb") as f:
        return f.read()


try:
    data = read_module(path)
except (OSError, subprocess.CalledProcessError, lzma.LZMAError, EOFError) as e:
    print(f"NOT CHECKED: cannot read {path}: {e}", file=sys.stderr)
    sys.exit(2)
if not data:
    print(f"NOT CHECKED: {path} is empty", file=sys.stderr)
    sys.exit(2)
needle = struct.pack("<HHH", 0x0003, vid, pid)
n = data.count(needle)
print(f"{'FOUND' if n else 'ABSENT'} {vid:04x}:{pid:04x} x{n}  {path}")
sys.exit(0 if n else 1)
