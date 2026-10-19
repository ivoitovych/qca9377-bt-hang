# Test-suite synchronization plan — 2026-10-19 04:57 UTC

How `main` and the test-suite maintainer's two branches get back in step after the comprehensive
code review, and how they stay in step while its findings are fixed. It is written beside the
review
([`review-comprehensive-code-review-20261019-014718.md`](review-comprehensive-code-review-20261019-014718.md)),
the reaction plan
([`review-reaction-plan-20261019-045758.md`](review-reaction-plan-20261019-045758.md)) and the
project completion plan
([`project-completion-plan-20261019-045758.md`](project-completion-plan-20261019-045758.md)).

## The short answer

**Yes, the test-suite maintainer should merge `main` now.** It is cheap and conflict-free.
- `main` has 32 commits since their last merge of it (`91ce9b2`). All of them touch one file, the
  review. These plans add three more files under `reviews/`.
- `git merge-tree` shows no conflict into either branch (checked below).
- The merge gives them the review, which names a large share of the work as theirs.

**`main` also needs work from them, in two parts:**
- one commit on the ready line that `main` lacks (`cf9b304`);
- the working branch's unoffered work, once they offer it.

## 1. Where the three lines stand

Measured read-only after `git fetch origin`, 2026-10-19 ~05:00 UTC:

| line | tip | relation |
|---|---|---|
| `main` | the commit that adds these plans (after `803c142`) | the active line. Since `91ce9b2`: the review only (`git diff --stat 91ce9b2 origin/main` → one file) |
| `tests/unit-testing-introduction-ready-for-main` (the ready line) | `704224a`, "Merge main (91ce9b2) into the ready line" | holds one commit `main` lacks: `cf9b304`, "devtools: a red run under an instrument names its failing checks" (`git diff --stat origin/main origin/tests/unit-testing-introduction-ready-for-main -- devtools` → 4 files, 14 lines) |
| `tests/unit-testing-introduction` (the working branch) | `ca02f58`, "Merge the ready line's tip (704224a) into the working branch" | `git diff --stat origin/main...origin/tests/unit-testing-introduction` → 42 files, +2,554/−182, not yet offered |

**What landed most recently.** On 2026-10-18 `main` took the ready line's seven commits by
cherry-pick (comms 2026-10-18T15:32Z). After that landing, `tests/`, `devtools/` and `.github/`
on `main` equalled the ready line byte for byte. Since then, only `cf9b304` has been added on the
ready line.

**What the working branch holds** (its 2026-10-16T15:28Z note, and the diff):
- the access audit: `devtools/access-audit`, `devtools/access-classify`, `tests/access-allowlist`;
- `devtools/ci` asking the repository of the remote the branch tracks (`8ecf3fd`). That file also
  holds the 30-run limit of comms 2026-10-18T15:32Z item 2, which was left to them for this
  reason;
- `bt-usbmon` and `bt-trace` killing their idle `sleep` on TERM;
- the BRIEF budget check reading the budget from `devtools/save`;
- `tests/system-resources.md`;
- 794 more lines of `tests/run-tests`;
- `checks.yml` (+78 lines);
- small edits to 14 tools;
- **six comms notes from them to `main` that `main` has never received:**
  - `2026-10-08T1828Z`;
  - `2026-10-09T0355Z`, `0628Z` and `2048Z`;
  - `2026-10-10T0421Z`;
  - `2026-10-16T1528Z`.

**No conflicts today.** Each `git merge-tree --write-tree` exits 0 with a tree id and no conflict
list:
- `main` into the ready line → `71e5f61a`;
- `main` into the working branch → `ea9d0b44`;
- the working branch onto `main` → `ea9d0b44`, the same tree.

## 2. The rules of the exchange, as practised

These are not new; they are how the two lines have worked since 2026-10-13. They are written down
here so the plan can be checked against them.

1. **`main` is the active line.** The test-suite maintainer merges `main` into their branches as
   merges, never by rewriting or force-pushing.
2. **`main` takes their work by cherry-pick, never by merge.** Each landing names the source
   commits in a comms note. They verify it with `git cherry` (every landed commit shows `-`).
