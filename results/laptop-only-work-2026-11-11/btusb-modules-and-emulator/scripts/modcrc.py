#!/usr/bin/env python3
"""modcrc.py - the logic of scripts/check-modversions.sh and of module-updates.sh's
bluetooth check, in Python, so that nothing here needs the modprobe command.

  modcrc.py check <Module.symvers of the NEW bluetooth build> <new btusb.ko> [<new bluetooth.ko>]
      For every module in /lib/modules/7.0.0-42-generic/modules.dep that depends on
      bluetooth.ko (kernel/ or updates/), and for the new btusb.ko, compare each
      imported CRC against what the new build exports. Dependants that the new
      pair replaces (updates/btusb.ko) are checked as the NEW btusb instead of the
      installed one. Prints one line per module and MISMATCH lines; exit 1 on any.
  modcrc.py exports <Module.symvers A> <Module.symvers B>
      Compare the exports of module net/bluetooth/bluetooth between two builds.
  modcrc.py imports <module.ko[.zst]>
      Print the imported symbols and CRCs (the module's __versions section).

Reads files only. Needs the zstd program to read .ko.zst.
"""
import os
import re
import struct
import subprocess
import sys

KREL = "7.0.0-42-generic"
MODDIR = f"/lib/modules/{KREL}"


def read_module(path):
    if path.endswith(".zst"):
        return subprocess.run(["zstd", "-dc", path], capture_output=True, check=True).stdout
    with open(path, "rb") as f:
        return f.read()


def section(data, want):
    """Return the bytes of ELF64 section <want> or None."""
    assert data[:4] == b"\x7fELF" and data[4] == 2
    shoff = struct.unpack_from("<Q", data, 0x28)[0]
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x3A)
    secs = []
    for i in range(shnum):
        o = shoff + i * shentsize
        name, typ, flags, addr, off, size = struct.unpack_from("<IIQQQQ", data, o)
        secs.append((name, off, size))
    stroff = secs[shstrndx][1]
    for name, off, size in secs:
        n = data[stroff + name: data.index(b"\0", stroff + name)].decode()
        if n == want:
            return data[off: off + size]
    return None


def imports(path):
    data = read_module(path)
    v = section(data, "__versions")
    out = {}
    if v is None:
        return None
    for i in range(0, len(v), 64):
        crc = struct.unpack_from("<Q", v, i)[0] & 0xFFFFFFFF
        name = v[i + 8: i + 64].split(b"\0", 1)[0].decode()
        if name:
            out[name] = crc
    return out


def read_symvers(path):
    ex = {}
    for line in open(path):
        p = line.rstrip("\n").split("\t")
        if len(p) >= 3:
            ex[p[1]] = (int(p[0], 16), p[2])
    return ex


def dependants():
    """Modules whose modules.dep line lists bluetooth.ko (kernel/ or updates/)."""
    res = []
    for line in open(f"{MODDIR}/modules.dep"):
        mod, _, deps = line.rstrip("\n").partition(": ")
        if re.search(r"(^| )(kernel/net/bluetooth|updates)/bluetooth\.ko(\.[a-z]+)?( |$)", deps):
            res.append(mod)
    return res


def cmd_check(symvers, new_btusb, new_bt=None):
    new = read_symvers(symvers)
    bt = {k: v[0] for k, v in new.items() if v[1] in ("bluetooth", "net/bluetooth/bluetooth")}
    print(f"exports of module net/bluetooth/bluetooth in new build: {len(bt)}")
    rc = 0
    mods = []
    for m in dependants():
        base = os.path.basename(m).split(".ko")[0]
        if base == "btusb":
            continue  # replaced by the new btusb below
        mods.append((f"{MODDIR}/{m}", m))
    mods.append((new_btusb, "NEW btusb.ko"))
    if new_bt:
        mods.append((new_bt, "NEW bluetooth.ko (imports from the kernel, unchanged by the patch?)"))
    for path, label in mods:
        imp = imports(path)
        if imp is None:
            print(f"   UNREADABLE {label}")
            rc = 1
            continue
        used = bad = 0
        for sym, crc in imp.items():
            if sym in bt:
                used += 1
                if crc != bt[sym]:
                    bad += 1
                    print(f"   MISMATCH {label}: {sym} expects {crc:#010x} new {bt[sym]:#010x}")
        print(f"{label:70s} uses {used:3d}  mismatched {bad}")
        if bad:
            rc = 1
    print("OK - every dependant accepts the new build" if rc == 0 else "DO NOT INSTALL as it stands")
    return rc


def cmd_exports(a, b):
    names = ("bluetooth", "net/bluetooth/bluetooth")
    ea = {k: v[0] for k, v in read_symvers(a).items() if v[1] in names}
    eb = {k: v[0] for k, v in read_symvers(b).items() if v[1] in names}
    print(f"exports A {len(ea)}  B {len(eb)}")
    diff = [k for k in sorted(set(ea) | set(eb)) if ea.get(k) != eb.get(k)]
    for k in diff:
        print(f"   DIFF {k}: A {ea.get(k, 0):#010x} B {eb.get(k, 0):#010x}")
    print(f"{len(diff)} exports differ")
    return 1 if diff else 0


if __name__ == "__main__":
    c = sys.argv[1]
    if c == "check":
        sys.exit(cmd_check(*sys.argv[2:]))
    if c == "exports":
        sys.exit(cmd_exports(*sys.argv[2:]))
    if c == "imports":
        for k, v in sorted(imports(sys.argv[2]).items()):
            print(f"{v:#010x} {k}")
        sys.exit(0)
    sys.exit(__doc__)
