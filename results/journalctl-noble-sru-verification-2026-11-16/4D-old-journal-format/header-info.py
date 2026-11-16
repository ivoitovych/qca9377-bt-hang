#!/usr/bin/env python3
"""header-info.py FILE... : header_size and whether the header holds tail_entry_offset (needs header_size >= 272), as v255 reads it.
Offsets of struct Header in v255 (journal-def.h): state 16, machine_id 40, header_size 88, tail_object_offset 136,
tail_entry_array_offset 256 (le32), tail_entry_array_n_entries 260 (le32), tail_entry_offset 264 (le64), end 272."""
import struct
import sys

for p in sys.argv[1:]:
    with open(p, "rb") as f:
        h = f.read(512)
    sig = h[:8]
    state = h[16]
    hs = struct.unpack_from("<Q", h, 88)[0]
    incompat = struct.unpack_from("<I", h, 12)[0]
    has = hs >= 272
    teo = struct.unpack_from("<Q", h, 264)[0] if has else None
    print(f"{p.split('/')[-1]}: signature {sig.decode(errors='replace')} state {state} header_size {hs} incompat_flags {incompat:#x} "
          f"tail_entry_offset {'PRESENT = %d' % teo if has else 'ABSENT (header_size < 272)'}")
