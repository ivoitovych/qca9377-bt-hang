# The btusb series on E, and the CO-21 and CO-20 send packages (2026-11-14)

QEMU emulation only (real btusb on bluetooth-next `da3cc02587c6`, an emulated controller through
usbip; KASAN and lockdep). Copied from `/root/exp/agent-work/lane1-btusb-20261114/task3/`; the
kernel tree and images stayed there. Full write-up: [`RESULTS.md`](RESULTS.md); `logs/SHA256SUMS`
is relative to `logs/`.

- **CO-43, the rest of the btusb series rebased on E** (packaged in
  `../../contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114/`): E, then A, B2,
  D v2, BT-24's fix, BT-25's fix; the cover letter says it applies on top of E and that B2 needs D.
  Runtime matrix on the full stack 18/18; after a brace fix in B2, one run of each scenario 6/6.
- **CO-21** (`../../contributions/CO-21-btusb-sco-alt-setting/send-20261114/`): the two patches
  rebased without conflict; patch 2's subject shortened to 65 characters. The five usbip scenarios,
  two runs each: unpatched 0/10, patched 10/10. The bot's checks: builds and all 11 testers pass,
  tester results identical to base, CheckSparse identical on both sides; only the Signed-off-by
  checks fail, and VerifyFixes passes on full history once a Signed-off-by follows `Fixes:`.
- **CO-20** (`../../contributions/CO-20-sco-unknown-handle-messages/send-20261114/`): two patches
  (receive failures reported by cause; data for a just-closed link logged at debug level, not
  counted as corruption). 20 calls hung up with data in flight: unpatched 17, 19, 24 "corrupted SCO
  packet" lines, patched none. Five packets for a handle that never was a link: unpatched counted
  as corrupted, patched reported as an unknown handle (5 to 7; the extra ones are data of the link
  that closed first, which patch 2's message states is still reported). The bot: only the
  Signed-off-by checks fail; no tester is selected for a btusb-only change.

**Checked on copy (2026-11-14):** `logs/summary-co21.txt` (10 FAIL unpatched, 10 PASS patched);
the CO-20 counts in the raw logs (`base-c20-rx-unknown-r1.log`: 13 kernel "corrupted SCO packet"
lines; the patched reruns: the harness's tally line reads "corrupted SCO packet: 0"); the
limitation the relaxed judge allows (at least five unknown-handle reports, none counted as
corrupted) is the one patch 2's message states (lines 28-29).
