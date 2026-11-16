# CO-21 v2: air mode first, one-pass count under hdev->lock (2026-11-14, track 6)

`WA` = `<work area>/lane6-btusb-20261114/`. Patches in `WA/out/co21/` (`0000-cover-letter.patch`, 0001, 0002),
on bluetooth-next `da3cc02587c6`; branch `l6-co21v2` in `WA/lx2` (`l6-co21` = the earlier two-count version).
Author Iaroslav Voitovych, no Signed-off-by. Nothing sent; the host's Bluetooth untouched.

## What changed against send-20261114

- 0001: `conn->air_mode = ev->air_mode` is stored **before** `conn->state = BT_CONNECTED` in `hci_sync_conn_complete_evt()`.
  `hci_conn_sco_up_num(hdev, &cvsd, &transp)` replaces the two RCU counts: one walk of `hdev->conn_hash.list`,
  `lockdep_assert_held(&hdev->lock)`, both counts from the same pass. The message says so.
- 0002: `btusb_work()` takes `hci_dev_lock()` only around that call and releases it before `usb_autopm_get_interface()`
  and the set-interface call. The message gives the interleaving and the lock-order argument.

## Lock order: is it safe to take hdev->lock in btusb_work()'s context?

Source, `lx2` at `l6-co21v2`:
- `btusb_work` runs in a workqueue and may sleep. It holds `hdev->lock` for the count only and calls no USB function
  with it held, so the lock order is only `hdev->lock` (leaf; nothing is taken inside it).
- `hdev->notify` (`btusb_notify()`) is called from the core with `hdev->lock` held and only does `schedule_work()`: it
  never waits for the work.
- The waiters for `data->work` are `btusb_close()` (`cancel_work_sync`, line 2203) and `btusb_suspend()` (line 4966).
  `hdev->close` is called from `hci_dev_drop_last_cmd_req_and_close()` (`hci_sync.c:5872`), outside every
  `hci_dev_lock()` section of `hci_dev_close_sync()` (those are 6087-6102 and 6146-6148). `btusb_suspend()` is called by the USB core's
  PM path, which does not hold `hdev->lock`. So nobody holds `hdev->lock` while waiting for the work, and there is no
  cycle. Lockdep (PROVE_LOCKING, all runs below, with suspend/resume and SCO traffic in the same guest): no report.
- The event handlers that change `state`, `air_mode`, `type` and the list all run under `hci_dev_lock()` (the code
  at `hci_event.c` `hci_conn_complete_evt`/`hci_sync_conn_complete_evt`), so a plain walk under the lock is consistent;
  the RCU variant is no longer needed.
Not run: KCSAN (no instrumented kernel was built; the builds of that day are KASAN + lockdep).

## The five scenarios, base against patched (`harness/spec-u.txt`, `harness/run-batch-usbip.sh`)

Kernels (`img/*.commit`, KASAN + lockdep): `base-u` = `da3cc02587c6`, `co21v2` = base + the two patches. Emulator
`harness/usbip-bt-emu.py`, two runs of each (`logs/summaries/co21.txt`):

| scenario | base-u | co21v2 |
|---|---|---|
| msbc-two-links-first | FAIL, FAIL | PASS, PASS |
| msbc-two-links-second | FAIL, FAIL | PASS, PASS |
| cvsd-two-links-first | FAIL, FAIL | PASS, PASS |
| msbc-single-race | FAIL, FAIL | PASS, PASS |
| cvsd-single-race | FAIL, FAIL | PASS, PASS |

0 of 10, then 10 of 10; the same as with the earlier version.

## The transition test (reviewer 7's interleaving)

Scenario `transition` (new, `harness/usbip-bt-emu.py`; the emulator also flags `STATE-BAD` when alt 0 is selected while the
controller has had a link up for more than 0.5 s). Two transparent (mSBC) links A and C are up (alt 1). C hangs up; its
notification starts `btusb_work()`, which looks at the links and then sleeps 2.5 s (**test kernels only**, a debug
parameter `btusb.sco_cnt_delay_ms`, `harness/apply-debug-co21.py`: for the two-count version between the CVSD and the
transparent count, no lock held; for the one-pass version after the count, with `hdev->lock` held). Meanwhile a CVSD link B is set up
(+0.3 s) and A hangs up (+0.8 s). Right: alt 2 in the end, and no alt 0 while a link had been up for 0.5 s.

Kernels: `co21v1-dbg` (the earlier two-count patch + hook), `co21v2-dbg` (this version + hook), `base-u` (no hook; the delay
parameter is absent, so the window is not opened). Three runs each, `logs/summaries/trans2.txt`:

| kernel | verdict | alt 0 chosen with a link up | SET_INTERFACE sequence |
|---|---|---|---|
| co21v1-dbg (two counts) | FAIL, FAIL, FAIL | 1, 1, 1 | 1, 0, 2, 0 (each run); the first `0` is the bad one |
| co21v2-dbg (one pass, lock) | PASS, PASS, PASS | 0, 0, 0 | 1, 0, 2, 0 (each run) |
| base-u | FAIL, FAIL, FAIL | 0, 0, 0 (no window) | 1, 0, 4, 0 (alt 4, two CVSD links' setting, for one CVSD link: wrong) |

The `0` in v2's sequence is the moment when A is gone and B not yet up (no link up in the controller: correct), and the
last `0` is B's hang-up. In v1 the work, having counted no CVSD link before the sleep and no transparent link after it,
selects alt 0 with B up for 0.6 s; alt 2 follows only because B's own notification schedules the work again. The first
transition attempt (`*-c21-transition-*.log`) also showed v2 failing, on the test's own last check (the hang-up of B
was looked at while the debug delay was still applied to the work run it started); the scenario now resets the delay
first (`setdelay(0)`). Those logs are kept.

