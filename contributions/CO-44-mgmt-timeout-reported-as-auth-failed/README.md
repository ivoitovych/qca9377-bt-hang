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

**Four outside reviews** (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`):
- **All four agree on the fix and on `Fixes: 161510ccf91c`.**
- **The missing half, confirmed:** `mgmt_errno_status()` has no `-EACCES` case. So a sync
  command that the controller answers with HCI Authentication Failure (`-bt_to_errno(0x05)` =
  `-EACCES`, `hci_sync.c:189`) is reported as `MGMT_STATUS_FAILED`.
  - **To decide:** add `-EACCES → MGMT_STATUS_AUTH_FAILED`, with a second test, once it is
    traced which commands can receive `0x05` that way.
  - **Traced (2026-11-13, the checks file, finding 9):** `bt_to_errno()` maps both
    Authentication Failure (`0x05`) and Pairing Not Allowed (`0x18`) to `EACCES`. The
    HCI-status table maps them to `AUTH_FAILED` and `REJECTED`, so no single `-EACCES` case
    is right. `ETIMEDOUT`, by contrast, comes only from Connection Timeout (`0x08`),
    Connection Accept Timeout (`0x10`) or no answer.
    - The table says `TIMEOUT` for both HCI codes.
    - "No answer" is not a table entry: it reaches the errno path directly.
    - So the patch makes that path agree with the table's timeout entries. (Wording
      corrected after outside reviewer 7.)
    - **Recommendation:** CO-44 stays one line, without the `-EACCES` case.
    - **Below the `---`:** the patch makes the errno path agree with the table.
- **Stable:** split. Two reviewers say yes; one leaves it to the maintainers; one says skip
  `Cc: stable` and state below the `---` that a user-visible status changes.
- **The BlueZ test:**
  - check that the hook actually saw Write Class of Device;
  - send it only after the kernel patch has landed, or the list's CI fails it.
- **A fifth review (reviewer 7)** found no blocker in either patch. It verified
  `161510ccf91c` itself and calls the fix a reasonable stable candidate after normal review.
  - **It lists BlueZ code that treats `AUTH_FAILED` specially:**
    - `bonding_attempt_complete()`'s PIN retry, `src/adapter.c:8933`;
    - `device_bonding_complete()`, `src/device.c:7552`.

    Pairing results reach those through the HCI-status table or explicit mappings
    (`pair_device()`, `mgmt.c:3772-3779`), so the patch leaves them as they are. Our audit
    stands. But the two statuses are not interchangeable to user space in general, and the
    mail must not say so.

**Prior art and history (2026-11-13, `prior-art-2026-11-13.md`, every claim with its source):**
- **Why the mapping:** the entry was there from the series' first RFC (2021-05-27) and is
  unchanged through v8. Nobody commented on it. The only related review was about using errno
  values at all. The two later changes to the function (`-ECANCELED`, `-ERFKILL`) left it
  alone.
- **Competing patches:** none on lore (its git archive, since 2021-05) or patchwork.
- **User reports:** six, with "Authentication Failed (0x05)" next to a timeout.
  - Two forum posts show the same Write Class of Device timeout as ours.
  - Two are on lore: the QCA6390 thread (2024-04-04), and a 2022 BlueZ patch whose message
    says Set Powered "returns Authentication Failed because disconnection takes too long".
    These two are the candidates for a `Link:`.
- **An inconsistency to state in the message (verified):** a pairing connection that times
  out already reports `MGMT_STATUS_TIMEOUT`. `hci_conn_failed(conn, bt_status(err))`
  (`hci_sync.c:7825` on `da3cc0258`) maps `bt_status(-ETIMEDOUT)` to 0x08, and the table maps
  that to `TIMEOUT`. Only the errno path says 0x05.
- **Consumers:**
  - in BlueZ only the text changes for the affected commands, including the D-Bus error
    message; the error name `org.bluez.Error.Failed` stays;
  - bluetoothd's own request timeout already uses 0x08;
  - Qt, python-btsocket, bleno, the Android HAL and paypal/gatt do not branch on 0x05.
- **Stable:** both forms have been accepted by this maintainer.
  - With `Cc: stable`: `86ef0f58bdec` (ours) and `4728474344793`, 2026-09/11.
  - Without it: the RFKILLED and ECANCELED additions to this function.
- **Test timing, by precedent:** the RFKILLED fix (2026-10) and the EIR name length fix (2024-03)
  sent their mgmt-tester case to BlueZ the same day, naming the kernel fix. The maintainer
  applied the kernel fix first, minutes before the test. So "send it only after the kernel
  patch has landed" (above) is stricter than practice: send the same day, and state the
  dependency below the `---`.

**Next:**
- **The commit message:** follow the RFKILLED commit's form (the symptom before and after,
  the mapping, `Fixes:`), and add the pairing-path inconsistency. Optionally add a `Link:` to
  one lore report.
- **Below the `---`:**
  - the BlueZ test is sent separately;
  - a user-visible status changes, and in BlueZ only the text changes for these commands;
  - the mgmt-tester totals.
- **`Cc: stable`:** the operator's decision; precedent supports either.
- **Sends:** the kernel patch and the BlueZ test on the same day, as two sends, the test naming
  the kernel fix. The operator's word for both.

**State (2026-11-14): send package ready, nothing sent** — [`send-20261113/`](send-20261113/).
The "Next" items above are done there, on bluetooth-next `da3cc02587c6` and BlueZ master:
- the kernel patch (`kernel/`), with the `Cc: stable` alternative (`cc-stable-variant.txt`), and
  the BlueZ test, which now asserts that the hook saw Write Class of Device (`bluez/`);
- `CHECKS.md`: checkpatch, get_maintainer; the list bot's checks run locally, base vs patched
  (the difference is only the three Signed-off-by checks, from the line the operator adds); the
  BlueZ bot's checks, all PASS; mgmt-tester 526 + 1 → 527, l2cap-tester and smp-tester unchanged;
- the dry runs of `git send-email` (2026-11-14, `dry-run-20261114/`): four forms, all `Result: OK`,
  recipients as listed in `send-commands.txt`;
- `NOTES-FOR-OPERATOR.md`: the decisions (Cc: stable, the `Link:`, the subject, the
  "deliberate" sentence, the order of the two sends). The cited logs are in `evidence/`.

**Decides:** the operator, for the send.
