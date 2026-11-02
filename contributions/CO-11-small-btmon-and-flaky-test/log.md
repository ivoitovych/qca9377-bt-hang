# CO-11 log

Append-only. Newest last.

## 2026-10-18 — the flake measured
`scripts/patchwork-checks.sh --failed-functional 200`: the case failed alone on 7 patches,
10-10 to 10-18, and passed in 19 runs. Pauli Virtanen's 14879847 gives the cause.

## 2026-10-19 — BT-4's abort reproduced
It was reproduced on the laptop's `bluez` build, off the laptop. A privileged MGMT open
aborts `btmon` at 80 columns or fewer.

## 2026-10-21 — dossier opened

## 2026-10-28 — reopened (the operator), both halves prepared
- **Why:** the laptop's own btmon aborted 13 times since 2026-10-23 (`coredumpctl`, until the
  `--columns=200` capture fix is deployed); Ubuntu 24.04 lacks both upstream fixes and Launchpad has
  no bug. And a Tested-by is a useful, small contribution.
- **btmon, prepared:** `ubuntu/` holds the debdiff `5.72-0ubuntu5.8` → `5.72-0ubuntu5.9` (the two
  upstream patches with DEP-3 headers; built in a noble container, source checksums matching the
  `.dsc`), the Launchpad text in Ubuntu's stable-update form, and `results-2026-10-28.md`: stock
  btmon aborts on `tests/btmon/real/`'s reproducer (`*** buffer overflow detected ***`, exit 134) at
  10, 40, 60, 79 and 80 columns and piped; the rebuilt one decodes at every width (exit 0). Gaps:
  Ubuntu's package disables `make check`; outputs above 81 columns compared by line count only; the
  live-socket path not exercised. Next: the operator reviews and files (the bug number is a
  placeholder until then).
- **The functional harness:** `harness-check-2026-10-28.md`: the host's emulator only listens on a
  UNIX socket and the test controllers are registered inside the QEMU guests, so the host's
  Bluetooth is not touched (except with `--usb`/`--pcie`, never to be used); the harness's
  `pytest-bluezenv` is not on this disk, so its exact flags are unverified. Run it in a container
  given only `/dev/kvm`. Next: the Tested-by runs for 14879847 (master and patched, N each).

### 2026-10-28 — the SRU after the outside reviews (`ubuntu/reviews-2026-10-28.md`)

- **Byte-for-byte run** (`ubuntu/results-2026-10-28-bytes.md`, `tmp/co11-btmon/run-test2.sh`):
  reviewer 4 reproduced exactly (81 and 82 columns: the privileged-Open label differs); identical
  elsewhere where both run; stock also aborts at 3000/5000 columns and on ordinary records at
  10-60; the rebuilt btmon exits 0 at every width. The report's "unchanged at 81 and above" is
  replaced by those results; [Impact] and [Test Plan] carry them.
- **The development release** (`scripts/ubuntu-series-versions.py bluez`): 27.04 `tenacious` and
  26.10 have bluez 5.87-4. dca0f10fd (2026-09-10) is in no BlueZ release (5.87: 2026-07-03), and
  none of 5.87-4's 19 Debian patches touches `monitor/packet.c`
  (`scripts/ubuntu-bluez-patches-check.py 5.87-4 tmp/co11-btmon/dev-release`). So the
  development release needs dca0f10fd too; [Other Info] says the bug should target it.
- Still open: the live-socket `comm[pid]` path (not run here: it touches the machine's
  Bluetooth), attaching the captures and `mkcap.py` when filing, the bug number.

## 2026-11-01 — the first fix alone does not fix the bug
An outside reviewer proposed shipping `fdbfe0018f6f` alone (it is in 5.80, so the later Ubuntu
series have it); another asked to test it first. btmon built three ways in a noble container
with the package's flags (`-D_FORTIFY_SOURCE=3`; the rebuilt stock btmon's output equals the
archive binary's at 10 of 10 widths where both exit 0), run on the two `mkcap.py` captures
(`ubuntu/results-2026-11-01-first-fix-only.tsv`; exit status "privileged MGMT Open capture /
ordinary-records capture"):

| width | stock | + fdbfe0018f6f only | + both |
|---|---|---|---|
| 10 | 134 / 134 | **134 / 134** | 0 / 0 |
| 60 | 134 / 134 | 0 / 0 | 0 / 0 |
| 80 | 134 / 0 | 0 / 0 | 0 / 0 |
| 81, 82, 100, 250 | 0 / 0 | 0 / 0 | 0 / 0 |
| 3000, 5000 | 134 / 134 | **134 / 134** | 0 / 0 |
| piped | 134 / 0 | 0 / 0 | 0 / 0 |

Every 134 is `*** buffer overflow detected ***`. With the first fix alone the aborts at width 10
and at 3000/5000 remain, on both captures. The ordinary terminal and piped cases are fixed by the
first patch. Rechecked the later series (2026-11-01, source markers): 27.04 (5.87-4; 5.87-5 in
-proposed), 26.10 (5.87-4) and 26.04 (5.85-4ubuntu0.4) carry `fdbfe0018f6f` and not
`dca0f10fd560`. The routing choice is the operator's: the first fix alone for 24.04 (common cases
fixed, very narrow and very wide terminals still abort), or `dca0f10fd560` into the development
release first. Work area: `/root/exp/agent-work/co03/review-20261101/co11a/`.
`dca0f10fd560` is in no BlueZ release yet (`git tag --contains dca0f10fd560` in
`cache/bluez-upstream`: no tag, 2026-11-01), so either route cites it as an upstream commit, not a
release.

