# Foundation-file consistency review — 2026-09-13

**Scope.** `README.md`, `HISTORY.md`, `BRIEF.md`, `docs/issues.md`,
`docs/fix-proposal.md`, `docs/bug-report.md`, `docs/investigation-plan.md`,
`docs/tooling-index.md`, checked against the actual state of the project (42 exhibits,
34 phases, `patches/bluez/`, the tool tree).

**Method.** Single agent, no delegation, as asked. Every claim below was checked against
the file, not recalled.

---

## Summary

One finding dominates: **the project's central result has not reached a single
foundation document.** Everything else is downstream of that, or cheap.

| # | finding | severity |
|---|---|---|
| 1 | The alt-1 result exists only in `EX-037…041`, `HISTORY` Phase 34 and `BRIEF.md` | **critical** |
| 2 | `README` names `docs/issues.md` authoritative and "kept current"; it cites `EX-021` of 42 | **critical** |
| 3 | The marker-synced `BT-1` statement is stale in all three copies at once | **high** |
| 4 | `HISTORY` had no forward pointers from superseded claims | **high** — *fixed* |
| 5 | `BRIEF` §5 overstated a retraction | **high** — *fixed* |
| 6 | Lessons from Phases 1–27 were never distilled | **medium** — *partly fixed* |
| 7 | 2,648 lines of stream-3 docs all predate the finding they exist to deliver | **high** |

---

## 1. ⚠️ The central finding is not in any foundation document

Highest exhibit cited, per file:

| file | highest `EX-` | lines |
|---|---|---|
| `docs/fix-proposal.md` | **`EX-018`** | 657 |
| `docs/issues.md` | **`EX-021`** | 503 |
| `README.md` | `EX-033` | 727 |
| `docs/investigation-plan.md` | `EX-033` | 789 |
| `docs/bug-report.md` | `EX-034` | 699 |
| `HISTORY.md` | `EX-041` | 2,806 |
| `BRIEF.md` | `EX-041` | 153 |

The result — **transparent SCO → alt setting 1 → 27-byte mSBC frames into a 9-byte
isochronous endpoint → controller stops answering in ~2.15 s**, `n = 5` across three
kernels, with alt 1 read directly from `sysfs` three times — appears in **none** of the
first five.

What `README` does carry (lines 512–529) is the *predecessor* of this finding: the source
argument that `BTUSB_USE_ALT1_FOR_WBS` selects alt 1 in a bare `else` that "logs nothing".
True when written, and now superseded by direct observation.

**Consequence:** a maintainer arriving at `docs/bug-report.md` — the file whose entire
purpose is to be sent upstream — gets the pre-alt-1 project.

## 2. ⚠️ The file `README` calls authoritative is the stalest one

`README.md` lines 63–66:

> ⚠️ **Sections below this point were written earlier and are being rewritten.** Where a
> section states a cause […] treat `docs/issues.md` as authoritative — **it is kept current**
> and this front page is not yet.

`docs/issues.md` cites nothing later than **`EX-021`**. It is *less* current than the
`README` that defers to it (`EX-033`). Readers are being routed from a stale page to a
staler one, with an explicit assurance of currency.

**This is the single most misleading sentence in the repository** and should be fixed
before anything else, even if the underlying documents are not rewritten today.

## 3. The `BT-1` sync gate checks agreement, not currency

`README.md`, `docs/fix-proposal.md` and `docs/issues.md` each carry the statement between
`<!-- BT1-CURRENT-BEGIN -->` / `<!-- BT1-CURRENT-END -->`. All three are **byte-identical**
(verified by `md5sum`) and `tests/run-tests:722` enforces that.

The mechanism works exactly as designed — and all three say:

> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions, while remaining USB-enumerated.

which is the **August** statement. A gate that proves three copies agree cannot notice that
all three are out of date. Same class as `BRIEF.md` staleness, and worth the same kind of
cheap check.

⚠️ **Not changed in this review.** It is the project's central public claim and three files
move atomically; the wording is proposed below for the operator's approval rather than
applied.

**Proposed replacement:**

> When this controller negotiates transparent (mSBC/WBS) synchronous audio, `btusb` selects
> USB alternate setting 1 — a 9-byte isochronous endpoint — and 27-byte mSBC frames are
> submitted to it. Roughly 2.15 s later the controller stops answering HCI, and also stops
> answering USB control transfers, while remaining enumerated. Only removing power recovers
> it. Observed 5 times across 3 kernels; the alternate setting is read directly from `sysfs`.
> The **mechanism** — how that traffic wedges the device — is not established.

