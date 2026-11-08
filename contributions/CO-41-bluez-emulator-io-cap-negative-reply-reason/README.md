# CO-41 — BlueZ emulator: IO Capability Negative Reply ignores the reason (U29)

**What:** in `emulator/btdev.c`, `cmd_io_cap_negative_reply()` (master l.3395-3407) completes
Secure Simple Pairing with `BT_HCI_ERR_AUTH_FAILURE` whatever reason the host gave. So an
emulated peer cannot refuse with "Pairing Not Allowed" (0x18), and BlueZ's own tests can reach
`AuthenticationFailed` but never `AuthenticationRejected`. That was U29's real-headset case.

**State (2026-11-07): idea, confirmed in source; no patch yet.** A one-line fix: pass the
command's reason into the Simple Pairing Complete status. The sixth reviewer raised it
(`reviews/2026-11-07T1415Z-u29-source-investigation-reviewer-6-verbatim.md` §6.2).

**Next:** write it with a tester case that needs it, such as a pairing refused with 0x18
mapping to `AuthenticationRejected`. Run BlueZ's CI bot locally on base and base plus the
patch. Then the operator's decision.

**Decides:** the operator.

**Refs:** `docs/issues.md` U29.