3. **A hash that a document places on `main` must be `main`'s own** (the cherry-pick), not the
   branch's original (`devtools/doc-main-hashes`; the 2026-10-16 incident).
4. **Test-first.** A red check is shown on the defect first, then the fix that turns it green
   (comms 2026-10-18T06:15Z, "test-first as before").
5. **The suite is theirs** (BRIEF §8a). `main` changes `tests/` only in a coordinated commit:
   a tool fix whose pinned test must change in the same commit (section 4).
6. **CI is the verdict while a trial is open**, because the suite refuses to run on the laptop then.
   Each side reads CI for its own pushes (`devtools/ci`).
7. **Nothing either side does touches the laptop.** A deploy is the operator's decision.

## 3. Steps

| step | who | what | done when |
|---|---|---|---|
| 1 | suite | merge `main` (at or after the commit adding these plans) into the ready line, then the ready line into the working branch, as before | `git merge-base --is-ancestor origin/main origin/tests/unit-testing-introduction-ready-for-main` succeeds, and the same for the working branch |
| 2 | main | land `cf9b304` by cherry-pick | `git diff --stat origin/main origin/tests/unit-testing-introduction-ready-for-main -- tests devtools .github` is empty; CI green on `main` |
| 3 | main | land the six comms notes that exist only on the working branch, by cherry-pick or by copy that names the source commit. They are addressed to `main` and complete its record of the exchange. | `git diff --name-only origin/main...origin/tests/unit-testing-introduction -- comms` is empty |
| 4 | main | **one comms note to the test-suite maintainer** (section 5), with this plan's division of the review's work and the open requests in both directions | the note is on `main` |
| 5 | suite, main | **confirm the state of the six tasks of BRIEF §9.2** (source review, instrumented `btusb` logging of `new_alts`, bug-report audit, `BL-09`, `bt-crash` tests, device survey): done, open or dropped | BRIEF §9.2 says which |
| 6 | suite | **offer the working branch's finished parts on the ready line**, as they choose; `main` lands them by cherry-pick (rule 2) | each landing has its comms note |
| 7 | both | **the review's work**, in the reaction plan's order (section 4) | per item |
| 8 | suite | **the split of `tests/run-tests` (UT-12)**, after RT7's fix | section 6 |

## 4. The review's work, divided

From the reaction plan. "Pinned" means a test asserts today's behaviour (review §82, §84, §85), so
the tool fix and the test change go in one commit.

**The test-suite maintainer's own:**

| item | § | note |
|---|---|---|
| T2, SW1: the `btmon` stub shortens header lines as the real `btmon` does; `--columns=200` at the seven call sites | 1, 31 | asked 2026-10-18T06:15Z, still open. Phase 1, before the deploy. Pins: 10785-10803, 2738-2741, 3591 |
| the second, local guard around `install.sh`'s reload block | comms 2026-10-18T15:32Z, item 1 | phase 1, test-first |
| CK1: `devtools/check` with `--no-suite` while a trial is open | 50 | phase 1 |
| SU1: the rehearsal catches I2, VI1 and MODE2 | 21 | phase 1 |
| PV1: the six standalone harnesses stub `tests/machine-tools` | 71, 83 | phase 2 |
| RT3: the whole-boot-read invariant catches every spelling | 84 | phase 6; land it red, and the failures are `main`'s work list |
| JC1: the journal contract reads a real journal | 51 | phase 6, with PH1/T9/EH1 |
| IN1, AWC1: coverage includes `scripts/`; awk coverage counts programs that never ran | 80 | phase 6 |
| DS4: `devtools/status`'s "cannot confirm" is not a pass; test 13193-13202 asserts the summary | 85 | phase 7 |
| RT1, RT2, RT4, RT5, RT6, RT7, UD1 | 84, 85 | phase 8; RT7 before the split |
| the cross-cutting invariants: the forbidden-advice check, the guest-guard check, NOT RUN is not PASS | reaction plan | each lands red first |

**`main`'s fixes whose tests are pinned** (both sides in one commit). `main` proposes the fix in a
note, the suite writes or reviews the test change, and `main` lands both together:

