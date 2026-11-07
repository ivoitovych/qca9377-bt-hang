# U29 — the second outside reviewer's fifth message: !137 and the next GNOME step

*Received 2026-11-07, after the GNOME runs on master and on master with MR !137. The technical
message is kept as received, except for tooling marks, which `scripts/review-text-clean.py`
removes. A second part followed: the reviewer's answer to the project author's question about
working beside another contributor's open merge request, with a look at that contributor's
public background. It is not kept in this public repository, which records technical facts,
not assessments of people. The project's own record of !137 is the merge request's public
history (`results/u29-gnome-pairing-feedback-2026-11-07/README.md`).*

*What came of it, 2026-11-07:*
- Two runtime tests on !137 were started, as evidence: a device removed during pairing, and
  user versus peer cancellation.
- No patch to gnome-bluetooth was started. Who writes one is the author's decision.

---

The GNOME investigation has produced an important change in direction: U29 is no longer a new bug report waiting to be written. It is a reproducible case that an existing, open upstream fix fails to address.

I agree with the project maintainer's decision to stop preparing a separate GNOME issue and investigate merge request !137 instead.

## 1. GNOME: we now know exactly what is missing

Based on the maintainer's independently checked tests:

| Pairing result                 | Current master          | Master + !137   |
| ------------------------------ | ----------------------- | --------------- |
| `AuthenticationFailed` — U13   | Silent                  | Toast displayed |
| `AuthenticationRejected` — U29 | Silent; journal warning | Still silent    |
| `AuthenticationCanceled`       | Silent                  | Toast displayed |

This is stronger than a source inspection. The agent built the actual settings widget, used mock BlueZ responses, checked screenshots and logs, and then repeated the experiment with !137 applied unchanged.

The existing upstream references are:

- [GNOME issue #18 — Show error when pairing or connecting fails](https://gitlab.gnome.org/GNOME/gnome-bluetooth/-/issues/18)
- [GNOME merge request !137 — Show error toast when authentication fails](https://gitlab.gnome.org/GNOME/gnome-bluetooth/-/merge_requests/137)

I couldn't independently open those GitLab pages through web access, so I am relying on the maintainer's retrieved discussions and experiments for their current state.

### My recommendation: prepare a small extension to !137 locally

Rather than merely commenting that `AuthenticationRejected` is missing, I would have the agent prepare a minimal patch adding that case to the toast handling and its regression test.

Then you would have something substantive to offer: a tested correction to an existing contribution, accompanied by independently reproduced evidence.

There are two details I would insist on addressing before submission.

First, don't assume `AuthenticationRejected` means the device isn't in pairing mode. That is a plausible explanation for U29, but not the only possible cause. A safer message would be:

> Pairing with “MOMENTUM 4” was rejected. Check that the device is ready to pair and try again.

Second, I am not convinced that displaying a toast for every `AuthenticationCanceled` result is desirable. If the user intentionally canceled pairing, an error toast would be unnecessary and potentially misleading. The existing merge request should be checked for how it distinguishes deliberate cancellation from unexpected cancellation.

### The possible crash deserves a separate regression test

The agent identified a possible null dereference when a device disappears while its asynchronous pairing operation is in progress.

That deserves a test which removes the mock `Device1` object before completing `Pair()` with an error.

It could reveal a real crash, but the code inspection alone does not establish one. I would not describe it as a confirmed defect until the test reproduces it.

## 2. BlueZ: the patch is progressing correctly, but the decisive tests are still running

The BlueZ agent has already established that the candidate builds successfully on both upstream master and the Ubuntu 5.72 baseline, with clean style checks and passing master unit tests.

That's a good start, but it isn't yet evidence that the patch is safe.

The particularly important scenario is a dual-mode device that can be contacted over either BR/EDR or LE. The original defect exists partly because a non-discoverable LE advertisement updates the state associated with a BR/EDR-created object.

I would examine three questions in the eventual results:

1. Does the patch prevent an explicitly non-discoverable advertisement from extending the lifetime of an unpaired, disconnected device?
2. Does it preserve bearer-selection information when the device is paired, connected or actively pairing?
3. Does it distinguish an advertisement with no Flags field from an advertisement that explicitly declares non-discoverability?

That last distinction is subtle. The current BlueZ path treats both as non-discoverable for this discovery filter, but the absence of Flags is not necessarily equivalent to an explicit declaration by the peripheral. If a proposed fix changes both cases identically, its compatibility implications deserve attention.

The rest of the reported matrix—discoverable advertisements, no advertisements, paired/trusted devices, long pairing operations and long-lived connections—is appropriate.

One further observation from test 2 is worth preserving: the timeout depends on advertisements received by BlueZ, not merely transmitted by the peer. The two early removals out of nine trials are therefore not evidence against the root-cause analysis. Any test assertions should use the received-report timestamps.

## 3. What this means for upstream contributions

My suggested priorities are now:

| Candidate                                       | Current assessment                        | Next action                                                           |
| ----------------------------------------------- | ----------------------------------------- | --------------------------------------------------------------------- |
| GNOME missing `AuthenticationRejected` feedback | Reproduced on current master and !137     | Prepare and test a minimal local extension                            |
| BlueZ temporary-device lifetime                 | Reproduced; candidate patch under testing | Finish safety matrix, inspect diff                                    |
| BlueZ A2DP `a6ac17f0e393` backport              | Reproduced and validated                  | Keep as independent Ubuntu backport candidate                         |
| BlueZ emulator IO Capability reason             | Source defect identified                  | Prepare isolated one-line fix and test                                |
| Persistent authentication-failure reporting     | Architectural need remains                | Evaluate existing `Device1.Disconnected` API before designing changes |

The GNOME result is especially compelling because it turns two separate real incidents—U13 and U29—into regression cases for two different failure branches of one longstanding UI problem.

## 4. One process improvement

The maintainer's disclosure about the accidentally staged GitLab pages and build logs is useful. Catching sensitive information before publication is exactly what the repository checks should accomplish.

I support retaining only minimal reproducibility assets in the repository, leaving large raw artifacts local with checksums, and running publication validators against the actual staged contents. Allowlists should remain limited to exact, verified public addresses or fixed test constants.

## Conclusion

I would let the BlueZ test matrix finish without redirecting the agent. In parallel, I would authorize one additional local GNOME experiment: extend !137 to handle `AuthenticationRejected`, test device disappearance during the asynchronous callback, and examine the cancellation UX.

No new GNOME issue, no upstream comment and no patch submission yet.

The next meaningful review is no longer about whether these bugs exist. The evidence now establishes that. It is about whether the proposed changes correct them without creating new failures, and whether they fit the maintainers' existing work.
