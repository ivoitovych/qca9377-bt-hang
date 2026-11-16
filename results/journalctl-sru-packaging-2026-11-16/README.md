# Packaging the two journalctl fixes for an Ubuntu 24.04 stable update (2026-11-16)

**Nothing was sent, filed or posted.** The Launchpad bug number and the uploader's name and e-mail do not
exist yet, so they are literal placeholders: `NNNNNNN` for the bug, `<AUTHOR-NAME> <AUTHOR-EMAIL>` in the
changelog. Everything ran in containers (Ubuntu 24.04 images); nothing was installed on the host.

| what | where |
|---|---|
| packaging commit, as a mail | `<repo>/packaging/noble-lp-NNNNNNN/0001-d-p-lpNNNNNNN-cherry-pick-two-upstream-fixes-for-jou.patch` |
| the two DEP-3 quilt patches | `<repo>/packaging/noble-lp-NNNNNNN/debian-patches/` |
| debdiff 8.19 against our 8.20 (source) | `<repo>/packaging/noble-lp-NNNNNNN/debdiff-255.4-1ubuntu8.19-to-8.20.txt` |
| our source package description | `<repo>/packaging/noble-lp-NNNNNNN/systemd_255.4-1ubuntu8.20.dsc` |
| the branch and its commit | `lp-NNNNNNN-journalctl-many-files-noble`, `90a78feea721d7811dbad7cf04e2c7453aff3a1c`, in the packaging clone `<work dir>/pkg/packaging` (a clone of the Launchpad repository; the commit is also the mail above) |

## 1. 8.19 against our patches

Commands (container `co46-build:1`, `scripts/inside-pkg-fetch.sh`, `scripts/inside-pkg-compare.sh`; full
output `data/8.19-against-8.18-and-apply-check.txt`):

```console
$ apt-get source --download-only systemd=255.4-1ubuntu8.18   # and =255.4-1ubuntu8.19, with noble-proposed enabled
$ dpkg-source -x --no-check systemd_255.4-1ubuntu8.19.dsc s
$ diff -u x818/s/debian/patches/series x819/s/debian/patches/series
```

- **8.19 is in noble-proposed** (`apt-cache showsrc systemd` lists 255.4-1ubuntu8, 8.18, 8.19). A fresh
  container without -proposed installs 8.18, so 8.19 has not reached -updates as of this check.
