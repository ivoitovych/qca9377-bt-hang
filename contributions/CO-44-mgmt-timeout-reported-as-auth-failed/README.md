# CO-44 — MGMT: a command timeout is reported as "Authentication Failed" (BT-21)

**What:** `mgmt_errno_status()` (`net/bluetooth/mgmt.c`) maps `-ETIMEDOUT` to
`MGMT_STATUS_AUTH_FAILED` (0x05). At the laptop's BT-17 incident (2026-11-12 18:03), the
controller did not answer the kernel's Write Class of Device, and bluetoothd logged "Failed to
remove UUID: Authentication Failed (0x05)" three times, although no authentication took
place (`results/incident-2026-11-12-1803/`). `MGMT_STATUS_TIMEOUT` (0x08) exists, and the
HCI-status table in the same file already uses it for Connection Timeout, Host Timeout and
Directed Advertising Timeout.

- **Origin:** `161510ccf91c` ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1",
  Luiz Augusto von Dentz, 2021-10-27, v5.17-rc1) added the errno table with this entry and
  gives no reason for it (third outside review of BT-17, checked with `git show`).
- **Present in:** bluetooth-next `da3cc0258` (2026-11-12) and Ubuntu's `7.0.0-42`/`-43`.

**State (2026-11-13): patch written and tested in QEMU; nothing sent.**

- **The patch:** `patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`,
  one line, `Fixes: 161510ccf91c`. No Signed-off-by: the operator adds his own.
  checkpatch `--strict --no-tree`: only the missing Signed-off-by, and "Unknown commit id"
  because it ran without a tree.
- **The test:** `patch/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch` (`[PATCH BlueZ]`
  on master `20ffd285b`; the same change as `patch/bluez-mgmt-tester-set-dev-class-timeout.diff`), a new mgmt-tester case,
  "Set Device Class - Timeout 1". Its emulated controller drops Write Class of Device (a
  `HCIEMU_HOOK_PRE_CMD` hook returning false, `emulator/btdev.c:8742-8744`). It expects
  `MGMT_STATUS_TIMEOUT`.
- **Measured** (BlueZ `doc/tester.config` kernels, base `da3cc0258` and patched):

  | tester | base | patched |
  |---|---|---|
  | new case | fails: "Unexpected status got Authentication Failed (0x05) expected Timeout (0x08)" | passes (2.050 s) |
  | mgmt-tester, all 527 | 526 passed, 1 failed (the new case) | 527 passed |
  | l2cap-tester | 144 passed | 144 passed |
  | smp-tester | 8 passed | 8 passed |

- **Reach of the change** (an audit of every path into `mgmt_errno_status()`):
  - The sync-queued MGMT commands (Set Powered, Set Device Class, Add/Remove UUID,
    Discovery, Advertising, …) get 0x08 instead of 0x05 when the controller does not answer.
    bluetoothd only logs the text for them (`mgmt_errstr()`).
  - Pairing paths take positive HCI statuses through the HCI table, not this function, so
    they are unchanged; the seven `AUTH_FAILED` expectations in mgmt-tester (pairing
    rejects) still pass.
  - BlueZ already treats 0x08 as a timeout (`src/device.c:3493` maps it to
    "AuthenticationTimeout").
  - A grep of BlueZ's `src`, `profiles`, `plugins` and `tools/btmgmt.c` found nothing that
    depends on 0x05 for a timeout.
- **One other case changes status, with the same verdict:** mgmt-tester "Get Conn Info -
  Power off".
  - The kernel's Read RSSI (`0x1405`) times out during the power-off, and Get Connection
    Information is answered `0x05` on base, `0x08` patched.
  - The test expects `0x0f` Not Powered, logs "Unexpected status got 5 expected 15" (base) or
    "got 8 expected 15" (patched), and **passes anyway**: this test only logs a wrong status.
  - So the patch changes this case too, and the test cannot tell. That is by design: the case
    is declared `fail_tolerant = true` (`tools/mgmt-tester.c`, `get_conn_info_power_off_test`),
    since the emulated controller is powered off under the pending Read RSSI. Not a defect
    signal.
  - With the patch, the reply there reads "Timeout" instead of "Authentication Failed",
    which is the more accurate of the two.
- **Logs:** `logs/excerpt.txt` (the new case's lines and every tester's totals, with each full
  log's SHA-256). The full logs stay local in `agent-work/bt17-mgmt-timeout/logs/` with
  `SHA256SUMS`: they carry the emulated controllers' addresses, which the publishing scan
  cannot tell from real ones.
- **Seen on the way, not fixed:** `unpair_device_complete()` (`mgmt.c:3134`) passes the
  raw negative `err` to `cmd_complete` instead of `mgmt_status(err)`; not traced.

**The list's CI bot, run locally on the kernel patch** (`tmp/bot-ci-local/co44-20261113/`):
- **Passes:** BuildKernel, BuildKernel32, CheckAllWarning, CheckSparse, CheckKernelLLVM,
  IncrementalBuild, SubjectPrefix, TestRunnerSetup.
- **Testers:** `TestRunner_mgmt-tester` passes on both sides, with identical not-passed
  sets (the bot's BlueZ master, without our new case). The kernel-report scan is clean.
- **CheckPatch, VerifySignedoff, GitLint:** fail only for the missing Signed-off-by.
- **VerifyFixes:**
  - first "Target SHA1 does not exist": an artifact of the runner's history limit (2023);
  - rerun with history from 2021-06 (`co44-verifyfixes-20261113/`): only "empty lines
    surround the Fixes tag", because `Fixes:` is the message's last line. The operator's
    Signed-off-by goes directly under it.
- **The base side's one non-pass,** `Mesh - Send cancel - 1`, failed once on the unpatched
  base and passed patched: unrelated to this change (mesh, M-1).

**The list's CI bot, run locally on the BlueZ test** (`--space user`, master `20ffd285b`, the
patched kernel image; `tmp/bot-ci-local/co44-bluez-20261113/`): every check passes on both
sides, 0 not PASS. Patched: CheckPatch, GitLint, BuildEll, BluezMake, CheckSmatch,
bluezmakeextell, TestFunctional, IncrementalBuild, ScanBuild. Base: the same six tree checks.
The bot's user-space checks do not run mgmt-tester; the new case's runs are the table above.

**Next:**
- the kernel patch and the BlueZ test as two sends, the test noting that it needs the kernel fix;
- the operator's word for both.

**Decides:** the operator, for the send.