## 2026-11-02 — the second fix's route, corrected (an outside review)
Ubuntu's stable-update rule wants a fix in every newer supported release before an older one, not
only in the development release. `fdbfe0018f6f` is already in 26.04 (5.85), 26.10 and 27.04 (5.87),
so a 24.04 update with it alone can go on its own. `dca0f10fd560` is in none of them, so it must
land in 27.04, then 26.10 and 26.04 LTS, before 24.04. The update text names the widths that still
abort with the first fix alone (10 and 3000/5000 columns, see the matrix above); a 10-column
terminal is rare but real (a narrow pane). Before filing: rerun the 24.04 container on more archived
captures and ordinary btmon options, not only the two captures.

## 2026-11-02 — the live-capture case (a second outside review; checked)
`dca0f10fd560`'s own message (`git show -s dca0f10fd560` in `cache/bluez-upstream`): when btmon
reads the monitor socket, each record carries a "comm[pid]: " prefix from its credentials, absent
when replaying a btsnoop file; with a 7-digit pid, a long process name plus a long label makes
max_len negative at ordinary widths, and a negative max_len also indexes before the start of
line[]. Our matrix replayed two captures, so it could not exercise this; "the remaining aborts are
at extreme widths" (decisions brief, 11-01) is withdrawn. Next, local only: run 24.04's btmon with
`fdbfe0018f6f` alone, live in a QEMU guest with an emulated controller, 80 columns, large
`kernel.pid_max`, long process names; the replay matrix stays as a separate test. If it aborts,
the proposed route becomes one 24.04 update with both fixes, with the first-only update as fallback.

## 2026-11-02 — live capture: the first fix alone still aborts at ordinary widths (measured)
24.04's btmon rebuilt from `bluez_5.72-0ubuntu5.8` with the package's own flags (`-D_FORTIFY_SOURCE=3
-O2`, gcc 13.3.0-6ubuntu2~24.04.1) in three variants: stock, + `fdbfe0018f6f` ("fix1"), + both
fixes; Ubuntu's own btmon as control (0 decode differences against rebuilt stock in 132 replay
cells). Each ran live on the monitor socket of a QEMU guest (test kernel 7.2.0, one `btvirt`
controller on the guest's own vhci, `kernel.pid_max` 4194304, pids set to 7 digits), under a pty
at 60/80/100/120/200 columns and piped, about 6 s per run with bluetoothd, btmgmt and hcitool
traffic; scenarios with real tool names and with 15-character names. Counts re-tallied from the four
`results.tsv` files (exit status per run; 134 is `*** buffer overflow detected ***: terminated`):
- fix1 aborts 5 of 5 at 60 columns without options (real names and long names), 5 of 5 at 60 with
  `-t` or `-T`, and 5 of 5 at 80 and piped with `-T` and 15-character names. With 5-digit pids
  (control) fix1 passes at 60 without options and still aborts at 60 with `-T`.
- A guest clock moved 100000 s forward (a btmon running about 28 hours): fix1 aborts 3 of 3 at 60
  and, with long names, at 70; stock aborts 3 of 3 at 80 and piped too.
- Both fixes: 0 aborts in 264 live runs (of 852 live runs over all variants).
- Replay, extended (3 archived captures, options none/-t/-T/-i hci0/-I, 800 runs): fix1 aborts only
  at 10 and 3000 columns, as before; replay never shows the live case.
Inferred from 5.72's `print_packet()`: the space left is `col - len - ts_len - 3`, `len` includes
`comm[pid]`, and the abort comes at -2 or less; consistent with every cell. The prefix needs the
kernel to pass credentials to the monitor (`69ae5065061c5`, first in v6.6-rc1). Conclusion: one
24.04 update with both fixes; the first-only update stays a fallback whose text names 60 columns,
and `-T` at 80/piped, as still aborting. Raw outputs, scripts and SHA256SUMS:
`/root/exp/agent-work/co11a-live-20261102/` (local).
