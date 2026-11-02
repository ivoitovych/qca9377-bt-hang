# CO-11a: dca0f10fd560 for tenacious, stonking and resolute - results, 2026-11-02

Every claim is marked: (measured) = a command ran and its output is in this file or in the named log;
(from source) = read from a file; (inferred) = reasoning from those. Nothing was filed or sent.
All builds and runs happened in containers (docker); nothing was installed on the host and nothing
touched the host's Bluetooth. Work area: `/root/exp/agent-work/co11a-ready-20261102/`.

## 1. What was done

For each of resolute (26.04), stonking (26.10) and tenacious (27.04): current bluez source found on
Launchpad (read only), downloaded into its own fresh directory, checked for the change of
`dca0f10fd560`, patched with it as a DEP-3 debian patch, built with `dpkg-buildpackage -b -uc -us`
next to an unpatched build of the same source, and both btmon binaries run through the width matrix.

## 2. Sources found (measured; `scripts/lpquery.py`, answers in `lp/<series>.json`)

Query: `https://api.launchpad.net/1.0/ubuntu/+archive/primary?ws.op=getPublishedSources&source_name=bluez&exact_match=true&distro_series=https://api.launchpad.net/1.0/ubuntu/<series>&status=Published&order_by_date=true`

| series | newest published | pocket | published | also published |
|---|---|---|---|---|
| tenacious (27.04, development) | 5.87-5 | Proposed | 2026-10-31 | 5.87-4 (Release, 2026-10-15) |
| stonking (26.10) | 5.87-4 | Release | 2026-10-02 | - |
| resolute (26.04 LTS) | 5.85-4ubuntu0.4 | Updates (and Security, 2026-10-13) | 2026-10-21 | 5.85-4 (Release, 2026-03-24) |
| noble (24.04) | 5.72-0ubuntu5.8 | Updates / Security | 2026-10-21 | (not rebuilt here; existing debdiff copied unchanged) |

For tenacious the base is 5.87-5 from -proposed (the newest source); the Release pocket still holds
5.87-4 and has the same packet.c. Downloads: `scripts/download.sh`, files in `src/<series>/`
(`https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/bluez/<version>/<file>`):

```
tenacious  005ae52ff09c0c50d196cc07f0e3e24b7d77bf2ba11e498788b26ae77596d00b  bluez_5.87-5.debian.tar.xz
tenacious  9d3f9f33f3b56694e50963cde43f37b55d5a32e5768845da4641540f850b2295  bluez_5.87-5.dsc
tenacious  8e086b38e7d269781fa78fb702fe2f38bd366d107cdc4debc1674ae9381988e4  bluez_5.87.orig.tar.gz
stonking   3510b2b38503a6ae0c88a4ac7adcdfe74b6460d275d4018302b35c164fddbfec  bluez_5.87-4.debian.tar.xz
stonking   53f780a1b7711ca0e6577e2e28e4a7210987b0661e80e45327a4f84758d417e7  bluez_5.87-4.dsc
stonking   8e086b38e7d269781fa78fb702fe2f38bd366d107cdc4debc1674ae9381988e4  bluez_5.87.orig.tar.gz
resolute   a0afe2b92434a5b29147c7dbd2b9508d97a5f2fa4d9a0a98fb063f849ca45509  bluez_5.85-4ubuntu0.4.debian.tar.xz
resolute   14feca64813b6b3229120e8b5e012b44b6e1537b844c3296baaa86353dd47caa  bluez_5.85-4ubuntu0.4.dsc
resolute   7516f167f6aaabff9a48eac1515638fd349ecb884d254b558481b02520e7abe8  bluez_5.85.orig.tar.gz
```

(The first download attempt saved empty files because the Launchpad file URLs answer 303 and `curl`
had no `-L`; those were removed and fetched again with `-L`. The hashes above are of the second fetch.)
Sources were extracted only inside containers (`dpkg-source -x --no-check`; the container has no
Canonical keyring, so signatures were not checked).

## 3. Is the change of dca0f10fd560 already present? (measured; `logs/prep-<series>.log`)

No, in all three. In each extracted tree (all debian patches applied), `grep -n 'sizeof(line) - pos - 1' monitor/packet.c`
finds nothing (exit 1), and no debian patch touches monitor/packet.c's print_packet (the only patch
naming `monitor/` is `all-Fix-typo-in-AVRCP_ATTRIBUTE_ILEGAL.patch`, stonking and tenacious, an AVRCP typo).
`fdbfe0018f6f` is present in all three: `if (max_len <= 0) { extra = NULL; max_len = col - len - ts_len - 3; }`
before the `snprintf` (resolute packet.c:551-553, stonking/tenacious packet.c:601-603). (measured)

