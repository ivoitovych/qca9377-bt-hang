# Elaboration of review results — 20260813-165243

**Branch identity:** `fixes/review-results-20260813-165243-utc`

**Base:** `d8b7abed8935872c86457f3fb062220f1971d7c1` (`origin/main`)

**Scope:** six findings from the external review supplied for this branch

**Disposition:** implemented locally; retained-journal re-capture remains a machine action

The timestamp is the branch timestamp rather than the document-writing time. It keeps this
elaboration, its fixes and any later verification report under one review identity.

## Overall result

All six findings were confirmed in substance. One historical qualification matters: the
previous full-tree review had already identified part of the documentation-residue class as
F7/F17. The new review did not discover that class from nothing; it demonstrated that the
earlier correction had not propagated far enough and found three additional semantic gaps
outside that earlier disposition (`bt-diagnose`, reset provenance and the phase null).

## Finding dispositions

| # | Finding | Disposition |
|---|---|---|
| 1 | Current BT-1 model contradicted by user-facing documents | Fixed and mechanically guarded |
| 2 | `bt-diagnose` converted aggregate counts into a causal verdict | Fixed; now phenotype-only |
| 3 | `stage2.awk` inferred reset provenance from missing bus errors | Fixed; positive/kernel/unknown categories |
| 4 | `bt-phase` treated independence alone as a uniform-phase null | Fixed; constant-hazard null stated |
| 5 | User-facing tools/comments retained the retired Stage-2/reset model | Corrected across current-facing tools |
| 6 | EX-004/EX-005/fix-proposal summaries over-interpreted intervention aftermath | Re-annotated without rewriting captured output |

## 1. One current BT-1 formulation

`docs/issues.md` remains authoritative. Its current BT-1 paragraph is marked with
`BT1-CURRENT-BEGIN/END` and reproduced byte-for-byte in:

- `README.md`
- `docs/bug-report.md`
- `docs/fix-proposal.md`

`tests/run-tests` extracts those blocks and fails if they differ. A second assertion scans
the current-facing documents and tools for the retired high-risk phrases: two-stage failure,
recovery-window closure, exact reset-path equivalence, autosuspend-as-trigger and generic
reset-safety claims.

The affected sections were rewritten around the two statements the evidence supports:

1. HCI non-response while USB remains enumerated is established.
2. USB collapse has only been observed after intervention, so its untreated relationship
   to BT-1 is unresolved.

## 2. `bt-diagnose` reports a phenotype, not a mechanism

The old implementation summed timeout, reset and firmware-message counts across every
retained boot, then used any reset anywhere to declare the current controller's reset
callback installed and working. With zero resets it declared that the kernel did nothing;
with zero firmware messages it inferred `driver_info=0`.

The tool now says explicitly that these records are aggregate, unpaired and not stably
VID:PID-scoped across boots. Its exit contract is:

- `0`: no timeout phenotype observed in retained history;
- `1`: timeout phenotype observed, with no cause inferred;
- `2`: cannot determine.

For `13d3:3503` it directs the operator to `bt-verify-kernel-mechanism`, where the separate
source/module/device-table fact belongs. The verdict is isolated in a sourceable function;
tests prove that reset messages do not suppress the phenotype, aggregate counts produce no
callback/firmware verdict, and a zero is absence of observation rather than proof of health.

## 3. Reset provenance in `bt-stage2`

The old classifier treated this implication as true:

```
target USB reset + no recognized preceding bus error -> OUR intervention
```

That is not provenance. The classifier now separates:

| Terminator | Evidence required | Interpretation |
|---|---|---|
| positive intervention | watchdog marker or btusb driver unload | operator/watchdog-censored |
| kernel treatment reset | explicit Bluetooth reset-callback message | A/B/C/D treatment-censored |
| unknown-origin reset | generic target USB reset without a positive marker | censored, origin unknown |
| hub recovery after recognized bus error | bus error precedes hub reset | remains in stock trajectory |
| direct USB disconnect | no prior censoring terminator | natural under the classifier |

Default acquisition now merges kernel records with `bt-hang-watchdog.service`. Historical
kernel-only caches remain readable, but their clean resets become `unknown-origin` rather
than `OURS`.

The stage-2 fixture now contains a marker-backed watchdog reset, a clean reset with no
provenance, and an explicit automatic kernel-treatment reset. The suite asserts all three
categories independently.

### Required machine re-capture

EX-018 and EX-020 preserve verbatim historical output. Their 14/0 headline may remain true,
but the classifier that produced the 9 reset / 5 shutdown breakdown could hide a natural
trajectory by calling an unknown reset “ours.” Both exhibits and the index now say so.

The affected machine must rebuild or re-read the retained journal with current `bt-stage2`
before that breakdown is cited again. This checkout does not contain the machine's
3.3-million-line journal, so fabricating a replacement result here would repeat the defect.

## 4. `bt-phase` null model

Normalising an event by the probe gap containing it does not make phase uniform from probe
independence alone. Failure hazard can vary with boot age, audio activity or time of day
without being caused by probes.

The tool now states the actual reference model: approximately constant failure hazard within
probe gaps, independent of the probe schedule. Output no longer interprets a departure as
uniquely probe-related or a non-departure as evidence of independence. EX-012 preserves its
old captured output but annotates this statistical correction.

## 5. Current-facing tool semantics

- `bt-usbmon` now describes USB capture as evidence needed to separate untreated behavior
  from intervention aftermath, not as “the only record of Stage 2.”
- The watchdog describes `USBDEVFS_RESET` as a proxy with a different path and context from
  `usb_queue_reset_device()`.
- Early audio-teardown triggers are labelled mitigation heuristics. Historical boot-level
  ratios are not called predictive precision, and an early intervention is explicitly a
  censored BT-1 counterfactual.
- A controller that answers after an early intervention is no longer logged as a recovered
  failure. New output says the controller responds after intervention and that the
  counterfactual is censored; readers still recognize historical wording.
- `bt-status`, `bt-postmortem`, `bt-health-report` and `bt-boot-stats` no longer convert USB
  absence into a natural second stage or advise a lower reset threshold from that premise.

## 6. Historical evidence and patch evaluation

EX-004 and EX-005 still report the events that occurred, but their claims now distinguish
observation from interpretation:

- an early reset left the controller answering, then HCI non-response appeared later;
- a late intervention did not restore HCI and was followed by USB loss;
- neither sequence identifies the untreated counterfactual or proves a recovery deadline.

The A/B/C/D proposal now scores benefit and harm on separate axes. In particular, an
automatic +0 s reset followed by excess USB loss is a harmful treatment result, not merely
“A failed.” The suggested upstream commit text states explicitly that every observed
USB-loss incident followed reset/rebind/reload and that warm-reboot behavior is unmeasured.

## Verification contract

The repository gates for this change are:

```bash
./tests/run-tests
./devtools/repo-validate .
./devtools/repo-scan . --all
```

The new suite total is 76 invariants. In addition to the normal gates, the final staged diff
and the raw commit object must be inspected before any push so author, committer, message and
trailers are known rather than assumed.
