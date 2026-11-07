# CO-10 — the four reviewers' recheck of version 6

*Received 2026-10-21. All four reviewers read version 6 at the frozen commit `1eda14a`, and all
four approve sending it. What their remaining points led to is in `../log.md`. The text is kept
as received, except for the reviewers' tooling marks, which `scripts/review-text-clean.py`
removes: tracking parameters, favicon lines with their labels, and HTML space entities. The
made-up address a review quotes is nobody's; `devtools/repo-scan-quoted-examples` allows it in
this file only.*

---

## Reviewer 1

**Version 6 is ready to send and is the better choice.** The single wording change in the mail is a precise improvement that more accurately describes the measured results. All other review points were internal (scanner, links, log/README wording) and do not affect the content that maintainers will see. Claims remain fully supported, form is correct, and the reply continues to help without creating work.

### The change in the mail (v5 → v6)
The body of `reply-6.6.160-rc2-v6.eml` is identical to v5 except for this sentence:

- v5: “All other cases that ran on both kernels either pass on both or fail on both”
- v6: “No other case that ran on both kernels passes on one and not on the other”

This is the correct precision. The results show one mesh case (“Send cancel - 1”) where 6.6.159 could Fail and rc2 Timed out. Both are non-passing, so there is still no new failure on rc2, but they are not the same verdict. The v6 wording states the actual property that was measured (no case that passes on one kernel and fails to pass on the other) without implying identical failure modes. Headers, recipients (the same 20), threading, the four specific fix results, the mgmt-tester counts, the hang note, and the kernel-report statement are unchanged. v5 is retained beside it for comparison.

### Handling of the other review points
These were addressed correctly and do not alter the mail:

- Scanner: exact matching for the author’s address (plus its own git-send-email Message-ID shape), quoted example addresses restricted to the files that quote them, kernel.org reduced to the five concrete addresses present in the tree, and a regression test for the list-host anchoring. The whole tree and staged changes scan clean; the new tests pass.
- Review-request links: now relative, so they resolve at the commit the reader opened.
- README and log: minor accuracy fixes (“tested in full”, app-password wording, times, and a misplaced sentence).

These are good internal hygiene. They strengthen the project’s own checks without adding anything to the message sent upstream.

### Final assessment against the criteria
1. **Claims supported?** Yes. The v6 wording is more accurate than v5 while remaining fully backed by the results file (including the isolated mesh re-runs). Nothing is overstated.
2. **Homework complete?** Yes. No further test is needed.
3. **QCA9377 entry:** Still correctly unmentioned, with the emulated-controllers disclosure.
4. **Form:** Unchanged and correct (headers, 20 recipients, threading, `Tested-by` identity, length).
5. **Noise vs. help:** Still pure help. The slightly tighter sentence makes the summary even clearer for a maintainer skimming the reply.

The pre-send operational checks (confirm `linux-6.6.y` is still at `c578c158a368` and that no rc3 has been announced) remain appropriate and do not affect the content.

**Recommendation:** Send version 6. It is the most precise version of an already solid, evidence-backed `Tested-by` reply. v5 would also have been acceptable, but v6 is better. The deadline is still Thursday 22 October 07:53 UTC; nothing should be sent until you give the final yes.




## Reviewer 2