## 4. The patch (from source)

`patch/monitor-clamp-max_len-in-print_packet.patch`, made by `scripts/mkpatch.py` from the
upstream commit: DEP-3 header (Description, `Author: Chad Spensky`, Origin = the commit URL,
Bug = https://github.com/bluez/bluez/issues/1104, `Bug-Ubuntu: ...bug/XXXXXX` placeholder,
Forwarded: not-needed, Last-Update: 2026-11-02) followed by the diff of `dca0f10fd560` unchanged.
`scripts/verify-patch.py` (measured): the diff part is byte-identical to
`git -C cache/bluez-upstream diff dca0f10fd560^ dca0f10fd560 -- monitor/packet.c`
(sha256 050e04300bba11b6007b1d3c9f233a8f44ef83e302f6bf16ac6597bad49a382f, 1137 bytes).
No e-mail address in any new file; the changelog trailer carries `<AUTHOR-EMAIL>`.
(An earlier set of builds used a copy of this patch whose blank context lines had lost their leading
space; those builds and debdiffs were discarded and everything was rebuilt from the byte-identical file.)

Changelog entries (version style per release):

| series | new version | style |
|---|---|---|
| tenacious | 5.87-5ubuntu1 | development release, Debian-synced base 5.87-5 gets an Ubuntu delta |
| stonking | 5.87-4ubuntu0.1 | stable release, unmodified Debian base 5.87-4 gets `ubuntu0.1` |
| resolute | 5.85-4ubuntu0.5 | continues the existing `ubuntu0.N` series |

