# CO-21: what is left to the operator (2026-11-16)

The package to send is this directory (the table "What to send" in `contributions/README.md`):
`0000-cover-letter.patch` and the two patches. The superseded `../send-20261114/` had the
operator's notes and the recipients; they are copied here unchanged:

- `NOTES-FOR-OPERATOR-from-send-20261114.md`: the Signed-off-by placement, the six decisions
  (stable Cc, patch 2's subject, the cover, the recipients, Hitalo Souza's series, the optional
  laptop test) and what the tests showed. **Read it with these differences:** the patches are
  the ones in this directory (the air mode is stored before the connection is marked connected,
  and one helper takes both counts in one pass), not the 2026-11-01 patches that note describes;
  the cover is `0000-cover-letter.patch` here, not `cover-letter.txt` (its "Changes since the
  first draft" paragraph was removed on 2026-11-16: the first draft was never posted); the
  results of this version are in `README.md` and `CHECKS.md`.
- `recipients-from-send-20261114.txt`: the get_maintainer output for the earlier form of the same
  two patches at the same base (`da3cc02587c6`). It was not re-run for these patches; they touch
  the same files, but re-run it from the project checkout before the send.

Nothing has been sent. The send is the operator's, with his own Signed-off-by.
