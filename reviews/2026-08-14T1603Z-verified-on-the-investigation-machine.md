# The escape fix, verified where it fires — and what is still open

**Written** 2026-08-14T16:03Z · **Covers** the tree at `795705e`, now `main`
· **Verification run by** the maintainer, on the investigation machine
· **Supersedes §7 of** [the sandbox escape postmortem](2026-08-14T1328Z-sandbox-escape-postmortem.md)

**Verdict.** The fix holds where it has to. 402/402 green on the host with all 34 tools
genuinely installed, and the contamination that prompted the postmortem is measured at
zero. Two of the four defects closed in this cycle were found *by that host* and could not
have been found here. SE-05 remains open and should not be written up as done.

---

## 1. Measured, on the machine

| | before the fix | the verification run |
|---|---|---|
| `bt-mark` markers injected | **549** | **0** |
| `evidence/sessions/` | grew | 10, unchanged |
| Trial state | a live trial closed | untouched |
| Working tree | contaminated | clean |
| Suite | green, and wrong | **402/402 green** |

Three checks that a development checkout structurally cannot make:

- **The guard's derivation, re-derived independently.** The maintainer produced the 34
  names from `install.sh` before reading `guard_names()`; the lists are byte-identical,
  including `bt-boots` — the name the *first* derivation missed. Their own first count was
  35, inflated by `/usr/local/bin/lib/*.awk`, which the `[^/]+$` anchor drops.
- **The open-trial refusal, with a trial genuinely open.** A disposable trial was opened
  for the purpose. The suite exited 2, printed the open trial, and ran nothing.
- **That the run left no trace.** `journalctl -t bt-mark` over the window: no entries.

The postmortem's §7 said the decoy makes the claim "testable rather than asserted". This
is the test, and it was run somewhere other than where the claim was written.

---

## 2. What that host found that this one could not

Both failures reported from the machine were **my** defects, and both passed here.

**`bt-mode`'s seam check asserted absolute state** — that three `.disabled` override files
do not exist. Moving exactly those aside is what `bt-mode experiment` is *for*, so the
check failed for the machine's correct configuration. It compares a before/after snapshot
now, and a leak is a change in either direction.

**The missing-baseline branch was unreachable wherever the project is installed.**
`bt-health-report.sh` hardcoded `/usr/local/share/qca9377-bt-hang/baseline.tsv` and
`/var/log/bt-health/baseline.tsv`, so on an installed host the branch is never taken and
its message never appears. Both are seams now — `BT_HEALTH_DIR` is the name
`verify-restored.sh` already used, `BT_SHARE_DIR` is `install.sh`'s own destination.

**The common shape.** A check coupled to the environment rather than to the code, wrong
precisely on the machine it exists to protect. That is now **seven** instances in this
effort — five found by reasoning, two by running it somewhere real — against five found
for logical reasons. The postmortem's §6 counted three; it was undercounting because two
had not yet been found.

**The method that worked**, and the one worth keeping: the failing configuration was
*constructed* locally — three `.disabled` overrides and an installed `baseline.tsv`
created by hand — the two reported failures reproduced exactly, and the repairs were then
verified against it. Same move as the decoy. A hazard you can build is a hazard you can
regression-test; a hazard you wait for is one you find out about from someone else.

---

## 3. Two more, found while fixing those

**The open-trial refusal is a window check.** It reads `/run/bt-trial` once, before
anything runs. The maintainer named the gap while verifying it, and it was real: a trial
opening mid-run was invisible. The suite now fingerprints the trial state and the results
row count at startup, beside the `evidence/sessions` count that already caught one
contamination, and compares at the end.

This is detection, not prevention, and the distinction matters: it converts a mid-run
escape from *found a day later by a missing trial* into *a red test in the same run*.

**An exclusion entry pointed at a blank line** and had done since it was written —
`tools/bt-health-report.sh:212-212`, where 212 was blank. It excluded nothing, silently,
while reading as a considered decision. The self-check cannot catch that case: it fires
only on lines that are excluded **and** executed, and this was neither. Its stated reason
was wrong too. A no-op exclusion is worse than a wrong one, because nothing can disagree
with it.

---

## 4. Still open, stated plainly

**SE-05.** A trial opening mid-run is detected, not prevented, and no control makes a
suite whose purpose is exercising actuators into a read-only observer of the machine. The
standing advice is unchanged: run it in a worktree, and not while an experiment is live.

**The branch stopped being test-only.** `tools/bt-health-report.sh` is a product change.
Every seam defaults to the value it replaced, so behaviour with the environment unset is
identical — but the tool emits a *judgement* about whether the mitigations are working, so
the change is worth knowing about rather than discovering later.

**Deployment is not the merge.** `main` now contains the hardened tools; the machine still
runs the older installed copies. That gap closes only on `install.sh --apply`, which
reloads `btusb` and therefore belongs in a cold-boot window, not in the middle of an
experiment.

---

## 5. The thing worth remembering

Every measurement in this branch was taken where the defect cannot fire. The postmortem
said that about one bug. It was true about four.

The correction is not "test more carefully" — it is that a suite which asserts things
about a machine has to be run on that machine, or the assertions are about the checkout.
Two coverage tools, 402 invariants and a mutation harness all agreed the suite was green,
and two of its checks were still wrong about the only host that matters.
