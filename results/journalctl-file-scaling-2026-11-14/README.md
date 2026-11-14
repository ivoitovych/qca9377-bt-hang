# journalctl's speed falls in proportion to the number of journal files (2026-11-14)

**Why this exists.** On 2026-11-14 a `journalctl -k -b all` started by `devtools/check`'s
journal-contract step ran 7 h 44 min at a full CPU. In that time it read 5.4 GB from the journal
files and wrote 1.29 GB of kernel text, about 46 KB/s, and the desktop was slow all morning. Our
part is fixed in `69d24d1`: the check needed only the first boot separator but counted all of
them, and `grep -m1` now ends it in 3.4 s. This page measures journalctl's part, which is the
speed itself.

**Machine.** The laptop, systemd 255 (`255.4-1ubuntu8.18`), 553 journal files, 17 GB in
`/var/log/journal` (BT-17's dynamic debug fills the kernel log). Every run is read-only. Output
was counted, never kept, and ran under `nice -n 10 ionice -c 2 -n 7` (the first pass of
`measure.sh` used `nice 19`/`ionice -c 3`). IO pressure during the runs was `avg10=0.00`, so
the runs were CPU-bound, not disk-bound.

## 1. Rate as a function of the files opened (`scaling.sh`)

The newest K files, passed as `--file=` arguments, `-o short`, 20 s each:

```
$ tmp/journal-perf/scaling.sh
files available: 553
K=1	lines=55231	seconds=.281142738	lines/s=196451
K=2	lines=55651	seconds=.346085318	lines/s=160801
K=5	lines=407015	seconds=3.394344679	lines/s=119909
K=10	lines=936380	seconds=10.677477762	lines/s=87696
K=25	lines=913605	seconds=20.010176799	lines/s=45657
K=50	lines=486455	seconds=20.007217443	lines/s=24313
K=100	lines=259799	seconds=20.007673000	lines/s=12984
K=200	lines=120132	seconds=20.009718584	lines/s=6003
K=400	lines=17985	seconds=20.014330065	lines/s=898
K=553	lines=14085	seconds=20.016798138	lines/s=703
--- -k -b all: exit status and stderr (first 30 s)
exit 124
```

(K = 1, 2, 5 and 10 ran out of entries before the 20 s were up. Exit 124 means `timeout` ended
it, and stderr was empty.)

- **From 25 to 200 files the rate halves each time the file count doubles:** 45 657 → 24 313 →
  12 984 → 6 003 lines/s. So the cost of each printed entry is proportional to the number of
  files open, and printing everything costs entries × files. Rotation adds files as the journal
  grows, so the total cost grows with the *square* of the journal size, where a merge of sorted
  files needs only about entries × log(files).
- **Past 200 files it drops further:** 898 lines/s at 400 files, 703 at 553. That is 280 times
  slower than one file (196 451). The cause past 200 files is not known. One hypothesis, not
  tested: sd-journal's mmap cache has a fixed size, so it thrashes once the files outnumber it.

## 2. The same queries as the check (`measure-be.sh`, 30 s each)

```
kernel, current boot	30.0 s	lines bytes:   64653 2916352	args: -k -b 0
kernel, all boots	24.9 s	lines bytes:   16071  626769	args: -k -b all
everything, current boot	30.0 s	lines bytes:   67705 3723264	args: -b 0
everything, all files, no filter	30.0 s	lines bytes:   13146  557056	args:
kernel, all boots, -o cat	30.0 s	lines bytes:   17959  233472	args: -k -b all -o cat
```

Even one boot runs at about 2 000 lines/s, because journalctl still opens all 553 files. `-o
cat` does not help, so the time goes on choosing the next entry, not on formatting it. The
"kernel, all boots" run that ended at 24.9 s did not repeat: the same query reached its 30 s
timeout in section 1 (exit 124).

## 3. What this is and is not

- **Ours, fixed:** a check that asked for the whole kernel log to see one line (`69d24d1`). It
  also ran at normal priority; since 11-14, background work runs at nice 10 or 19 with low disk
  priority.
- **journalctl's, measured, cause not read in the source:** cost per entry ∝ files open, from 25
  to 200 files, and worse beyond that. Whether systemd's current main still behaves this way has
  not been checked. That check comes before any report: read `sd-journal.c` (`real_journal_next`)
  on v255 and on main, then reproduce with synthetic journals in a VM (journald with a small
  `SystemMaxFileSize`, K = 25…800 files) on v255 and on main.
- **Practical workaround until then:** fewer, larger files (`SystemMaxFileSize=`), a
  `MaxRetentionSec=` limit, or `--file=`/`-b` with `--list-boots` for queries that need only
  part of the journal. Changing the laptop's journald config is the operator's decision.