| finding | pinned test (`tests/run-tests` lines) |
|---|---|
| KR1 | 8830-8834; 12121-12127 and `tests/journal/window-reset` |
| MODE1 | 6136-6138 |
| UN1 | 11748-11751 |
| UN2 | 11723-11726 |
| CAP1 | 7568-7573, 7599-7606, 8010-8019, 8029-8035, 8386-8396, 8416-8421 |
| BJ1 | 9728-9740 |
| AJ1 | 9752-9765 |
| PM1 | 4865-4869 |
| BL1 | 4575-4580 |
| PH1, T9, EH1 | 8866-8867, 10883, `tests/journal/envhist` |
| KM1 | 6193-6242 |
| EV2 | 6786-6788 (and a new refusing-sanitiser case) |
| SN1 | 9934-9944 |
| CD2 | the capdiff fixtures |

The line numbers are those of `main` at `803c142`; they move with every edit, so each note quotes
the test's text as well.

**The open requests, both directions:**
- **To the suite**, from `main`:
  - the `--columns` fix with a shortening stub (06:15Z);
  - the second reload guard, the 30-run limit in `devtools/ci`, and `bluetoothctl`'s MGMT open
    crashing the capture's `btmon` (15:32Z, items 1-3);
  - whether `scripts/trial-close-now.sh`, `scripts/trial-snapshot.sh` and
    `scripts/trial-sco-decode.py` should come under the suite (15:32Z).
- **To `main`**, from the suite:
  - the shared deadline for the whole close (2026-10-18T01:47Z, "your call"). It also settles
    what ends the 10-11 journal three seconds into the close.

## 5. The note that starts it (step 4)

`comms/<UTC>-from-main-branch-maintainer-to-test-suite-maintainer.md`, in the usual form
(`from`, `to`, `date`, `branch`, `tip`, `subject`, `needs`). Its content:
- the review is complete on `main` (§1-§86), and these three plans are beside it;
- please merge `main` (step 1);
- `cf9b304` and the six notes will land (steps 2 and 3); say if any note was not meant for `main`;
- section 4's division, with the phase-1 items named as the ones before the deploy;
- the request to confirm BRIEF §9.2's six tasks (step 5);
- `main`'s answer on the shared close deadline, or that it is still open.

Nothing in it is a send outside the repository.

## 6. Keeping the lines in step afterwards

- **After every landing on `main`:** the suite merges `main` into both branches within the same
  working session. Check: `git merge-base --is-ancestor`, as in step 1.
- **Before every landing:** `main` checks that `tests/`, `devtools/` and `.github/` equal the ready
  line afterwards (step 2's check), so no part of a landing is left behind.
- **`tests/run-tests` is where the two lines collide.** It is 14,195 lines and both sides change
  it: the suite for its own work, `main` for pinned fixes. The split into parts (UT-12) is the
  structural fix. RT7 (one closing scan reads the entry file by name) must be fixed before it, or
  a part escapes that scan. Until the split, `main` touches `tests/run-tests` only in pinned-fix
  commits announced in a note.
- **CI is read after each push.** The red periods of 2026-09-01 to 09-14 and 2026-09-26 to 10-02
  went unread (BRIEF §9.4).
- **Stubs and fixtures come from real output.** When either side finds a stub that the real tool
  contradicts (the `btmon` case), the stub is fixed in the same exchange (reaction plan,
  cross-cutting 3).
- **A weekly check** of the three lines with the commands in section 1, recorded in STATUS's
  branch survey.

## 7. What could go wrong, and the guard

| risk | guard |
|---|---|
| a landing leaves part of a series behind (the 2026-08-16 incident) | step 2's empty-diff check; `devtools/branch-status` |
| a document names the branch's hash as `main`'s | `devtools/doc-main-hashes` |
| the two lines fix the same finding twice, differently | section 4's division; a note before starting any shared item |
| a pinned test is changed without its fix, or the reverse | the pin table; each fix commit names its test |
| the suite cannot run on the laptop, so a red goes unseen | CI is the verdict; `devtools/ci` after each push (rule 6) |
| `main` lands work the suite did not mean to offer | land only what is on the ready line or named in a note; ask when in doubt (as 2026-10-18T15:32Z did) |
