# 4E: imported and merged journals (header machine ID against entry `_MACHINE_ID`)

Result: **no stock/patched difference.** 45 comparisons (5 fixtures x 9 queries): all exit 0, all non-empty, identical
sha256 (`4E.txt`). The output ORDER of one fixture (E1) differs from the true order, identically in stock and patched.

## What each fixture varies (`make4E.py`; counts are measured and printed by the script, see `4E.txt`)

Three originating machines A, B, C, two boots each, boot ranges overlapping in time (A 0-200 s, B 50-250 s, C 25-225 s;
clocks agree, so the true order is the realtime order). One boot of one machine per file, 4 files of 400 entries per boot,
24 files, 9600 entries per fixture, all ARCHIVED. systemd-journal-remote writes the receiver's machine ID into every
header; `make4E.py` then rewrites the header machine ID (offset 40) where noted.

| fixture | distinct header machine IDs | distinct entry `_MACHINE_ID` | what is varied |
|---|---|---|---|
| E1-header-same | 1 | 3 (A, B, C) | entries only: every header holds the receiver's ID, as journal-remote writes it (the imported case) |
| E2-header-eq-entry | 3 | 3 | header ID equals the entries' ID (files as each machine wrote them natively) |
| E3-header-unrelated | 24 | 3 | header IDs unique per file and unrelated to the entries' IDs |
| E4-header-only | 24 | 1 | header IDs vary per file, all entries carry one machine ID |
| E5-header-swapped | 3 | 3 | header IDs are those of a different machine than the entries (A files carry B, B carry C, C carry A) |

The earlier "two machine IDs" fixture (`twomachines` of `make-sets.py` in the packaging test set) varied the **entry**
`_MACHINE_ID` only: 40 files, 1 distinct header machine ID (the receiver's), 2 distinct entry IDs (re-measured in this
run, first lines of `4E.txt`). It therefore is the same shape as E1 and did not cover distinct header IDs; E2-E5 do.

## Equivalence

Queries per fixture (stock 255.4-1ubuntu8.19 against the 8.20 test build, `inside-4E.sh` + `../scripts/cmp-lib.sh`):
`-o export`, `-o export -r`, `-o cat`, `-o cat -r`, `--list-boots`, `-b <newest boot id>`, `-k`, `-n 100`, a 60 s
`--since/--until` window. Termination: each command ends by itself, cap 7200 s, not reached. 45 of 45 SAME.

## Order against the true order (`order-check.py`; upstream ae940730c6 was not added)

`-o cat` output compared with the realtime order of all 9600 entries:

| fixture | stock | patched |
|---|---|---|
| E1-header-same | all 9600 once; NOT true order: 5 adjacent inversions, longest displacement 1999 | identical to stock |
| E2-header-eq-entry | true order | true order |
| E3-header-unrelated | true order | true order |
| E4-header-only | true order | true order |
| E5-header-swapped | true order | true order |

So the ordering defect that ae940730c6 describes shows up exactly where several entry machine IDs sit behind one header
ID (E1, the shape journal-remote produces), it is present in stock, and the patched build reproduces it byte for byte; the
two commits neither add nor remove it.
