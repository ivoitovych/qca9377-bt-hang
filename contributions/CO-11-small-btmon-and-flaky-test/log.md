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