I rechecked the frozen `1eda14a4c3c599afe19a528d77846d8b52329a0f` state itself, including v5 and v6, the updated results/README/log/review request, `repo-scan`, both address lists, the new scanner tests, and the current GitHub Actions state.
Verdict: send v6, not v5
I now consider the upstream CO-10 mail finished.
The v5→v6 change is exactly as described: the only mail-body change is the comparison sentence. Headers, recipients, four positive fix results, diagnostic claim, environment description and `Tested-by` are unchanged.
The new wording:
`No other case that ran on both kernels passes on one and not on the other`
is better than both previous formulations. It describes exactly what the experiment establishes: outside the four improvements already enumerated, there is no passing→non-passing transition. It remains true when one kernel says `Failed` and the other says `Timed out`.
I also independently compared the v6 `.eml` body with `reply-6.6.160-rc2.txt`: they are byte-for-byte equivalent as body text. So there is no “reviewed draft versus different sendable mail” problem.
I would not change another word in the upstream body.
The dossier corrections are real
The review request is now genuinely freeze-safe. The internal links are relative, and from the CO-10 directory the `../../scripts`, `../../patches`, `../../evidence`, `../../docs` and `../../BRIEF.md` paths resolve to the intended repository files. A reviewer entering through the pinned `1eda14a` request no longer gets silently sent to moving `main`.
The README no longer makes the misleading “tested in full” claim; it accurately says all eleven suites ran on both kernels while explicitly noting where L2CAP was stopped because both kernels hang. The log cleanup is also correct: the approximate timestamp and misplaced sentence from the previous version are gone from the relevant final section.
So those reviewer findings are closed.
The scanner fixes are mostly good—and the reported tests now test the right things
The maintainer correctly fixed the issues reviewers actually identified.
The author's address is no longer accepted merely because it is a substring of another address. The explicit regression test now rejects `private-<author address>` while permitting the author's git-send-email Message-ID form.
The made-up reviewer examples are no longer globally declared “published.” The new `repo-scan-quoted-examples` mechanism associates them with the particular review files containing them and rejects the same token when another tracked file contains it.
The broad `kernel.org` exemption is gone; the five actual public tokens presently needed are explicit. And reviewer 3's alleged list-host anchoring bug really was a false positive: keeping the literal `@` means `private@evil.lists.linaro.org` does not match lists.linaro.org. The new negative tests make that invariant explicit.
The fact that the old `05f5aef` scanner fails the new author-substring and quoted-example tests while the new one passes them is particularly useful. Those aren't merely tests that happen to be green; at least those two demonstrably distinguish broken from corrected behavior.
I did find two remaining scanner weaknesses
Neither affects CO-10 or should delay this stable report, but I would put them into the scanner backlog.
First, the thing called “the maintainer's own address” is still initially obtained from:

```
git config user.email
```

and only falls back to the tip commit author when that is absent. That means the privacy gate trusts whoever happens to be operating the checkout, not necessarily an identity demonstrably published by this repository. If someone temporarily has a private address in `user.email`, that private address—and matching send-email-shaped tokens—becomes exempt from the scanner.
For a publication gate, I would eventually derive this from repository-controlled public data, or require an explicit public-address entry. A mutable local Git setting should not silently widen a privacy allowlist.
Second, `--all` has a subtle working-tree/index mismatch. Its main `CONTENT` comes from `cat` on tracked working-tree files, while `quoted_only_where_listed()` uses:

```
git grep --cached
```

to determine where a quoted example occurs. Consequently, an unstaged copy of an allowed example added to some unauthorized tracked file can appear in `CONTENT` but remain invisible to the location check, which still sees only the indexed authorized review occurrence.
The staged-addition and range checks close this before the current commit/push, so this is not a defect in `1eda14a`'s published state. But `repo-scan --all` does not quite satisfy its advertised “scan every tracked file” semantics in the presence of unstaged changes. In `--all`, the occurrence check should inspect the working tree too.
There is also one trivial stale comment in `repo-scan-public-addresses`: it says the author's address is allowed “and so are vger.kernel.org, lists.linux.dev, kernel.org”. Broad `kernel.org` allowance has just been removed. That's documentation only.
CI remains exactly as the maintainer says
At my check, both workflows for `1eda14a` are still queued:

* `access-audit`
* `checks`

There is still no basis for saying this commit is CI-green.
The inability to run the full local suite while E3 #2 is open does not bother me. Respecting a deliberate trial guard is better than overriding it just to make a checkmark. The scanner-specific block was the code changed here, and it was exercised separately; full CI can eventually give the repository-wide confirmation.
The only true pre-send gate now is freshness
I could not independently obtain a sufficiently authoritative live view of the current `linux-stable-rc/linux-6.6.y` head or definitively rule out an rc3 through the public sources available to me right now. So I would not substitute my review for the maintainer's immediate pre-send freshness check.
Immediately before the actual send, check exactly what the dossier says: `linux-6.6.y` must still identify the tested rc2 `c578c158a368`, and there must be no superseding `6.6.160-rc3`. If either changed, stop and reassess. If both remain true, the content is ready.
Final classification
CO-10 v6: APPROVED / SEND-READY, conditional only on the immediate rc freshness and final mechanical mail checks.
I recommend v6 over v5. There is no reason for another kernel test campaign, another QCA9377 reboot, another broad review round, or another wording revision. The remaining scanner observations are separate engineering debt in the repository's privacy tooling, not defects in this stable `Tested-by` contribution.
At this point, more editing of the upstream mail would be more likely to introduce churn than improve it.



## Reviewer 3

# CO-10 — v6 independent recheck

Frozen commit `1eda14a4c3c599afe19a528d77846d8b52329a0f`

