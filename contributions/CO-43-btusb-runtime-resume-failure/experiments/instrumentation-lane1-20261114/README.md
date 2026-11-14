# CO-43: test-only kernel instrumentation of the 2026-11-14 runs, recovered and filed

All four patches are **debug-only, not for submission**. They were commits in a kernel tree of the
11-14 btusb work and were never filed as patches. That tree's shared object store was deleted in
the disk reclaim of 2026-11-14, a mistake noted in `docs/STATUS.md`. They were recovered from the
tree's own objects (`tmp/space-audit/salvage-lx.py`).

| patch | what it does | used by |
|---|---|---|
| `292682e1e529-…bt17_reset_delay_ms.patch` | usbcore parameter that delays the queued reset, to open D's "reset lost" window | `results/co43-b2-and-runtime-d-2026-11-14/` (`ab2d-dbg-d-delay-*` runs) |
| `eb0574caa0e2-…BT-24-injection-on-the-A-B2-D-v2-tree.patch` | BT-24 fault injection on the A + B2 + D v2 tree | `results/co43-d2-series-bt24-bt25-2026-11-14/` |
| `9bc09760e4ca-…BT-24-injection-plus-the-BT-24-fix….patch` | the same injection with the BT-24 fix applied | as above |
| `8b370c404f80-…fault-injection-for-BT-24-and-BT-25--E-F-tree-.patch` | BT-24 and BT-25 fault injection on the E + BT-25 tree | as above |

`1dd76cb88f88-…E-tree-.patch` is the E-only variant of the last one, recovered from a later tree
that had fetched the same branches.

Not recoverable: one more `bt17_reset_delay_ms` commit on another branch (`6f672acb184c`), whose
parent is gone. It has the same subject as the filed one.

Every submission patch of that tree is filed in the send packages (matched by `git patch-id`, or by
subject where the diff could no longer be produced).

The author line was set to the operator's on copy (the commits carried a placeholder).
