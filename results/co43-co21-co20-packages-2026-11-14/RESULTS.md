# Task 3: the CO-43 series on top of E, the CO-21 send package, the CO-20 patches (2026-11-14)

All kernels ran in QEMU guests (4 CPUs, KASAN, lockdep) or in the list bot's Docker image; nothing touched the
host's Bluetooth; nothing was sent. Raw logs `logs/runs/` (`logs/SHA256SUMS`, bot results
`logs/SHA256SUMS-bot`), batch summaries `logs/summary-*.txt`, `logs/metrics.txt`. Harness: `harness/`.
Kernel tree `../lx` (branches below), images `../img/`.

## 1. The CO-43 series rebased on E (`step1/series/`)

Base: bluetooth-next `da3cc02587c6` + E ("Bluetooth: btusb: Anchor a deferred URB under txlock", the E package's
patch, applied unchanged with `git am`). On it, in this order (branch `lane1-s3f`, `lane1-s3` before one
cosmetic change):

| # | subject |
|---|---|
| 0001 | Bluetooth: btusb: Report a failed runtime resume for deferred data (A, the send package's text; applied clean) |
| 0002 | Bluetooth: btusb: Don't wait for a resume in the HCI command timeout (B2) |
| 0003 | Bluetooth: btusb: Recover after a runtime reset-resume (D v2) |
| 0004 | Bluetooth: btusb: Drop deferred URBs under txlock on a failed resume (BT-24) |
| 0005 | Bluetooth: btusb: Free the skb of a deferred URB that is discarded (BT-25) |

`0000-cover-letter.patch` states: "applies on top of 'Bluetooth: btusb: Anchor a deferred URB under txlock'" and
the dependency of 0002 on 0003. **BT-24's fix belongs after B2**, not before: without B2 the command credit comes
back only after the failed resume's path has ended, so the window it closes cannot be reached (task 2: `e-kml-dbg`
bt24 runs found the anchor empty 3/3); it touches the same `done` block as B2's flag clearing.

**What the rebase changed (conflicts I resolved):**
- B2 against E, in `submit_or_queue_tx_urb()`: E anchors in the `else` of `if (!suspending)`; B2 adds the
  command flag there. Resolved as `if (!suspending) {...} else { usb_anchor_urb(); if (HCI command) set_bit(); }`.
  checkpatch `--strict` first said `CHECK: Unbalanced braces around else statement` on this (the `if` had no
  braces); I added them, rebuilt (`s3f`, `harness/build-kernel.sh s3f`) and re-ran one of every scenario.
- BT-24 (0004) against B2: B2's `clear_bit(BTUSB_CMD_DEFERRED)` sits in the same `done:` block; both kept, the
  scuttle first.
- BT-25 (0005) against B2: three sites also carry B2's flag clearing (`btusb_close()`, `play_deferred()`,
  `btusb_resume()`); both kept.
- Nothing else changed in the code of the five patches; their messages are those of task 2, B2's and D's unchanged.

**Runtime matrix on E + the full stack** (`harness/gen-spec.sh harness/spec-s3-matrix.txt s3 1 3 s`,
`harness/run-batch.sh`, `logs/summary-s3-matrix.txt`; 3 runs of each scenario): **18/18 PASS**, `batch: 18 runs, 0 FAIL`.

| scenario | `s3` (E + A, B2, D v2, BT-24, BT-25) |
|---|---|
| dead device | 3/3 |
| recovering device | 3/3 |
| power-off-started resume | 3/3 |
| dropcmd | 3/3 |
| dropcmd-wedge | 3/3 |
| healthy cycles (30 each) | 3/3 |

The same scenarios on `ab2dv2` (task 2: A + B2 + D v2 without E, BT-24, BT-25) were 18/18, so the rebase
changed nothing in what they measure. `s3f` (the brace fix) one of each: 6/6 (`logs/summary-s3f-sample.txt`).
No kernel report in any run (`logs/metrics.txt`, `kreports=0` for every log).
checkpatch `--strict --no-tree` on 0001 to 0005: only `Missing Signed-off-by`, and the unknown-commit-id warning
for the `Fixes:` tags of 0004 and 0005 (both ids verified in the history).

## 2. CO-21 send package (`co21-package/`)

Patches on `da3cc02587c6` (rebased from `42b8c2d72926` without a conflict), patch 2's subject shortened to 65
characters, old Signed-off-by lines removed. Package: patches, `recipients.txt`, `CHECKS.md`,
`NOTES-FOR-OPERATOR.md`, `cover-letter.txt`.

