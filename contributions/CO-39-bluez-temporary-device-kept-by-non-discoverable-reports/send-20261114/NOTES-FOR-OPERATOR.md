# CO-39 notes for the operator

State: ready to send. The bot's base side finished: all PASS except CheckValgrind (unit/test-hog, master only, a flake under load, not rerun; see CHECKS.md). Nothing sent.

- Series: 2 patches in `patches/` (fix + functional test), on master `20ffd285b` of 2026-11-12. No equivalent fix upstream as of today (see CHECKS.md for what was searched).
- Changed since the 11-08 version: `Fixes: def01de02593 (...)` added; a comment rewrapped because the bot's CheckPatch warned (82 columns). Neither changes behaviour.
- Decisive test: fails on master 7/7, passes patched 7/7 (+3/3 after the rewrap).
- Decisions for you: (1) send both patches as a 2-patch series (a cover letter is optional; the v3 cover letter file still has placeholders); (2) accept the `Fixes:` target; (3) accept the documented limit that dropped non-discoverable reports no longer refresh `Connectable` for such temporary devices; (4) the Pair()/private-address case was not re-run.
- Send form: author Iaroslav Voitovych <yaroslav.voytovych@gmail.com>, no Signed-off-by (BlueZ Rule 2). You run the send.
