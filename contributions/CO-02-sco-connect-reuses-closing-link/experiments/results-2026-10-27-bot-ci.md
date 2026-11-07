# CO-02 v7 — the list's CI bot, run here with its own code and image (2026-10-27)

**Question:** will the linux-bluetooth CI bot report anything on v7's two mails, and if so, is it
ours? The bot posts one check per test on patchwork for every patch. A failure there is public
and would arrive with no context. So before the send, the bot's own checks ran here, on the
mails as they will be sent, on the base and on base plus the mails. Only the difference counts.

## What was run
- **The bot's source:** `github.com/bluez/action-ci`, `main` at `60348956fc7b` (2026-09-15).
  It is the action that both the bluetooth-next and the BlueZ workflow name
  (`bluez/bluetooth-next`, branch `workflow`, `.github/workflows/ci.yml`:
  `uses: bluez/action-ci@main`, read 2026-10-27).
  - Its check list matches what the bot posted on patchwork over the last days
    (`scripts/patchwork-checks.sh 40`, 2026-10-27). For kernel patches that is BuildKernel,
    BuildKernel32, CheckAllWarning, CheckKernelLLVM, CheckPatch, CheckSparse, GitLint,
    IncrementalBuild, SubjectPrefix, TestRunnerSetup, `TestRunner_*`, VerifyFixes and
    VerifySignedoff. For `hci_conn.c` it runs all 11 testers, as on "Bluetooth: hci_conn:
    Initialize the device before hash insertion" (patch 14912235, 2026-10-24).
  - Correction: `cache/action-ci` is a clone of the old fork `BluezTestBot/action-ci`
    (2024-11-12). Read by mistake earlier on 2026-10-27, it lacks CheckKernelLLVM, the 11th
    tester (`6lowpan-tester`) and the ASan TestRunner build. It had also made `ci-local.sh`
    skip VerifyFixes and VerifySignedoff; fixed the same day.
- **The image:** `bluez-action-ci:60348956fc7b`, built from that commit's Dockerfile.
  - Base image: `FROM ghcr.io/pv/bluez-ci-image:latest@sha256:8d31a3fca8392a6ef194c8c21d05637a619c02d6f94820fdf50be7b7b8c0a191`.
  - Ubuntu 26.04, gcc 15.2.0; clang 23.1.0 (`/opt/llvm`); sparse at `37156835e3d7` and smatch
    at `5e13a0ee549b`, as that Dockerfile pins them; checkpatch from Linus's master at image
    build time.
- **The tool:** `scripts/bot-ci-local.sh` with `scripts/bot-ci-local/harness.py`.
  - The bot's `create_test_list_kernel()` / `create_test_list_user()` and each check's own
    `run()`/`post_run()` run unchanged, with `dry_run`.
  - The patchwork calls are answered from the mail files. A `post_check` raises, so nothing can
    be posted.
  - The trees are prepared as in the bot's workspace: `origin/master` is the base, and HEAD is a
    merge whose second parent is the series.
  - `make -j4`, as the bot's real runs (its `-j` default; only its `localci` task passes `auto`).
- **Bases:** bluetooth-next `47d4d9f67e92` and BlueZ master `b0bf49270d44`, both still the
  heads at 12:55 UTC (`git ls-remote`); ELL `002b32d7c091`.
- **The mails:**
  - kernel: `patch/v7-candidate/send/kernel/0001` to `0003`, as committed;
  - BlueZ: `patch/v7-candidate/send/bluez/0001`, with the placeholder replaced by a lore link of
    the form fill-bluez-link.sh writes
    (`tmp/co02-v7ci/bluez-mail/`; `diff` against the package shows only line 34).

## Kernel series
Commands:
- `scripts/bot-ci-local.sh --tree cache/co02-v7-kernel --base 47d4d9f67e92 --bluez-commit b0bf49270d44 --out tmp/co02-v7ci/bot-full <0001..0003>`;
- then `--side patched --only CheckPatch,VerifyFixes,VerifySignedoff,GitLint,SubjectPrefix --out tmp/co02-v7ci/bot-verifyfixes`.

| check | v7 | base |
|---|---|---|
| CheckPatch, GitLint, SubjectPrefix, VerifySignedoff | PASS | — |
| VerifyFixes | PASS (second run) | — |
| BuildKernel, CheckAllWarning (W=1), CheckSparse, BuildKernel32 | PASS | PASS |
| CheckKernelLLVM (clang 23.1, W=1, `CONFIG_WARN_CONTEXT_ANALYSIS=y`, `CONFIG_WERROR=y`) | PASS | PASS |
| TestRunnerSetup (BlueZ with ASan, `doc/tester.config` kernel) | PASS | PASS |
| `TestRunner_` l2cap, iso, bnep, mgmt, rfcomm, sco, ioctl, mesh, smp, userchan, 6lowpan | 11 × PASS | 11 × PASS |
| IncrementalBuild (each patch built in order) | PASS | — |

