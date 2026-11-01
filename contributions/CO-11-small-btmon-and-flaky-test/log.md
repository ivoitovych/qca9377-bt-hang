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
