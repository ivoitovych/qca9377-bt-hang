Title: [SRU] btmon aborts with "buffer overflow detected" when decoding a record at 80 columns or fewer

Bug: https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/XXXXXX (placeholder)
Package: bluez, 5.72-0ubuntu5.8 (noble-updates / noble-security)

[Impact]

btmon from Ubuntu 24.04's bluez 5.72-0ubuntu5.8 aborts with
"*** buffer overflow detected ***: terminated" (SIGABRT, exit 134) and prints nothing,
when it decodes a record whose label makes the width left for the packet text negative
(`max_len` in `print_packet()` in monitor/packet.c). Example: a "MGMT Open: bluetoothctl
(privileged)" record, read with `btmon -r file.btsnoop` when its output is not a terminal
(80 columns) or with `--columns=N`, N <= 80. Because btmon cuts lines at 80 columns when
piped, scripts that pipe btmon output are affected. The package is built with
_FORTIFY_SOURCE=3, which turns the bad `snprintf()` size into an abort.

Upstream fixes:
- fdbfe0018f6f ("monitor: Fix crash due to negative max_len", first in BlueZ 5.80)
- dca0f10fd560 ("monitor: clamp max_len in print_packet", master)

[Test Plan]

1. On Ubuntu 24.04 with bluez 5.72-0ubuntu5.8, create a capture holding one privileged MGMT
   Open record (a btsnoop file in the monitor format with a "bluetoothctl" privileged
   MGMT Open, as written by `mkcap.py`, attached) and run:

       TZ=UTC btmon --columns=80 -T -r priv-open.btsnoop; echo "exit $?"

   Before: "*** buffer overflow detected ***: terminated", exit 134, no output.
   The same happens at 79 columns and below, and when piped without `--columns`.
2. Install bluez 5.72-0ubuntu5.9 from -proposed and repeat for 10, 40, 60, 79, 80, 81, 100,
   200 columns and piped. After: exit 0 and the records are decoded at every width
   (long text and labels are shortened to fit).
3. Run a second capture with ordinary records (`lines.btsnoop`, attached): the output is
   the same before and after.

Result of this test in a noble container with the stock and the rebuilt package: see
results-2026-10-28.md.

[Where problems could occur]

The change touches only `print_packet()` in monitor/packet.c, i.e. how btmon formats the
line header and cuts text to the terminal width. A mistake would show as wrongly truncated
or missing text in btmon output, or a crash in btmon. Nothing in bluetoothd, libbluetooth or
the kernel is changed. Output at normal widths (81 columns and above) is unchanged in the
captures tested. Tools that parse btmon text could see shorter lines at very narrow widths,
where btmon used to abort.

[Other Info]

- Affected: Ubuntu 24.04 (noble), bluez 5.72. The first fix is in BlueZ 5.80 and later; other
  releases were not checked.
- Upstream commits: fdbfe0018f6f216ff089c0e1db848ec8ae16585e (5.80),
  dca0f10fd560f8095493021ca2ac20236fde026e (master; upstream issue
  https://github.com/bluez/bluez/issues/1104). Both apply to the 5.72 tag in this order.
- The debdiff 5.72-0ubuntu5.8 to 5.72-0ubuntu5.9 adds the two patches with DEP-3 headers and
  a changelog entry; it builds with dpkg-buildpackage. The package's `dh_auto_test` is
  disabled (debian/rules), so no unit tests run during the build.
