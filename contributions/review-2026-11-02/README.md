# Review round 2026-11-02: the submissions package and its follow-ups

- `review-package.md` — every package that was ready to send or ready for review on 2026-11-02,
  explained in full and self-contained (no links, every patch and mail verbatim, tests with
  numbers, open questions). Built for outside reviewers; it is not what goes to any list.
  Corrections made after the first readings are in it (the six CO-37 mails, the CO-02 mismatch
  patch, the CO-11a live result, the CO-35 patch-id claim, 7.2.y's end and v7.4-rc1).
- `followups.md` — what six outside reviews asked for, each claim checked where it could be:
  the operator's decisions (D1 to D14), the follow-ups by item (F-01 to F-92, each marked do /
  decide / you / doc), the rules to carry into every send, and where the reviewers were wrong.
  **Nothing on it has been acted on yet**; it waits for the operator to close the review round.
- `build/` — the sources: the front page, the page styles, `build.py` (joins the section files,
  scans for addresses, links, local paths and wording, renders with pandoc) and
  `followups-build.py`. The per-item section files were written in local work areas under
  `/root/exp/agent-work/review-doc-20261102/` (not tracked); the assembled `review-package.md`
  here is the complete text.

Both are also kept as private pages for the operator. The reviewers' own texts are not stored
here; their points are summarised in `followups.md` with what was found when checking them.
