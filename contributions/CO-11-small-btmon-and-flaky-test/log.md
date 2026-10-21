# CO-11 log

Append-only. Newest last.

## 2026-10-18 — the flake measured
`scripts/patchwork-checks.sh --failed-functional 200`: the case failed alone on 7 patches,
10-10 to 10-18, and passed in 19 runs. Pauli Virtanen's 14879847 gives the cause.

## 2026-10-19 — BT-4's abort reproduced
It was reproduced on the laptop's `bluez` build, off the laptop. A privileged MGMT open
aborts `btmon` at 80 columns or fewer.

## 2026-10-21 — dossier opened
