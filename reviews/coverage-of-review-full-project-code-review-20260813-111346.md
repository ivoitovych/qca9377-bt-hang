# Actionable-item coverage — review 20260813-111346

One page. Carries the review's fingerprint; full detail lives in
`review-…-20260813-111346.md`, `fixes-…-20260813-123326.md` and
`verification-of-review-…-20260813-111346.md`.

## Review findings (26: 5 HIGH · 14 MED · 7 LOW)

| Disposition | Count | Notes |
|---|---:|---|
| Landed in code/docs | **23** | merged to main in `4077cec`, verified present post-merge |
| Landed, one half external | **2** | F4 (tree cleaned; git-history purge is an owner decision) · F19 (annotation + `bt-exhibit` 126/127 gate; re-capture needs the machine) |
| Closed on the machine since | **1** | F2 re-verified against the real 3.3 M-line journal → `EX-020`; result byte-identical |
| Deliberately skipped, reasons recorded | **3 sub-items** | §-renumbering (breaks cross-refs), naive/offset timestamp mixing (no caller does it), `bt-sco` cosmetics |

**Nothing is unaccounted for.** Every finding is landed, landed-with-an-external-half,
or skipped with a stated reason.

## Follow-up suggestions from the verification pass (5)

| # | Item | State |
|---|---|---|
| S1 | Cross-form aliasing assertion | **Handed to the unit-testing stream** — its test section and fixture live there. The property itself is verified working (gawk installed; colon/underscore/dash → one placeholder); what is owed there is the regression guard. Exact change recorded in the verification report |
| S2 | Exhibit temp-path invariant | **Done** — mutation-tested with the EX-018-shaped violation |
| S3 | `reviews/` in the drift detector | **Done** |
| S4 | `bt-usbmon` gap log | **Done** |
| S5 | Full `devtools/check` on the machine | **Owner action** (step 4 below) |

Two items previously deferred as *doubtful* were settled by investigation rather than
judgement: the kernel's `PRODUCT=%x/%x/%x` format (read from `usb_uevent` in
`drivers/usb/core/driver.c` → leading-zero fix in `install.sh`), and the sanitiser's
runtime behaviour (gawk installed here; runs and self-verifies).

## What is on the branch, and what it needs

`claude/project-code-review-sr0s9f` = **one commit** on `a57a450`; main
fast-forwards. Contains only review work — no unit-testing content. Gates: **68/68
invariants**, `repo-validate` clean, `repo-scan --all` clean.

## Outstanding — all external, in execution order

| # | Action | Blocker |
|---|---|---|
| 1 | Merge this branch, pull on the machine | — |
| 2 | `sudo apt install gawk` | machine (mawk fails the sanitiser's patterns) |
| 3 | `sudo ./install.sh --apply` + `bt-verify-install` | machine — **until this runs, `/usr/local` still holds pre-review tooling**: old watchdog text, ring-buffer `bt-usbmon`, stale counters |
| 4 | `devtools/check` | machine (only place every gate runs) |
| 5 | Re-capture `EX-019` (command in the report) | machine |
| 6 | `ls /var/log/bt-health/usbmon/` after ~a day | machine — several timestamped pcaps + `gaps.log` confirms F13; one file reproduces the old ring |
| 7 | `git push origin --delete claude/project-code-review-sr0s9f` | owner (session credentials cannot delete refs) |
| 8 | Git-history MAC purge, per checklist §1 | owner decision, before any upstream submission |

Steps 1–5 are one sitting; 6 needs uptime; 7–8 are yours to schedule.

## For maintainers picking this up

**Branch:** `claude/project-code-review-sr0s9f` — two commits on base `a57a450`:
`617476d` (the review work) and this summary on top. Main fast-forwards; no merge
commit needed. Current tip: `git rev-parse claude/project-code-review-sr0s9f`.

```bash
git fetch origin && git checkout claude/project-code-review-sr0s9f
devtools/check                 # expect: ready — run this before AND after any change
```

Four conventions, so what follows stays consistent with what came before:

1. **The chain is fingerprinted.** Every document about this review carries
   `20260813-111346` — the review's own timestamp, not the writing date. Add to the
   chain by appending a section or a new `*-of-review-…-20260813-111346.md`; a new
   review of different scope starts its own fingerprint.
2. **Keep the streams apart.** This branch carries review work only. The unit-testing
   branch is a separate, in-progress stream — do not merge it in to make something
   here work. If a change needs its fixtures (the cross-form aliasing assertion is the
   one known case), it belongs *there*, and the hand-off text is in the verification
   report.
3. **A finding is not closed until a check can fail.** The convention this review
   found the hard way: after adding an invariant, break the thing it guards and watch
   it go red — `devtools/assert-test-catches <file> <violating-line> <substring>` for
   shell targets, or a planted violation restored afterwards for data/markdown
   targets.
4. **Gates before commit:** `tests/run-tests`, `devtools/repo-validate .`,
   `devtools/repo-scan . --all`. `devtools/check` runs all three. The `--all` scan
   matters — staged-additions scanning lets already-committed leaks ride along, which
   is how two real device addresses survived in the tree for days.

Open work is the eight-step table above; step 3 is the one that makes any of it take
effect on the machine.

## One-line summary

23 of 26 findings fully closed and merged, 2 closed on the repository side with an
owner/machine half remaining, 1 re-verified on real data since; 3 of 5 follow-up
suggestions implemented, 1 handed to the parallel stream by design, 1 owner action;
8 external steps outstanding, of which step 3 is the one that makes the fixes take
effect on the machine.
