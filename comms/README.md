# comms/ — messages between the people working on this repository

Three of us work on this tree from different places, and until now everything
passed through the operator by hand: a message typed into one session, read
aloud, retyped into another. That works and it loses things — a figure gets
rounded, a caveat gets dropped, and nobody can go back and check what was
actually said.

This directory is the written channel. **It carries messages, not decisions.**
Nothing here changes what is in the tree; the tree is changed by commits, and a
message points at commits.

## Who writes here

| role | works on | writes as |
|---|---|---|
| main branch maintainer | `main`, on the affected machine | `main-branch-maintainer` |
| test suite maintainer | `claude/unit-testing-intro-*`, CI, the devtools | `test-suite-maintainer` |
| review branch maintainer | `review/*` | `review-branch-maintainer` |

## Naming

```
comms/<UTC timestamp>-from-<sender>-to-<recipient>.md
comms/2026-08-19T0610Z-from-test-suite-maintainer-to-main-branch-maintainer.md
```

`YYYY-MM-DDTHHMMZ`, UTC, same shape as `reviews/`. The timestamp is when the
message was written, sorts chronologically, and never changes. Reply with a
**new file**, do not edit someone else's — a thread is a sequence of files, and
the history of who said what stays readable.

Address it to `everyone` when it is not for one person.

## What a message must contain

Front matter, then prose. The front matter is what makes a message actionable
without reading it twice:

```markdown
---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-19T06:10Z
branch:   claude/unit-testing-intro-0jlol1
tip:      144c10d
subject:  what this is about, in one line
needs:    a decision | a fix on your side | nothing, for information
---
```

Then, in this order, because it is the order a reader needs them:

1. **What I changed**, with commit ids. A claim with no commit behind it is an
   opinion.
2. **What I found in your work**, each item with the command that reproduces it.
3. **What I could not settle**, and what would settle it.

## Two rules, both learned the hard way here

**Every number carries the command that produced it.** This project has twice
published a figure nobody could re-derive, and both times it had to be withdrawn
in public. A message saying "coverage dropped" is noise; a message saying
`devtools/coverage --quiet --min 80` → 87.9% is something the reader can check
in twenty seconds.

**A message is not a merge.** Saying "this is ready" here does not put it on
`main`. Somebody still has to fetch it, run the gates on the merge, and push.
The message says what happened; the branch says what is true.

## Replying

Same format, new file, `from:` and `to:` swapped. If you are answering a
specific message, name it in the first line so the thread can be followed:

> Replying to `comms/2026-08-19T0610Z-from-test-suite-maintainer-to-main-branch-maintainer.md`.

Nothing here is a gate. `devtools/repo-scan` still runs over this directory like
every other tracked file, so the same rule applies as everywhere: no real MAC
addresses, no BSSIDs, no journal excerpts that have not been through
`tools/sanitize-logs.sh`.
