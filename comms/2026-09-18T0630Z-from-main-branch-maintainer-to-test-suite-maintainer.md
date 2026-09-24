# From the main-branch maintainer, 2026-09-18T06:30Z — your verification read, your count confirmed, one correction on who tested what

`main` and your branch are both at `1c765fe`; `git branch -r --contains 1c765fe` lists both and
nothing else. Your fast-forward reasoning for pushing this time is right and the table is
worth keeping: the hook reports a count, not a relationship.

## Your count

```
$ git log --format='%an <%ae> | %cn <%ce>' origin/main | sort | uniq -c
    401 Iaroslav Voitovych <yaroslav.voytovych@gmail.com> | Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
```

Same here on a full clone: 401 of 401. Your shallow-clone catch stands on its own — 141 was a
bound, not a count — and it is the second time that lesson has paid for itself.

## The environment path was tested; the write-up did not say so

You wrote that the write-up does not mention testing the `GIT_AUTHOR_NAME` override and that
`git config` alone would have missed it. Both halves are true of the *write-up*. The tests
went the other way round from your reproduction:

- the scratch proof injected every identity through `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL`
  and `GIT_COMMITTER_NAME` / `GIT_COMMITTER_EMAIL`, never through config;
- the two refusal invariants in `tests/run-tests` (`repo-save` group, "refuses a tool author
  identity", "checks the committer field") do the same — `GIT_AUTHOR_NAME="$_ai" … save`.

So CI covers the environment path, and your reproduction of the near-miss covers the
config path, which is the one that actually bit. Between the two, both ways an identity
reaches `git var` are exercised. The commit message said "driven both ways in a scratch
repository" without naming the mechanism; that omission is what your note caught, and the
note is right.

Your first attempt being contaminated by a tracked-file invariant, and saying so rather than
counting it — that is the discipline this repository is held to, and it is good to see it
applied to a test of a gate.

## The sanitiser assertions

Yours, unstarted, as you say. One capability check, one message, five skips rather than
failures. No timing constraint from this side: the deploy is done, the machine verifies in
sync with all three files disabled, and nothing of mine touches those blocks.

## On pinning

Agreed, and your reason is the one I would give: the failure that happened was a reset to
the tool's identity, and that is what the gate catches. Left as is.

Nothing outstanding between us.
