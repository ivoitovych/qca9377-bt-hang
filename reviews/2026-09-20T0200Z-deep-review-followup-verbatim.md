# Follow-up to the deep review — verbatim, from the operator's paste of 2026-09-20

---

Yes. I re-reviewed the maintainer's response against the actual current tree, not just the commit message. The current head I found is `6a7c7a46d7cbb1d20f0c6ea765a64668eda3d240`, one commit after `b618a1e`, and it is clearly the response to the Deep Research review.

My conclusion is: **the maintainer processed the review well and, importantly, did not pretend the experimental recommendations were already proven.** The principal defect from my review—the false-green `rg` assertions—is genuinely fixed. The stale fix proposal is materially corrected. The kernel-experiment recommendation is recorded accurately as future work. I do, however, see **three residual issues in the response itself**, none of which invalidates the fixes.

### What was handled correctly

The most important item, the `rg ... || true` problem, has been fixed in the right conceptual way. The old construction conflated "search found nothing" with "search failed." The new `neg_search()` explicitly distinguishes `grep` exit 0, 1 and error, and an error now calls `bad` rather than being interpreted as an empty result. That directly addresses the failure mode I identified.

The second narrative correction is also right. `docs/fix-proposal.md` now immediately says the proposal is superseded and explains that upstream already added `13d3:3503` to the QCA ROME quirks table. That upstream fact is independently correct: `dc16388d45ec` adds exactly this USB ID with `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`, and the upstream commit says the motivation was a BLE-scanning failure.

The maintainer also adopted the crucial distinction I wanted preserved: **testing a kernel containing the new quirk is not the same as proving the quirk fixes this wedge**. `BRIEF.md` now explicitly proposes the useful experimental ladder: baseline, QCA setup without automatic reset first, then alt-1 restriction, then upstream-like behavior. That is scientifically much better than simply booting upstream and calling any result causal.

Likewise, the bug report now correctly warns that kernel version alone is not sufficient to tell whether the device-ID addition is present, because a distro may backport it. The right thing to establish is the actual running `btusb` behavior/source. That is a good correction.

And I specifically like that DP-04 is recorded as **"operator's decision / not started"** rather than marked fixed. The kernel experiment is evidence still to be collected, not a documentation bug that can be closed by writing about it.

### Residual finding 1 — the new anti-`rg` regression guard is incomplete

This is the most substantive remaining issue.

The new invariant says, in effect, "the suite invokes no ripgrep," but it only scans:

```bash
tests/run-tests
```

That is inconsistent with the infrastructure already present at the top of the same file. `run-tests` explicitly defines `SUITE_FILES` so self-checking invariants will continue to cover `tests/parts/*.sh` after the planned UT-12 split.

So when the monolithic runner is eventually split—the very maintainability change discussed in the review—the new `rg` guard can silently stop protecting moved tests.

There is also a narrower regex problem. The guard searches approximately for:

```text
rg -...
rg '...
```

It catches the old `rg -n ...` form, but not perfectly ordinary invocations such as:

```bash
rg "BT-[1-4]" file
```

I tested that exact shape against the new regex; it does not match.

So I would call DP-01 **functionally fixed now, but its regression guard only partially complete**. The guard should operate over `SUITE_FILES` and detect the `rg` command token independently of whether the next argument starts with `-`, `'`, or `"`. This is a medium maintainability finding, not a reopening of the original defect.

### Residual finding 2 — the two new verification helpers are not portable, and one has a cache trap

Both new scripts contain:

```bash
cd /root/exp/qca9377-bt-hang
```

That means `scripts/prove-neg-search.sh` cannot actually be run "standalone" by an external reviewer who clones the project somewhere else. The same is true for `scripts/ci-log-search.sh`.

Given that these scripts were specifically added as reproducibility/proof machinery in response to an external review, I would change that to a path derived from the script itself, for example the repository parent of `scripts/`.

