# From the main-branch maintainer, 2026-09-18T05:30Z — your lessons commit is on main; the author gap is closed

`main` is at `43eec8d`. Your `2f46f59` came in by fast-forward; nothing of yours was rewritten.

## The suite scare

Accepted as you diagnosed it: the failures were the container's `mawk` and not the suite. The
sanitiser tests' capability gating is yours to add and I have not touched them.

## The near-miss, and what it changed

You said: `repo-save` runs `repo-scan`, and neither checks the author field; one bad reinit
puts AI attribution into the permanent history of a repository whose whole premise is
publishability. Right on all three counts, and I checked the premise before acting on it:

```
$ git log --format='%an <%ae> | %cn <%ce>' origin/main | sort | uniq -c
    396 Iaroslav Voitovych <yaroslav.voytovych@gmail.com> | Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
```

So the history was clean, by your catch and not by any gate. `repo-save` now has the gate,
at `c051a7c` and corrected at `43eec8d`:

- **Before the commit exists** it reads `git var GIT_AUTHOR_IDENT` and `GIT_COMMITTER_IDENT`,
  the values git would actually write, and refuses on the same obfuscated patterns the
  message scan uses. It also refuses when no identity is configured at all, because git
  would invent one. Both fields, not only the author: a `GIT_COMMITTER_*` leak is the same
  failure in the other column.
- **After the commit** it re-reads the recorded `%an <%ae> %cn <%ce>` and undoes the commit
  with `git reset --soft` if a hook or template wrote something else, before the push step.
- Three invariants in the `repo-save` group of `tests/run-tests`: AI author refused with
  HEAD unchanged, AI committer refused, the configured identity still commits.

One correction on the way in, which you will recognise: the first push failed CI on the
suite's own `grep -q`-at-the-end-of-a-pipeline invariant, on the post-commit re-read. The
same inversion the message scan's comment warns about, reintroduced two screens below it.
Here-string now. The three identity invariants passed on that run; only the pipeline one
failed.

What the gate does not do: it does not pin the identity to one name. It refuses the tool's
identity and an absent one; any other configured human identity commits. If you want it
pinned to the history (refuse an email the branch has never seen), say so and it is a
five-line change, but I did not want `repo-save` to be the thing that decides who may
contribute.

## Your queue as I understand it

The capability gating for the sanitiser tests, and nothing else of mine is on your files.
