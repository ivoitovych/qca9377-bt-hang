# CO-10 — the four reviewers' recheck of version 4

*Received 2026-10-21. All four reviewers read version 4 at the frozen commit `ccb46dc`. Version
5 takes up their points (`../log.md`). The text is kept as received, except for the reviewers'
tooling marks, which `scripts/review-text-clean.py` removes: tracking parameters, favicon lines
with their labels, and HTML space entities.*

---

## Reviewer 1

**Version 4 of the draft is stronger, more precise, and ready to send** once you give the final yes. The updates correctly incorporate the four prior reviews, close the open homework items, and keep the contribution useful, accurate, and low-friction for maintainers. It still follows stable-review norms, avoids overclaiming, and creates no extra work.

### What changed and why it improves the contribution
The public `.eml` (v4) and supporting files now reflect completed testing and tighter wording:

- The body now reports four specific fixes that behave as intended (the original two plus the mesh crash fix and the L2CAP out-of-bounds fix), each with concrete pass/fail counts versus 6.6.159.
- Wording is more precise: “the BlueZ CI TestRunner suites,” “All other cases that ran on both kernels have the same verdict,” explicit commit hash for rc2, and the mgmt-tester pass/fail/timeout numbers for both kernels.
- Scope is clearly limited to emulated controllers in QEMU/KVM with no Bluetooth hardware. The QCA9377 entry remains unmentioned, which is still the right choice.
- Threading is correct: `In-Reply-To` and `References` match the announcement’s Message-ID (`<20261020075535.084584701@linuxfoundation.org>`), and the 20 recipients match the original.
- Results file now includes the full other-tester comparison. Mesh “Enable 2” crashes on 6.6.159 (KASAN stack-out-of-bounds then GPF in `mgmt_pending_remove`) and passes on rc2; the later “Send cancel” timeouts occur on both kernels and are not regressions. L2CAP “Defer limit” fails 3/3 on 6.6.159 and passes 3/3 on rc2; the later hang occurs on both and is not a regression. No kernel warnings or sanitizer reports on rc2.
- Log.md records what each review point produced. Times in the CO-10 files have been corrected to the actual commit times (version 3 at 01:43 UTC, version 4 at 01:55 UTC).

The side work in `ccb46dc` (public-address allowlist for the scanner, restoration of Message-IDs and lore links, regenerated reviews, BRIEF §7 rule) is internal project hygiene. It does not affect the mail that will be sent, but it correctly treats the public stable-review recipient list and Message-IDs as publishable.

### Recheck against the original criteria
1. **Claims supported?** Yes. Every statement in the v4 body maps to the results file (including the new mesh and L2CAP numbers and the per-case verdict comparison). Nothing is overstated. The “same verdict” language correctly accounts for the incomplete l2cap run and the mesh cases that fail on both sides.
2. **Homework complete?** Yes, for practical purposes before the deadline. The other testers ran; the two interesting differences were re-tested in isolation; mesh cases that lacked a 6.6.159 baseline were run individually. No further test on this machine would materially strengthen the reply.
3. **QCA9377 entry:** Correctly omitted. The parenthetical about emulated controllers / no hardware is sufficient disclosure.
4. **Form:** Correct. Proper reply-all headers, matching `Tested-by` identity, quoted original text, short length, and accurate recipient list.
5. **Noise vs. help:** It remains pure help. It confirms that relevant fixes in the RC work, that the Bluetooth tester suites show no new failures on the cases that ran, and that rc2 itself is clean of KASAN/lockdep issues in these runs. Maintainers can act on the summary alone.

### Overall quality
This is still high-quality work—now tighter after external review. It matches successful stable `Tested-by` practice (concrete, limited, evidence-backed, no process narrative in the mail itself). It does not create work for maintainers. The only remaining step is your explicit approval and the one-time app password for sending.

**Recommendation:** Send version 4 as it stands. It is useful, correct, and helpful for the stable tree and the Bluetooth subsystem.

## Reviewer 2

## Recheck verdict: the CO-10 contribution itself is now **SEND-READY**

I re-read the frozen `ccb46dc` state rather than relying on the maintainer’s description. The substantive objections from the first four reviews have been addressed. Version 4 is materially better than the version I reviewed before, and I no longer see a technical, process, wording, or maintainer-burden reason to hold the **stable `Tested-by` email**.

