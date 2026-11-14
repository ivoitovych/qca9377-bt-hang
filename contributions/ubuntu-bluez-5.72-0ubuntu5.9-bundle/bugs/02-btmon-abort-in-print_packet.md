Title: btmon aborts with "buffer overflow detected" in print_packet()

Bug: https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/XXXXXX (placeholder)
Package: bluez (noble: 5.72-0ubuntu5.8; the noble fix is in 5.72-0ubuntu5.9, one upload with four other bugs, see BUNDLE.md; the
three newer series have their own debdiffs from 2026-11-02, unchanged, in the CO-11a package)

Target series, in upload order (a fix goes into every newer series first):

| series | source version now | update | debdiff |
|---|---|---|---|
| tenacious (27.04, development) | 5.87-5 | 5.87-5ubuntu1 | bluez_5.87-5_5.87-5ubuntu1.debdiff |
| stonking (26.10) | 5.87-4 | 5.87-4ubuntu0.1 | bluez_5.87-4_5.87-4ubuntu0.1.debdiff |
| resolute (26.04 LTS) | 5.85-4ubuntu0.4 | 5.85-4ubuntu0.5 | bluez_5.85-4ubuntu0.4_5.85-4ubuntu0.5.debdiff |
| noble (24.04 LTS) | 5.72-0ubuntu5.8 | 5.72-0ubuntu5.9 | bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff |

The three newer series get one patch, upstream dca0f10fd560 (they already have fdbfe0018f6f, first
in BlueZ 5.80). noble gets both.

[Impact]

btmon from Ubuntu 24.04's bluez 5.72-0ubuntu5.8 aborts with
"*** buffer overflow detected ***: terminated" (SIGABRT, exit 134) and prints nothing,
when it decodes a record whose label makes the width left for the packet text negative
(`max_len` in `print_packet()` in monitor/packet.c). Example: a "MGMT Open: bluetoothctl
(privileged)" record, read with `btmon -r priv-open.btsnoop` when its output is not a terminal
(80 columns) or with `--columns=N`, N <= 80. Because btmon cuts lines at 80 columns when
piped, scripts that pipe btmon output are affected. Ordinary records abort it as well at
narrow widths (60 columns and fewer in our test), and both tested captures abort it at very wide
widths (`--columns=3000`). The `comm[pid]` prefix of a live btmon (present only when btmon reads
the monitor socket) can push `max_len` negative at ordinary widths. The package is built
with _FORTIFY_SOURCE=3, which turns the bad `snprintf()` size into an abort.

Live results, measured 2026-11-02 (24.04's btmon rebuilt with the package's own flags, running on
the monitor socket of a QEMU guest with an emulated controller, 7-digit pids, under a pty at 60 to
200 columns and piped):
- with the first upstream fix (fdbfe0018f6f) alone, btmon still aborted 5 of 5 runs at 60 columns;
- with both fixes, 0 aborts in 264 live runs (852 live runs over all variants).
So the first fix is not enough for 24.04, and releases that have only the first fix (26.04 to 27.04)
still abort at 10 and at 3000 columns on replayed captures (see [Test Plan]).

Upstream fixes:
- fdbfe0018f6f ("monitor: Fix crash due to negative max_len", first in BlueZ 5.80; already in
  26.04, 26.10 and 27.04)
- dca0f10fd560 ("monitor: clamp max_len in print_packet", master; in no BlueZ release and in no
  Ubuntu release yet)

[Test Plan]