| | result |
|---|---|
| five usbip scenarios, base vs patched, 2 runs each (`logs/summary-co21.txt`) | base 0/10, patched 10/10 |
| checkpatch `--strict` (bot image) | only `Missing Signed-off-by` on each |
| bot (local), patched | builds, CheckAllWarning, CheckKernelLLVM, BuildKernel32, SubjectPrefix, IncrementalBuild, TestRunnerSetup and all 11 testers PASS; CheckSparse WARNING (same output on the base); CheckPatch, VerifySignedoff, GitLint FAIL on the missing Signed-off-by only; VerifyFixes FAIL "Target SHA should be an ancestor of your tree" (the project's partial history) |
| VerifyFixes with full history (`harness/verifyfixes-full.sh`) | fails only "empty lines surround the Fixes tag" without a Signed-off-by, passes with it after `Fixes:` |
| tester not-passed sets patched vs base | identical for every tester (0 and 0); every tester log `clean` |
| GitLint title length | no complaint on the 65-character title; the README's "81 characters" was not reproduced (the old title measures 75) |

`NOTES-FOR-OPERATOR.md` carries the decisions: `Cc: stable` (our reading: no; patch 1 adds a field to `struct
hci_conn` and patch 2 cannot build without it, so a plain Cc on patch 2 would be wrong), the shortened subject,
the cover letter, the recipients (four blamed-fixes authors on patch 2), Hitalo Souza's pending series (state as of
11-11, not re-read), the laptop test.

## 3. CO-20 (`co20-package/`)

The 2026-11-11 prototype, converted to `btusb_main.c`, applied to the tip: clean. Two patches ("Report SCO
receive failures by cause"; "Log SCO data for a just closed link at debug level"). Mainline's newline fix
`f51ee3bb5fbe` is already in the tip.

Emulator (`harness/usbip-bt-emu.py`, now with a judge of the kernel's SCO receive messages):

| scenario | base | patched |
|---|---|---|
| `rx-cycles` (20 calls with data in flight at the hang-up), 3 runs | "corrupted SCO packet" 17, 19, 24 | 0 corrupted, 0 unknown, 15 to 18 debug lines |
| `rx-unknown` (five injected packets for a handle that never was a link, two links up), 4 base and 8 patched runs | "corrupted" 7, 7, 6, 6 | "unknown handle dropped" 5 to 7, none "corrupted" |

Not clean runs, reported: the first batch had 3 FAIL of 12: the base `rx-cycles-2` lost its emulator socket
(`OSError 77`, no verdict; rerun as `2b`), and the patched `rx-unknown-2` and `-3` failed my first judge, which
demanded exactly five (they showed 6: data of the link that closed first, which patch 2's message names as still
reported). The judge was relaxed to "at least five, none corrupted" and the cases rerun (`-r1` to `-r5`:
7 runs, 0 FAIL). The first logs are kept.
checkpatch `--strict`: only the missing Signed-off-by. Bot, patched: builds, CheckAllWarning, CheckSparse,
BuildKernel32, CheckKernelLLVM, TestRunnerSetup, IncrementalBuild, SubjectPrefix and VerifyFixes (no tag) PASS;
CheckPatch, VerifySignedoff and GitLint fail only on the missing Signed-off-by; base all PASS. The bot selects no
tester for a btusb-only change.

## Open, and things to know

- The package files are not "send-ready" until you add your Signed-off-by (each NOTES file says where).
- CO-21: Hitalo Souza's series state (11-11) not re-read; the laptop test needs both modules built together.
- CO-20: the heuristic of patch 2 is a design choice for the maintainers to weigh; the core's own "unknown
  connection handle" lines are untouched; the laptop numbers in the cover letter are the README's, not re-measured.
- B2 stays dependent on D; D's system-resume path is still source-reading only.
- **Disk:** it fell to 23 GB free during the bot run; I deleted the bot's `work/` trees and my kmemleak build
  directory (`build/kobj-kml`), and it was back at 29 GB. My work directory holds about 4 GB (`lx` 1.9 GB,
  `build/kobj` 0.8 GB, `img` 0.2 GB, `task3/project`).
- **Helper scripts:** the project clone's `scripts/bot-ci-local.sh` carries the three local changes of the CO-43 E
  package and a read-only mount of the tree's object-store alternates (each marked in the file); the stop-process
  helper refused my own batch scripts, so one chain was stopped with the harness' task-stop tool before it could
  start a second guest beside the bot's.
- Per your note: every script with a shebang is executable and none contains a session-temporary path (the
  chain scripts of task 2 that had one were fixed: they now wait on summary files).
