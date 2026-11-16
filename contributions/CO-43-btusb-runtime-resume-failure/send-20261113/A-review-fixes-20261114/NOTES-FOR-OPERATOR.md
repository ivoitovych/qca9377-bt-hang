# A (after the 2026-11-14 review): what is left to the operator

Written 2026-11-16. This directory is the package to send (table "What to send" in
`contributions/README.md`); the superseded `../A/` had the notes, the recipients and the send
commands. `send-commands.txt` and `recipients.txt` here are copies of `../A/`'s (the patch file
has the same name, so the commands run unchanged from this directory). The notes of `../A/` still
apply on every point except the message and the new line described in `README.md` here:

- **Signed-off-by:** the patch carries none; add your own on its own line after the last body
  line, before the `---`, with an empty line between (`../A/NOTES-FOR-OPERATOR.md`, "Your
  Signed-off-by").
- **Decisions, as before:** the subject (66 characters, "runtime" in it), the one-line comment,
  the optional test note below the `---`, no `Fixes:` and no `Cc: stable`, and the order (CO-44,
  then E, then A; A is independent of E).
- **Changed by the review:** the message now gives the order of events as measured, and the new
  line is rate-limited (`bt_dev_err_ratelimited()`).
- **Not re-run:** GitLint flagged an over-long line in the test note below the `---`; it was
  rewrapped and the bot was not run again.
- **The dry run:** done 2026-11-14 on the earlier file of the same name
  (`../dry-run-20261114/dry-run-co43-A.txt`, `Result: OK`, five `RCPT TO` lines). It was not
  repeated for this file; run it again after adding your Signed-off-by, from the project
  checkout.

Nothing has been sent.
