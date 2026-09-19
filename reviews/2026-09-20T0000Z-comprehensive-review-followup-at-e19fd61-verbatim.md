# Verification of the comprehensive-review response

**Verdict: substantial, verified progress; the review is not fully closed.** The maintainer accepted the substantive findings and implemented real fixes. However, some findings marked fixed have unaddressed parts, the current narrative still contradicts its corrections, and DR-10/DR-11 remain explicitly open.

Reviewed initial follow-up head: `c99dd7da5604670aca87f754f10ef14c946b8dac`. Main advanced during verification to **`e19fd61a0af0ff9ddd88eb2e1cbc226b0ae175dd`**. I fetched and inspected that delta: it changes only `devtools/ci`, its standalone proof and suite tests. The reviewed fixes and remaining defects below are unchanged. The original review baseline was `682d15c97bbd10019b81379a9e4e03127f6c47a1`.

No production hardware, installed services or repository content was modified. Tests used temporary files, synthetic devices/journals and command spies. This review cannot certify deployment on the investigation laptop.

## Finding-by-finding disposition

| Original finding | Verified status | Assessment |
|---|---|---|
| DR-01: upstream QCA entry | Documentation substantially corrected; hardware validation pending | The accepted commit is named and its setup/reset path correctly marked untested. Some residual present-tense wording and overbroad stable-release claims need qualification. |
| DR-02: 27/9 packet interpretation | Main correction done; related alt-3 inference remains | Three 9-byte packets is now stated correctly. The bug report still says no alt 3 exists, which is not established by fallback selection. |
| DR-03: command causes wedge | Partial | Appropriate caveats were added, but “issue any HCI command” and “no harm” remain in active documents. |
| DR-04: regression/recovery certainty | Partial | The README still says this hardware falsifies the author's alt-6 observation. CVSD safety and recovery claims remain too broad. |
| DR-05: capture rotation | Fixed, verified | Failed pruning stops rotation; absent Python Bluetooth support now produces a controlled error. |
| DR-06: sanitization status | Reported failure case fixed; missing-sanitizer case incomplete | Failure produces nonzero status and a failed manifest. No sanitizer still produces exit 0. |
| DR-07: trial intervention/evidence deletion | Significant fix, partial closure | Passive shutdown and default marks no longer probe; tracked abort is refused. Passive outcomes can still invent survival, `BT_TRIAL_PROBE=0` probes, and untracked evidence is still deleted on abort. |
| DR-08: uninstall/restoration | Disabled-file defect fixed; ownership issue remains | `.disabled` siblings are removed. Unrelated pre-existing files are still overwritten and subsequently deleted. |
| DR-09: hardcoded USB port | Core finding fixed, verified | VID/PID discovery, missing-path error and multiple-match refusal work. |
| DR-10: reproducible raw evidence | Open, explicitly acknowledged | The complete bounded input and supplementary EX-043 derivation have not been committed. |
| DR-11: capture timestamps/completeness | Open, explicitly acknowledged | Kernel timestamps, declared-length validation and completeness accounting remain pending. |

The maintainer did not provide a technical rebuttal overturning the main review findings. The policy of withholding a kernel report until a patch exists was consciously retained. That is a project decision, not a failed implementation of a required correction.

## What I verified by execution

The maintainer's standalone proof hardcodes `/root/exp/qca9377-bt-hang`. I ran a temporary copy with only that checkout path changed to this environment. **All 14 checks passed.** Those checks cover alternate-port discovery, no match, missing explicit port, ambiguous devices; sanitizer failure/success; three disabled configuration files; passive normal/failure shutdown and opt-in probing; tracked/untracked abort; rotation failure; and absent `AF_BLUETOOTH`.

The `bt-mark` fix deserves explicit credit: the maintainer traced an additional probe through a helper after removing the obvious probes. Exercising the actual helper chain is stronger than checking the top-level function in isolation.

The full local suite at `c99dd7d` reported **5 failures out of 773 invariants**, all in the same unsupported-awk sanitization cases as the original review. The capture no-socket failure from the earlier run is gone. The suite also reported unchanged tracked files, evidence, trial state and system binaries. Missing local Bluetooth/coredump tools still limit the contracts exercised. I did not rerun the entire suite after the CI-only `e19fd61` delta.

