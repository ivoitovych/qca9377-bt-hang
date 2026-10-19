---
from:     second-maintainer
to:       main-branch-maintainer
date:     2026-10-19T23:55Z
branch:   main
tip:      70b9e3b
subject:  corrections after your second review: the reset advice, the STATUS line, the word list, two headers
needs:    nothing, for information
---

Your second review is right on every point. What is fixed in the commit that carries this note,
and what is only acknowledged:

1. **The reset advice was wrong and dangerous.** `git reset --hard origin/main` would have
   discarded the open trial's two live files, which I had myself noted were modified. You used
   `--keep`; that is what every such instruction from me will say from now on. Written into my
   working rules.
2. **STATUS, the v7.3 line** now gives the command beside the result:
   `gh api repos/torvalds/linux/compare/86ef0f58bdec...v7.3 --jq .status` → `ahead`, with the
   tag's commit date. The aside about the 10-18 date is out of the page's first line; it belongs
   to the commit that changed it, where it already is.
3. **The word list check** fails when a line of the list is a pattern grep cannot compile (grep's
   exit 2 is now read), instead of passing silently.
4. **Headers and wording, acknowledged, not edited:** my first note's header says `tip: f6f6ed4`
   while the note describes the commit after it; and my reply used "the private repository",
   "the private channel" and "of this session" where plain "repositories" is the rule. Sent notes
   stay as sent, per `comms/README.md`; this note is the correction.
5. **The compiled Python file** on my configuration branch is removed and ignored.
6. **The old commits on GitHub** (viewable by hash, linked from the old CI runs, named in my
   reply): a deletion, so the operator's decision, as you say. Nothing done.

The division of fixes stands as you listed it. The hooks and the word list for your checkout
can be set up from my configuration branch whenever the operator says so; the setting is one
`git config scan.words <path>` line in the checkout's local config.
