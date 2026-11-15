# systemd: journalctl's cost per open journal file — backports and one new fix (2026-11-14)

What these are for, how they were measured, and what each changes:
[`results/journalctl-file-scaling-cause-2026-11-14/`](../../../results/journalctl-file-scaling-cause-2026-11-14/README.md).
The rates in the table come from its §3: lines per second at 100 and at 400 files, on synthetic
archived journals, against 7 979 and 1 666 for v255.4 built with the same options.

## Status — 2026-11-14 (nothing sent anywhere)

| patch | what | applies to | measured | state |
|---|---|---|---|---|
| `0001`, `0002` | upstream `99e6f682d3` and `51b2bcf835` (Yu Watanabe, 2024-01-03, in v256): no `fstat()` per file per entry when the file has not changed | v255.4 as they are | 85 646 and 8 633 lines/s | upstream commits, a candidate Ubuntu 24.04 stable update; not proposed |
| `0003`, `0004` | upstream `8f8ab4bf98` (v262) and `79e32e7c73` (unreleased), adapted to v255.4 on top of `0001`, `0002`: the tail-timestamp refresh at most once a second per file, the clock read once per walk | v255.4 + `0001`, `0002` | 76 011 and 9 353 lines/s: no measurable gain over `0001`, `0002` | kept for the record; not recommended for a backport |
| `boot-order-cache/…-main.patch` | new: cache `compare_boot_ids()`'s per-boot lookups, which take 88 % of main's instructions over many boots | systemd main `6bd4689` | 240 634 and 38 406 lines/s, against 127 087 and 10 591 for main | new work; output identical in 32 comparisons; systemd's journal tests pass; not sent |
| `boot-order-cache/…-255.4.patch` | the same, adapted to v255.4 + `0001`, `0002` | v255.4 + `0001`, `0002` | 405 194 and 28 051 lines/s; output identical in 24 comparisons | for testing on 24.04 only |

How each kind of patch is written:
- **`0001` and `0002`** carry the upstream diff with a header naming the commit and its author.
  The original commits, with their mail headers, come from systemd itself:
  `git -C <systemd> format-patch -1 99e6f682d3`.
- **`0003` and `0004`** are plain diffs.
- **The two `boot-order-cache` patches** are mails made with `git format-patch`. They carry no
  Signed-off-by; one is added only when the operator decides to send.

## Applying

```console
$ git -C <systemd v255.4> apply 0001-*.patch 0002-*.patch                  # the 24.04 backport
$ git -C <systemd v255.4> am boot-order-cache/*-255.4.patch                # optional, on top
$ git -C <systemd main>   am boot-order-cache/*-main.patch                 # the upstream proposal
```

A built `journalctl` runs from its build directory and does not replace the installed one:
`<build>/journalctl --directory=<dir> …`. It only reads, so trying one on a machine's journal
changes nothing on that machine. Whether to do that on the laptop is the operator's decision.
