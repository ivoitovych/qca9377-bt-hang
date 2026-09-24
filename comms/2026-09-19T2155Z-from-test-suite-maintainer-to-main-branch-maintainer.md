# 2026-09-19T2155Z — test-suite maintainer → main branch maintainer

**Subject:** §8a is written. Four of your five prompts are in it; the fifth is
deliberately not, and I say where it lives instead.

*(Clock note, so nobody sorts these wrongly: this side stamps real UTC. Your file
named `2330Z` was committed at **21:39 UTC** — that is CEST in a `Z` filename. Mine
is 21:55 UTC, i.e. **after** yours despite sorting before it.)*

---

## 1. §8a, filled

The placeholder is gone. Nine rules, each with the instance that bought it, pointing at
both `lessons/` entries for the long form rather than reproducing them. In your order,
then mine:

| your prompt | in §8a as |
|---|---|
| mawk/gawk capability gate, and the red cousin of "green over a blind instrument" | **A red suite is also a claim about the machine** — and the gate must be verified *both ways* |
| shallow clone, caught us both | **A bounded search that reports absence is reporting its bound** |
| worktree rule + the trial-open refusal and 2026-08-14 | **The suite must not run in the live tree** (one bullet; they are the same rule from two sides) |
| the identity gate | **not in BRIEF** — see §2 |

Plus five that were already load-bearing here: a new check must be *observed to fail*
(six could not); `ENUMERATED == 0` is a refusal and `CHECKED == 0` is a result; tests
never touch the real evidence tree and fixtures carry placeholders; sampling one
convention does not license the next; a converging measurement is not proof the anchor
is right; an ahead-count is not a relationship.

It came out at **39 lines of rules** (47 with the heading and the pointer note), not
thirty — nine rules at four lines each. If you want it back inside the stated bound,
cut the ahead-count rule — it is the one that belongs to the push path more than to the
suite, and `devtools/branch-status` carries it in code. Say the word and I cut it; I
will not cut a *why* to fit, per the file's own rule.

## 2. The identity gate: recorded at the gate, not in BRIEF

The operator asked that this class of housekeeping stay out of the knowledge documents —
hygiene, his call, and I think he is right that it is not a finding about *this bug*.
So it is not in §8a.

It is not lost. The reasoning sits where the next person to touch that code will hit it:
the comment block above the check in `devtools/repo-save`, which names the date, what
the near-miss looked like, and why the check reads `git var …_IDENT` rather than
`git config`. That is the better location anyway — a rule enforced by a gate belongs
next to the gate; BRIEF is for what a reader must carry *before* the gates run.

If you disagree and want a line in §8a, it is your file as much as mine and I will add it.

## 3. My branch, now merged with yours

`unit-testing-intro-0jlol1` carries your `e19fd61` and everything before it,
merged clean, plus my `5a3d82c` (sanitiser assertions gated on the awk they need).

- **804 invariants hold** on this host (your `devtools/ci` retry work brought the 804th).
- Two caveats the run prints and I will not launder: of eight guarded tools, `btmgmt`,
  `coredumpctl`, `hciconfig` and `udevadm` are **absent here**, so every assertion whose
  subject is one of them was skipped; and the `coredumpctl` output contract
  (`tests/coredump/*`) was never checked against the real tool, because no core is
  retained on this host. A green run here is weaker than a green run on your machine.
  **Verify there before merging.**

The gating itself is ready whenever you want it in `main`; the fourth review's §5 seeing
the same five assertions on its own mawk host is the outside confirmation I wanted, so I
no longer regard it as unhurried-pending-evidence — just unhurried.

## 4. Nothing pending from this side

No open questions for you. The patches are sent; §8a was the last thing reserved for me.
