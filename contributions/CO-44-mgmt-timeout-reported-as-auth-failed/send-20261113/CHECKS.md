# CO-44 send package: every check, its command and its result (2026-11-13)

Work directory `W=/root/exp/agent-work/co44-send-20261113`. Scripts in `$W/scripts/`, logs in
`$W/logs/`. Nothing was sent, posted or mailed.

## Tips used

| tree | tip | source |
|---|---|---|
| bluetooth-next `master` | `da3cc02587c629420603df4395179ec82955c941` "Bluetooth: hci_vhci: Report write readiness with queued input" (2026-11-12) | `git ls-remote` of git.kernel.org; objects from the GitHub mirror `bluez/bluetooth-next`, same id |
| bluetooth `master` | `3b069de8a5d688c7e8381b99d6cdb7467fcae0de` "Bluetooth: L2CAP: Fix size check for receive buffer space" (2026-11-12) | git.kernel.org, fetched |
| BlueZ `master` | `20ffd285b58facfd1f2478d159a5f941b09d5be1` "shared/gatt-client: Track pending discovery Database Hash reads" (2026-11-12) | git.kernel.org, fetched |
| ELL `master` | `002b32d7c091993c5036956bf92d2444aca1c799` "Release 0.83" | fetched |
| bot image | `bluez-action-ci:c7d077f185cd` (bluez/action-ci `main` `c7d077f185cd`, new on 2026-11-12; base `ghcr.io/pv/bluez-ci-image@sha256:8d31a3fc…`) | fetched |

Fetched 2026-11-13 18:57–19:09 UTC (`logs/kernel-tips.txt`, `logs/bluez-tips.txt`). Both
bluetooth-next and BlueZ master are the same commits the dossier tested on; bluetooth `master`
moved since the project's cache (`11701044c532`, 2026-10-30).

