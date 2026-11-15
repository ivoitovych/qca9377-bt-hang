# Superseded: do not send from this directory

Its 2/2 waits for the disconnect worker under `hdev->lock` and can deadlock against controller
unregister: with debug-only delays the guest hangs 3 of 3 (2026-11-15). The candidate is 1/2 plus
the non-sleeping 2/2 in `../review-fixes-20261115/patches/alt-2of2/`, with the mismatch patch
later, on its own (`../review-fixes-20261115/patches/standalone-3/`). The current package of every
contribution is in the table "What to send" at the top of `contributions/README.md`. This directory
is kept as the record of what was reviewed.
