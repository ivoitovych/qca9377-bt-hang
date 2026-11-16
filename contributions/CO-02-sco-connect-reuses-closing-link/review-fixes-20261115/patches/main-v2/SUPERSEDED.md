# Not to be sent: this 2/2 can deadlock

Marker added 2026-11-16. The 2/2 here waits for the disconnect worker under `hdev->lock` and
hangs 3 of 3 against controller unregister with debug-only delays (2026-11-15, see
`../../README.md` section 1). The candidate is patch 1 plus the non-sleeping 2/2 in
`../alt-2of2/`, with its cover in `../../msg/cover-alt.txt`; the mismatch patch later, on its own
(`../standalone-3/`). The current package of every contribution is in the table "What to send"
at the top of `contributions/README.md`. This directory is kept as the record of what was
reviewed (it is also the three-patch form that `../../msg/cover-main.txt` describes).
