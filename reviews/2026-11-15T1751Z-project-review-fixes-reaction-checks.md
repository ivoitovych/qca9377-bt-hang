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
| 6 | `README.md`: BT-16 "twice", the laptop on `-42` with E3, the L2CAP hang in "every released kernel" | **right** | BT-16: three boots (11-05, 11-11, 11-13; `results/bt16-third-2026-11-13/`). The laptop: `7.0.0-43` with its own btusb since 11-12 22:55, E3 retired (STATUS, the machine). L2CAP: the 7.3, 6.18, 6.12 and 6.6 lines, the older ones only with `enable_ecred` (STATUS BT-10, CO-35). Also: "four BlueZ fixes in code every adapter runs" is three, the fourth (`8da7e648a9fb`) is the emulator's; the `results/` line of the map. The direction block now says STATUS has each item's dated state. |
| 7 | STATUS rows BT-1, BT-9, BT-16, U24; the opening count of `docs/issues.md` | **right** | Each row against its submission row: BT-9 released in 6.1.191 (10-30); BT-1's next step no longer asks for E3 on `-42`; BT-16 three occurrences; U24's `7e3212fa233e` in BlueZ 5.88 (CO-37 `send-20261114/CHECKS.md`, `git tag --contains`). BT-10's next step names the 11-14 package. `docs/issues.md`: 25 `BT`, 5 `M`, 31 `U`, 4 `X`, counted from the STATUS rows, and a dated pointer block for what its sections do not yet say. |
| 8 | `BRIEF.md`: the 10 GB budget, "chapters to 2026-10-28", the survival row's "8" | **right** | The budgets: 20 GB for bt-trace (since 10-29) and 25 GB for the desktop captures (since 11-13; `scripts/raw-capture-archive-all.sh`). `HISTORY.md`'s chapters run to 11-14. The survival row: `EX-037` says the surviving session carried eight `len 90 mtu 9` packets and no `len 27 mtu 9`, so the cell is now 0 with that note; `EX-042` records no first-command delay, so "~90 ms" is now "not recorded". §4 now counts two survivals, as §3 already describes `EX-031` (F-08). The state block's stale stable, machine and decision lines are corrected and marked. |
| 9 | `install.sh` says "three controlled demonstrations" | **right** | BRIEF §0 and §7 say two controlled demonstrations (`EX-023`, the 2026-08-15 boot) and a third case, `EX-026`, after a reset this project did not issue. Both places in `install.sh` now say that; its `--help` range follows the added line. |
| 10 | `systemd/bt-raw-archive.service` names `/root/exp/…` and every install enables it | **right** | Installed from any other checkout, the unit named a script that is not there, and every install enabled it. The unit is the investigation machine's archive (that checkout's `archive/`, its budgets), so `install.sh` now installs and enables it only from the checkout its `ExecStart` names, and says why it skips it elsewhere. A first attempt rewrote the installed copy's path instead; CI's upgrade rehearsal refused it, because the installed file then differed from its source, so it was replaced the same evening. The staged-install test judges both branches, whichever checkout it runs from. |
| 11 | `<AUTHOR-EMAIL>` in 20 files, 17 at the review | **partly** | The count: wrong. `git grep -l` finds the same 20 files at `da23558`, the reviewed commit; none was added. The placeholders are all in older packages that nothing is sent from. Four of those packages had no `SUPERSEDED.md`, which the earlier marking missed: CO-11 `ubuntu/ready-20261102/`, CO-37 `work/patches/master-final-6-20261102/` and `work/patches/5.72-3-20261102/`, CO-38 `send-20261102/`. Each now has one, naming its replacement. The placeholders stay: those directories are the record of what was reviewed. |
| 12 | `bt-trial start` still truncates a reused trial directory (T-09) | **right** | `start` now sets an existing directory aside as `trial-NN.unclosed-<time>`, as `autostart` already did, and refuses to start if that move fails. `autostart` now refuses too, where before it went on and wrote over the directory. A test pre-creates `trial-01` with a step and a state file and checks that both survive whole beside a fresh `trial-01`. |
| 13 | The work-area path in 2,716 files; none of the wording of the review's section 3.2 changed | **operator** | Not an oversight. The forward-only approach (scan patterns, no history rewrite) was put to the operator on 2026-11-15 and is waiting for the answer. |

## Not raised by the reviewer, found while checking

- One `SUPERSEDED.md` of the earlier marking read "These BlueZ tests was replaced"; corrected.
- The bot's answer to the BlueZ v1 mails (F-09): 22:05 UTC against an 18:44 UTC send is 3 h 21 min,
  not "within 90 minutes". One of the two times is probably in another zone; the mails' headers
  are not in the repository, so BRIEF and `patches/bluez/README.md` now say it is not settled.

## Group B items still open

- **CO-03 and the Ubuntu bundle (R-01):** BRIEF and STATUS say `5.72-0ubuntu5.9~co03.1` carries the
  BT-7 fixes, and so does the CO-03 dossier; the bundle's `BUNDLE.md` and `CHECKS.md` say the final
  CO-03 candidate left them out. Which build is staged on the laptop settles it: a read of the
  staged package, which is the operator's machine.
- **One place for "current" (S-12):** the content of the "current" blocks is corrected and points at
  STATUS; removing the blocks themselves is an editorial decision, not made here.
- **Done in the same pass:** `S-06`, STATUS now cites `contributions/review-2026-11-02/followups.md`.
  `E-02` was **partly** right: the CO-02 boot's "E3 #3" (10-23 to 10-29) has no row, as BRIEF said.
  The row numbered 3 is a later boot, 10-30 on `-42`, that reused the number and the directory,
  which is the reuse T-09 is about (`trial-03/NOTE-verdict-of-2026-10-30-is-an-artefact.txt`).
  BRIEF's "to be recovered" was stale: the result was recovered on 10-30, 63 links and 0 timeouts
  (`trial-03/RESULT-boot-257d1599-from-journal.md`). BRIEF now says both.
- **Left for a later pass:** `S-08`, `S-14`, and the dossier and patch-README items of C-03, C-07,
  D-02 and PA-01.
