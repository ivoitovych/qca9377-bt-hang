# CO-09 — The QCA9377 entry in Ubuntu's kernel

**State:** waiting. It will probably arrive with Ubuntu's stable updates; a request would only
make it sooner.

**Target:** Ubuntu's `linux-hwe-7.0` (24.04 HWE kernel).

**Comes from:** BT-1. The fix is upstream `dc16388d45ec` (Tibor Harcsa), carried to stable by
our request of 2026-10-02.

## The facts

- **Upstream stable:** the entry is released in 7.2.10 and 6.18.56 (2026-10-11) and 6.12.113
  (2026-10-15). It is in the 6.6, 6.1, 5.15 and 5.10 release candidates (STATUS).
- **Ubuntu** (2026-10-20): `7.0.0-38.38~24.04.4` is in updates and security, and
  `7.0.0-39.39~24.04.1` is in proposed since 2026-10-01. Neither carries the entry
  (`zgrep` of `-39`'s diff, 2026-10-18).
- **Launchpad:** no bug mentions 13d3:3503.
- **Why it should arrive anyway (inference):** `-39`'s newest upstream-stable base is "v6.18.51,
  v7.2.5", and the entry is in 7.2.10 and 6.18.56. A later Ubuntu stable update that takes
  those releases should carry it. That follows from Ubuntu's cadence; it is not a promise.

## Until then

Before any new kernel boots on the laptop, run `scripts/btusb-has-device.py` on its **stock**
btusb. If it reports ABSENT, rebuild E3 for that kernel first (BRIEF §0).

## Next

Watch each new `linux-hwe-7.0` upload. The operator decides whether to request it sooner (an
SRU).
