# CO-02: changes that existed only in `cache/` kernel worktrees, filed 2026-11-14

Found by the disk audit of 2026-11-14 (`tmp/space-audit/our-commits.py`). These are commits of ours
whose change (`git patch-id --stable`) was in no tracked patch file. They are filed here before the
worktrees are removed.

- `0001-scratch-park-hci_conn_timeout-for-SCO-after-refcnt-0.patch` and
  `0001-scratch-park-only-once-diagnostic-not-for-submission.patch` are **test-only instrumentation,
  not for submission**. They hold `hci_conn_timeout()` for an SCO link after its last reference is
  dropped, so the close-then-reconnect race can be hit on purpose. The 2026-10-22 parked-worker
  runs used them (`../race-park-2026-10-22.md`, `../results-2026-10-22*.md`); that record quotes a
  later variant of the same park inline.
  - They come from worktree `co02-w2c-basepark` (branch `w2c/base-park-20261022`). The first was
    also in `co02-w2c-diag`, `co02-stable-6.18` and `co02-stable-7.2`.
- `0001-CO-02-v5-series-on-Ubuntu-7.0.0-38-with-abd93c85c866.patch` is the v5 series combined into
  one diff on Ubuntu 7.0.0-38's Bluetooth sources, together with `abd93c85c8667` and
  `816fb1590a4c`, for the laptop module builds (`../build-laptop-module-42.sh`,
  `../build-laptop-module-v2.sh`). It comes from worktree `co02-ubuntu42`.
  - It was committed under a work identity; the author line is the operator's on copy.
  - The Ubuntu sources it applies to can be fetched again, so their import commit is not kept.