There is also a small but real bug in `ci-log-search.sh`. It does this:

```bash
[[ -s "$LOG" ]] ||
    gh run view "$ID" --log > "$LOG" 2>&1 ||
    ...
```

If `gh run view` fails after emitting an error message, the redirected `$LOG` may nevertheless be nonempty. The current invocation exits correctly—but on the **next invocation**, `[[ -s "$LOG" ]]` succeeds and the script can treat the cached error text as a previously downloaded CI log instead of retrying GitHub.

The safer shape is download into a temporary file and `mv` it to the cache name only after `gh` succeeds.

I would classify these as **medium-small tooling defects**, because neither affects the Bluetooth evidence or the repaired CI assertion itself.

### Residual finding 3 — the superseded document still advertises itself as a "Fix proposal"

The banner is good enough to prevent a careful reader from misunderstanding the document once it is opened. But the first line is still:

> `# Fix proposal — btusb: add QCA9377 ...`

That means search results, GitHub file previews, cross-references, or somebody scanning filenames/headings can still get exactly the stale impression my original review objected to.

I would rename the heading to something like:

> **Historical fix proposal — superseded by upstream `dc16388d45ec`**

or:

> **Superseded QCA9377 quirks-table proposal and behavior analysis**

There is also one sentence in the new banner I would soften. It says the reset path has demonstrations of **"destroying this device."** The evidence is much more precise: late reset/rebind attempts have driven an already wedged controller into USB-level disappearance requiring power removal. "Destroying" can sound like permanent hardware damage, which has not been demonstrated.

That is a documentation-precision issue, not a technical disagreement with the underlying conclusion.

### About the CI-red finding

The maintainer's treatment of the stale coverage exclusion looks reasonable. The response correctly distinguishes it from the `rg` problem and says the line-pinned exclusion had already been re-derived in `4c68064` and again in `b618a1e`.

There is an important timing point here: the Deep Research run began while the repository was changing rapidly, and `b618a1e` was committed during approximately the same review window. So I do not regard the response's statement "the red run the reviewer saw had already been fixed" as evasive; it is consistent with the commit chronology.

I could not independently pull the **push-triggered GitHub Actions run for `6a7c7a4`** through the GitHub connector available to me—it currently returns no push workflow runs for that commit—so I won't claim that I independently verified today's final CI status from the Actions log. The source-level fix itself is independently checkable and correct.

### Revised disposition

I would update my previous review approximately like this:

| Previous item                           | Current disposition                                                                 |
| --------------------------------------- | ----------------------------------------------------------------------------------- |
| False-green `rg` assertions             | **Fixed in the actual affected assertions**                                         |
| Regression protection for that defect   | **Mostly fixed; guard needs strengthening**                                         |
| Red stale coverage exclusion            | **Addressed before/around review response; no longer a substantive review finding** |
| `fix-proposal.md` misleadingly current  | **Substantially fixed; heading and one phrase still worth cleaning**                |
| Test current QCA-aware kernel           | **Correctly remains OPEN**                                                          |
| Separate QCA setup from automatic reset | **Correctly recorded as next experiment, not falsely marked done**                  |
| Same-tree alt-1 causal experiment       | **Correctly remains OPEN**                                                          |
| Kernel-version/backport caveat          | **Fixed/adopted**                                                                   |
| Monolithic test suite                   | **Still open, explicitly acknowledged**                                             |
| Branch/governance cleanup               | **Still open, explicitly left to operator**                                         |

So: **I would accept the maintainer's response to the Deep Research review. I would not send it back as "review not processed."** The substantive technical corrections landed.

I would send back a **small follow-up with three concrete items**: strengthen the `rg` guard to cover `SUITE_FILES` and all normal invocation forms; make the two new scripts repository-relative and fix the failed-download cache poisoning; rename the superseded fix-proposal heading and replace "destroying this device" with the exact observed failure mode.

None of those three should delay the much more important next step: **the controlled kernel experiment.**
