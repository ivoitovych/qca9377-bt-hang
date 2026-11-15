# CO-02 v2 after the 2026-11-15 outside review: the lock cycle is real; a non-sleeping 2/2

The review points are in `../../../reviews/2026-11-15T0300Z-submitted-status-review-checks.md`
(items 3, 4, 7, 16, 17). Nothing was sent. The mails carry no Signed-off-by; the author is the
operator. Base: bluetooth-next `da3cc02587c6`, BlueZ `20ffd285b58f`. QEMU, 4 CPUs, KASAN and lockdep.

## 1. The lock cycle in v2 2/2: reachable, with a narrow window

v2 2/2 waits in `cancel_delayed_work_sync(&sco->disc_work)` with `hdev->lock` held. The analysis,
with every edge by file:line, is in `analysis/lock-cycle-analysis.txt`. In short:
- **The cycle:** the `connect()` holds `hdev->lock` and waits for the running disconnect worker.
  The worker waits for `cmd_sync_work_lock`. `hci_cmd_sync_clear()` (controller unregister)
  holds `cmd_sync_work_lock` and runs destroy callbacks that take `hdev->lock` on
  `-ECANCELED`.
- **Those callbacks:** `add_ext_adv_params_complete()`, and `add_advertising_complete()` /
  `add_ext_adv_data_complete()` through `add_adv_complete()` (`analysis/destroy-scan.txt`).
  `add_device_complete()` is not among them: it takes the lock only when `!err`.
- **Narrow:** `hci_devcd_shutdown()` takes and releases `hdev->lock` just before
  `hci_cmd_sync_clear()`. So the `connect()` must take the lock after that, for example one
  already past `hci_get_route()` and waiting for it.
- **Not "not new":** on the base kernel nothing waits for a running `disc_work` under
  `hdev->lock` and then reaches the mutex. v2 2/2 adds the first such waiter. The 11-14 claim
  is withdrawn.

The test uses debug-only delays that stand in for the scheduling windows
(`test-only/kernel/`, `test-only/bluez/`, the `LKD` case; 100 s guest limit). **Checked on copy**
in the raw guest logs, `exit=` and `Total:` lines:

| kernel | 3 runs | evidence |
|---|---|---|
| v2 1/2 + 2/2 | **hangs 3 of 3** (`exit=124`) | the trace ends `destroy add_ext_adv_params_complete err -125, holding cmd_sync_work_lock`, then `lookup_entry: taking cmd_sync_work_lock`, and nothing after (`evidence/lkd-traces.txt`) |
| base, same delays | 3 of 3 pass | same file |
| alternative 2/2, same delays | 3 of 3 pass | same file |

Lockdep did not print the SCO chain:
- **What it printed:** with an Add Extended Advertising Parameters entry queued at unregister, a
  two-lock inversion that does not involve SCO. It is the same on every kernel, base included
  (`evidence/lockdep-reports.txt`), and lockdep stops after its first report.
- **Why not the SCO chain:** lockdep does not record the edge from `hdev->lock` to the
  `disc_work` wait on the unmodified v2 kernel, though the `connect()` waited about 260 ms. It
  appears only with a debug-only explicit annotation (`evidence/lockdep-edges.txt`).
- So the deadlock is shown by the hang, not by lockdep. No run hit the window without the
  delays.
- These lockdep points were taken from the run notes and the evidence extracts, not re-read in
  the raw logs.

## 2. The alternative 2/2: no sleep under the lock (`patches/alt-2of2/`, message `msg/alt2-msg.txt`)

After the hold is taken, it refuses with `-ECONNABORTED` if `abort_reason` is set or
`work_busy()` reports the disconnect worker running. It does not wait. The argument, which is in
the message:
- with the hold taken, nothing can queue the work again;
- a work that is not running has either not started (and now cannot) or has finished, in which
  case `abort_reason` is set;
- a running work that would only have seen the hold is refused for nothing, and the caller
  retries.

**Checked on copy:**
- **sco-tester**, 44 cases (35 posted, 9 research): 35 pass, 2 fail, 7 not run, in each of 3
  runs. The 2 failures are the two "Other Voice" cases, which belong to the mismatch patch; the
  7 need the debug kernel.
- **mgmt-tester** 526/526; **iso-tester** 213/213.
- The closed-link race with the late park: 2/2 on the alternative, 1/2 on base.
- No lockdep, KASAN or BUG line in any of these runs.

## 3. Wentao Liang's patch (patchwork 14942649)

- **Effect:** v2 keeps the bug it describes, neither fixing nor worsening it. A new connection
  whose `hci_conn_link()` fails is still dropped without a hold, and 2/2 does not touch that
  branch. This was read from the code; no allocation failure was injected.
- **Applying:** `git apply -3` conflicts in every order tried (`analysis/item2-apply-tests.txt`).
- **Rebased variant:** our 1/2 and 2/2 on top of his patch (`patches/wentao-then-v2/`; his patch
  itself is not copied here, use patchwork). It builds. **Checked on copy:** sco-tester 35 pass,
  2 fail in each of 3 runs; mgmt 526/526; iso 213/213.

## 4. `READ_ONCE()` at `hci_abort_conn()`'s top check

It is needed as annotation hygiene: a plain load pairs with the marked write in the same
function. It is not a functional need. KCSAN ran, 3 runs each, with and without it. Every report
was in the console driver and virtio, none on `abort_reason`, and the tests never run two abort
callers at once, so KCSAN does not settle it either way. (The KCSAN counts were not re-read in the
raw logs.)

## 5. The mismatch patch on its own (`patches/standalone-3/`)

It applies to the untouched base and builds. **Checked on copy:** its two "Connect Twice Other
Voice" cases pass 3 of 3. The cases that fail without 1/2 and 2/2 are theirs ("Reconnect During
Disconnect", "Connect Twice"). Its form on the base and its form on top of 2/2 differ, so only
one of the two can be sent.

## 6. Wording and the stable note

`msg/p2-final.txt` and `patches/main-v2/` drop "the wait is safe". The cover letters
(`msg/cover-main.txt`, `msg/cover-alt.txt`) and 2/2 say that 2/2 depends on 1/2 and must not be
backported alone. The proposed trailer form is:

`Cc: stable@vger.kernel.org # needs "Bluetooth: hci_conn: hold a reused SCO connection for its caller"`

That is the operator's call.

## What this means for the send

`patches/main-v2/` (the sleeping 2/2) is **not to be sent**: it can deadlock. The candidate is
1/2 + the alternative 2/2 (`patches/alt-2of2/`), with the mismatch patch later, on its own. It
still needs, from the project checkout:
- checkpatch on the new files;
- the bot's CI on base and base + ours;
- send commands and a dry run.

Open: the 3-of-33 hangs on the debug-only kernel of 11-14 were not re-examined. The deadlock above
needs an advertising entry that the matrix never queues, so it does not explain them.
