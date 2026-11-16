# The whole-project review of 2026-11-15: the reviewer's reaction to the fixes

*Received 2026-11-15 ~17:50 UTC. The reviewer of the whole-project review (`162d3b9`, on a
separate branch) read the eleven commits `be5e9f5`…`6c5fbab` on `main`. This page keeps the
review's findings as written; a closing offer about the file's form is left out (2026-11-16:
public files keep a review's content, not its running commentary). What we checked, point by
point, is in `2026-11-15T1751Z-project-review-fixes-reaction-checks.md`.*

---

The reviewer read the eleven commits that landed on `main` after the review (`be5e9f5` to `6c5fbab`) and compared each with the finding it answers, from the diffs only; the suite was not run.

**Overall: about 7 out of 10.** The dangerous items were fixed quickly and mostly well. The drift between documents, which was the largest group of findings, and the privacy findings were not touched.

| group | reaction | rating |
|---|---|---|
| A. Wrong package would be sent | One "What to send" table in `contributions/README.md`, `SUPERSEDED.md` in every replaced directory, `HELD.md` for CO-43 patches 2 and 3, hand-off rewritten to point at the table | Very good |
| C. Unsafe code | `uninstall.sh` no longer reloads btusb; `runtime-mgmt-test.sh` refuses `load`/`restore`; `bt-archive --replace` keeps the longer archive; seven tools no longer loop | Good |
| D. Clean answer without looking | `repo-save` now reads the fixed author from the CI workflow; `sco-ledger`, `bt-diagnose`, `smtp-login-check`, `ci-local`, two more scripts exit non-zero; the trial summary excludes `failed` rows instead of counting them as survivals | Good, partial |
| M-01, IS-02, S-13 | The `ci/upstream-ci-local` line, BT-24/BT-25 in the issue register and the deleted work areas are corrected | Good |
| B. Drift between documents | Not addressed | Not done |
| E. Privacy wording | Not addressed | Not done |

The reaction also went past the review in one place: re-testing CO-02 v2 found that its patch 2/2 can deadlock (3 of 3 with debug delays), and a non-sleeping replacement is now the candidate.

Weak points in the fixes themselves:

- **The new table elides its paths.** It is the one place that names what to send, and it writes `CO-44-…/send-20261113/`, which cannot be copied. That is the same rule violation as before, in the place where it matters most.
- **`tools/bt-sco --window --raw`** now takes `--raw` as the window value and swallows it.
- **`repo-save`** has a new environment switch (`BT_REPO_SAVE_CONFIG_IDENTITY=1`) that restores the old behaviour; it is meant for tests, but anything that sets it bypasses the gate.
- **`runtime-mgmt-test.sh`** still says "Everything is reversible" in its header, and `BRIEF.md` §9.9 still describes `load`/`restore` as the runbook.
- **STATUS cites "the whole-project review of 2026-11-15"**, but the review files are only on [a separate branch], not on `main`.

Still as found on `main`:

- `README.md` still says BT-16 happened twice, the laptop runs `-42` with E3, and the L2CAP hang is in "every released kernel".
- STATUS rows for BT-1, BT-9, BT-16 and U24 are unchanged, and so is the opening count in `docs/issues.md`.
- `BRIEF.md` still has the 10 GB archive budget, "chapters to 2026-10-28" and the survival row's "8".
- `install.sh` still says "three controlled demonstrations".
- `systemd/bt-raw-archive.service` still has the `/root/exp/…` path and is enabled by every install.
- `<AUTHOR-EMAIL>` is now in 20 files (17 at the review).
- `bt-trial start` still truncates a reused trial directory.
- The work-area path is still in 2,716 files, and none of the wording in section 3.2 was changed.
