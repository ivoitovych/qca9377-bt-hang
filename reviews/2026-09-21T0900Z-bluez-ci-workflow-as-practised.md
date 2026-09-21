# BlueZ's CI workflow as the maintainers built and practise it — 2026-09-21T09:00Z

The operator found the GitHub pull requests the bot had opened for both patches
(`bluez/bluez` #2554, #2555), saw red checks on them, and objected to this side's
"wait for the maintainer" recommendation: *"Maintainer created the CI scripts, so
they should be followed … for what reason we should have an exception?"* He asked
for the workflow to be measured rather than assumed — a few dozen recent merges,
who reacts to CI errors — and then whether a new version lands in the same pull
request. Every answer below is from the maintainers' own sources or from
patchwork/GitHub data, with the command.

## 1. What the pull requests are

The maintainers' CI is `bluez/action-ci` ("bzcafe"). Its own text, in
`cleanup_pr.py`, posted on any pull request a person opens:

> Currently, the BlueZ repo in Github is only for CI and testing purposes, and
> not accepting any pull request at this moment. If you still want us to review
> your patch and merge them, please send your patch to the Linux Bluetooth
> mailing list.

`doc/maintainer-guidelines.rst` Rule 1: the trees are linear — "NO merges".
Measured:

```console
$ gh api "search/issues?q=repo:bluez/bluez+is:pr+is:merged" --jq .total_count
0
$ gh api "search/issues?q=repo:bluez/bluez+is:pr+is:closed+is:unmerged" --jq .total_count
1073
```

No pull request in that repository has ever been merged. #2554 and #2555 were
opened by `BluezTestBot` from patchwork series 1169362 / 1169363, on a branch the
bot owns inside `bluez/bluez` (named by the series id); the only commenters on
them are the bot and a code-quality bot. A contributor cannot push to them, and
nobody reviews there. They are where the CI runs, not where the work is accepted.

## 2. A new version is a new pull request — by the maintainers' design

`sync_patchwork.py`, the maintainers' comment at the point where a series is
turned into a pull request:

```python
# Check if PR already exist. The closed PRs count as well: the
# series was already handled and it must not be tested again,
# a resent series comes with a new series id.
if ci_data.gh.pr_exist_sid(series['id']):
```

The pull request is keyed by the patchwork series id; a v2 mailed to the list
gets a new series id, therefore a new branch and a new pull request. The old one
is closed by the bot's cleanup task once its series is no longer "New" in
patchwork, or after 14 days. Observed (`gh pr list -R bluez/bluez --search …`):

```
2487  CLOSED  2026-09-03T21:04  [PW_SID:1157334] btattach: Update for glibc 2.42 compatability
2490  CLOSED  2026-09-03T23:13  [PW_SID:1157441] [BlueZ,v2] btattach: Update for glibc 2.42 compatibility
2334  CLOSED  2026-07-20T19:56  [PW_SID:1131086] [BlueZ] tools/iso-tester: fix GIOChannel refcounting
2432  CLOSED  2026-08-23T10:55  [PW_SID:1150371] [BlueZ,v2] tools/iso-tester: fix GIOChannel refcounting
```

The maintainer's own respins go the same way (patchwork `14758089` v1 →
`14759726` v2, separate series). **There is no way to add a commit to an existing
bot pull request, and a second pull request for a v2 is the intended path, not a
discourtesy.** The GitHub model — follow-up commits on the same branch until CI
is green — does not exist here; the unit is the mailed version.

## 3. Does the maintainer apply patches whose bot run failed?

`scripts/bluez-accepted-survey.py 10` — the 1000 most recent patchwork entries
(2026-07-22 → 09-21), 137 BlueZ series, 68 accepted, 63 of those with bot checks.
Full output: `2026-09-21T0900Z-bluez-ci-workflow-survey-output.txt`.

| accepted BlueZ series with bot checks | 63 |
|---|---|
| CheckPatch or GitLint **fail/warning at the accepted version** | **25 (40 %)** |
| TestFunctional fail at the accepted version | 7 |
| every lint check green | 32 |

The 25 include the maintainer's own patches (CheckPatch `fail` ×5, GitLint `fail`
×1) and regular contributors' (Pauli Virtanen, Bastien Nocera, Frédéric Danis,
George Kiagiadakis, Naga Bhavani Akella). The tree agrees
(`BT_REV=origin/master scripts/git-log-tab-count.sh <tree> 300`, at `ebbb4ee31`):

```
commits examined:            300
message has a hard tab:      8      (one authored by the maintainer)
message has a line > 75:     23
```

And the maintainers' written rule covers one of our two lint items outright —
`doc/maintainer-guidelines.rst` Rule 2: "Commit messages should adhere to a 72
characters by line limit … **Exceptions to this rule are logs, trace or other
verbatim copied information.**" The lint checks are advisory. They are not a
gate, and a patch carrying them is not an exception to the rule; it is 40 % of
what is applied.

## 4. Who reacts to bot failures

Of 14 superseded BlueZ series whose bot run had a lint problem, 10 had no comment
but the bot's; where a next version is visible in the window, lint was as often
still failing as fixed (2 / 2, and one of the "fixed" has no checks at all). A
human mentioned the CI in 2 of the 16 non-bot comments cached, both about one
thing — the maintainer, 2026-09-15, replying to the bot on his own series:

> Any idea how to fix the errors above? Locally they seem to work just fine, so
> perhaps this is something related to the CI environment.

That is `TestFunctional`, the failure register row CB-03 already showed on twelve
unrelated patches. The maintainer treats it as a CI-environment problem, and a
series titled "mgmt-tester: fix test failures" reached the list on 09-20 (#2556).

⚠️ Limit of this measure: patchwork attaches list replies to the patch they
answer, so replies to cover letters, and off-list exchanges, are not counted.
"Nobody asked" means "nobody asked on the patch thread".

The bot's mail to us asks for nothing: "This is automated email and please do not
reply … This is a CI test results with your patch series". The only request in it
is checkpatch's own boilerplate, "has style problems, please review".

## 5. What this means for the two patches

- The operator's instinct — a contributor owns their CI result — is the right
  instinct, and the workflow does give it an outlet: **a v2 by mail**. It is
  wrong only about the mechanism (same pull request) and about the weight the
  maintainer gives lint (advisory; 40 % of applied series carry it).
- This side's "wait" was not arrogance, and it was also not measured when it was
  given. Measured: sending a lint-clean v2 unprompted is unusual here but entirely
  within the workflow, costs the maintainer nothing (patchwork marks v1
  superseded, the bot closes its pull request), and removes the one thing on the
  patches that is ours. Not sending it is equally within practice.
- Whichever is chosen: v2 goes **to the list**, as two separate mails, and will
  appear as two **new** pull requests. That is correct. Nothing should be done on
  GitHub — no comment, no push, no pull request of our own.
- `TestFunctional` will very likely fail on v2 as well until the maintainers' CI
  fix lands. That is not ours and needs no reply.

CB-02 stays the operator's decision, now with the facts under it.