## 4. `HISTORY` had no forward pointers from superseded claims — *fixed*

`HISTORY` records what was believed *when*, which is correct and should not be rewritten.
But a reader stopping at Phase 30 met "It is anonymous by construction" as a settled
conclusion, with the correction 700 lines later and no signal it existed.

Three `⚠️ SUPERSEDED` / `STRENGTHENED` blocks added, in place, pointing forward:

- Phase 30, *"anonymous by construction"* → Phase 34 / `EX-036` names it `0x0406`.
- Phase 30, the alt-1 objection → reasoning stands, but alt 1 is now directly observed.
- Phase 32, `"→ silence → alt 1"` → wrong; an artefact of `EX-036`'s own grep.

**Convention proposed:** when a phase's claim is overturned, add a blockquote at the claim
naming the phase and exhibit that overturned it. Cheaper than rewriting history, and it
makes the document safe to read from the top.

## 5. `BRIEF` §5 overstated a retraction — *fixed*

`BRIEF.md` listed:

> "`0x0428` is submitted and never answered" → **FALSE** — answered every time

"Answered every time" is itself wrong. `EX-006` (Phase 19, 05:00:16) recorded a `0x0428`
that genuinely was **not** answered and timed out 2.169 s later — the only one in that boot.
The retraction applies to the *general characterisation of `BT-1`*, not to every instance.

⚠️ Worth recording plainly: **the file created to stop retracted claims being re-asserted
introduced an over-broad claim of its own**, within a day of being written. Compression is
where nuance dies; §5 entries must name the scope of what they retract.

## 6. Lessons from Phases 1–27 were never distilled — *partly fixed*

`### The shape` sections begin at **Phase 28**. The first 27 phases hold their lessons in
prose, unextractable without reading ~2,000 lines.

Sampled three, all durable, none previously in `BRIEF` — now added to §8:

- **Phase 14** — *separate what the operator did (unknown) from how the controller
  responded (measured).* The reproductions were never a controlled procedure; every trigger
  attribution is an inference read backwards from logs. This is still load-bearing: it is
  exactly the caveat `EX-040` carries.
- **Phase 17** — *a flag is not one behaviour.* `BTUSB_QCA_ROME` installs six things, so an
  A/B toggling it isolates none of them.
- **Phase 25** — *one observation is an anecdote; build the tool that checks the corpus.*
  `bt-stage2` turned one boot into 22 boots and 3.3 M lines.

⚠️ **Not exhaustive.** Only Phases 14, 17 and 25 were read in full. Phases 1–13, 15–16,
18–24, 26–27 remain unharvested — a bounded, worthwhile task.

## 7. The stream-3 documents are the wrong size and the wrong age

```
docs/investigation-plan.md   789 lines   ≤ EX-033
docs/bug-report.md           699 lines   ≤ EX-034
docs/fix-proposal.md         657 lines   ≤ EX-018
docs/issues.md               503 lines   ≤ EX-021
                           -----------
                           2,648 lines, none reflecting the finding
```

These predate the result they exist to communicate. The bug report in particular now
understates the case: it argues from timeout statistics and a missing `hdev->reset`, when
the project can now name the endpoint, the frame size, the interval and the recovery
failure.

**Recommendation:** rewrite `docs/bug-report.md` first and alone. It is the deliverable;
the other three are internal and can follow. A shorter report built on `EX-037`–`EX-041`
would be stronger than the current long one.

---

## What was changed by this review

| file | change |
|---|---|
| `BRIEF.md` | §5 retraction scoped correctly; three Phase 14/17/25 lessons added to §8 |
| `HISTORY.md` | three forward-correction blocks (Phases 30, 30, 32) |

Nothing else was edited. Findings 1, 2, 3 and 7 are proposals, because each changes a
public claim or a deliverable and belongs to the operator.

## Recommended order

1. **Fix the `docs/issues.md` "kept current" sentence in `README`** — one line, removes an
   active falsehood.
2. **Update the `BT1-CURRENT` block** (3 files, atomic, test-gated) with the wording above,
   once approved.
3. **Rewrite `docs/bug-report.md`** around `EX-037`–`EX-041`.
4. Harvest the remaining Phases 1–27 lessons into `BRIEF` §8.
5. `docs/issues.md`, `docs/fix-proposal.md`, `docs/investigation-plan.md` last.
