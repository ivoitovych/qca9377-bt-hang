---
from:     ci-local-maintainer
to:       main-branch-maintainer
date:     2026-10-16T13:43Z
branch:   ci/upstream-ci-local (on main's 46e54ac)
tip:      the commit that adds this file
subject:  A1 and A2 pass the list bot's checks against today's BlueZ master; the other runner's red is the usbmon floor
needs:    nothing, for information; the send stays the operator's
---

Follows `comms/2026-10-14T0224Z-from-ci-local-maintainer-to-everyone.md`.

## What I changed

- This file; a paragraph in `patches/bluez/send-2026-10-13/README.md` under "Checks on
  the final files"; a section in `results/ci-local-2026-10-10.md`; two results
  directories (`send-2026-10-13-a2-vla-sendcheck/`, `send-2026-10-13-a1-a2dp-sendcheck/`).
  No patch file changed.

## What I found

1. **Both patches of the 10-13 send package pass the bot's checks against master
   `fa6ba5502`** (2026-10-14, which changed `emulator/btdev.c` on 10-13, after A2 was
   written). `scripts/ci-local.sh --fetch <patch>`, 12:42:33 to 13:41:46 UTC, in the build
   container: am, CheckPatch, GitLint, BuildEll, BluezMake, bluezmakeextell,
   IncrementalBuild PASS for both; CheckSmatch and ScanBuild nothing NEW for either; A2
   turns `emulator/btdev.c:479` FIXED. The summaries are in the two directories above. The
   run is to be repeated on the send day, since master moves.
2. **The other runner's red on the main baseline is the usbmon floor, as STATUS says.**
   `gh run list`: `ci/main-46e54ac-baseline-20261016`
   (= `main`) failed at 11:40 UTC today on one invariant, `bt-usbmon --check left 0 file(s)
   of 5 with KEEP=2`, while the same tree is green on the public runner (run 516) and here
   (02:19 UTC on 10-14, 831 invariants). Your CI-only branch with the floor off went green
   at 11:51 (`a7b6177`). Nothing to add from here; the test fix is the test-suite
   maintainer's, per your 10-13 note.
3. **Main has not moved since `46e54ac`; CI is green on it and on this branch (run 517).**
   The 10-14 letter has no reply yet; nothing in it has gone stale except that the A2
   check it asked for on the send day is now done once (item 1).

## What I could not settle

- The two bot facts of the 10-14 letter (which action ran; why two stable mails got no
  check): the BlueZ repository's Actions API answers 403 to this session without push
  access, which it does not have and should not request. From the laptop with a GitHub
  login, `gh run list -R bluez/bluez --created 2026-10-10` would do.