What the single snapshot does not do: a link change that arrives after the snapshot but before the set-interface call is
still seen only by the next work run (the notification schedules it). The snapshot guarantees that the decision comes
from one consistent set of links, not that no later change exists.

## Mixed CVSD and transparent links: does the transparent alt setting carry a CVSD link?

**Short answer: not by the specification's table, and btusb's own comments do not claim it.** Sources:

1. Core Specification Vol 4 Part B (USB transport), section 2.1, Table 2.1 "USB firmware interface and endpoint settings".
   The pages I could fetch are the 2006 text (version 1.2 or later, 76-page volume), saved in `fetched/`
   (`nefarius-bluetooth-spec-v4.pdf`, from git.nefarius.at `USB-Bluetooth-Specs`, `Bluetooth Spec v4.pdf`; text in
   `spec-v4-vol4-text.txt`, Table 2.1 at its lines 1005-1045). It lists, for interface 1 (isochronous, endpoints 0x83/0x03):

   | alt | contents | max packet |
   |---|---|---|
   | 0 | no active voice channels | 0 |
   | 1 | one voice channel, 8-bit encoding | 9 |
   | 2 | two 8-bit channels, or one 16-bit channel | 17 |
   | 3 | three 8-bit channels | 25 |
   | 4 | two 16-bit channels | 33 |
   | 5 | three 16-bit channels | 49 |

   (The spec's worked example: 3 ms of one 8-bit channel is sent as 9-byte frames, 3 bytes of HCI header and 6 of data.)
   Alt 6 (63 bytes, the transparent/mSBC setting btusb uses where it exists) is not in this older text. The kernel history
   cites it as "core spec 5, vol 4, part B, table 2.1 ... for alt setting 6 the HCI packet interval should be 7.5 ms":
   `fetched/local-git-show-baac6276.txt` (`git show baac6276c0a9`, in the kernel tree) and
   `fetched/f4001d28-dynamic-alt.html` (the commit "Bluetooth: btusb: Dynamic alternate setting", which makes the alt
   setting follow the number of SCO links and the bit depth). I did not get a copy of the current Core 5.x/6.x volume
   (bluetooth.com serves it behind its own pages; my direct requests returned a bot check or an LFS pointer), so
   the alt 6 row is second-hand.
2. btusb (`btusb_work()` on `l6-co21v2`): the CVSD table is `alts[] = { 2, 4, 5 }` for a 16-bit voice setting
   (`voice_setting & 0x0020`) and the link count otherwise, i.e. exactly Table 2.1's channel and bit-depth rows. For a transparent link: alt 6
   if the device has it, alt 3 for devices flagged `BTUSB_USE_ALT3_FOR_WBS` with `sco_mtu >= 72`, else alt 1, with the comment "Alt 1
   appears to work for all adapters that do not have alt 6, and which work with WBS at all". That is a statement about mSBC alone.
3. Arithmetic from the table: a CVSD link with 16-bit voice setting needs 16 bytes per ms (alt 2 and up); alt 1 carries 9.
   An mSBC link needs 60 + 3 bytes per 7.5 ms, about 8.4 bytes per ms, which alt 1 (9) just carries. So with a
   CVSD (8-bit) and an mSBC link together the sum is about 16.4 bytes per ms plus headers (alt 2 or more), with a 16-bit CVSD link about
   24.4 (alt 3 or more). Alt 1 under-provisions both; alt 6 has the room (63 bytes per frame) but the spec ties it to a 7.5 ms
   packet interval for the transparent stream, which a CVSD stream does not follow. I did not find a statement in the pages I have that
   alt 6 may carry a CVSD link.

**The patch's behaviour with both kinds up:** `transp` non-zero selects the transparent setting (alt 6, 3 or 1), as the old code did when the
transparent link was the last notification; the old code chose the CVSD table instead when the CVSD link was last. The new
rule is deterministic, not better for the CVSD link. In the emulator (`mixed`, `co21v2` and `co21v1-dbg` and base alike): alt 1 is chosen, the emulated
controller accepts it; the emulator cannot tell whether a real controller would pass 16-byte-per-ms CVSD frames through a 9-byte alt, so this is not
evidence either way.

**Open for the review, not decided here:** whether btusb should pick a setting that fits the sum when both kinds are
up (for example the larger of the CVSD table value for `cvsd` links and one step above the transparent setting), or keep the
transparent setting and say in the message that a mixed set is not served correctly. The cover letter states the question.
No code for it is written. A hardware test would need two links of different air modes on a controller that supports both.

## checkpatch `--strict --no-tree`

0001 and 0002: only `ERROR: Missing Signed-off-by: line(s)` (`total: 1 errors, 0 warnings, 0 checks`, 68 and 69 lines).

## Bot CI

See the end of this file (appended after the run).

### Bot CI (run locally, out/bot-results/co21/)

Same setup, base da3cc02587c6. Patched: CheckPatch, VerifySignedoff, GitLint FAIL (only the missing Signed-off-by);
VerifyFixes FAIL ("Target SHA should be an ancestor of your tree": partial history; it passes with the full history, see
send-20261114/CHECKS.md); SubjectPrefix, BuildKernel, CheckAllWarning, BuildKernel32, CheckKernelLLVM, TestRunnerSetup,
IncrementalBuild PASS; CheckSparse WARNING, the same on the base (a "note: in included file" line for hci_event.c).
All 11 TestRunner testers PASS on both sides with identical not-passed sets (compare-*.txt); kernel-report-scan exit 0.
So the cover letter's "sco-tester results are the same with and without it" holds for this version too.
