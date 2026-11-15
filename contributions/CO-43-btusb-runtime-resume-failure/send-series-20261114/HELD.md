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

The current package of every contribution is in the table "What to send" at the top of
`contributions/README.md`.