Files attached: `mkcap.py` (writes the two captures), `priv-open.btsnoop` (one privileged MGMT
Open record), `lines.btsnoop` (the header lines the project's tools read).

1. On Ubuntu 24.04 with bluez 5.72-0ubuntu5.8, run (or use the attached `priv-open.btsnoop`):

       python3 mkcap.py .
       TZ=UTC btmon --columns=80 -T -r priv-open.btsnoop; echo "exit $?"

   Before: "*** buffer overflow detected ***: terminated", exit 134, no output.
   The same happens at 79 columns and below, and when piped without `--columns`.
2. Install bluez 5.72-0ubuntu5.9 from -proposed and repeat for 10, 40, 60, 79, 80, 81, 82,
   100, 200, 3000 and 5000 columns and piped. After: exit 0 and the records are decoded at
   every width (long text and labels are shortened to fit).
3. Run both captures (`priv-open.btsnoop`, `lines.btsnoop`) before and after at
   every width above, keep the outputs, and compare them byte for byte (`cmp`). Expected,
   as in our run: stock aborts (exit 134) at 3000 and 5000 columns as well, and on
   `lines.btsnoop` at 10, 40 and 60; where both versions run, the outputs are identical
   except the privileged Open label at 81 and 82 columns (`@ MGMT O..n (privileged) version
   1.22` becomes `@ MGMT Open: bluetoothctl`).
4. On 26.04, 26.10 and 27.04 (bluez 5.85-4ubuntu0.4, 5.87-4, 5.87-5), run both captures at 10, 60,
   80, 3000 columns and piped, with no option, `-t` and `-T`
   (`TZ=UTC btmon [-t|-T] [--columns=N] -r <capture>`). Before: exit 134 at 10 and at 3000
   columns (12 of 30 cells), exit 0 elsewhere. After (5.85-4ubuntu0.5, 5.87-4ubuntu0.1,
   5.87-5ubuntu1): exit 0 in all 30 cells. Of the 18 cells where both versions run, 16 are
   byte-identical; the other 2 (`lines.btsnoop`, 60 columns) differ in one line each: with `-t`
   `@ MGMT Open.. version 1.22  {0x0002}` becomes `@ MGMT Open:  version 1.22  {0x0002}`, with `-T`
   `@ MGMT Comma..   {0x0002}` becomes `@ MGMT Command   {0x0002}`.
5. The live run on the monitor socket (see [Impact]) was done for 24.04 only; it was not repeated
   on the newer series.

Results of these tests in containers with the stock and the rebuilt packages:
results-2026-10-28.md (24.04 exit codes), results-2026-10-28-bytes.md (24.04 byte-for-byte
comparison, 3000/5000 columns), results-2026-11-02-ready.md (26.04, 26.10, 27.04).

Results on the noble candidate 5.72-0ubuntu5.9 (2026-11-14; its btmon carries both patches), against 5.72-0ubuntu5.8, btmon built by
dpkg-buildpackage in a noble container:
- replay of priv-open.btsnoop and lines.btsnoop, options none, -t, -T, at 10, 40, 60, 79, 80, 81, 82, 100, 200, 3000, 5000 columns and
  piped (72 cells): before, exit 134 in 32 cells (10, 40, 60, 79, 80, 3000, 5000 and piped); after, exit 0 in all 72; where both
  exit 0 (40 cells) 38 are byte-identical and 2 differ (priv-open, -T, 81 and 82 columns: the privileged Open label);
- live on the monitor socket of a QEMU guest with an emulated controller, under a pty at 60 to 200 columns and piped, "real" and
  "long" scenarios, 5 runs per cell: before, 20 aborts in 60 runs; after, 0 in 60.

[Where problems could occur]

The change touches only `print_packet()` in monitor/packet.c, i.e. how btmon formats the
line header and cuts text to the terminal width. A mistake would show as wrongly truncated
or missing text in btmon output, or a crash in btmon. Nothing in bluetoothd, libbluetooth or
the kernel is changed. The output also changes at widths where btmon did not abort: on 24.04 at
81 and 82 columns a long label is shortened differently; on 26.04 to 27.04 one line differs at 60
columns with `-t`/`-T` (the stock text `MGMT Comma..` becomes `MGMT Command`, `MGMT Open..`
becomes `MGMT Open:`; in the stock code the two dots overwrite the end of the label). In our byte comparisons, where both versions
completed, everything else matched. Tools that parse btmon text could see that different
truncation, and decoded lines at widths where btmon used to abort. On the newer series the
patch applies with an offset (-52 lines on 5.85, -2 lines on 5.87), no fuzz; it was built and run in
containers of each release, the unit tests of the package are disabled (debian/rules) and did not run.

[Other Info]

- Affected: Ubuntu 24.04 (noble) bluez 5.72, 26.04 (resolute) bluez 5.85, 26.10 (stonking) and
  27.04 (tenacious) bluez 5.87. fdbfe0018f6f is in BlueZ 5.80 and later, so 26.04 to 27.04 have it.
  dca0f10fd560 (2026-09-10) is in no BlueZ release (5.87 is 2026-07-03) and none of the three
  newer packages carries it: checked 2026-11-02 in 5.87-5 (tenacious, -proposed), 5.87-4
  (stonking) and 5.85-4ubuntu0.4 (resolute): `monitor/packet.c` has no `sizeof(line) - pos - 1`
  and no debian patch changes `print_packet()`.
- Order, following the stable-update rule: dca0f10fd560 first in the development release
  (tenacious), then stonking and resolute, then noble. noble's update carries both patches.
- Upstream commits: fdbfe0018f6f216ff089c0e1db848ec8ae16585e (5.80),
  dca0f10fd560f8095493021ca2ac20236fde026e (master; upstream issue
  https://github.com/bluez/bluez/issues/1104). Both apply to the 5.72 tag in this order.
- For noble the debdiff to attach is the bundle's (bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff of BUNDLE.md), which contains these
  two patches among ten; the older noble-only debdiff of 2026-10-28 is superseded.
- Debdiffs (attached): tenacious 5.87-5 to 5.87-5ubuntu1, stonking 5.87-4 to 5.87-4ubuntu0.1,
  resolute 5.85-4ubuntu0.4 to 5.85-4ubuntu0.5, noble 5.72-0ubuntu5.8 to 5.72-0ubuntu5.9. Each adds
  the patch(es) with DEP-3 headers (the upstream diff unchanged), the series line and a changelog
  entry; each source package builds with dpkg-buildpackage in a container of its release
  (tenacious: an Ubuntu 26.10 container upgraded to tenacious, no 27.04 image exists).
