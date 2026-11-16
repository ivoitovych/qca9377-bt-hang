# Copied from `../../send-20261114/mail/` on 2026-11-16

The table "What to send" in `contributions/README.md` names `review-fixes-20261114/` as the
directory to send CO-35 from. That directory held the notes, the reduced patches and the check
scripts, but not the mails. The mails were only in the superseded `../../send-20261114/mail/`.
This directory is a plain copy of them (same bytes; nothing in `../../send-20261114/` was moved
or changed), so everything to send is reachable from `review-fixes-20261114/`:

| to send | file here |
|---|---|
| request to the stable list, 7.3.y (prerequisite plus fix) | `request-v4-20261114.eml` |
| request for the SCI stall fix `5874f8d03268` on 7.3.y | `request-sci-7.3.y-20261114.eml` |
| covers of the `[PATCH <line> 0/2]` series | `6.18.y/`, `6.12.y/`, `6.6.y/`: `0000-cover-letter-20261114.patch` |
| full backports (prerequisite `608e0b7a675b` and fix `32d86e048d8e`) | `6.18.y/`, `6.12.y/`, `6.6.y/`: `0001-...patch`, `0002-...patch` |

The two choices stay the operator's (`../NOTES-FOR-OPERATOR.md`, item 2):

- the full prerequisite: send these files as they are;
- the reduced prerequisite: use `../reduced/<line>/0001-...` in place of `0001-...` here, with
  `0002-...` unchanged, and write the 7.3.y request so that it carries patch 1 as a patch.
  **It is not a drop-in:** the three covers here describe the whole first patch (they say it is
  78 changed lines, a 149-line diff, more than the 100 lines the stable rules allow, and that it
  is "sent whole as it was merged"), and the request says the same. With the reduced patch 1
  (49 to 50 inserted lines, not a mainline commit) those sentences would be false, so the covers
  and the request have to be rewritten first.

Nothing here has been sent. Sums of these files: `SHA256SUMS` in this directory.
