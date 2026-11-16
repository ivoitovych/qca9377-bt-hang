# Held: this series is not sent as it stands

This is the 11-14 morning series on E. Its patches have since gone separate ways:
- **0001** (A): replaced by `../send-20261113/A-review-fixes-20261114/`.
- **0002** (B2) and **0003** (D v2): held.
  - D v2 registers `.reset_resume`, which suppresses `needs_binding`. A system reset-resume then
    never rebinds the interface, and the firmware is not reloaded
    (`../../../reviews/2026-11-14T1300Z-bt17-open-work-reviewer-3-checks.md`).
  - B2 needs D.
  - The linux-usb question comes first (`../drafts/`).
- **0004** and **0005** (BT-24, BT-25): replaced by `../send-bt24-bt25-20261114/`, two patches on
  E alone.

**Note of 2026-11-16:** patch 3's message ("The system resume path is meant to stay as it is")
and the cover letter's paragraph on the system path (not tested; patch 3 acts only while the
device's runtime PM status is RPM_RESUMING, "checked in the source only") rest on a premise
that the D v2 finding above refutes: patch 3 does change the system path (it suppresses
`needs_binding`). Do not reuse those texts. The cover's kmemleak line ("1 to 4 objects
per run, then none in 12 of 12 runs") quotes the re-run kept in `../send-bt24-bt25-20261114/logs/`
(12 of 12 leaking on E alone); the first run in
`results/co43-d2-series-bt24-bt25-2026-11-14/RESULTS.md` had 11 of 12.

The current package of every contribution is in the table "What to send" at the top of
`contributions/README.md`.
