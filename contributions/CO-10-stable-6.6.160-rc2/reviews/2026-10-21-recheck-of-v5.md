# CO-10 — the four reviewers' recheck of version 5

*Received 2026-10-21. All four reviewers read version 5 at the frozen commit `05f5aef`. Version
6 and the scanner changes take up their points (`../log.md`). The text is kept as received,
except for the reviewers' tooling marks, which `scripts/review-text-clean.py` removes: tracking
parameters, favicon lines with their labels, and HTML space entities. The made-up addresses
the reviews quote are nobody's; `devtools/repo-scan-quoted-examples` allows them in this file
only.*

---

## Reviewer 1

**Version 5 is ready to send.** The only material change from v4 is a small, correct precision fix in the wording. All claims remain supported by the results, the form is correct, the homework is complete, and the reply continues to help rather than burden maintainers. Nothing in it creates noise or extra work.

### What changed from v4 to v5
The body of `reply-6.6.160-rc2-v5.eml` is nearly identical to v4. The two adjustments (documented in the draft notes and `log.md`) are:

- “All other cases that ran on both kernels have the same verdict” → “All other cases that ran on both kernels either pass on both or fail on both”.  
  This correctly covers the single mesh case (“Send cancel - 1”) where 6.6.159 sometimes Failed and rc2 Timed out. Both are non-passing; the new phrasing does not claim identical verdicts while still accurately stating there are no new failures.
- “No kernel warnings or sanitizer reports” → “No kernel warnings, sanitizer or lockdep reports”.  
  This matches the actual scan (which already included lockdep) and the confirmed config options.

Headers, recipients (the same 20 as the announcement), `In-Reply-To`/`References` (`<20261020075535.084584701@linuxfoundation.org>`), subject, quoted text, `Tested-by` identity, and the four specific fix results are unchanged. The results file and supporting evidence are the same as previously reviewed; the isolated mesh re-runs already closed the comparison gaps.

The scanner/address-list work and the restored Message-ID/lore links remain internal project hygiene and do not affect the mail.

### Recheck against the criteria
1. **Is the reply right?** Yes. Every claim in the v5 body is backed by the results file. The new “pass on both or fail on both” language is more precise than the previous version and does not overstate. Architecture (x86_64), config (BlueZ `doc/tester.config` with KASAN/lockdep), base (6.6.159), commit hash, and emulated-only scope are all present. Nothing a stable maintainer would normally expect is missing.
2. **Homework complete?** Yes. The full TestRunner suite comparison, the isolated re-tests of the differing mesh and L2CAP cases, the kernel-report scan, and the config/boot verification are all done. No additional practical test on this machine before the deadline would strengthen the reply further.
3. **QCA9377 entry:** Correctly left unmentioned, with the clear parenthetical that testing used emulated controllers and no Bluetooth hardware.
4. **Form:** Correct. Proper reply-all headers, matching recipient list, correct threading, short length, and the established `Tested-by` name/address.
5. **Noise vs. help:** Still pure help. It confirms the relevant fixes behave as intended, that the Bluetooth tester suites show no new failures on the cases that ran on both kernels, and that rc2 itself produced no kernel/sanitizer/lockdep reports in these runs. Maintainers can act on the summary alone.

The two open items noted by the maintainer (CI still queued for the scanner tests, and the pre-send check that no rc3 has appeared and that `linux-6.6.y` remains at `c578c158a368`) do not affect the content of the mail. They are correctly treated as final operational checks before sending.

**Recommendation:** Send version 5 as it stands. It is accurate, complete, well-supported, and useful for the stable review. The deadline remains Thursday 22 October 07:53 UTC; nothing should be sent until you give the final yes.




## Reviewer 2

I rechecked the pinned `05f5aefd09ba9d7faa60734451ad04eaf29cc1c4` state, including the actual v5 `.eml`, the results, the v4 recheck, the scanner implementation/tests, and the workflow state.
Verdict
CO-10 itself is technically ready. Version 5 correctly resolves the substantive issue found in the v4 recheck, and I see no reason for more testing, another hardware reboot, or another broad review cycle.
I have only one micro-wording improvement I would make to the upstream mail for maximal precision. It is not a substantive technical objection.
The strongest changes since v4 are all correct:

* v5 names the exact rc2 SHA and retains the proper x86_64/QEMU/emulated-controller scope.
* The four positive fix demonstrations remain fully supported.
* The false v4 statement that all comparable cases had the “same verdict” is gone.
* The final clean-run sentence now explicitly includes lockdep, which is supported by the actual config and scan.
* The text draft and the public v5 `.eml` have identical bodies.
* The review request correctly says version 5 and points reviewers to v5.
* The previous stale reviewer-header description of the cleaner has been corrected.
* The credential procedure is now right: password stays in the operator's terminal and is explicitly revoked in the Google account afterward.

[Version 5 mail](https://github.com/ivoitovych/qca9377-bt-hang/blob/05f5aefd09ba9d7faa60734451ad04eaf29cc1c4/contributions/CO-10-stable-6.6.160-rc2/drafts/reply-6.6.160-rc2-v5.eml)
One tiny wording issue
v5 currently says:
`All other cases that ran on both kernels either pass on both or fail on both:`
This is substantially better than “same verdict,” but in the very next text you distinguish the tester statuses Failed and Timed out. The mesh `Send cancel - 1` evidence is precisely:

* 6.6.159: 3 `Timed out`, 1 `Failed`
* rc2: 4 `Timed out`

So in rigorous tester terminology, “fail on both” can be read as saying both sides have a `Failed` verdict, when what you actually established is neither side passes.
For maximum precision I would use:
All other cases that ran on both kernels either pass on both or are non-passing on both:
or, slightly more natural:
No other case that ran on both kernels changes between passing and non-passing:
I prefer the second formulation. It describes exactly the regression property you measured and does not collapse `Failed` and `Timed out` into one formal verdict.
This is a micro-fix, not a reason for new testing. After changing that sentence, I would freeze the mail. I would not ask the reviewers to repeat another deep review merely because of that wording change.
The scanner issue from my previous recheck is genuinely fixed
The previous implementation had two real holes:

1. linuxfoundation.org effectively allowed every address at the organization.
2. An exact allowed address could also allow suffix-shaped strings such as `private-f.fainelli@gmail.com`.

Both are fixed structurally now.
Individual addresses and whole Message-ID tokens are exact-matched with `grep -F -x`; domain-wide entries are explicitly restricted to mailing-list hosts. More importantly, the tests now attack exactly the cases the earlier test missed:

* an unlisted address on the same domain as a listed person;
* a local part ending in a listed address;
* a different Message-ID ending in a listed sender.

Those negative tests are much better. My previous scanner finding is therefore closed.
I do see one small residual design smell in the scanner, but it is separate from CO-10: the public-address list now contains plausible-looking hypothetical addresses from the reviewers' prose, such as `anything@linuxfoundation.org` and `private-f.fainelli@gmail.com`, solely so the review can remain verbatim. Those tokens are therefore globally exempt from future scans. It would be safer eventually to alter those hypothetical examples transparently to reserved `.invalid` forms, rather than globally allowlisting plausible real mailboxes. The pre-existing broad kernel.org exemption is similarly wider than the new “exact individuals” policy.
I would classify that as post-deadline privacy-gate cleanup, not a reason to delay this stable reply.
Evidence quality remains excellent
The updated results are internally coherent. In particular, the mesh section now explicitly says why the wording changed:

* every mesh case has a control result;
* `Enable 2` is the intended rc2 improvement;
* both `Send cancel` cases remain non-passing on both kernels;
* one control run was `Failed` rather than `Timed out`.

That is exactly the sort of correction I want to see after outside review: the project did not suppress the inconvenient classification difference; it changed the public claim to match the evidence.
The clean-run claim is also stronger now without being broader than the data:
`No kernel warnings, sanitizer or lockdep reports were found on rc2 in these runs.`
That is supported by the generated configs, the broader kernel-report scanner, the 18 clean rc2 logs, and the positive control that successfully detects the known KASAN/GPF crash on 6.6.159.
Maintainer burden
Still extremely low.
Greg gets a compact mail describing:

* exact candidate and control;
* architecture/config/environment;
* four directly observed fixes;
* the comparative test outcome;
* the common L2CAP hang;
* absence of rc2 diagnostics;
* one `Tested-by`.

There is no request for him to read your repository, inspect logs, reproduce anything, or answer a question. The large dossier exists for your assurance, not as work pushed onto the stable team.
That is exactly the right separation.
The two real send gates remain external
The maintainer is also correct about the remaining operational gates.
GitHub currently still shows both workflows for `05f5aef`—`checks` and `access-audit`—as queued, not successful. So nobody should write “CI passed” yet.
And immediately before transmission, the project should still verify:

1. `linux-stable-rc/linux-6.6.y` is still the exact candidate you tested, `c578c158a368`.
2. No 6.6.160-rc3 has superseded this review cycle.

If either changes, the v5 email becomes stale even though all the underlying work was correct.
Final classification
My recheck is therefore:
APPROVED, with one recommended one-line precision edit: replace “fail on both” with “non-passing on both” (or equivalent).
After that, I recommend stop editing the substantive mail. No more test campaign, no QCA9377 reboot, no additional repetition of the deterministic cases, and no repository URL added to the upstream reply.
Then the only blockers should be mechanical: CI status if the project wants that gate, final header/lint check, rc2 freshness, no rc3, and your explicit authorization to send.
Relative to a normal individual stable `Tested-by`, the engineering evidence behind this is considerably more thorough than necessary while the actual maintainer-facing message remains appropriately small. That is the balance you were aiming for.




## Reviewer 3

# CO-10 — fifth-round independent review

Frozen commit `05f5aefd09ba9d7faa60734451ad04eaf29cc1c4` · 21 October 2026

## 1. The upstream contribution itself

Approved on technical content

Version 5 resolves my remaining substantive objection to version 4. I inspected the actual sendable `.eml`, rather than relying solely on the maintainer's description, and checked it against the revised experimental results.

The critical correction is present:

> All other cases that ran on both kernels either pass on both or fail on both.

This replaces the previously inaccurate claim that every case had exactly the same verdict. It now accommodates the mesh test that failed once on 6.6.159 but timed out on 6.6.160-rc2.

For technical precision, I would personally prefer “pass on both or remain nonpassing on both”, since `Failed` and `Timed out` are distinct tester outcomes. But the current sentence is understandable and does not materially misrepresent the experiment. I would not require a version 6 for this wording change.

The experimental evidence continues to support four improvements:

| Test                         | 6.6.159               | 6.6.160-rc2         |
| ---------------------------- | --------------------- | ------------------- |
| BT-9 simultaneous discovery  | Fails 3/3             | Passes 3/3          |
| BT-8 MGMT power-off flush    | Incorrect `0x00`, 2/2 | Correct `0x0f`, 2/2 |
| Mesh Enable 2                | KASAN fault and GPF   | Passes              |
| L2CAP deferred-connect limit | Fails 3/3             | Passes 3/3          |

The known failures and timeouts remain disclosed, the incomplete L2CAP execution is accurately bounded, and the message correctly says that no physical Bluetooth hardware was tested with rc2.

The email is concise, technically relevant, properly scoped, and appropriate for a Linux stable release review.

From the stable maintainer's perspective, I consider the v5 report ready, subject to the final release-candidate and email-header checks described in the dossier.

## 2. The address scanner: improved, but I found three residual weaknesses

Separate project-maintenance findings

The v5 scanner is materially safer than v4. I verified that it now uses exact-token matching for individually published addresses and Message-IDs, rather than permitting arbitrary suffixes. The test suite also contains new negative cases that specifically address the previous reviewers' objections.

However, the revised implementation still has three gaps.

### A. Mailing-list host matching is not fully anchored

In `devtools/repo-scan`, the final domain filter is:

```
grep -viE "($PUB_DOMS)$"
```

With the allowlisted host `lists.linaro.org`, that also accepts:

```
private@evil.lists.linaro.org
private@notlists.linaro.org
```

Neither is an address at the exact host `lists.linaro.org`.

I verified this behavior by executing an equivalent `grep` expression against synthetic examples.

Fix: require the `@` immediately before the allowed hostname:

```
grep -viE "@(${PUB_DOMS})$"
```

Add a negative test for an address at an unlisted subdomain of an allowed mailing-list host.

### B. The author's own address is still matched as a substring

An earlier stage in the same pipeline contains:

```
grep -viF "$ALLOW_MAIL"
```

This is not an exact-address comparison. It can suppress `private-<author-address>` just because that string contains the author's allowed address.

The equivalent synthetic test confirmed this behavior.

Fix: use exact, case-insensitive, fixed-string matching:

```
grep -viFx "$ALLOW_MAIL"
```

If the project needs to accept git-send-email Message-IDs containing the author's address, those need a separately defined rule or an exact published-token entry—not a general substring exception.

### C. Hypothetical private addresses are now globally allowlisted

The [public-address list](https://github.com/ivoitovych/qca9377-bt-hang/blob/05f5aefd09ba9d7faa60734451ad04eaf29cc1c4/devtools/repo-scan-public-addresses) contains several synthetic addresses quoted by earlier reviewers, including `anything@linuxfoundation.org` and `private-f.fainelli@gmail.com`.

The explanatory comment says they are included to preserve the reviewers' original text and should be refused elsewhere. But the scanner has no per-file distinction: an exact token in this list is permitted throughout the repository.

This contradicts the list's documented purpose of containing already-published upstream identities.

A cleaner design would distinguish verified public identities from documentation fixtures, without adding the latter to the global allowlist.

These are real static-code findings. They do not imply that an actual private address has leaked, and they do not compromise the v5 kernel-testing evidence. But I would not yet approve the scanner as a reliable privacy-enforcement gate.

## 3. Verification of the actual v5 email

I compared the sendable v5 email with the repository's human-readable draft and also compared the v5 body directly against v4.

| Check                                                              | Result              |
| ------------------------------------------------------------------ | ------------------- |
| Review request identifies v5                                       | Confirmed     |
| v5 `.eml` body equals reviewed draft                               | Exact match   |
| Changes from v4 affect intended wording                            | Confirmed     |
| `In-Reply-To` matches documented announcement ID                   | Confirmed     |
| Email contains 20 distinct recipients                              | Confirmed     |
| No `PENDING` markers in sendable body                              | Confirmed     |
| No unnecessary repository link or project narrative                | Confirmed     |
| Direct, independent comparison with original upstream mail headers | Not completed |

The actual email-body changes from v4 to v5 are limited to the corrected comparison wording and the explicit inclusion of lockdep in the diagnostic-report sentence. The technical results are unchanged.

This is good change discipline. The maintainer has not inadvertently changed experimental claims while correcting their presentation.

## 4. CI and upstream status

GitHub Actions for `05f5aef`

Queued

At inspection, all nine jobs in the `checks` workflow and the separate `access-audit` job were queued, with no reported conclusions.

[View checks](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39532638145) · [View access audit](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39532638126)

The new scanner tests therefore cannot yet be classified as CI-passing. My own review was static inspection plus independent testing of the specific regex behaviors described above, not an execution of the entire repository test suite.

I also attempted to independently verify the upstream rc2 announcement and look for rc3. The accessible upstream search information was insufficient to confirm the current head of `linux-stable-rc/linux-6.6.y` or establish definitively that no rc3 exists.

Consequently, the maintainer's final pre-send check remains necessary. The recorded deadline is 22 October 2026 at 07:53:04 UTC.

## 5. Two optional documentation improvements

The dossier README currently says “tested in full,” although `l2cap-tester` was intentionally stopped before all its cases completed. I would change this to “all eleven CI TestRunner suites attempted; incomplete L2CAP execution documented.” The actual email already handles this limitation properly.

The end of `log.md` also contains a misplaced sentence about correcting the old `02:xx` and `03:xx` timestamps, following the description of the version 5 sendable file. This looks like an editing artifact. It is worth cleaning up for historical readability but has no effect on the upstream submission.

Neither item justifies another technical review round.

## 6. Final verdict for the project maintainer

CO-10 v5 stable-review email

Approved

The technical claims are supported by the published dossier, the messaging is appropriately scoped, and the contribution is consistent with good Linux stable-review practice.

v5 address scanner

Further fixes recommended

Three privacy-filtering weaknesses remain. They concern the repository's publication safeguards, not the correctness of the Bluetooth test report.

I do not recommend repeating the kernel tests, extending the email, or beginning another general review cycle. The contribution itself is mature and should be useful to the stable maintainers.

My recommendation is to send the reviewed v5 email once the final release-candidate identity, absence of a superseding rc3, and mail checks are confirmed. The scanner corrections can be handled separately, but should be completed before relying on the scanner as a comprehensive privacy gate for subsequent publications.

This is a review recommendation, not authorization to send. No email was sent, no credential was requested, and no repository content was modified.

The project has reached the point where further polish on the stable-report email is likely to offer less value than submitting the carefully verified results within the upstream review window.




## Reviewer 4

## CO-10 v5 re-review — commit `05f5aef`

The first important result is positive: v5 fixes the substantive wording problem from my previous review.

The upstream email now says:

> All other cases that ran on both kernels either pass on both or fail on both.

That accurately accommodates the mesh test whose outcome differs between Failed and Timed out. The updated results document explains the distinction and explicitly identifies the isolated mesh runs that closed the earlier comparison gap.

I also confirmed that the review request identifies version 5, the sendable `.eml` exists at the frozen commit, and the dossier README references that same file. The email still clearly limits the results to x86_64, QEMU/KVM and emulated Bluetooth controllers.

These are meaningful improvements, not merely cosmetic edits.

## Independent verification of the sendable email

I fetched both the frozen v4 and v5 emails and compared their contents directly.

| Check                              | Result                                                      |
| ---------------------------------- | ----------------------------------------------------------- |
| v5 matches the prepared draft body | Pass — exact match                                          |
| Email headers changed from v4      | No                                                          |
| Recipients                         | 20                                                          |
| `In-Reply-To`                      | Correctly names the rc2 announcement                        |
| `References`                       | Preserved                                                   |
| `Tested-by` identity               | Preserved                                                   |
| Line-length issues                 | Only two 73-character lines quoted from Greg's announcement |
| Substantive changes                | Regression wording and explicit lockdep-report wording      |

The email remains consistent with the published results. I found no new technical or methodological blocker.

The Linux stable documentation explicitly permits responding to stable release candidates with a `Tested-by` email describing the testing performed.


1\. Moderate — the supposedly frozen review still contains moving links. The [review request, lines 34–66](https://github.com/ivoitovych/qca9377-bt-hang/blob/05f5aefd09ba9d7faa60734451ad04eaf29cc1c4/contributions/CO-10-stable-6.6.160-rc2/REVIEW-REQUEST.md), links repeatedly to `/blob/main/...`, including the draft, results and v5 email. Therefore, starting from the frozen `05f5aef` URL does not guarantee that every linked document remains frozen. Replace those links with commit-pinned URLs or relative paths that resolve at the same revision. This is a reviewer-reproducibility issue, not an upstream email defect.

2\. Separate scanner issue — one substring exception remains. In [devtools/repo-scan, line 187](https://github.com/ivoitovych/qca9377-bt-hang/blob/05f5aefd09ba9d7faa60734451ad04eaf29cc1c4/devtools/repo-scan), the repository author's address is filtered using `grep -viF "$ALLOW_MAIL"`. Unlike the new exact public-address filter, this also accepts address-shaped tokens containing the author's address. The earlier third-party suffix problem is fixed, but this analogous exception remains. Exact matching with `grep -viFx` and a negative regression test would be safer, while explicitly listing legitimate Message-IDs that contain the author's address.

3\. Minor — a log entry needs cleanup. The [CO-10 log, lines 119–140](https://github.com/ivoitovych/qca9377-bt-hang/blob/05f5aefd09ba9d7faa60734451ad04eaf29cc1c4/contributions/CO-10-stable-6.6.160-rc2/log.md) still uses `02:2x UTC`, and its final paragraph contains a sentence about correcting earlier timestamps accidentally joined to the new sendable-file description. Neither affects the evidence or email, but both are worth correcting for a clean historical record.

## Final operational checks

[v5 GitHub checks](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39532638145)

Queued when checked

The new scanner test assertions exist in the repository, but I could not confirm their passing in GitHub Actions. I also could not independently verify the current upstream `linux-6.6.y` head or definitively rule out a newer `-rc3` announcement. Those remain send-day checks, as the maintainer correctly notes. The kernel documentation specifically warns that the stable-rc tree can be rebased frequently.


GO for the v5 stable `Tested-by` email, subject to the existing send-day verification.

The email is accurate, concise, properly scoped, and supported by unusually extensive comparative testing. It should be useful to the stable maintainers without asking them to reconstruct the investigation.

I would correct the frozen-link issue for outside reviewers and separately address the remaining scanner exception. Neither justifies another substantive rewrite of the upstream email.

No repository changes or external submissions were made during this review. Your explicit authorization is still required before sending anything.