A full clone of bluetooth-next from git.kernel.org was reset mid-transfer ("RPC failed; curl 56
Recv failure: Connection reset by peer"), so the local tree is a treeless clone of the GitHub
mirror (history since 2021-06-01, so `161510ccf91c` resolves), with the tip id checked against
kernel.org's `ls-remote`.

## Kernel patch

**Commits:** `b7df6ff0a817` on bluetooth-next `da3cc0258`; the mail is `git format-patch -1
--base=da3cc0258`, with the below-`---` text put in by `scripts/insert-below-line.py`.

| check | command | result |
|---|---|---|
| applies to bluetooth-next | `git am` on `da3cc0258` (`scripts/kernel-prepare.sh`, `logs/kernel-prepare.txt`) | applied, `net/bluetooth/mgmt.c | 2 +-` |
| applies to bluetooth | `git am package/kernel/0001-…patch` on `3b069de8a5d6` (worktree `$W/linux-bt`) | applied; result `856cc4c0b7c6`; the same line 297 in both trees; `git log -1 --format=%B` shows the message ends at `Link:` (the note below `---` is dropped) |
| the cited code is the same in both trees | `git grep` of `create_le_conn_complete`, `hci_conn_failed(conn, bt_status(err))`, the table's Connection/Host Timeout entries, `lib.c`'s `ETIMEDOUT` cases | identical: `bt_to_errno()` returns `ETIMEDOUT` only for 0x08 and 0x10; `bt_status(-ETIMEDOUT)` is 0x08 |
| checkpatch `--strict` | `scripts/kernel-tree-checks.sh` → `scripts/checkpatch.pl --strict` from inside the tree at `b7df6ff0a817` | `ERROR: Missing Signed-off-by: line(s)`, `total: 1 errors, 0 warnings, 0 checks` (`logs/final-kernel-checkpatch.txt`). No "Unknown commit id": the `Fixes:` commit resolves |
| checkpatch control | the same on a local copy with a Signed-off-by line added (`controls/kernel-with-sob-local-check-only.patch`, never to be sent) | `total: 0 errors, 0 warnings, 0 checks` … "no obvious style problems" |
| recipients | `scripts/get_maintainer.pl` on the packaged mail | Marcel Holtmann, Luiz Augusto von Dentz (maintainers; both `blamed_fixes`), linux-bluetooth, linux-kernel (`recipients-kernel.txt`) |
| `Link:` target exists | lore web answers 403 here (`curl … /raw` → `403`); lore's git archive (`git grep … e9acdab51 -- m`: Message-Id, subject, "returns Authentication Failed because disconnection takes too long."); patchwork API `?msgid=…` | patchwork `12951690`, "[Bluez,v2] adapter: Reset pending settings when receiving MGMT error", accepted, BlueZ `ede7b915980f` (`logs/link-check-patchwork-12951690.json`) |
| Fixes: target | `git log -1 161510ccf91c` | "Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1", Luiz Augusto von Dentz, 2021-10-27 — the subject in the tag is exact |

### Testers in QEMU (BlueZ `doc/tester.config` kernels)

Built by `scripts/build-kernels.sh` with BlueZ master's `doc/tester.config` + `olddefconfig`:
base `da3cc02587c6` (`bzImage-base`, sha256 `bd38430d…`), patched `b7df6ff0a817`
(`bzImage-patched`, sha256 `c5ea91ce…`); no warning in either build log. BlueZ: master + the
new test (`co44-test`, `0e5d0c431cb1`), `./bootstrap-configure --disable-lsan`, no warning.
Run by `scripts/run-testers.sh` through `tools/test-runner`; judged by the project's
`compare-tester-verdicts.py` and `kernel-report-scan.py` (`logs/testers-analysis.txt`, with
every log's SHA-256).

| tester | base | patched | difference |
|---|---|---|---|
| mgmt-tester (527) | 526 passed, 1 failed | 527 passed | only "Set Device Class - Timeout 1": Failed → Passed |
| l2cap-tester (144) | 144 passed | 144 passed | none |
| smp-tester (8) | 8 passed | 8 passed | none |
| kernel reports (13 kinds) | clean, `7.3.0-gda3cc02587c6` | clean, `7.3.0-gb7df6ff0a817` | — |

- **The new case, base:** "Dropping HCI command" → `Opcode 0x0c24 failed: -110` → "Unexpected
  status got Authentication Failed (0x05) expected Timeout (0x08)" → test failed (2.050 s).
- **Patched:** the same drop and timeout → "Set Dev Class (0x000e): Timeout (0x08)" → "Test
  condition complete, 0 left" → test passed (2.032 s). The hook fired once in the whole run.
- **"Get Conn Info - Power off"** (`fail_tolerant = true`): Read RSSI `0x1405` times out;
  "Unexpected status got 5 expected 15" on base, "got 8 expected 15" patched; passed on both.
- "Unexpected status got 15 expected 14" (another case) is in both logs at the same line: not
  ours, unchanged.

## BlueZ test

**Commit** `0e5d0c431cb1` on master `20ffd285b`; mail `git format-patch -1 --subject-prefix="PATCH
BlueZ" --base=origin/master`, the below-`---` text put in by `scripts/insert-below-line.py`.

- **Reviewer 2's point, done in the neighbours' style:** the test adds a condition before
  registering the hook, and the hook completes it (as `test_adv_enable_hook()` does), so the test
  cannot pass unless Write Class of Device was sent and dropped.
- **Negative control** (`scripts/control-no-condition.sh`, `controls/control-no-condition.txt`):
  a scratch build whose hook drops the command but does not complete the condition, full
  mgmt-tester on the patched kernel: "Set Device Class - Timeout 1" **Timed out** (527 cases,
  526 passed), every other verdict as in the real run. Source restored and rebuilt afterwards;
  `git status` clean.
- **Base and patched kernels:** the tester table above (the same runs).

## The list's CI bot, run locally on the kernel mail

`scripts/bot-ci-local.sh` (from a clone of the project in `$W/project`, `--cache $W/cache`), image
`bluez-action-ci:c7d077f185cd`, base `da3cc02587c6`, BlueZ `20ffd285b`, ELL `002b32d7`,
`--history-since 2021-06-01` for VerifyFixes. Wrappers `scripts/bot-kernel.sh` and
`scripts/bot-kernel-base.sh`; outputs in `$W/project/tmp/bot-ci-local/co44-kernel-send-20261113/`
(patched) and `…-base/` (base). Their `work/` trees were deleted once the summaries and reports
existed.

| check | base | patched | reason for a non-pass |
|---|---|---|---|
| CheckPatch | — | FAIL | `ERROR: Missing Signed-off-by: line(s)` only (0 warnings, 0 checks) |
| VerifyFixes | — | PASS | (the dossier's run had "empty lines surround the Fixes tag"; the `Link:` line now follows `Fixes:`) |
| VerifySignedoff | — | FAIL | "author Signed-off-by missing / committer Signed-off-by missing" only |
| GitLint | — | FAIL | `CC1 Body does not contain a 'Signed-off-by' line` only |
| SubjectPrefix | — | PASS | |
| BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM | PASS | PASS | |
| TestRunnerSetup | PASS | PASS | |
| TestRunner_mgmt-tester (BlueZ master, 526 cases, without our new case) | PASS, 526/526 | PASS, 526/526 | `compare-tester-verdicts.py`: 0 cases differ, not-passed sets identical |
| TestRunner_mesh-tester (10) | PASS, 10/10 | PASS, 10/10 | identical (the dossier's run had one unrelated base-side mesh failure; not today) |
| IncrementalBuild | — | PASS | |
| kernel-report-scan of the four TestRunner logs | clean | clean | |

**The difference:** only the three Signed-off-by checks, all from the line you add; the control
in the kernel table shows checkpatch clean once it is there.

**One run problem, not the patch's:** the first run's base workspace failed ("could not fetch
1e14f023db71… from promisor remote"): the bot's `--shared` clone of my treeless kernel clone
lacked objects. The base side was rerun alone (`--side base`) with the patched side's own complete
bluetooth-next clone as `--tree`, same base commit; the comparison above is between those two runs
(`…-base/compare-split-run.txt`, `scripts/compare-bot-kernel.sh`).

## The list's CI bot, run locally on the BlueZ mail

`scripts/bot-ci-local.sh --space user` (wrapper `scripts/bot-bluez.sh`), image
`bluez-action-ci:c7d077f185cd`, base BlueZ `20ffd285b`, ELL `002b32d7`, TestFunctional booting
the patched tester.config kernel (`b7df6ff0a817`). Output
`$W/project/tmp/bot-ci-local/co44-bluez-send-20261113/`; `work/` deleted afterwards.

| check | base | patched |
|---|---|---|
| CheckPatch | — | PASS (no "Unknown commit id": the message names the kernel fix by subject, not by id) |
| GitLint | — | PASS |
| BuildEll, BluezMake, CheckSmatch, bluezmakeextell, TestFunctional, ScanBuild | PASS | PASS |
| IncrementalBuild | — | PASS |

0 not PASS on either side. The bot's user-space checks do not run mgmt-tester; the new case's
own runs are the tester table above. (ScanBuild, per the script's header, compares the patched
tree with itself.)

## The checked mails

Every check above ran on these exact files (the bot runs on byte-identical copies in
`$W/project/tmp/co44-mails/`):

```
8a265e321fc37c1a8b3f434764826ec0ca933968a59b0dd57aacaf51c7686fd9  kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
f50518d35c97bc73a1c88cf422a69e7fc84c87ae25b64ad6f5b2aa66cd6f5956  bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch
```

Adding your Signed-off-by (kernel) and the lore link (BlueZ) changes them; nothing else may.
A wording scan of both mails (`grep -i` for tool or assistant names, review, laptop, family,
household, private, public) found nothing.

## Dry runs of git send-email (2026-11-14)

Run from the project checkout with `dry-run-20261114/run.sh`, which applies the commands of
`send-commands.txt` with `--dry-run --confirm=never`. Four forms, four `Result: OK`
(`dry-run-20261114/dry-run-co44-*.txt`); the RCPT TO lines match `send-commands.txt`.