Version 6 approved for submission

The v6 email is technically ready. I compared it against the exact v5 file and inspected the supporting dossier. The change is appropriately narrow and resolves the last wording ambiguity without modifying the experimental conclusions.

The new sentence is:

> No other case that ran on both kernels passes on one and not on the other.

This correctly distinguishes passing versus nonpassing without treating `Failed` and `Timed out` as identical verdicts. It is supported by the documented mesh comparison, including the one baseline run that failed rather than timed out.

The rest of the report still accurately describes the four observed fixes, the existing nonpassing cases, the incomplete L2CAP run, and the QEMU-only testing scope. Its `Tested-by` trailer and intended upstream reply threading remain unchanged.

I recommend v6 rather than v5. There is no substantive reason to produce v7 or repeat the kernel tests.

## 2. Address scanner — rechecked and substantially corrected

I inspected the new [scanner](https://github.com/ivoitovych/qca9377-bt-hang/blob/1eda14a4c3c599afe19a528d77846d8b52329a0f/devtools/repo-scan), [public-address list](https://github.com/ivoitovych/qca9377-bt-hang/blob/1eda14a4c3c599afe19a528d77846d8b52329a0f/devtools/repo-scan-public-addresses), [quoted-examples list](https://github.com/ivoitovych/qca9377-bt-hang/blob/1eda14a4c3c599afe19a528d77846d8b52329a0f/devtools/repo-scan-quoted-examples), and regression tests at the pinned revision.

| Previous finding                                    | Current assessment                                                                                                          |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| A. List-host matching accepts unwanted subdomains   | My previous finding was incorrect. The generated pattern retains `@`, and the negative tests confirm the intended behavior. |
| B. Author address matched as a substring            | Fixed. Exact-address matching is combined with a narrowly defined git-send-email Message-ID pattern.                        |
| C. Hypothetical review addresses globally permitted | Fixed. The separate quoted-examples mechanism restricts them to specified tracked files.                                    |
| Broad `kernel.org` exemption                        | Fixed. Five specific address-shaped tokens are now allowlisted individually.                                                |

I independently exercised the author and mailing-list-host matching expressions with synthetic addresses. The author's exact address and correctly shaped Message-ID passed; a prefixed private address and the two disputed subdomain examples were rejected.

The quoted-examples mechanism also looks consistent with its intended policy in the three supported scanning modes. It uses tracked-file searches to ensure the example does not appear outside its permitted review files.

The reported 12 passing isolated scanner tests are credible and the test cases are appropriate. I have not independently executed all twelve or the full project suite, so I would distinguish the maintainer's test report from an independently completed CI run.

## 3. Documentation and email checks

The revised review request now identifies v6 and uses relative repository links, preserving the intended frozen-review context.

I also checked the actual mail bytes through the GitHub connector:

- The v6 email body matches `drafts/reply-6.6.160-rc2.txt` exactly.
- The v6 and v5 email headers are byte-for-byte identical.
- The change in the email body is confined to the intended comparison sentence and its line wrapping.
- The recipient list, subject, threading identifiers and `Tested-by` identity are unchanged.

The README now explains the deliberately interrupted L2CAP run and correctly describes the app-password revocation procedure. The log records the review decisions and changes.

I found no new send-blocking problem in these changes.

## 4. CI and upstream status

GitHub CI at `1eda14a`

Queued

The `checks` and `access-audit` workflow runs were both still queued at inspection, with no reported conclusions.

[Checks](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39534616541) · [Access audit](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39534616571)

I also independently checked the official [kernel.org stable-review archive](https://www.kernel.org/pub/linux/kernel/v6.x/stable-review/). It lists `6.6.160-rc1` from 17 October and `6.6.160-rc2` from 20 October 2026, with no `6.6.160-rc3` artifact shown at the time of retrieval.

That is useful corroboration, but not a substitute for checking the live `linux-6.6.y` branch head. I could not independently verify that it still points to `c578c158a368`; the maintainer should perform that final check before sending.

The official stable process explicitly welcomes `Tested-by` reports in response to stable release candidates, and warns that the stable-rc tree is frequently rebased.


I approve version 6 for sending, subject only to the final mechanical checks and your explicit authorization.

The scanner corrections, improved wording, frozen links and documentation changes address the reviewer feedback without introducing an apparent new substantive problem. More review rounds are unlikely to improve the Linux stable contribution meaningfully.

The reported test-suite guard was also respected rather than bypassed, which was the appropriate decision.

My recommendation to the project maintainer is: freeze v6, verify the upstream candidate and final mail, then submit within the review deadline if authorized. Do not block the stable test report solely because unrelated repository CI jobs remain queued, provided the publication checks on the final content pass.

No email was sent and no GitHub files were changed during this recheck.




## Reviewer 4


## CO-10 v6 re-review — commit `1eda14a`

GO for v6, subject to the final pre-send checks

I inspected the frozen v6 files and compared them with v5. My recommendation is to send v6 rather than v5.

The upstream email has changed in just one place: the regression-comparison sentence. The new wording is more precise:

> No other case that ran on both kernels passes on one and not on the other.

This accurately distinguishes Failed from Timed out without disguising either as a passing result. The four documented fixes, kernel identification, tester counts, hardware limitations, mail headers and `Tested-by` identity remain unchanged.

I found no substantive reason to request another revision of the upstream email.

## Verification results

| Item                                     | Result                                                              | Assessment |
| ---------------------------------------- | ------------------------------------------------------------------- | ---------- |
| v5 → v6 email comparison                 | Only the regression sentence and its line wrapping changed          | Pass       |
| Mail headers                             | Byte-for-byte identical to v5                                       | Pass       |
| Recipients                               | 20 distinct addresses                                               | Pass       |
| Line lengths                             | Only two 73-character quoted lines                                  | Pass       |
| Review request links                     | Replaced moving `main` references with relative links               | Pass       |
| Scanner author's address                 | Exact address or specified git-send-email Message-ID shape          | Fixed      |
| Published-address list                   | Exact addresses; domain exceptions restricted to mailing-list hosts | Fixed      |
| Hypothetical addresses quoted in reviews | Separate file-scoped exception list                                 | Fixed      |
| `kernel.org` exemption                   | Replaced broad exception with five specific tokens                  | Fixed      |
| README and log corrections               | Updated and consistent with v6                                      | Pass       |

### Scanner findings

The [scanner at ](https://github.com/ivoitovych/qca9377-bt-hang/blob/1eda14a4c3c599afe19a528d77846d8b52329a0f/devtools/repo-scan)[`1eda14a`](https://github.com/ivoitovych/qca9377-bt-hang/blob/1eda14a4c3c599afe19a528d77846d8b52329a0f/devtools/repo-scan) addresses the substantive vulnerabilities identified during the previous review.

In particular, the author's address can no longer be accepted merely because it appears as a substring of another address. The new exact matching also preserves the special Message-ID format needed by previously submitted patches.

The additional review-example restriction is sensible: retaining invented addresses in verbatim reviews should not cause those same addresses to be accepted indiscriminately throughout the repository.

I agree with the maintainer about the alleged mailing-list subdomain problem. The regular expression retains the `@`, so it does not match arbitrary subdomains or lookalike hostnames. Adding negative tests was still worthwhile.

Testing qualification: I inspected the new test assertions and their intended positive and negative cases. The maintainer reports 12 passing isolated scanner tests, but I did not independently execute those tests or the full suite.

### GitHub CI

[Checks for ](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39534616571)[`1eda14a`](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39534616571)

Queued

Both associated workflows were still queued when queried. There is therefore no independently verified green CI result for v6 yet.

I would not make this a blocker for the stable `Tested-by` response: the scanner changes are internal, and the testing evidence supporting the upstream email was established separately.

## Pre-send conditions

The only important remaining conditions are operational. Immediately before sending, the maintainer should verify that the stable-rc `linux-6.6.y` branch still points to the tested candidate, `c578c158a368`, and that no subsequent release candidate has superseded it. My attempt to independently inspect the upstream Git tree was unsuccessful, and public search did not establish its current head.

The deadline stated in the upstream announcement is Thursday, October 22, 2026, at 07:53:04 UTC, or 09:53:04 in mainland Spain.

The planned dry run, final header checks, terminal-only app-password entry, subsequent revocation, and logging of the actual submission are all appropriate.

## Final recommendation to the project maintainer

APPROVED — SEND V6 AFTER THE FINAL UPSTREAM AND MAIL CHECKS.

I do not request another revision of the email, additional kernel testing, or another round of external review. The issues I raised in earlier rounds have been addressed, and the current report is appropriately cautious about its coverage while communicating useful test results.

The strongest feature of this contribution remains the separation between a detailed, reproducible private/project-side investigation and a concise, consumable upstream response.

This is a ready-to-send technical review verdict, not authorization to send. I have not sent anything or modified the repository.
