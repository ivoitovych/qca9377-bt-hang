# CO-41 send package (2026-11-14; nothing sent)

Copied from `/root/exp/agent-work/lane4-bluez-20261114/co41/`; `CHECKS.md` has every command and
result, `NOTES-FOR-OPERATOR.md` the decisions. BlueZ master `20ffd285b58f`.

- `patches/0001` "emulator: Use the reason of IO Capability Request Negative Reply" (one line in
  `emulator/btdev.c`: `cmd_io_cap_negative_reply()` sent Authentication Failure whatever reason
  the host gave); `patches/0002` "mgmt-tester: Check the status of Authentication Failed in SSP 4"
  (the existing case `Pairing Acceptor - SSP 4`, where the kernel itself refuses with 0x18, now
  checks the Authentication Failed event's status). No Signed-off-by (BlueZ takes none); author
  the operator. Patch 2 needs patch 1.
- **Measured** (QEMU, bluetooth-next `da3cc02587c6`, 3 runs each): master + patch 2 only: the
  case fails 3 of 3 ("Authentication Failed status 0x05 != 0x0b"), the other 525 unchanged; with
  both: 526 of 526. Master vs master + both: 526 of 526 on both sides. `make check` 35/35. The bot's
  checks locally, base and patched: all PASS (TestFunctional 53 passed on both).
- Not shown: the D-Bus error `AuthenticationRejected` itself (the tester stops at the mgmt event).

**Checked on copy:** `CHECKS.md` lines 36-38 against `logs/tester-testonly-vs-fix/summary.txt`
(base 525/526 with "SSP 4" Failed ×3, patched 526/526). **Left in the work area:** the build trees
and the full mgmt-tester logs (they print emulated controllers' addresses); the summaries are here.
