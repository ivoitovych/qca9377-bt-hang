# Checks of the reviewer's reaction to the fixes after the 2026-11-15 whole-project review

The reaction is stored as `2026-11-15T1751Z-project-review-fixes-reaction-verbatim.md`. It reads
the commits `be5e9f5`…`6c5fbab` against the review (`162d3b9`). It is an opinion, not the truth:
each point was checked against the tree on 2026-11-15, 17:50–19:00 UTC. Verdicts:
- **right**: the reviewer is right, and it is fixed;
- **partly**: right in part;
- **wrong**: the claim does not hold;
- **open**: not settled yet; the work is assigned;
- **operator**: waits for the operator's decision, on purpose.

## Weak points in the fixes

| # | Point | Verdict | What was checked, and what changed |
|---|---|---|---|
| 1 | The "What to send" table elides its paths (`CO-44-…/`), so they cannot be copied | **right** | Every path in the table is now written in full, in both columns, relative to `contributions/`. `scripts/send-table-check.py` checks that each one exists and that none is elided; it found 40 problems before the fix and none after, and the suite runs it with a scratch table that must be refused. |
| 2 | `tools/bt-sco --window --raw` takes `--raw` as the window and swallows it | **right** | Reproduced: the committed tool printed `Full event window (+/- --raws)`. The window value is now optional and only a whole number is taken; `--window --raw` gives the raw form. The usage lines name `--window` (they did not), and `--help` prints them (it stopped one line short). A test drives `--window --raw`. |
| 3 | `repo-save`'s test switch `BT_REPO_SAVE_CONFIG_IDENTITY=1` bypasses the identity gate wherever it is set | **right** | The switch is now refused in the project's own checkout and in any repository with a remote that is not a local path, before any commit. The suite's offline checkout copy used the switch; it now commits under the author named in `checks.yml`, through the real gate. A test sets the switch on a repository with a network remote and expects the refusal and no commit. |
| 4 | `runtime-mgmt-test.sh` still says "Everything is reversible"; `BRIEF.md` item 9 of §9 still names `load`/`restore` as the runbook | **right** | The header now says a module swap wedged the controller and that `load`/`restore` are refused; its usage text prints two more lines to keep the warning. BRIEF's runbook sentence carries a dated update. |
| 5 | STATUS cites the whole-project review, which is not on `main` | **right; operator** | STATUS now names the commit and says it is on a separate branch only. Where the review files live is the operator's decision (asked 2026-11-15). |

## Still as found

| # | Point | Verdict | What was checked, and what changed |
|---|---|---|---|
| 6 | `README.md`: BT-16 "twice", the laptop on `-42` with E3, the L2CAP hang in "every released kernel" | **open** | Group B. Assigned: each item against its primary record, restatements replaced by pointers to the STATUS row where STATUS owns the fact. |
| 7 | STATUS rows BT-1, BT-9, BT-16, U24; the opening count of `docs/issues.md` | **open** | As 6. |
| 8 | `BRIEF.md`: the 10 GB budget, "chapters to 2026-10-28", the survival row's "8" | **open** | As 6. |
| 9 | `install.sh` says "three controlled demonstrations" | **right** | BRIEF §0 and §7 say two controlled demonstrations (`EX-023`, the 2026-08-15 boot) and a third case, `EX-026`, after a reset this project did not issue. Both places in `install.sh` now say that; its `--help` range follows the added line. |
| 10 | `systemd/bt-raw-archive.service` names `/root/exp/…` and every install enables it | **partly** | The path: right. Installed from any other checkout, the unit named a script that is not there. `install.sh` now rewrites the installed copy's `ExecStart` to the installing checkout (from the investigation machine's checkout nothing changes, and a `.disabled` sibling is respected), and the staged-install test checks that the installed unit names an executable script of the checkout it was installed from. The enabling: left as it is. The unit archives only the captures that the same install turns on, stops at its budget, never deletes and never acts on the controller. |
| 11 | `<AUTHOR-EMAIL>` in 20 files, 17 at the review | **partly** | The count: wrong. `git grep -l` finds the same 20 files at `da23558`, the reviewed commit; none was added. The placeholders are all in older packages that nothing is sent from. Four of those packages had no `SUPERSEDED.md`, which the earlier marking missed: CO-11 `ubuntu/ready-20261102/`, CO-37 `work/patches/master-final-6-20261102/` and `work/patches/5.72-3-20261102/`, CO-38 `send-20261102/`. Each now has one, naming its replacement. The placeholders stay: those directories are the record of what was reviewed. |
| 12 | `bt-trial start` still truncates a reused trial directory (T-09) | **right** | `start` now sets an existing directory aside as `trial-NN.unclosed-<time>`, as `autostart` already did, and refuses to start if that move fails. `autostart` now refuses too, where before it went on and wrote over the directory. A test pre-creates `trial-01` with a step and a state file and checks that both survive whole beside a fresh `trial-01`. |
| 13 | The work-area path in 2,716 files; none of the wording of the review's section 3.2 changed | **operator** | Not an oversight. The forward-only approach (scan patterns, no history rewrite) was put to the operator on 2026-11-15 and is waiting for the answer. |

## Not raised by the reviewer, found while checking

- One `SUPERSEDED.md` of the earlier marking read "These BlueZ tests was replaced"; corrected.
