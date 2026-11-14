# CO-02 v2 after the 2026-11-14 outside review

`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §12 holds the review
points. Nothing was sent. All mails are authored by the operator and carry no Signed-off-by.

- **Two layouts for the operator** (`mails/`):
  - (a) `a-two-plus-one/`: v2 as two patches (1 hold the reused connection, 2 don't reuse an
    aborting one), with patch 3 (parameters of a connection that has a holder) as its own mail.
    The BlueZ tests are split to match.
  - (b) `b-three/`: all three, with the wording changes below.
  - Placeholders `KERNEL-V2-LINK`, `KERNEL-P3-LINK`, `BLUEZ-V2-LINK` and `BLUEZ-P2-LINK` are filled
    at send time.

| sco-tester, KASAN + lockdep guests, 3 runs each (`logs/totals.txt`) | base | 1+2 | 1+2+3 |
|---|---|---|---|
| with BlueZ patch 1 only (33 cases) | 31 pass, 2 fail | 33 pass | — |
| with both BlueZ patches (39 cases, 2 not run on every kernel) | 33 pass, 4 fail | 35 pass, 2 fail (the two "other voice" cases) | 37 pass, 0 fail |

- **Other testers:** mgmt-tester 526/526 and iso-tester 213/213 on 1+2 and on 1+2+3.
- **Build and kernel checks:** no `net/bluetooth` build warning; no lockdep, KASAN, BUG or WARNING
  report in any guest. checkpatch `--strict` reports only the missing Signed-off-by and `--no-tree`
  commit ids (`logs/checkpatch.txt`).

**The incoming-link test** (reviewer 2) needed a debug-only kernel parameter (`research/park*.diff`,
not for posting). An unheld link is torn down within microseconds, so the test holds back the idle
worker. The test cases are in `proposal/`.
- A link a socket still holds gives `-EBUSY` on every kernel.
- An unheld link set up by the remote:
  - **base:** `connect()` returns 0;
  - **1+2:** `-ECONNABORTED` once the worker has made its decision;
  - **1+2+3:** `-ECONNABORTED` either way, and the retry gets its own link. That held in 30 of the
    30 runs that completed.
- So on 1+2 a transparent socket is silently given the remote's CVSD link, which is what patch 3
  prevents.
- **Side effect:** a remote-set-up link stores zero parameters, so a matching connect is also
  refused once. The patch 3 message now says so.

**Audits:**
- `abort-reason-audit.txt` (reviewer 2): one write and seven reads, each with its lock context.
  The check at the top of `hci_abort_conn()` is a plain load paired with the new `WRITE_ONCE`. A
  one-line `READ_ONCE` is proposed in `proposal/abort-reason-readonce.diff`; it builds and passes
  sco-tester. It is not in the mails: the operator decides.
- `cancel-sync-analysis.txt`:
  - Reviewer 7's argument holds for `hdev->lock` itself.
  - A rare three-way cycle through `cmd_sync_work_lock` at unregister is possible in principle.
  - It is not new: `hci_conn_del()` already waits on the same work under `hdev->lock`, and patch
    2's message now says so.
  - Lockdep showed nothing, but the cycle was not provoked.

**Wording:**
- The stable line is "6.18.y and 7.3.y". `e6720779ae61` is in v6.13+, the kref code is in v6.18.63,
  v7.2.13 and v7.3.4, and 7.2 is end of life (reviewer 6).
- "while the connection has a holder" (reviewer 3).
- The codec comparison's scope is the voice setting, codec id and data path (reviewer 7).
- "no causal evidence found" for the l2cap stalls (reviewer 7).

**Not resolved:**
- 3 of 33 runs of the early-park *debug* kernel (1+2+3 plus the debug parameter) hung with no
  result, early in the series and in tests that open no SCO link.
- There were 0 of 62 on the other kernels, including all four that match the mails, and none in
  23 later runs, including runs under load and with the hung-task detector.
- The cause is not known, and the patches cannot be excluded.

**Checked on copy:**
- the totals of every sco-, mgmt- and iso-tester run against the table above;
- every run log scanned for kernel reports (none);
- build warnings (none).

**Changed on copy:** the internal work name was removed from `OPERATOR-NOTES.txt` and two script
headers.

**Left in the work area:** the trees, images, binaries, fetched pages and raw tester logs, which
print emulated addresses.