- **What 8.19 adds** (12 patches, changelog dated 15 Oct 2026):
  - `lp2145709-resolved-dont-treat-conn-reset-as-packet-loss.patch` (resolved, LP: #2145709);
  - `lp2167098-preserve-ipv4-route-mtu.patch` (networkd, LP: #2167098);
  - two `lp2085314-*` patches (networkd tclass qdisc crash, LP: #2085314);
  - **eight `lp2088163-*` patches: "Fix user journal corruption on rotate when using btrfs"** (LP: #2088163).
- **Which touch the journal sources.** Searching all patches of 8.18 and 8.19 for
  `sd-journal/(journal-file.c|journal-file.h|sd-journal.c|journal-internal.h)`: none in 8.18; in 8.19 only
  `lp2088163-sd-journal-use-stat_verify_linked.patch`, which changes `journal_file_fstat()` in
  `journal-file.c` (the `st_nlink <= 0` check becomes `stat_verify_linked()`). The other seven of that bug touch
  `src/shared/` (`journal-file-util.c`, `copy.c`), `src/basic/` and tests. None touches `journal-file.h` or
  `sd-journal.c`.
- **Do 0001 and 0002 still apply to 8.19?** Yes, without fuzz and without a reject, applied one after the other
  on the tree with all of 8.19's patches in place:

```
== x819: 0001 then 0002, GNU patch
patching file src/libsystemd/sd-journal/journal-file.c
Hunk #1 succeeded at 2249 (offset 5 lines).
patching file src/libsystemd/sd-journal/journal-file.h
patching file src/libsystemd/sd-journal/sd-journal.c
Hunk #1 succeeded at 2405 (offset -23 lines).  ... Hunks #2 to #5 likewise
patching file src/libsystemd/sd-journal/sd-journal.c
Hunk #2 succeeded at 2472 (offset -23 lines).
Hunk #3 succeeded at 2497 (offset -23 lines).
== x819: git apply, 0001 applied then 0002
x819 0001 applies (git apply, strict)
x819 0002 applies after 0001 (git apply, strict)
```

  The only difference from 8.18 is one more line of offset in `journal-file.c` (4 on 8.18, 5 on 8.19), from
  `lp2088163`'s three-line change above it. Offsets, not fuzz. (They are offsets because the patches were made
  against upstream v255.4 and Ubuntu's patch stack shifts the lines.)

## 2. The packaging git

```console
$ git clone --branch ubuntu-noble https://git.launchpad.net/~ubuntu-core-dev/ubuntu/+source/systemd pkg/packaging
$ git -C pkg/packaging log -1 --format='%H %cd %s'
e9f476fd65e92a37b460cbb0af458f562a3e0ce2 Thu Oct 15 11:58:33 2026 -0400 Release systemd 255.4-1ubuntu8.19
```

- **The head of `ubuntu-noble` is the 8.19 release commit**, so it equals 8.19 (not newer). Its tags include
  `ubuntu/255.4-1ubuntu8.18`; there is no 8.19 tag yet.
- **Our branch:** `lp-NNNNNNN-journalctl-many-files-noble`, one commit on top,
  `caf74770891561d1e264ab2937a9a91562181c28` (revised on 2026-11-16: headers in the house style and a changelog
  entry matched to 8.19's; the first version was `90a78feea721d7811dbad7cf04e2c7453aff3a1c`). Its debdiff
  against 8.19: changelog +11, the two patches +106 and +54, series +2; 173 insertions, no deletions.
- **Series position:** at the end (97 patches before ours, 99 with them). The series starts with Ubuntu/Debian delta patches
  (`debian/...`), and later fixes are simply appended, mostly as `lp<bug>-*` files in the order they were added
  (the last entries are 8.19's `lp2088163-*`). I saw no separate section for upstream backports, so the two
  patches follow `lp2088163-test-add-test-cases-for-journal-corruption-on-btrfs.patch`.
- **Patch headers, in the house style** of 8.19's own cherry-picks (for example
  `lp2088163-sd-journal-use-stat_verify_linked.patch`): `From`/`Date`/`Subject`, `Origin: upstream,
  https://github.com/systemd/systemd/commit/<full hash>`, `Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN`,
  a blank line, the upstream message unchanged, `(cherry picked from commit <hash>)`, `---`. I surveyed the
  57 patches that are not ours: **`Applied-Upstream:` is used by none, so it is gone; the `Description:` paragraph
  is gone. `Bug:` (the GitHub issue) is used by 3 patches, one of them 8.19's own
  (`lp2145709-resolved-dont-treat-conn-reset-as-packet-loss.patch`: `Bug: https://github.com/systemd/systemd/issues/33719`),
  so by your rule I kept it**, between `Origin` and `Bug-Ubuntu` as that patch has it. The first patch's header:

```
From: Yu Watanabe <watanabe.yu+github@gmail.com>
Date: Wed, 3 Jan 2024 04:27:59 +0900
Subject: sd-journal: cache last entry offset and journal file state
Origin: upstream, https://github.com/systemd/systemd/commit/99e6f682d3627c2c06d99bb3c3756e448e8d9bd1
Bug: https://github.com/systemd/systemd/issues/31486
Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN

When the offset of the last entry object (or last object for journal
files generated by an old journald) is not changed, the timestamps
should be updated by journal_file_read_tail_timestamp() are unchanged.
So, we can drop to call fstat() in the function.

As, the journal header is always mapped, so we can read the offset and
journal file state without calling fstat.
Still, when the last entry offset is changed, we may need to call fstat()
to read the entry object. But, hopefully the number of fstat() call
can be reduced.

(cherry picked from commit 99e6f682d3627c2c06d99bb3c3756e448e8d9bd1)
---
```

  The second has `Date: Wed, 3 Jan 2024 04:28:03 +0900`, the subject `sd-journal: make
  journal_file_read_tail_timestamp() notify to the caller that some new journal entries added`, the hash
  `51b2bcf8356b847e7ab778adfad930691713c7ef`, and the body `Tiny optimization for
  journal_file_find_newest_for_boot_id().` `v256` is the first release containing each (checked with
  `git tag --contains` in an upstream clone). The house patches that are `git format-patch`-style also carry a
  diffstat after `---`; I did not add one. **The code hunks are byte-identical to the first version**
  (`data/code-hunks-identical-check.txt`, with the diff of the headers), so no rebuild was needed.
- **Changelog entry**, matched to 8.19's (a short title with the bug on the same line, `- d/p/<file>:` and an
  indented description ending in a full stop; two files in the `file,` / `file:` form 8.19 uses for #2085314):

```
systemd (255.4-1ubuntu8.20) UNRELEASED; urgency=medium

  * Fix journalctl being very slow on journals with many files (LP: #NNNNNNN)
    - d/p/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch,
      d/p/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch:
      Cherry-pick upstream commits 99e6f682d3 and 51b2bcf835 (v256): stop
      sd-journal from calling fstat() on every open journal file for every
      entry it returns.

 -- <AUTHOR-NAME> <AUTHOR-EMAIL>  Mon, 16 Nov 2026 09:00:00 +0000
```

  8.19's and 8.18's entries are at most 78 columns wide. Ours is 77 on the bullet line and 78 or less in the
  description, **except the two `d/p/` file lines (84 and 96 columns), because a file name cannot be wrapped**;
  8.19 avoids it by naming shorter files. I kept the names as asked; shorter ones would fit.

## 3. The build, as the archive would (`scripts/inside-pkg-build.sh`, `inside-pkg-build2.sh`)

Container `co46-build:1` (Ubuntu 24.04 with the build dependencies, `apt-get build-dep`), amd64,
`DEB_BUILD_OPTIONS=parallel=4`, `nice -n 19 ionice -c 3 dpkg-buildpackage -b -uc -us`.

| step | result |
|---|---|
| `dpkg-source -b` of the branch | clean: applies all patches, builds `systemd_255.4-1ubuntu8.20.dsc` and `.debian.tar.xz` (output in the first lines of the task log; `.dsc` kept) |
| full build with the tests (`-b -uc -us`) | **exit 2 after 471 s**: compiled and installed fine, then `override_dh_auto_test` failed on 2 tests |
| the same, unpatched 8.19 | **exit 2 after 470 s**, the same 2 failures (`data/build-baseline819-summary.txt`) |
| build with `nocheck` | **exit 0 after 562 s**, 28 debs plus the `-dbgsym` ddebs (the source of the test below) |

- **Test result** (meson, 1 256 tests; `data/build-summary.txt` for ours, `data/build-baseline819-summary.txt`
  for unpatched 8.19; the counts are identical): **1 229 OK, 2 FAIL, 25 SKIP, 0 timeout.**
  - **FAIL:** `test-fd-util` and `test-capability`, both `killed by signal 6 SIGABRT`. They fail the same way
    on unpatched 8.19, so they are a property of this container (most likely Docker's reduced capabilities or limits; I did not
    investigate which), not of the patches.
  - **SKIP (exit status 77):** 25 tests that need a real system: `test-bpf-*`, `test-cgroup-*`, `test-execute`,
    `test-namespace`, `test-bus-*`, `test-sd-device-monitor`, `test-udev`, `test-tpm2`, `test-ukify`, and so on.
  - **The journal tests all pass** (`data/build-journal-tests.txt`): `test-journal`, `test-journal-interleaving`,
    `test-journal-enum`, `test-journal-flush`, `test-journal-init`, `test-journal-match`, `test-journal-stream`,
    `test-journal-file`, `test-journal-verify`, `test-journal-send`, `test-journal-importer`,
    `test-mmap-cache`, `check-help-journalctl`, and the `fuzz-journal*` sample runs.
- **Because the container fails those two tests, the debs came from the `nocheck` rebuild of the same branch.**
  I did not hide this: the build with the tests did not finish cleanly here, for a reason that is also true of
  the unpatched source. It does mean the full test run was not green in this environment, for either tree.

## 4. Testing the built package (`test/inside-pkgtest.sh`, `inside-pkgtest-user.sh`; output `test/pkgtest-output.txt`)

A fresh `ubuntu:24.04` container; the archive's `systemd` and `systemd-journal-remote` are installed first
(8.18, plus resolved and timesyncd, which come with it), then **upgraded to the built debs with `apt-get install
<debs>`**; the unprivileged part runs as `tester`.

- **Installation.** `apt-get install` of the 8 built debs of the installed source packages
  (`libsystemd-shared`, `libsystemd0`, `libudev1`, `systemd`, `systemd-dev`, `systemd-journal-remote`,
  `systemd-resolved`, `systemd-timesyncd`) over 8.18: **exit status 0**, `dpkg --audit` clean,
  `journalctl --version` reports `255.4-1ubuntu8.20`. (The other debs of the build were not installed;
  `systemd-standalone-sysusers/-tmpfiles` conflict with `systemd`'s own by design.)
- **The reproducer, as `tester`, against `/usr/bin/journalctl`** (the patched one):

```
     K      lines    seconds      lines/s       us/entry
    25      25004       0.13       189958            5.3
    50      50009       0.39       128788            7.8
   100     100000       1.34        74597           13.4
   200     100000       3.59        27878           35.9
   400     100000       8.65        11567           86.5
exponent b of (time to read everything) ~ K^b, K >= 50: 2.19   (2 = quadratic, 1 = linear)
```

  The stock 8.18 figures for the same script are in `../journalctl-file-scaling-host-2026-11-16/reproducer/test/output.txt`
  (8 564 lines/s at 25 files, 264 at 400; exponent 2.30).
- **`journalctl --verify` on the reproducer's files, patched binary:** `verified 400 files, 0 failed`
  (one `--file=` run each); `--directory=` form on 10 of them: three `PASS:` lines shown, exit status 0; the
  stock 8.18 binary on the same 10 files: the same, exit status 0.
- **Byte-identical output.** Four sets written by the installed `systemd-journal-remote` into the user's
  `/tmp` (`test/make-sets.py`): `plain` (60 files, 12 boots), `interleaved` (60 files, 12 boots with overlapping
  time windows and copied stretches), **`twomachines` (40 files, two machine IDs, each with four boots, time
  ranges overlapping, the second machine's clock 7 s ahead)** and the first 25 of the reproducer's files. For
  each, 14 query kinds in export format (every field and the cursor): forward, reverse, `-n 500`, `-k`, one boot
  by match, `-b -3`, `--since/--until`, `-r --since`, `-r -n 3000`, `--lines=+3000`, and four cursor seeks
  (`--cursor`, `--after-cursor`, forward and reverse). **Stock 8.18 is the reference; stock 8.19 and the patched
  build were each compared by SHA-256: 112 comparisons, all `same`, no empty result** (the stock 8.19 binary
  is the unpacked archive deb, run without being installed).
- **A file still being written** (`test/live-test.py`): 20 archived files plus one live file written through
  `systemd-journal-remote`'s stdin in three batches with pauses (the file stays ONLINE; its entries fall in the
  time range of the archived ones), with `journalctl -f -o export -n all` of 8.18, 8.19 and the patched build
  reading the directory while it grows; then a plain read of the final directory:

```
follow read #0 stock 8.18:  21643 entries, sha256 1a5a03f173cc0e03
follow read #1 stock 8.19:  21643 entries, sha256 1a5a03f173cc0e03
follow read #2 patched:     21643 entries, sha256 1a5a03f173cc0e03     follow reads identical: True
final read, all three:      24500 entries, sha256 61e3e0e5eaa8b22b     final reads identical: True
```

  (A follow reader prints only what comes after its position, so it does not print live entries that are older
  than the position it has reached: 21 643 of the 24 500, the same for all three.)
- **Safety:** path, type, size and mtime of everything under `/var/log`, `/run/log` and `/etc/systemd` before and
  after the unprivileged part: `identical (52 entries)`.

## 5. The debdiff and the format-patch

```console
$ debdiff systemd_255.4-1ubuntu8.19.dsc systemd_255.4-1ubuntu8.20.dsc > debdiff-255.4-1ubuntu8.19-to-8.20.txt
$ git -C pkg/packaging format-patch -1 HEAD -o <repo>/packaging/noble-lp-NNNNNNN
```

The debdiff file is now the diff only (195 lines): 4 files changed in `debian/`, 173 insertions, no deletions
(the changelog entry, the two patches, the series). What `debdiff` writes to standard error is kept apart in
`debdiff-255.4-1ubuntu8.19-to-8.20.stderr.txt`: the `gpgv` lines ("Can't check signature: No public key"), two
`dpkg-source` warnings (cannot verify the inline signature of the 8.19 `.dsc`; extracting an unsigned source package)
and `diff: .../test/testdata: recursive directory loop`. The first version of the file had those lines mixed in.
Checks after the revision (`data/header-and-changelog-update-checks.txt`): `dpkg-source -b` exits 0 and builds
the `.dsc`; `quilt push -a` on a fresh 8.19 tree (pristine orig tarball plus 8.19's `debian/`, then our patches,
series and changelog) applies 99 of 99, exit 0, no fuzz, no reject, offsets only (`journal-file.c` +5,
`sd-journal.c` -23).

## 6. Precedent and policy

- **Policy text** (<https://documentation.ubuntu.com/project/SRU/reference/requirements/>, which redirects to
  <https://ubuntu.com/project/docs/SRU/reference/requirements/>; the overview is
  <https://documentation.ubuntu.com/project/SRU/stable-release-updates>; the old
  `https://wiki.ubuntu.com/StableReleaseUpdates` is an empty page now). Section "What is acceptable to SRU":
  - "Stable release updates will, in general, only be issued in order to fix high-impact bugs." The examples are
    severe regressions ("packages which are totally unusable"), loss of user data, and adjusting to changes in
    the environment.
  - Under "Other safe cases": "Bugs which do not fit under above categories, but (1) have an obviously safe patch
    and (2) affect an application rather than critical infrastructure packages (like X.org or the kernel)."
  - "Any fix or feature addition being made to one release must first be made to all future releases to prevent
    users regressing when they upgrade."
  - **Performance is not mentioned.** The word occurs on those pages only in "High-Performance Computing team".
  - Two consequences: a pure speed-up is not one of the listed categories; and `systemd` is plausibly "critical
    infrastructure", which would exclude condition (2) of the "safe cases". The case has to be made as a
    high-impact bug (the 2026-11-14 incident: a read that took 7 h 44 min on a 553-file journal, 478 `fstat()`
    calls per printed line) rather than as an optimisation. That is the SRU team's call, not mine.
- **Precedent, 249.11-0ubuntu3.x (jammy):** I read `changelog` of 249.11-0ubuntu3.12 (the 12 SRU entries 3.1 to
  3.12, lines 1 to 251 of the file) and searched for `perform|slow|speed|fast|optimi|latency|cpu|memory|hang|
  delay|excessive|reduce|spin|busy loop`. The hits in that range are all unrelated (an nvme symlink fix, a coredump
  information leak, a swap/memory-pressure note). **No performance fix.**
- **Precedent, 255.4-1ubuntu8.x (noble), through 8.19:** the same search finds only 8.19's "Avoid resolved TCP
  reset busy loops (LP: #2145709)": a CPU-burning loop, but a malfunction (resolved spinning on a reset
  connection), not a speed-up. **I found no noble or jammy systemd SRU that was a pure performance fix.** The
  closest journal-related SRU is 8.19's LP: #2088163 (journal corruption on btrfs; data loss, a different category).
  Limits of this search: keyword matches on changelog text only; a performance fix described in other words
  would be missed; the jammy changelog I fetched is that of 3.12 (the newest I could download), so anything later is not covered.
  Changelog files: `data/` has the search output; the noble changelog is in the 8.19 source package.

## 7. What could not be done, and why

- **The Launchpad bug and the maintainer identity** do not exist: placeholders, as asked. The Bug-Ubuntu
  URL, the patch file names and the branch name carry `NNNNNNN`; the patch file names should become
  `lp<number>-...` once the bug exists (a `git mv` and a sed in the changelog and the series).
- **The full build with the tests did not pass in the container** (2 failures that are identical on unpatched
  8.19); the debs come from a `nocheck` rebuild. No build on the archive's builders, no other architecture, no sbuild
  or PPA build, and the upstream autopkgtests (the qemu integration tests) were not run.
- **8.19 is in -proposed, not -updates**, as far as the container could see: an upload made now would sit on top
  of an unreleased 8.19, which the SRU team may want sequenced; I did not check the bugs of 8.19.
- **The journald path** (`systemd-cat` into a running journald) was not used: the container has no systemd as PID 1.
  The live-file test used `systemd-journal-remote` instead, as the brief allowed.
- **The packaging clone lives in the scratch area**, not in this repository; the commit is preserved as the
  format-patch above (it applies to `ubuntu-noble` at `e9f476fd65`).

## Files

| file | what |
|---|---|
| `data/8.19-against-8.18-and-apply-check.txt` | series and changelog differences, journal-touching patches, the apply check |
| `data/build-*.txt` | test summaries of the three builds; the journal tests; the tail of the build |
| `data/sru.txt`, `data/req.txt` | the policy pages as fetched, as text |
| `test/` | the container test: scripts, sets, live test, and `pkgtest-output.txt` |
| `scripts/` | fetch, compare, build, debdiff, packaging commit, precedent search |
