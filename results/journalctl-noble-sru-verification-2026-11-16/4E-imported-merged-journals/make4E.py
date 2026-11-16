#!/usr/bin/env python3
"""make4E.py REMOTE OUTROOT : imported/merged journal fixtures, each varying the header machine ID and/or the entries' _MACHINE_ID.

Three originating machines A, B, C (entry _MACHINE_ID), each with two boots; the machines' boot ranges OVERLAP in time and
their clocks agree, so the true order of all entries is their realtime order. A machine's boot is cut into 4 files of 400
entries (one boot of one machine per file). systemd-journal-remote writes the RECEIVER's machine ID into every header; the
fixtures change the header's machine_id (offset 40) afterwards:
  E1-header-same      every header carries one ID (the receiver's, as journal-remote writes it); entries' IDs: A, B, C
  E2-header-eq-entry  every header carries the machine ID of its entries (as files written natively by each machine)
  E3-header-unrelated every header carries its own ID unrelated to the entries' machine IDs (A, B, C vary in the entries)
  E4-header-only      all entries carry ONE machine ID (A); the headers carry per-file distinct IDs
  E5-header-swapped   header IDs are the entries' IDs of another machine (A's files carry B's ID, B's carry C's, C's carry A's)
The fixture records are printed (counts of distinct header IDs and distinct entry IDs per fixture). All files ARCHIVED.
Also writes true-order.txt per fixture: the expected message order (realtime, then machine, then sequence)."""
import os
import struct
import subprocess
import sys

remote, root = sys.argv[1], sys.argv[2]
MACH = {"A": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "B": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "C": "cccccccccccccccccccccccccccccccc"}
BASE = 1_700_000_000_000_000
S = 1_000_000
# (machine, boot index, start s, end s)
BOOTS = [("A", 1, 0, 100), ("A", 2, 100, 200), ("B", 1, 50, 150), ("B", 2, 150, 250), ("C", 1, 25, 125), ("C", 2, 125, 225)]
PER, NF = 400, 4


def files(entry_machine_override=None):
    """list of (name, machine, entries[(rt, mono, boot, msg)])"""
    out = []
    for mach, bi, s0, s1 in BOOTS:
        boot = f"{ord(mach):02x}{bi:06x}" + "e005" * 6
        slot = (s1 - s0) * S // (PER * NF)
        for k in range(NF):
            ents = []
            for e in range(PER):
                t = BASE + s0 * S + (k * PER + e) * slot + (ord(mach) - 65) * 17     # distinct realtimes across machines
                mono = 5 * S + (k * PER + e) * slot
                ents.append((t, mono, boot, f"E {mach}{bi} k{k} e{e:03d}"))
            out.append((f"{mach}{bi}k{k}", mach, ents))
    return out


def write(path, mach_in_entries, ents):
    lines = []
    for t, mono, boot, msg in ents:
        lines.append(f"__REALTIME_TIMESTAMP={t}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={boot}\n_MACHINE_ID={mach_in_entries}\n_HOSTNAME=fx\n"
                     f"_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE={msg}\n\n")
    r = subprocess.run([remote, f"--output={path}", "-"], input="".join(lines).encode(), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0:
        sys.exit(r.stderr.decode()[-200:])


def patch(path, header_id_hex):
    with open(path, "r+b") as f:
        f.seek(16); f.write(b"\x02")
        if header_id_hex:
            f.seek(40); f.write(bytes.fromhex(header_id_hex))


def uniq(i):
    return f"{i:08x}" + "dd00" * 6


fixtures = ["E1-header-same", "E2-header-eq-entry", "E3-header-unrelated", "E4-header-only", "E5-header-swapped"]
allfiles = files()
swap = {"A": "B", "B": "C", "C": "A"}
for fx in fixtures:
    d = f"{root}/{fx}"
    os.makedirs(d, exist_ok=True)
    hdr_ids, ent_ids = set(), set()
    expected = []
    for n, (name, mach, ents) in enumerate(allfiles):
        em = MACH["A"] if fx == "E4-header-only" else MACH[mach]
        p = f"{d}/system@{n:05d}.journal"
        write(p, em, ents)
        if fx == "E1-header-same":
            hid = None
        elif fx == "E2-header-eq-entry":
            hid = em
        elif fx in ("E3-header-unrelated", "E4-header-only"):
            hid = uniq(n + 1)
        else:
            hid = MACH[swap[mach]]
        patch(p, hid)
        with open(p, "rb") as f:
            f.seek(40); hdr_ids.add(f.read(16).hex())
        ent_ids.add(em)
        for t, mono, boot, msg in ents:
            expected.append((t, em, msg))
    expected.sort()
    with open(f"{d}.true-order.txt", "w") as f:
        f.write("\n".join(m for _, _, m in expected) + "\n")
    print(f"{fx}: {len(allfiles)} files, distinct header machine IDs {len(hdr_ids)}, distinct entry _MACHINE_ID {len(ent_ids)}, "
          f"entries {len(expected)}")
