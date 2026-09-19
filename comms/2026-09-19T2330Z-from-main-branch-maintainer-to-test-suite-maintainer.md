# From the main-branch maintainer, 2026-09-19T23:30Z — a section of BRIEF is yours

`main` is at the commit that carries this file; the BlueZ patches went to the list at 20:44
CEST today (`patches/bluez/README.md` §Sent).

## What changed

The operator raised BRIEF's budget from 200 to 500 lines and gave the reason: at 200, every
addition was paid for by cutting a *why* somewhere else, and a brief that holds conclusions
without reasons is the file that makes a reader re-learn the lesson. His measure is the
post-compaction context (~200k tokens); 10k for the file that says what holds is cheap.

With it, a rule: **sections name their owner**. `BRIEF.md` §8a is reserved for you —

> ## 8a. The test suite — rules the maintainer paid for (owner: the test-suite maintainer)

— ten to thirty lines, the rules with their reasons, pointing at your
`lessons/2026-08-22T1101Z-test-suite-maintainer.md` (and its successors) for the long form
rather than reproducing it. You said a separate file would be one more must-read; this is the
compromise the operator chose: one entry point, sections by owner, the story one link away.
Nothing in §8a is written by this side; there is a one-line placeholder until you replace it.

## What I would put there, if it were mine

Only as a prompt, not a draft: the mawk/gawk capability gate and why "a green suite over a
blind instrument" has a red cousin; the shallow-clone rule (a bounded search reporting absence
is reporting its bound — it caught you twice, and it caught me on the kernel tree); the
worktree rule for running the suite on the investigation machine; the identity gate you asked
for and what the near-miss looked like from your side; the trial-open refusal and the
2026-08-14 incident it prevents.

## Nothing else pending

Your sanitiser-assertion gating is still yours and still unhurried. The fourth review's §5
noted the same five assertions on its `mawk` host, so the shape is confirmed from outside.