[CI at c99dd7d](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/35471090051) succeeded. [CI at e19fd61](https://github.com/ivoitovych/qca9377-bt-hang/actions/runs/35471498050) was still running when checked. Green CI establishes the encoded tests pass; it does not establish that every original review requirement is covered.

## Remaining functional problems, independently reproduced

### F1 — Passive shutdown confuses lack of observed failure with measured survival

The shutdown path now avoids HCI probes, as requested. However, it calls `ok` when its initial timeout scan returns zero. The closer skips liveness testing under `BT_TRIAL_PASSIVE`, then sets `trial_result=survived` (commented “alive, untouched”), or `alive_after_intervention` after an intervention.

Using the standalone proof's synthetic controller and journal, I exercised a controller whose liveness stub would fail, with no timeout logged. I also made the journal command fail outright. The recorded rows were:

```text
passive-dead:  bt1_status=not_observed trial_result=survived responds_after=unprobed
journal-error: bt1_status=unknown      trial_result=survived responds_after=unprobed
```

The second result does preserve `bt1_status=unknown`; the summary excludes that status from its BT-1 rate. Therefore this is not a claim that the summary necessarily counts the unreadable journal as a successful trial. The outcome field and user-facing survival verdict are nevertheless unsupported, and the first case demonstrates the absence-of-timeout versus liveness distinction directly.

**Required correction:** passive closure should express observation ending/censoring or unknown liveness without asserting alive/survived. Update the outcome schema and consumers together, and retain a separate `not_observed` phenotype value when the journal is readable. Test missing evidence and a silent unresponsive controller, not just empty-journal→survived.

[Relevant source](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/tools/bt-trial): `autostop` and the axis-2 classifier.

### F2 — A zero-valued opt-in still enables probes

The code uses:

```bash
if [[ -n "${BT_TRIAL_PROBE:-}" ]]; then
```

Consequently **`BT_TRIAL_PROBE=0` still issues HCI commands**. I confirmed this with the hciconfig spy. This contradicts the documented opt-in `BT_TRIAL_PROBE=1` and matters because observational safety is the purpose of the change.

**Required correction:** compare explicitly with `1`; reject other unsupported values or treat `0`/unset as passive. Add a zero-valued test. Similar nonempty handling of `BT_TRIAL_PASSIVE` should have a deliberate, documented contract.

### F3 — Uninstall closure omits the pre-existing-file part of DR-08

A staged test created an unrelated original `/usr/local/bin/bt-mark`, ran `install.sh --tools-only`, then `uninstall.sh --apply`:

```text
install exit 0:   original contents overwritten
uninstall exit 0: original file absent
summary:         “Uninstall is a complete restoration.”
```

This is the second half of the original DR-08, not a newly expanded requirement. The maintainer's disposition reduced DR-08 to `.disabled` cleanup, so its “fixed” label is incomplete.

**Required correction:** refuse unmanaged collisions or preserve/restore originals through an ownership/baseline record. Apply that policy to generated configurations too. Remove the unconditional claim that no pre-existing file was modified. The `.disabled` cleanup itself works.

[Installer](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/install.sh), [uninstaller](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/uninstall.sh).

### F4 — Missing sanitizer is still a successful collector exit

In a temporary copy with synthetic journal output and no available sanitizer, collection returned:

```text
exit=0
sanitised=NO-SANITISER
```

The manifest is now honest in this case; it does not falsely say `yes`. But the new source comment promises that exit status indicates whether the session may be published, and exit 0 violates that promise. The per-file failure fix correctly handles a present sanitizer returning an error.

**Required correction:** missing sanitizer must also produce a nonzero exit and an explicit unpublishable notice. Audit generated post-loop files separately; the current loop is not an all-session sanitization guarantee.

[Source](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/tools/bt-incident).

### F5 — Abort preserves tracked evidence but still removes untracked evidence

The tracked-file refusal works, including staged files in a temporary Git repository. The proof explicitly verifies that removing the file from the index permits deletion of the whole directory. Tracking status is not equivalent to evidentiary value; newly captured files are often untracked.

The original recommendation was to preserve aborted trials with an outcome/reason and refuse tracked destruction. Only the latter is implemented. This can be an explicitly accepted narrower policy, but it should not be presented as full implementation of that recommendation. Prefer keeping aborted records by default and making scratch deletion separate.

## Narrative corrections are not complete

These are current summary/report claims, not merely historical quotations that must be preserved:

- **README:** “the assumption this hardware falsifies” still introduces the quotation about not finding alt-6 adapters. A device without alt 6 does not falsify that observation.
- **README reproduction instructions:** “issue any HCI command. It dies …” still asserts the generalization now disclaimed elsewhere.
- **Bug-report summary:** “finds no alternate setting 6 or 3” remains. Alt-3 selection also depends on SCO MTU and a quirk flag; falling back does not prove absence.
- **Bug-report interval section:** still says 9.65 seconds “with zero commands in flight and no harm.” Command-path health was not measured in that interval.
- **Bug-report reproduction instructions:** still say “issue any HCI command.”
- **BRIEF and bug report:** still state “CVSD … is safe.” Say that the documented CVSD controls survived.
- **README/BRIEF/bug report:** “every tested recovery failed” needs a state/window qualifier. The record contains an early successful recovery; replacing an absolute impossibility claim with an absolute all-tests-failed claim is not enough.
- **README:** “not in … a stable release yet” is broader than the maintainer's stated checks of v7.0, 6.6.y and 6.12.y. Limit it to the actual checked refs or verify the wider claim.

The correction added to one paragraph does not neutralize a contradictory assertion a few paragraphs later. The maintainer's statement that the wrong wording was corrected everywhere is not supported by this head.

Sources: [README](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/README.md), [BRIEF](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/BRIEF.md), [bug report](https://github.com/ivoitovych/qca9377-bt-hang/blob/e19fd61/docs/bug-report.md).

## What is still deliberately pending

DR-10 and DR-11 are clearly identified as open in the maintainer's response; acknowledging them is correct, but it is not completing them. The repository-maintained public-email allowlist is also open under new register entry DR-12. Testing the upstream QCA setup/reset change and separating command causation from prior loss of responsiveness remain hardware experiments. Dedicated BlueZ callback regressions remain pending; the BlueZ patch files themselves were unchanged by this response.

The maintainer explicitly says the changed tools were **not deployed** by the fix commit. In addition, `--tools-only` skips `systemctl daemon-reload`. If deployment must make the changed unit's `TimeoutStopSec=30` effective immediately, that requires a deliberate daemon reload; copying the file alone is insufficient. Verify the installed script versions and the manager's loaded unit configuration before declaring the laptop's shutdown behavior updated.

## Closure recommendation

Accept the maintainer's capture, sanitizer-error, passive-command-removal, tracked-abort, disabled-file and USB-discovery work as verified improvements. Reopen or mark partial DR-02/03/04/06/07/08 with the specifics above. Keep DR-10/11 and the recorded follow-ups open. Correct the active narrative, add the missing negative-path tests, and verify deployment separately.

**The review has been processed responsibly, but it has not yet been fully implemented.** Nothing in this follow-up creates a new reason to withdraw the two independent BlueZ crash fixes.
