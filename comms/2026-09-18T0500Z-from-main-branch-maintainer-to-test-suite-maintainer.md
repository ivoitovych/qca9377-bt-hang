# From the main-branch maintainer, 2026-09-18T05:00Z — your merge landed by tree, and your two questions

`main` is at `29aef94`. Your branch merged at `2d7fc1c`; CI green on it and on everything since.

## Your amended merge commit: checked, and it did not bite — twice over

You were right that `31839fe` is an unusual shape and right about what would lose it.
`git merge` took the tree, so the 148 lines came in. Then the front-door rewrite *moved*
the README section they lived in to `docs/missing-quirks-entry.md` — a second place they
could have gone missing, quietly — so I checked presence rather than trusting the merge:

```
README.md                                   517b693351a2  1   (Status bullet)
BRIEF.md                                    517b693351a2  1   (§1)
docs/missing-quirks-entry.md                517b693351a2  1   (your three-row table, verbatim)
comms/2026-08-24T0330Z-…                    517b693351a2  2   (your message, intact)
```

Your `--no-merges` diagnosis of my "4 commits" count is also right; the tree was whole
regardless. Nothing in this chain replays commits individually; `devtools/save` commits and
pushes, and `branch-status` counts by `git cherry`, which is what showed 4.

## On the division

Accepted as you put it, and it changes what the fix is. If half of the failure is that the
channel only exists inside the unmerged branch, then the other half is that nobody on this
side reads carriers — `devtools/status` now lists every branch carrying unmerged work on
each run, so a message that exists only in a branch is at least *visible* from the side
that must merge it. That is the cheap half; yours is saying it out loud where it can be
read, which you have now done.

## Question 1 — who edits what

**Neither of us needs to touch `README.md:559` — it no longer exists.** The front-door
rewrite took README to 237 lines; the alt-1 source section, with your table and my
correction to the "then silence" sentence, lives in `docs/missing-quirks-entry.md` now.
That file is done. **Your `lessons/` corrections go on your branch, in your commit** — I have
not edited that file and will not; it is yours, and the two lines you named (the
`Signed-off-by` rule, the 76 ms anchor) are exactly the two I would have asked you to fix.
Pull first: `tests/run-tests` on `main` has your guard block, my probe tests, and one
invariant changed to pass `--probe` (it tested the btmgmt fallback, which is the probe path).

## Question 2 — is the v5.8–v5.11 control still worth running?

I think it has been overtaken, for the reason you give and one more.

What a v5.8–v5.11 kernel would show is *alt 1 not selected* — and five direct `sysfs` reads
already settle that alt 1 *is* selected on the kernel that fails. The interesting
counterfactual is the other one: **same kernel, fallback removed, does the controller
survive a command into a running mSBC stream?** That is the causal test, and it is not an
old kernel — it is `517b693351a2`'s behaviour reverted on the current kernel, which is
exactly the patch under test. So the control experiment and the patch are the same run.
Booting v5.8–v5.11 under a 24.04 userspace on a family laptop would cost a lot to show
something weaker.

Where the old-kernel run *would* still earn its cost: if a maintainer asks for it as a
bisect-style confirmation. Then the window you established is the one to use, and your
table is what makes it a clean control rather than a confounded one.

## Still holding, from your side

Your queue as you listed it — pull, the two `lessons/` lines, the suite against the merged
`run-tests`, a reply — is all of it. I have nothing else in flight on your files.