Ordering check (inferred, `dpkg --compare-versions` not run): 5.85-4ubuntu0.5 < 5.87-4ubuntu0.1 < 5.87-5ubuntu1,
so the upgrade path between series is monotone.
Entry text (the same in the three; noble's wording mirrored): "btmon: fix abort (buffer overflow detected)
in print_packet() when the computed line width is negative or larger than the line buffer (LP: #XXXXXX)"
plus the patch line. Distribution field = the series name (as noble's 5.72-0ubuntu5.9 `noble`).

## 5. Builds (measured; `scripts/inner-prep.sh`, `scripts/inner-build.sh`, `scripts/run-build.sh`, logs in `logs/` and `build/<series>/`)

| series | container | toolchain | stock build | patched build | patch applies |
|---|---|---|---|---|---|
| resolute | `ubuntu:26.04` (26.04.1 LTS, digest sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c) | gcc 15.2.0-16ubuntu1, binutils 2.46-3ubuntu2, debhelper 13.31ubuntu1, dpkg-dev 1.23.7ubuntu1, libc6 2.43-2ubuntu2.4 | exit 0 | exit 0 | `Hunk #1 succeeded at 553 (offset -52 lines)`, no fuzz |
| stonking | `ubuntu:26.10` (digest sha256:262df65c0ec6bf8d9dcc87454f4330a05fae4b97825f45854af3b136666584c2) | gcc 15.3.0-4ubuntu1, binutils 2.47-6ubuntu1, debhelper 14.5ubuntu1, dpkg-dev 1.23.7ubuntu2, libc6 2.44-1ubuntu2 | exit 0 | exit 0 | `Hunk #1 succeeded at 603 (offset -2 lines)`, no fuzz |
| tenacious | `ubuntu:26.10` image moved to tenacious (`sed` on `ubuntu.sources`, `apt-get dist-upgrade`; Docker Hub has no `ubuntu:27.04`: "manifest unknown"); zlib1g stepped down from the stonking-updates 1:1.3.dfsg+really1.3.2-3ubuntu1.1 to tenacious's ...-3ubuntu1 to satisfy build-deps | gcc 15.3.0-4ubuntu1, binutils 2.47-6ubuntu1, debhelper 14.5ubuntu1, dpkg-dev 1.23.7ubuntu2, libc6 2.44-1ubuntu2 | exit 0 | exit 0 | `Hunk #1 succeeded at 603 (offset -2 lines)`, no fuzz |

- Both trees of a series were built with `DEB_BUILD_OPTIONS=parallel=3`; `dh_auto_test` is disabled in debian/rules of all three
  (`override_dh_auto_test: # disable`), so no unit tests ran (from source: debian/rules in `logs/prep-<series>.log`).
- `dpkg-buildpackage` rejects the placeholder `<AUTHOR-EMAIL>` ("cannot parse maintainer email address"). The debdiff
  was therefore taken before the build, and only the build tree's changelog trailer was changed to
  a dummy address at the reserved `example.invalid` domain. The binaries do not depend on it. (measured: first attempt failed with that error.)
- `-D_FORTIFY_SOURCE=3` is on the compile lines of both builds in every series (measured: grep of `build/<series>/build-patched.log`);
  each btmon imports one `__snprintf_chk` (measured: `nm -D | grep -c __snprintf_chk` = 1 for stock and patched, all series).
- Same container, same source, only the patch differs between "stock" and "patched" (the stock build is the unmodified
  source package, not the archive binary; the archive binary was not compared here - for noble that comparison
  gave 0 differences on 132 cells in the 2026-11-02 live work).
- Debdiffs: `debdiff <old>.dsc <new>.dsc` inside the container, stdout saved; each is 3 files: changelog, the new patch, series.

btmon binaries (kept in `bin/<series>/`):

```
resolute   4faae01e2baff26e083f3770caa37df732a7e7ea1c5631b4e8bb591e2ffc21ab  btmon-stock
resolute   1c2e4db4a71ab7517e30f39b59b28ec50aae774b5895a80eb6ff46a4da6b5ae1  btmon-patched
stonking   210fb54baccb5765bbf4c22658cdb476d8b2c51c9759710496dd6b832bec9b64  btmon-stock
stonking   3c3a7aea5e5b0d30ee228142f24565202173b1c1189871f9e45b02fe02ac1012  btmon-patched
tenacious  e8c61aa761730bdd9957e7e07a6b903e063cd0111aef7b9d6e02d3585f3b3a76  btmon-stock
tenacious  325ed7794cca172fb78ac783ebe4dd984c5c067c56aee78f714d05f6e374d9c6  btmon-patched
```

Built packages (bluez_*.deb, .changes, .buildinfo) are in `build/<series>/`; the other binary packages and all build trees were removed after the run.

## 6. Width matrix (measured; `scripts/replay2.py`, results in `results/<series>/results.tsv`, raw outputs in `results/<series>/raw/`)

Command for each cell, run inside the same container that built the binaries (no terminal, stdout and stderr to files):

```
TZ=UTC /w/bin/<series>/btmon-<stock|patched> [-t | -T] [--columns=<W>] -r /w/final/<lines|priv-open>.btsnoop
```

Captures: `lines.btsnoop` and `priv-open.btsnoop` in `final/`, written by `final/mkcap.py`
(`python3 -I mkcap.py <dir>`; the files in `final/` are byte-identical to the ones used on 2026-11-02 in
`co11a-live-20261102/caps/`, checked with `cmp`). Widths 10, 60, 80, 3000 and "piped" (no `--columns`, stdout a file).
Option sets: none, `-t`, `-T`. Per series: 2 captures x 3 option sets x 5 widths x 2 variants = 60 runs; 180 runs in all.
Exit code 134 = `*** buffer overflow detected ***: terminated` (SIGABRT).

Replay of a file has no `comm[pid]` prefix, so this matrix cannot show the live-socket case; that was measured
for noble on 2026-11-02 (CO-11 log.md) and is not repeated here for the newer series (not measured).

Summary (identical in resolute, stonking and tenacious):
- stock: exit 134 at width 10 and at width 3000 in all 12 such cells per series (2 captures x 3 option sets x 2 widths);
  exit 0 at 60, 80 and piped.
- patched: exit 0 in all 30 cells per series, 0 aborts in 90 patched runs.
- Where both exit 0 (18 cells per series): 16 are byte-identical; 2 differ (`lines.btsnoop`, 60 columns, one line each), the same
  two in all three series (diff in section 7): with `-t` the stock line `@ MGMT Open.. version 1.22  {0x0002}` is
  `@ MGMT Open:  version 1.22  {0x0002}` in the patched build; with `-T` the stock `@ MGMT Comma..   {0x0002}` is
  `@ MGMT Command   {0x0002}`. (inferred from source: when `max_len` is small and `n > max_len`, the stock code writes the
  dots at `line[pos + max_len - 1]` and `line[pos + max_len - 2]`, which for `max_len` of 0 or less lie before `pos`, over the end of the label
  already written; the patch writes them only when `max_len >= 3`.)

## 7. Tables and differences (generated by `scripts/summarize2.py` and `scripts/gen-results.py`)

### tenacious (/root/exp/agent-work/co11a-ready-20261102/results/tenacious/results.tsv, 60 runs)
| capture | btmon opts | width | stock exit | patched exit | stdout stock | stdout patched | byte-identical |
|---|---|---|---|---|---|---|---|
| lines | - | 10 | 134 | 0 | 0 B | 2056 B | - |
| lines | - | 60 | 0 | 0 | 2243 B | 2243 B | yes |
| lines | - | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | - | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | - | piped | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -t | 10 | 134 | 0 | 0 B | 2105 B | - |
| lines | -t | 60 | 0 | 0 | 2243 B | 2243 B | NO |
| lines | -t | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -t | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | -t | piped | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -T | 10 | 134 | 0 | 0 B | 2182 B | - |
| lines | -T | 60 | 0 | 0 | 2243 B | 2243 B | NO |
| lines | -T | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -T | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | -T | piped | 0 | 0 | 2383 B | 2383 B | yes |
| priv-open | - | 10 | 134 | 0 | 0 B | 92 B | - |
| priv-open | - | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | - | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | - | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | - | piped | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -t | 10 | 134 | 0 | 0 B | 106 B | - |
| priv-open | -t | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | -t | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -t | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | -t | piped | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -T | 10 | 134 | 0 | 0 B | 128 B | - |
| priv-open | -T | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | -T | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -T | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | -T | piped | 0 | 0 | 187 B | 187 B | yes |

cells: 30; stock aborts (exit 134): 12; patched non-zero exits: 0; both exit 0: 16 identical, 2 different
stock aborting cells by width: 10, 3000
stderr first lines of non-zero exits: *** buffer overflow detected ***: terminated

Cells where both exit 0 but the output differs (tenacious):

```
# lines, options -t, width 60
--- stock
+++ patched
@@ -3 +3 @@
-@ MGMT Open.. version 1.22  {0x0002} [hci0] 23:04:57.000300
+@ MGMT Open:  version 1.22  {0x0002} [hci0] 23:04:57.000300
```

```
# lines, options -T, width 60
--- stock
+++ patched
@@ -4 +4 @@
-@ MGMT Comma..   {0x0002} [hci0] 2026-10-16 23:04:57.000400
+@ MGMT Command   {0x0002} [hci0] 2026-10-16 23:04:57.000400
```

### stonking (/root/exp/agent-work/co11a-ready-20261102/results/stonking/results.tsv, 60 runs)
| capture | btmon opts | width | stock exit | patched exit | stdout stock | stdout patched | byte-identical |
|---|---|---|---|---|---|---|---|
| lines | - | 10 | 134 | 0 | 0 B | 2056 B | - |
| lines | - | 60 | 0 | 0 | 2243 B | 2243 B | yes |
| lines | - | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | - | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | - | piped | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -t | 10 | 134 | 0 | 0 B | 2105 B | - |
| lines | -t | 60 | 0 | 0 | 2243 B | 2243 B | NO |
| lines | -t | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -t | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | -t | piped | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -T | 10 | 134 | 0 | 0 B | 2182 B | - |
| lines | -T | 60 | 0 | 0 | 2243 B | 2243 B | NO |
| lines | -T | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -T | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | -T | piped | 0 | 0 | 2383 B | 2383 B | yes |
| priv-open | - | 10 | 134 | 0 | 0 B | 92 B | - |
| priv-open | - | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | - | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | - | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | - | piped | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -t | 10 | 134 | 0 | 0 B | 106 B | - |
| priv-open | -t | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | -t | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -t | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | -t | piped | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -T | 10 | 134 | 0 | 0 B | 128 B | - |
| priv-open | -T | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | -T | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -T | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | -T | piped | 0 | 0 | 187 B | 187 B | yes |

cells: 30; stock aborts (exit 134): 12; patched non-zero exits: 0; both exit 0: 16 identical, 2 different
stock aborting cells by width: 10, 3000
stderr first lines of non-zero exits: *** buffer overflow detected ***: terminated

Cells where both exit 0 but the output differs (stonking):

```
# lines, options -t, width 60
--- stock
+++ patched
@@ -3 +3 @@
-@ MGMT Open.. version 1.22  {0x0002} [hci0] 23:04:57.000300
+@ MGMT Open:  version 1.22  {0x0002} [hci0] 23:04:57.000300
```

```
# lines, options -T, width 60
--- stock
+++ patched
@@ -4 +4 @@
-@ MGMT Comma..   {0x0002} [hci0] 2026-10-16 23:04:57.000400
+@ MGMT Command   {0x0002} [hci0] 2026-10-16 23:04:57.000400
```

### resolute (/root/exp/agent-work/co11a-ready-20261102/results/resolute/results.tsv, 60 runs)
| capture | btmon opts | width | stock exit | patched exit | stdout stock | stdout patched | byte-identical |
|---|---|---|---|---|---|---|---|
| lines | - | 10 | 134 | 0 | 0 B | 2056 B | - |
| lines | - | 60 | 0 | 0 | 2243 B | 2243 B | yes |
| lines | - | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | - | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | - | piped | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -t | 10 | 134 | 0 | 0 B | 2105 B | - |
| lines | -t | 60 | 0 | 0 | 2243 B | 2243 B | NO |
| lines | -t | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -t | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | -t | piped | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -T | 10 | 134 | 0 | 0 B | 2182 B | - |
| lines | -T | 60 | 0 | 0 | 2243 B | 2243 B | NO |
| lines | -T | 80 | 0 | 0 | 2383 B | 2383 B | yes |
| lines | -T | 3000 | 134 | 0 | 0 B | 22823 B | - |
| lines | -T | piped | 0 | 0 | 2383 B | 2383 B | yes |
| priv-open | - | 10 | 134 | 0 | 0 B | 92 B | - |
| priv-open | - | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | - | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | - | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | - | piped | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -t | 10 | 134 | 0 | 0 B | 106 B | - |
| priv-open | -t | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | -t | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -t | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | -t | piped | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -T | 10 | 134 | 0 | 0 B | 128 B | - |
| priv-open | -T | 60 | 0 | 0 | 147 B | 147 B | yes |
| priv-open | -T | 80 | 0 | 0 | 187 B | 187 B | yes |
| priv-open | -T | 3000 | 134 | 0 | 0 B | 6027 B | - |
| priv-open | -T | piped | 0 | 0 | 187 B | 187 B | yes |

cells: 30; stock aborts (exit 134): 12; patched non-zero exits: 0; both exit 0: 16 identical, 2 different
stock aborting cells by width: 10, 3000
stderr first lines of non-zero exits: *** buffer overflow detected ***: terminated

Cells where both exit 0 but the output differs (resolute):

```
# lines, options -t, width 60
--- stock
+++ patched
@@ -3 +3 @@
-@ MGMT Open.. version 1.22  {0x0002} [hci0] 23:04:57.000300
+@ MGMT Open:  version 1.22  {0x0002} [hci0] 23:04:57.000300
```

```
# lines, options -T, width 60
--- stock
+++ patched
@@ -4 +4 @@
-@ MGMT Comma..   {0x0002} [hci0] 2026-10-16 23:04:57.000400
+@ MGMT Command   {0x0002} [hci0] 2026-10-16 23:04:57.000400
```

## 8. Files in final/

- `bluez_5.87-5_5.87-5ubuntu1.debdiff` (tenacious), `bluez_5.87-4_5.87-4ubuntu0.1.debdiff` (stonking),
  `bluez_5.85-4ubuntu0.4_5.85-4ubuntu0.5.debdiff` (resolute): new, made in section 5.
- `bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff` (noble): copy of the 2026-10-28 file, unchanged
  (it still carries the author's address in its Author/changelog lines, as written then; the three new ones carry none).
- `lp-report.md`: the edited copy of the Launchpad draft.
- `lines.btsnoop`, `priv-open.btsnoop`, `mkcap.py`: the two synthetic captures and their generator.
- `results-2026-11-02-ready.md` (this file), `SHA256SUMS`.

## 9. Not done / limits

- No live-socket (pty, `comm[pid]` prefix) runs on resolute, stonking or tenacious; only file replay.
  The live result is noble's (CO-11 log.md, 2026-11-02): first fix alone aborts 5 of 5 at 60 columns live, both fixes 0 aborts in 264 live runs.
- noble was not rebuilt; its debdiff and the 2026-10-28 results are as before.
- No 27.04 image exists on Docker Hub; tenacious is a stonking image upgraded to tenacious through apt (section 5).
- The `bluez_*.deb` files were built but not installed or run as packages; the matrix ran the `btmon` taken from `debian/tmp/usr/bin/` of each build tree.
- `dh_auto_test` is disabled in all three packages, so no unit tests ran.
- tenacious base 5.87-5 is in -proposed at the time of the query; if it is superseded before upload, the debdiff needs a rebase (the patch itself applied with offset -2 on 5.87).
- Nothing was filed, sent or posted; `XXXXXX` bug numbers and `<AUTHOR-EMAIL>` are placeholders.
