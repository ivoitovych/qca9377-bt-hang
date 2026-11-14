# CO-41 notes for the operator

State: patch pair written, tested, checked locally on master `20ffd285b` (2026-11-12). Nothing sent.

## What is proposed
Two patches, in this order (`patches/`):
1. `emulator: Use the reason of IO Capability Request Negative Reply` (1 line).
2. `mgmt-tester: Check the status of Authentication Failed in SSP 4` (+34): the existing case `Pairing Acceptor - SSP 4` now checks the Authentication Failed event's address and its status, `MGMT_STATUS_REJECTED`.

They are separate so that a maintainer can take the emulator fix alone; patch 2 alone fails (`Authentication Failed status 0x05 != 0x0b`), so it must not be applied before patch 1.

## Decisions left to you
1. **Send as two patches or squash into one.** Two is what the files suggest (emulator vs tester); the cover letter is unnecessary for two small patches.
2. **Strengthen the existing case or add a new case.** I changed `SSP 4` in place (no new case name, no runtime cost). The alternative is a copy of the case with the new check; more lines, and the old case would keep not checking the status.
3. **Zero reason.** `cmd->reason == 0` (SUCCESS) would make the emulator complete pairing as a success and send link keys. No host sends it (the kernel and BlueZ use real error codes), so I did not guard it. A guard (`reason ? reason : BT_HCI_ERR_AUTH_FAILURE`) is one more line if a maintainer wants it.
4. **Scope of the claim.** The patches show the mgmt-level status (`MGMT_STATUS_REJECTED`). They do not show the D-Bus error; the chain to `AuthenticationRejected` is source reading (`mgmt_status_table`, `src/device.c`). U29's real-headset case (a peer refusing with Pairing Not Allowed) still has no emulated D-Bus-level test.

## Send form
`git send-email` is for you: author line Iaroslav Voitovych <yaroslav.voytovych@gmail.com>, no Signed-off-by (BlueZ userspace, `doc/maintainer-guidelines.rst` Rule 2), to linux-bluetooth@vger.kernel.org. Two subjects as in `patches/`.

## Reproduce
- Fail/pass: `scripts/run-testonly-vs-fix.sh` (needs the lane's `project/` clone, kernel image and `bluez` clone; paths inside).
- Bot: `scripts/bot-ci.sh`. Evidence and exact numbers: `CHECKS.md`. Hashes: `SHA256SUMS`.
