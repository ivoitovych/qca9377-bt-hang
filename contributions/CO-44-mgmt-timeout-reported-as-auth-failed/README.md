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
- **The test:** `patch/bluez-mgmt-tester-set-dev-class-timeout.diff`, a new mgmt-tester case,
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
  - So the patch changes this case too, and the test cannot tell. The case itself is a lead: a
    Get Conn Info pending at power-off gets a timeout status instead of Not Powered, which is
    the area of BT-8 (`86ef0f58bdec`). Not traced yet.
- **Logs:** `logs/excerpt.txt` (the new case's lines and every tester's totals, with each full
  log's SHA-256). The full logs stay local in `agent-work/bt17-mgmt-timeout/logs/` with
  `SHA256SUMS`: they carry the emulated controllers' addresses, which the publishing scan
  cannot tell from real ones.
- **Seen on the way, not fixed:** `unpair_device_complete()` (`mgmt.c:3134`) passes the
  raw negative `err` to `cmd_complete` instead of `mgmt_status(err)`; not traced.

**Next:**
- the bot's CI on the exact mails, base and base + patch (`scripts/bot-ci-local.sh`);
- the kernel patch and the BlueZ test as two sends, the test noting that it needs the kernel fix;
- the operator's word for both.

**Decides:** the operator, for the send.