- **Testers compared by case** (`scripts/compare-tester-verdicts.py`): 10 testers have
  identical verdict sets, with 0 not passed on either side.
- **ioctl-tester** cannot be compared by name: upstream has two cases named "Set Pkt Type - 2-DH"
  (`BT-12`). It passed 28 of 28 on both sides; the two logs list the same 28 lines.
- **Kernel reports:** `scripts/kernel-report-scan.py` on all 22 tester logs gives `clean`. The
  base runs booted `7.3.0-rc6-01698-g47d4d9f67e92`, the v7 runs `7.3.0-rc6-01702-g79e9a9a053d6`
  (the merge commit, as the bot builds it).
- **Sparse really ran:** 66 `CHECK` lines, `net/bluetooth/hci_conn.c` among them. The host's
  sparse had been skipped silently by the kernel in earlier runs (`ci-local.sh` warned "no CHECK
  line").
- **The clang build compiled the file:** `CC net/bluetooth/hci_conn.o` appears in
  `CheckKernelLLVM.log`.
- **VerifyFixes failed in the first run, and the cause was this machine:**
  - It reported "Target SHA should be an ancestor of your tree" for all three Fixes: tags, with
    `error: Could not read 10d97b74e2ee` (a mainline merge of 2026-04-12, absent from the
    project's partial-clone kernel repository).
  - The second run used a blobless clone of bluetooth-next with complete history since
    2023-01-01: PASS.
  - The first run shows that the harness passes a VerifyFixes failure through as the bot would.

## BlueZ test
Command: `scripts/bot-ci-local.sh --space user --base b0bf49270d44 --kernel-image tmp/co02-v7ci/bzImage-bot-base-47d4d9f67e92 --out tmp/co02-v7ci/bot-bluez-j4 tmp/co02-v7ci/bluez-mail/0001-…patch`.
The bzImage is the bot-built `doc/tester.config` kernel of the base above. TestFunctional
otherwise clones bluetooth-next master, which is the same commit, and builds it with that config.

| check | with the test | master |
|---|---|---|
| CheckPatch, GitLint | PASS | — |
| BuildEll, BluezMake, bluezmakeextell | PASS | PASS |
| CheckSmatch | WARNING | WARNING (the same) |
| TestFunctional (49 tests: 0 failures, 0 errors, 1 skipped) | PASS | PASS |
| IncrementalBuild | PASS | — |
| ScanBuild | PASS | PASS |

- **The CheckSmatch WARNING is upstream's.** The bot reports smatch lines for the files a series
  touches, including lines from headers they include. For `tools/sco-tester.c` that is
  `./lib/bluetooth/bluetooth.h:232:15` and `:237:31: warning: array of flexible structures`.
  - Nothing is reported in `sco-tester.c` itself.
  - The base run, without the test, prints the same: its `Output String` line in
    `base/CheckSmatch.log` is identical to the patched side's.
  - The bot posts `CheckSmatch:warning` on unrelated BlueZ patches too, e.g. 14917102
    "advertising: Fix leaking clients…" and 14916993 "monitor: validate Return Link Keys…".
- **The unit tests are skipped by design.** The bot's file-mapping gives `tools/` no unit tests,
  so MakeCheck, MakeDistcheck and CheckValgrind are not in its list.
- **The bot's ScanBuild compares the patched tree with itself** (`ci/scanbuild.py` never checks
  out the base). It can report only a build failure or a nondeterministic finding.
- **A first attempt with `-j16` failed BuildEll.** ELL's test-certificate generation stopped
  (`unit/cert-intca.pem`, `tmp/co02-v7ci/bot-bluez/patched/BuildEll.log`). It passes with the
  bot's `-j4`, so that failure was this harness's job count.

## Not covered here
- **`sashiko-nipa`:** a separate automated reviewer that now also posts on linux-bluetooth
  patchwork, with a link to `netdev-ai.bots.linux.dev/sashiko/`. It is open source
  (`github.com/sashiko-dev/sashiko`) but needs a language-model service, so it was not run.
- **pre-ci_am:** the bot's sync job applies the series to bluetooth-next master. Here the same
  `git am` onto the same commit succeeded.
- **The bot's own GitHub runner:** 4 vCPUs, with KVM since 2026-09-15 (`action-ci` `835f93f`).
  Here: 16 CPUs, KVM. The testers' timing could differ.