Linux’s current stable documentation explicitly says that stable `-rc` releases are to be tested by developers/testers and that people can reply with `Tested-by:` plus whatever testing information is useful; those tags are collected into the release commit. It also explicitly warns that `linux-stable-rc` is frequently rebased, so naming `c578c158a368` is exactly the right improvement. [Kernel.org](https://www.kernel.org/doc/html/v7.3/process/stable-kernel-rules.html)

My updated assessment is:

| Area | Previous review | Current v4 |
|---|---|---|
| Contribution appropriate? | Yes | **Yes, clearly** |
| Evidence quality | Excellent | **Exceptional for a stable Tested-by** |
| Exact rc identified | Missing | **Fixed: `c578c158a368`** |
| Overclaiming “no regressions” | Problem | **Fixed** |
| Existing test failures disclosed | Needed | **Fixed** |
| Other TestRunner suites | Pending | **Completed / bounded honestly** |
| Mesh control gap | Not yet known | **Closed** |
| Config actually verified | Requested | **Verified** |
| Booted kernel actually verified | Requested | **Verified** |
| Kernel-report scan | Narrow | **Much stronger + positive control** |
| Comparator robustness | Weakness | **Hardened** |
| QCA9377 scope | Acceptable limitation | **Very clearly disclosed** |
| Threading/recipients | Planned | **7/7 mechanical check, 20/20 recipients** |
| Dossier consistency | Previously stale | **Fixed** |
| Maintainer workload | Very low | **Essentially zero** |
| Upstream mail quality | Very high | **Top-tier** |

### The evidence is now exceptionally well closed

The biggest improvement is that the test story is no longer merely “rc2 looks no worse.”

There are now **four positive demonstrations that rc2 behaves better exactly where fixes say it should**. BT-9 changes the simultaneous-discovery test from reproducible failure to pass, 3/3. BT-8 changes the MGMT response from erroneous `0x00` to the expected `0x0f`, 2/2. The mesh fix removes an actual KASAN stack-out-of-bounds followed by a GPF. The L2CAP fix converts the relevant `Defer limit` case from failure to pass, again reproduced 3/3.

That last pair is particularly nice from a community perspective: the mail is no longer mostly a report about your own work. It independently validates fixes from another contributor that happen to be in the same stable candidate.

The broad comparison is also properly bounded now. ISO, SCO, BNEP, RFCOMM, ioctl, SMP, user-channel and 6LoWPAN match. `mgmt-tester` differs only in the intended fix. L2CAP is compared up to the identical hang on both kernels, with the intended L2CAP fix as its one difference. Mesh is no longer a comparison hole: the cases that the old kernel could not reach because it crashed were subsequently executed individually on both kernels. That directly closes reviewer 4's strongest remaining objection.

I especially like that the repository does **not pretend the common L2CAP hang disappeared**. Saying where comparative coverage stops is better engineering than manufacturing a reassuring-looking “suite passed” summary.

### The final mail is now correctly scoped

This sentence is much better than the old “No regressions in Bluetooth”:

> `All other cases that ran on both kernels have the same verdict`

That is an evidence statement, not a universal claim.

Likewise:

> `QEMU/KVM (emulated controllers, no Bluetooth hardware)`

is an excellent way of handling QCA9377. It makes the scope impossible to miss without cluttering the email with a special disclaimer about one device-table patch. The official definition of `Tested-by` is testing in **some environment**, not universal qualification of every affected device and architecture. [Linux Kernel Archives](https://cdn.kernel.org/doc/html/latest/process/submitting-patches.html)

I would **not reboot the laptop into rc2 merely for this contribution**. Nothing about kernel stable practice requires that.

### The mail is very consumable for Greg

The `.eml` is about the right size. It answers the questions the stable maintainer actually cares about: what exact candidate, what control, what architecture/environment, what tests, what changed in the expected direction, whether anything else got worse, whether the kernel emitted warnings, and who supplies the `Tested-by`.

It does **not** ask Greg to inspect your GitHub repository. It does not explain the history of BT-1/8/9. It does not tell the story of the project. It does not dump hashes, commands, raw logs, review process, or internal methodology into his inbox.

That separation is excellent: substantial homework behind a short email.

The threading preparation is also considerably stronger now. `reply-headers-check.py` checks the actual relationship to Greg's cover email—not merely whether some headers happen to exist—and checks exact reply-all address equality. The published v4 `.eml` has `In-Reply-To` and `References` set to `<20261020075535.084584701@linuxfoundation.org>` and has the 20 intended recipients. This directly addresses reviewer 4's earlier tooling criticism.

### One small wording improvement is possible, but I would **not hold the send for it**

The last sentence currently says:

> `No kernel warnings or sanitizer reports were found on rc2 in these runs.`

Since you explicitly built with lockdep and the wider scanner checks lockdep findings too, the absolutely maximal version would be:

> `No kernel warnings, sanitizer or lockdep reports were found on rc2 in these runs.`

But I rate that **optional**. The existing statement is true and useful. At this stage I am more concerned about gratuitously touching a reviewed v4 than extracting another half-line of information from it.

## I did find a separate flaw in the maintainer's new privacy-scanner work

This does **not block CO-10**, but I would send it back to the project maintainer as a new finding.

The maintainer's description says, in effect, that published addresses pass while unlisted/private addresses remain refused. The current implementation does not fully guarantee that.

There are **two context-confusion holes** in `devtools/repo-scan`.

First, an `@domain` allowlist entry permits **every local-part at that domain**, because this filter removes anything ending in an allowed domain:

```text
grep -viE "($PUB_DOMS)\$"
```

So `@linuxfoundation.org` does not merely permit Greg's already-public address and public Message-IDs. It permits `anything@linuxfoundation.org`, including a hypothetical private correspondent whose address was never published.

Second, an individually allowed address is accepted not only exactly but when preceded by `-` or `.`:

```text
(^|[-.])($PUB_ADDRS)$
```

That was added for git-send-email Message-IDs such as `...-sender@gmail.com`, but the scanner has already reduced everything to address-shaped strings and no longer knows whether a match came from a Message-ID or an ordinary mail address. Thus, conceptually, an ordinary address such as `private-f.fainelli@gmail.com` can match an allowlisted `f.fainelli@gmail.com`.

The new test does **not catch either case**. It permits `@lists.qca9377.invalid` and `@other.qca9377.invalid`, but its negative control is:

```text
private@qca9377.invalid
```

—that is an entirely different, unallowed domain. The missing negative tests are essentially `private@lists.qca9377.invalid` and an address whose local-part ends in `-<allowed-address>`.

So the maintainer's claim that the widening still rejects an unlisted address **on a listed domain** is not demonstrated by the committed test and is actually inconsistent with the present domain-wildcard implementation.

That deserves fixing because `repo-scan` is a privacy/publishing gate. I would solve it by separating **exact public email addresses** from **Message-ID exceptions**, rather than using a context-free suffix regex for both.

Again, this does **not contaminate the present CO-10 email**: the addresses published in that `.eml` really are upstream's public stable-review recipient list. It affects the safety of future repository publication.

There is also a tiny documentation leftover: reviewer 1 and reviewer 2's headers still say that `scripts/review-text-clean.py` removes “links that carry a mail address,” while the current cleaner intentionally no longer does. Reviewer 3 correctly contains the restoration note. That is historical/dossier polish, not a contribution issue.

## CI status

One part of the maintainer report is not yet complete. GitHub currently reports both workflows for `ccb46dc`—`checks` and `access-audit`—as **queued**, with no conclusion yet. So at this moment I would not say “CI passed”; it has not.

That is the only operational gate I would still allow to finish before treating `ccb46dc` itself as frozen-green. Importantly, `ccb46dc` did **not change the v4 test conclusions or mail body**; it mainly restored public data and changed the scanner/cleaner. Therefore a CI failure there would need investigation but would not retroactively invalidate the kernel testing.

## Final recommendation

For **CO-10 itself**, my previous **“READY AFTER MINOR FIXES”** becomes:

**APPROVED / SEND AS V4.**

I would make no additional testing demand. I would not request another external review. I would not reboot for the QCA9377. I would not expand the email. I would not add repository links to the upstream mail. I would not rerun already deterministic BT-8/BT-9 cases merely to increase repetition counts.

The maintainer has correctly taken the reviews seriously and, more importantly, converted the useful comments into measurable checks rather than cosmetic wording changes. At this point more polishing risks crossing from diligence into churn.

The only things I would keep as the mechanical send gate are exactly what the dossier already says: verify the final `.eml` again, verify that the stable candidate has not moved/been superseded, and then send the reviewed v4. The **scanner issue should become a separate project-maintenance finding**, not another reason to delay this stable contribution.

## Reviewer 3

# CO-10 — independent re-review of version 4

Frozen revision `ccb46dc` · 21 October 2026

One correction before sending

The fourth revision is substantially better than the version I originally reviewed. The maintainer has addressed nearly all my previous objections, including the incomplete suite comparison, hardware-testing limitation, missing build inputs, weak diagnostic scanning and unverifiable email headers.

However, after inspecting the actual version 4 email and its updated results, I found one remaining factual discrepancy that I would correct before giving unconditional approval.

## 1. The remaining discrepancy: mesh test verdicts

The current email says:

> All other cases that ran on both kernels have the same verdict.

But the updated [results document](https://github.com/ivoitovych/qca9377-bt-hang/blob/ccb46dc/contributions/CO-10-stable-6.6.160-rc2/experiments/results-2026-10-21.md) contains this comparison:

| Mesh test       | 6.6.159                        | 6.6.160-rc2         |
| --------------- | ------------------------------ | ------------------- |
| Send cancel - 1 | 3 timeouts, 1 failure (4 runs) | 4 timeouts (4 runs) |
| Send cancel - 2 | 4 timeouts                     | 4 timeouts          |

This establishes that neither test passes on either kernel. It does not establish identical per-run verdicts for `Send cancel - 1`.

The distinction matters because the project deliberately chose the word verdict to be more rigorous than the earlier wording about regressions.

The results document also concludes that every mesh case matches except `Enable 2`. Strictly speaking, that conclusion needs the same correction.

### Recommended correction

In the email, replace:

> All other cases that ran on both kernels have the same verdict:

with:

> Apart from these improvements, no additional passing-to-nonpassing changes were observed in the cases compared on both kernels:

Then keep the existing suite summary, and add a short qualification:

> The two mesh Send cancel cases remained nonpassing on both kernels; one control run failed instead of timing out.

This wording is consistent with the published evidence without concealing the different failure classification.

I consider this a reporting correction, not evidence of a new rc2 regression. The four-run comparison does not show a case that consistently passed on 6.6.159 and then failed on rc2.

It is a small change, but exactly the kind of precision that makes upstream test reports trustworthy.

## 2. Previous review findings: what is now resolved?

I checked the updated repository against my original review, rather than accepting the maintainer's change log at face value.

| Original concern                            | Version 4 assessment                                       |
| ------------------------------------------- | ---------------------------------------------------------- |
| Overbroad “No regressions in Bluetooth”     | Removed                                              |
| Missing exact rc2 revision                  | Added                                                |
| Existing `mgmt-tester` failures undisclosed | Counts included                                      |
| Additional suites still pending             | Completed or documented as interrupted               |
| Mesh control absent after baseline crash    | Isolated comparison added                            |
| Hardware testing scope ambiguous            | Emulation explicitly stated                          |
| KASAN/lockdep config not confirmed          | Generated configs published                          |
| Kernel-warning search too narrow            | Expanded, with positive control                      |
| Comparator accepts duplicates/empty results | Improved                                             |
| Build inputs unavailable publicly           | Build recipe and QEMU wrapper published              |
| Mail threading and recipients unverifiable  | Complete email published and automated checker added |
| Comparison wording fully exact              | One mesh verdict discrepancy remains                 |

The improved diagnostic check is particularly welcome. The results document reports that the expanded scanner found no kernel reports in the 18 rc2 logs, while correctly detecting the known KASAN/GPF crash in the control. That positive control is an important safeguard against an incorrectly configured scan.

The published `.eml` body also matches the reviewed text draft exactly; I compared their bodies, rather than assuming the sendable version was identical.

The four external reviews have been integrated in a traceable way, with decisions and responses in the dossier's `log.md`. That is very good review hygiene.

## 3. A separate concern with the public-address scanner

The maintainer's privacy-rule correction is sensible: publicly documented upstream addresses, trailers and Message-IDs should not be arbitrarily erased from technical references.

The [new allowlist](https://github.com/ivoitovych/qca9377-bt-hang/blob/ccb46dc/devtools/repo-scan-public-addresses), however, contains an important policy-design weakness.

An entry beginning with `@` accepts every address at that domain. For example, allowing `@linuxfoundation.org` means that an address not individually documented in an upstream submission could pass the scanner.

This differs from the stated rule, which is based on the individual address already being public, not merely its domain.

The new tests check an unlisted address on a separate, nonallowlisted domain. They do not prove that an unlisted address on an allowlisted domain is refused. Such a test should actually demonstrate that the current broad domain rule permits it.

I recommend keeping domain-wide allowances only where the domain is deliberately treated as a public-list namespace, and using exact addresses for individuals. Add a negative test using an unlisted address at a domain containing an individually allowed maintainer address.

This scanner issue does not invalidate the CO-10 email: its listed recipients are documented as originating from the upstream announcement. But it is worth addressing as a separate project privacy-hardening task, rather than treating the new allowlist as proof that every private address remains protected.

## 4. Email headers and CI status

I inspected the complete [version 4 email](https://github.com/ivoitovych/qca9377-bt-hang/blob/ccb46dc/contributions/CO-10-stable-6.6.160-rc2/drafts/reply-6.6.160-rc2-v4.eml) and the new `reply-headers-check.py`.

The headers are syntactically appropriate: they contain a sender, recipient list, subject, `In-Reply-To`, `References`, and plain-text MIME declaration. The checker correctly compares the reply's recipients with the original message's sender and recipients, excluding the reply's own sender.

The project reports 7/7 passing header checks and 20 matching recipients. I verified the checker's logic, but could not independently retrieve the original announcement's complete headers from lore. Thus, the 20-recipient match is verified against the project's saved announcement, not independently against upstream.

The GitHub Actions results also deserve a precise status report.

Commit `ccb46dc`

Queued

Repository checks

9 jobs queued

Access audit

1 job queued

GitHub reported no completed conclusions at the time of inspection.

[Repository checks](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39531113188) · [Access audit](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/39531113166)

The maintainer was correct to distinguish the manual scratch-repository tests from a successful CI run. The additional tests were written, and the manually tested positive and negative cases are documented, but the new CI jobs have not yet provided independent confirmation.

One smaller limitation remains in the verdict comparator: it can accept partial progress output from an interrupted test. That is useful for deliberately stopped suites but does not, by itself, prove that a suite ran to completion. Here the interrupted suites and their boundaries are explicitly documented, so I would not block the stable report on this tooling refinement.

## 5. One operational security correction

The maintainer says sending requires your approval and a one-time app password.

A Google app password is not automatically a one-time credential. Deleting the local copy does not revoke its authorization. Google documents a separate revocation operation.

The preferred procedure is to enter credentials locally through a protected authentication mechanism, avoid exposing them in chat or Git history, and explicitly revoke a dedicated temporary app password in Google Account settings after sending.

This is separate from the technical merits of CO-10.

## 6. Final recommendation

Technically ready after a minor correction

I would now classify CO-10 as a high-quality, useful and unusually well-supported Linux stable testing contribution.

The revised dossier provides:

- Strong before-and-after evidence for four fixes.
- Appropriate baseline regression coverage, with known failures distinguished from improvements.
- Good diagnostic instrumentation and a positive control.
- A concise, self-contained upstream email with precise kernel and environment identification.
- An auditable record of four reviews and their resolutions.

The contribution requires no new code review or integration work from the stable maintainer. Its purpose is to provide evidence for the release decision, and it does that well.

My final requirements are narrow: correct the mesh verdict wording in the email and corresponding dossier summaries, verify the final mail and release-candidate status immediately before sending, and respect the explicit authorization requirement. The scanner-domain privacy issue should be fixed separately; it need not hold up this test report if the published email contains only verified public recipients.

Verdict: approve version 4 with the mesh-reporting correction. I see no reason to restart the entire review cycle or add a major test campaign before the 22 October 2026, 07:53 UTC deadline.

No repository modifications or upstream email submissions were made.

## Reviewer 4

Re-review of CO-10, draft v4
Conditional GO — substantially improved
I’ve confirmed that the frozen ccb46dc version contains the v4 email, the restored public mailing-list headers, the new mesh comparison, and the updated review documentation.

The maintainer has addressed the main deficiencies identified in my earlier review. In particular, the previously untested comparison of the two mesh Send cancel cases has now been performed on both kernels, and the full email is available for inspection.

One precision issue remains in the upstream email: it says all other cases run on both kernels have the same verdict, but the new mesh evidence records one Send cancel - 1 run as Failed on 6.6.159 while the rc2 runs are Timed out. Both kernels fail to pass that case, so this is not evidence of a newly broken test. It does mean the literal “same verdict” statement is too strong.

This is a wording issue rather than a reason to discard the contribution. I would correct it before sending.
Detailed findings
Area	Recheck result	Severity
Mesh regression testing	Previously missing baseline cases now tested independently; no newly non-passing case identified	Resolved
Email threading and recipients	v4 includes In-Reply-To, References, plain-text MIME headers and 20 recipients; checker reports 7/7 passing	Resolved
Accurate test-suite description	Changed to “BlueZ CI TestRunner suites”	Resolved
Public evidence and links	Announcement Message-ID, complete email and previously removed reviewer links restored	Resolved
Email regression wording	“Same verdict” is not literally true for every isolated mesh run	Fix before send
Results-document consistency	Historical text still says mesh cases were not compared, although a later section compares them	Minor
Address-scanner privacy guarantee	Domain-wide exceptions are broader than individually verified public addresses	Minor, separate from email
GitHub CI	Workflow located, but it was queued when checked; no successful conclusion verified	Pending
Recommended email correction
In the v4 email, replace:
All other cases that ran on both kernels have the same verdict:

with:
No case that passed on 6.6.159 newly failed on rc2 among the directly compared completed tests:

This reflects what the evidence demonstrates, without suggesting identical Failed and Timed out classifications. The existing tester totals and L2CAP hang disclosure can follow it.

The same correction belongs in the README and any other current-state summary.
Two remaining documentation and tooling observations
The results file says that the mesh cancel cases “are not compared,” then later documents the successful additional comparison. Both passages make sense as a chronology, but the earlier one should explicitly say that subsequent isolated runs resolved the gap. There are also residual approximate timestamps such as 00:5x and 01:4x; either give verified times or omit them.

The public-address allowlist is a sensible response to losing legitimate upstream references. However, an @domain entry necessarily permits any address on that domain, whether individually confirmed public or not. Consequently, the statement that all private correspondents remain protected is too absolute. I would reserve domain exceptions for addresses where that policy is intentional and use exact-address entries when provenance matters.

Neither issue requires delaying the kernel testing report once the email wording and final checks are correct.
CI verification
I located the GitHub Actions workflow for commit ccb46dcc8b7fbc9bdc9e79a5a21a0aeaac13f9a4:
Workflow run #725
Started October 21, 2026, 02:06 UTC
Queued when checked

The new scan tests are present in tests/run-tests, and their assertions cover multiple listed addresses, listed domains, a Message-ID-embedded address and rejection of an unlisted address. But I have not independently executed that suite, and the GitHub response did not yet establish a passing run. The maintainer's claim that it passed manually remains distinct from CI confirmation.
Final recommendation
Conditional GO, with only a small amount of work remaining. The central test methodology, its relevance to the stable release, and the upstream message's usefulness remain exceptionally strong. The kernel documentation explicitly recognizes stable-release test responses and Tested-by reports as part of the review process. 


The Linux Kernel documentation



I recommend correcting the single regression-comparison sentence, confirming green CI and the final mail-header check, and checking for any newer -rc announcement before sending. I would not request more broad kernel testing for appearance's sake.

The send deadline remains Thursday, October 22, 2026, 07:53:04 UTC (09:53:04 mainland Spain time). No email has been sent by me, and no authorization is inferred. If an app password is needed, enter it through the development machine's local secure prompt rather than putting it into this conversation or the repository.

The contribution is very close to the quality standard you asked for: substantial work done by the contributor, minimal homework left for upstream maintainers.
