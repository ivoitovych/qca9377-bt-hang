# repo-scan now lets published upstream addresses through

From the main-branch maintainer to the second maintainer, 2026-10-21. You maintain
`devtools/repo-scan` since `90a542b`, so you should know about this change to it. Nothing is
asked of you unless you see a problem.

## Why

The operator's rule of 2026-10-13: what upstream has already published is public. That covers
sign-offs, maintainers' and list addresses, Message-IDs, and lore or patchwork links. None of
it is to be masked or removed.

The rule lived only in my notes, and the scan's mail check refused every address outside its
short allowlist. Each time it refused one, I removed the data rather than question the check.
On 2026-10-20 and 10-21 that took out:
- the rc2 announcement's Message-ID from STATUS;
- seven patchwork and patch links from three outside reviews;
- the CO-10 reply's public recipient list.

The operator caught it. The rule is now in `BRIEF.md` §7, with that history.

## What changed

- **`devtools/repo-scan-public-addresses`** (new, tracked), in the scanned repository:
  - `@domain` lines accept every address at that exact domain;
  - other lines accept one address, alone or as the tail of a git send-email Message-ID
    (`<date>.<pid>-<n>-<sender>`, which the mail pattern reads as one address);
  - `#` starts a comment.
- **The scan reads it** if present. Everything not listed is still refused, so a private
  correspondent's address cannot pass.
- **The first version had a bug.** `tr -d '[:space:]'` joined all entries into one string;
  the real tree's scan showed it. It is now `sed`. The suite's new test uses two entries of
  each kind for that reason.
- **`tests/run-tests`**, after the "AND THE WIDENING MUST NOT BLIND IT" block: listed
  addresses pass (exact, by domain, inside a Message-ID); an unlisted one beside them is
  refused. Checked by hand on a scratch repository, both directions. The suite itself refuses
  here while a trial is open, so CI runs it first.
- **`scripts/review-text-clean.py`** no longer replaces links that carry addresses.

## Open for you

- **Whether the list belongs in `devtools/`**, or next to the scan's other data, if you
  prefer.
- **Whether `repo-save`'s identity check needs the same idea.** It checks authors, not
  content, so probably not.
