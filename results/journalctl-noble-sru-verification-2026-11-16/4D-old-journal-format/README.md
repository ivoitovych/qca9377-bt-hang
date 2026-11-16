# 4D: journal files in the older format (no tail_entry_offset in the header)

Result: **no difference.** 21 comparisons (3 fixtures x 7 queries): all exit 0, all non-empty, stock and patched sha256
identical (`4D.txt`). The fallback branch was exercised by the patched build (debugger count below).

## How the old-format files were made

`inside-4D-old.sh` runs in `ubuntu:22.04` and installs `systemd-journal-remote` 249.11-0ubuntu3.23 (systemd 249). That
binary writes the files (`make4D.py`: 12 files, 1000 entries each, three boots, one machine, exported as a stream into the
writer). The state byte (offset 16) of each file was set to ARCHIVED (2), as for a rotated file.

Proof that the field is absent (`header-info.py`, from `4D-gen.txt` and `4D.txt`): `header_size` is at offset 88 of the
header; in v255 `tail_entry_offset` ends at offset 272, so a file has the field only if `header_size >= 272`.

| fixture | files | header_size | tail_entry_offset |
|---|---|---|---|
| old-249 | 12 | 256 (all) | ABSENT |
| mixed | 12 (6 from 249, 6 from 255.4) | 256 x6, 272 x6 | absent in 6, present in 6 |
| new-255 | 12 | 272 (all) | PRESENT |

## Equivalence

`inside-4D-test.sh` with `../scripts/cmp-lib.sh`: `-o export`, `-o export -r`, `--list-boots`, `-b <newest boot id>`, `-k`,
`-n 100`, `-n 100 -r`, for each fixture, stock 255.4-1ubuntu8.19 against the 8.20 test build, on `--directory=<fixture>`.
Termination: each command ends by itself (cap 7200 s, not reached). Result: 21 of 21 SAME (`-o export`: 156000 lines,
5159143 bytes in all three fixtures for both builds).

## Is the fallback path exercised? (labelled: debugger observation plus code reading)

Observed: `tail.gdb` puts a breakpoint on `journal_file_read_tail_timestamp` of the 8.20 build (libsystemd-shared with its
debug symbols) and prints `f->header->header_size` at every hit during `journalctl -n 5`:

| fixture | hits with header_size 256 (field absent) | hits with header_size 272 (field present) |
|---|---|---|
| old-249 | 264 | 0 |
| mixed | 96 | 168 |
| new-255 | 0 | 264 |

Inferred from the code (`sd-journal.c`, `journal_file_read_tail_timestamp`, with the two commits): when
`JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset)` is false the function reads `tail_object_offset` and uses object
type `OBJECT_UNUSED`, and when the object it lands on is not an entry it takes the header-timestamp or
`journal_file_next_entry` path. The debugger run proves the condition is false for every call on the old files; that the
`OBJECT_UNUSED` line itself ran follows from the code, it was not single-stepped.
