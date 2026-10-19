# Review reaction plan — 2026-10-19 04:57 UTC

The plan for acting on
[`review-comprehensive-code-review-20261019-014718.md`](review-comprehensive-code-review-20261019-014718.md)
(six passes, §1-§86, complete at `803c142`). The review's consolidated ranked list orders the
findings by urgency; this plan turns that list into work: who does each item, in what order, which
tests change with it, and what has to be true before the laptop's tools are deployed.

Like the review, this is a snapshot. Progress is recorded in the action register
(`reviews/README.md`, step 0.3), not by editing this file.

## Rules for working this plan

- **Nothing on the laptop without the operator's word.** The plan's code work happens in the
  repository and is proven in CI and in the deploy rehearsal (`tests/system-upgrade`). A deploy, a
  timer, a module, or a Bluetooth action on the laptop is the operator's decision, every time.
- **Never `install.sh --apply`; never unload, reload or rebind `btusb` or `bluetooth.ko` live**
  (BRIEF §0, `EX-046`, `EX-023`, `EX-026`). Several findings below exist because tools still
  suggest or contain these actions.
- **A fix changes its pinning test in the same commit.** The review's maps (§82, §84, §85) list
  the tests that assert today's wrong behaviour. A fix that leaves such a test green has not
  changed what the test asserts; one that turns it red without changing it leaves the tree red.
- **Test-first, as the two maintainers already work** (comms 2026-10-18T06:15Z): a check that goes
  red on the defect, then the fix that turns it green, both named in the commit message.
- **Siblings in the same series.** Most findings name their siblings (pattern 1). A fix that
  reaches one sibling and not the others reproduces the pattern.
- **Published results are re-derived, not edited.** Where a fix changes an instrument behind a
  published number (phase 6), the number is recomputed with the fixed instrument and any change is
  recorded as a correction beside the original. Evidence is never deleted.
- **No sends.** Nothing in this plan mails, posts or opens anything upstream. Phase 4 hardens the
  gates used before a send; the sends themselves stay the operator's.

**Owners.**
- **main:** the main-branch maintainer. Owns the tools (`tools/`, `bin/`, `scripts/`, `install.sh`,
  `uninstall.sh`) and the documents.
- **suite:** the test-suite maintainer. Owns `tests/`, the measurement instruments in `devtools/`
  and `.github/` (BRIEF §8a).
- **ci-local:** the ci-local line. Owns `scripts/ci-local*.sh` and `scripts/bluez-tester-compare.sh`.
- **operator:** owns every action on the laptop and every send.

Where a tool fix changes a pinned test, main writes the fix and suite writes or reviews the test;
the test-suite synchronization plan (beside this file) says how the two lines exchange that work.

## Phase 0 — decisions for the operator (no code)

| step | what | why now |
|---|---|---|
| 0.1 | **CAP1: restart the capture archive, or copy the unarchived captures to the keep directory.** The U10 captures (2026-10-11) and the two BT-9 correction captures (2026-10-10) exist nowhere else. | STATUS (2026-10-17) measured about three weeks of margin at that week's rate and about 8 days at 10-13's rate. Rotation is visibly running (§76). |
| 0.2 | **Until CAP1's code fix lands, do not run `bt-trace --check` or `bt-usbmon --check` on the laptop.** Both prune past KEEP as part of the check (§85). | A check that deletes captures is not read-only. |
| 0.3 | **Whether to register this plan's items in `reviews/README.md`'s action register**, one block "From `review-comprehensive-code-review-20261019-014718.md`", one row per item with the command that decides its status, as the register's convention requires. | Without a register the plan's progress lives only in commit messages. |
| 0.4 | **When to deploy `main`'s tools.** This plan recommends after phase 1. | Until the deploy, a shutdown with a trial open can lose its row and probes the controller (STATUS). E3 #2 is open since 2026-10-18 17:05. |

## Phase 1 — before the deploy of `main`'s tools

Small fixes that the deploy would otherwise carry onto the laptop. All of them can be proven in
CI. After this phase the deploy rehearsal must still pass in both modes, and
`python3 -I scripts/installed-vs-commit.py . cccf0fe main` gives the operator the list of files
the deploy changes.

| item | § | what to do | owner | tests that change |
|---|---|---|---|---|
| I2 | 4 | bound the whole-boot kernel read in `install.sh --tools-only`'s last step | main | the rehearsal (SU1) |
| VI1, DS1, SR1, and MODE1's hints | 16, 50, 36, 8 | one advice wording everywhere: "`sudo ./install.sh --tools-only`, then `daemon-reload`, `bt-verify-install`, `bt-mode status`"; never `--apply`, never `bt-mode mitigation` | main | none asserts the advice today (§82); add the invariant in "Cross-cutting" below |
| MODE2 | 8 | `bt-mode status` prints "inactive" once | main | the `bt-mode` section |
| CK1 | 50 | `devtools/check` passes `--no-suite` and says so while a trial is open, as `repo-save` does | suite | add the open-trial case |
| T1 | 1 | an interrupted close cannot write a second row | main | a close killed after the row, then re-run |
| the second reload guard | comms 2026-10-18T15:32Z, item 1 | `if (( APPLY && ! TOOLS_ONLY ))` around `install.sh`'s reload block, so that one regression in `run()` is not enough | suite (test-first), main | a check with `run()`'s gate disabled |
| T2, SW1 | 1, 31; comms 2026-10-18T06:15Z | `--columns=200` instead of `COLUMNS=` at the seven `btmon -r` call sites; the suite's `btmon` stub shortens header lines to 80 columns, as the real one does | suite (asked 10-18), main | 10785-10803, 2738-2741, 3591 (§82, §84) |
| SU1 | 21 | the rehearsal catches I2, VI1 and MODE2 | suite | `tests/system-upgrade` |

## Phase 2 — hazards held only in prose

| item | § | what to do | owner | tests that change |
|---|---|---|---|---|
| **KR1** (first) | 38 | add a `BT_RE_KERNEL_RESET` class for `hci[0-9]+: Resetting usb device` and the `reset … USB device` line that follows it; record `kernel_reset=N` in the row; count such rows as confirmed failures in the rate; correct `journal.sh`'s comment; `bt-window` names it as the kernel's own | main, suite | 8830-8834 (§82); 12121-12127 and its fixture (§85); a new fixture with the kernel line first |
| MODE1 | 8 | `bt-mode mitigation` restores the power policy only; the watchdog only behind an explicit option that names `EX-005`/`EX-023` | main | 6136-6138 (§82) |
| I1, UN1, RM1 | 4, 5, 32 | remove the live reloads from `install.sh --apply`, `uninstall.sh` and `runtime-mgmt-test.sh`; a module change goes through `updates/`, `depmod` and a cold boot, on the operator's word | main | 11748-11751 (§82) |
| RS1 | 12 | `repo-save` pushes to `origin` only branch families on an allowlist | main | the held-branch section |
| PV1 | 71, 83 | the six standalone trial harnesses stub every name in `tests/machine-tools` | suite | each harness's own run |
| GG1 | 86 | guest-only tools refuse unless `/proc/cmdline` carries test-runner's `TESTHOME=`; the BT-8 reproducer refuses while a USB adapter is present | main | a refusal check each |
| WD1 | 17 | decide the watchdog's future under E3: retire it, or rewrite its premise. It is not enabled on the laptop. | main, then the operator | the watchdog sections |

KR1 comes first because E3's failure rate is the project's main result and E3 #2 is accumulating
now. No E3 trial has had a timeout yet, so no recorded row is wrong (§38).

## Phase 3 — evidence retention

| item | § | what to do | owner | tests that change |
|---|---|---|---|---|
| CAP1 (code) | 7, 85 | prune sets aside, not deletes, any capture absent from the archive manifest unless the free-space floor forces it, and says so; `--check` reports and does not prune (or prunes only with an explicit option) | main | 7568-7573, 7599-7606, 8010-8019, 8029-8035, 8386-8396, 8416-8421 (§85) |
| CAP2 | 7 | `bt-trace` keeps the file it was writing when it stops for space | main | the floor tests |
| AR1 | 10 | the archiver also covers the decode-free capture directory | main | `prove-bt-trace-archive.py` |
| BJ1 | 23 | a daily dated segment export of the live boot, never named as the boot | main | 9728-9740, whose comment premise goes (§85) |
| AJ1 | 24 | `--replace` keeps the old archive unless the new one contains its first cursor and at least as many records | main | 9752-9765 (§85) |
| UN2, SW2 | 5, 31 | no advice or flag that deletes unarchived captures | main | 11723-11726 (§82) |
| SC-1 | 42 | `bt-sco` cannot fill the disk | main | the `bt-sco` section |

Installing the archiver as real units, rather than the transient timer the 10-13 reboot removed,
belongs with the deploy and is the operator's decision.

## Phase 4 — upstream gates (before the next send or backport request)

These tools stand between a patch and a send. Each can report success for a check it did not make.
None is known to have let anything through (§57-§83 summary).

| item | § | what to do | owner |
|---|---|---|---|
| TC1 | 77 | a tester that crashes or times out with the patches is a failure, not "no regression" | ci-local |
| BF1 | 73 | a patch that fails to apply fails the build | main |
| STB1 | 74 | match the subject exactly and name a `Revert "…"` hit as a revert | main |
| CL3, CL4, CL5 | 79 | sparse with no CHECK line is NOT RUN; checkpatch with no `total:` line is NOT RUN; the base-side cache key includes the toolchain | ci-local |
| KP1, KP2 | 73 | the preflight compares sparse across every touched file; an interrupted run leaves nothing the next run takes as passed | main |
| CM1 | 73 | an unreadable dependant refuses the module | main |
| CC1 | 86 | `patches/bluez/checkpatch-check.sh` requires checkpatch's `total:` line; candidates sorted with `sort -V` | main |

**When:** before the next mail. Candidates: a v2 of A1/A2 (STATUS: not before 2026-11-01, and only
under its send rules), the mesh power-off reply, an M-2 patch. Each gate gets a self-test that
feeds it a crashing tool and expects NOT RUN.

## Phase 5 — the publishing gate and the records

| item | § | what to do | owner |
|---|---|---|---|
| SC1, SAN1 | 13, 15 | raw-byte, IPv6 and EUI-64 addresses fail the publishing gate | main, suite |
| EV2, CP1 | 31, 83, 29 | `bt-evidence` names a refused file in its manifest and exits non-zero, as `bt-incident` does; a test drives a refusing sanitiser, as 5221-5250 do for `bt-incident` | main, suite |
| HK1 | 70 | the key-material counter sees `MGMT Command: Load … Keys` | main |
| VR1 | 47 | the restoration check sees `updates/` modules and the self-built `bluetoothd` | main |
| UC1, FT1, ATC1 | 64, 75, 80 | sanitiser errors stay inside the protected directory; no helper rewrites an exhibit's verbatim output; an interrupted `assert-test-catches` restores the file | main, suite |
| EV4 | 83 | `bt-evidence stop` also lists the decode-free capture directory | main |
| VS1 | 83 | `reviews/verify.sh` says "not measured here" when the suite refuses, instead of calling the register stale | main |

## Phase 6 — measurement correctness

| item | § | what to do | owner |
|---|---|---|---|
| PH1, T9, EH1, JC1 | 37, 51, 56, 82, 85 | match systemd 255's "Finished <unit> - <Description>." wording; the journal contract takes the message format from a real journal, not from its own fixture; the fixtures at 8866-8867, 10883 and `tests/journal/envhist` change | main, suite |
| EH2 | 61 | `bt-env-history` gets a driver column (stock vs E3) | main |
| PM1, PM2, PM3 | 57 | `bt-postmortem` concludes nothing from a watchdog that is off; test 4865-4869 changes (§84) | main |
| CD2 | 65 | `bt-capdiff`'s key drops the frame number; the fixtures stop sharing frame numbers | main, suite |
| SL1, SL2, BBS1 | 69 | the SCO ledger anchors a link on the kernel's send line (`hci0 opcode 0x(0428\|043d) plen`), counts accepted links as `incoming`, prints the boot's total command timeouts beside its own and flags any outside a link; `boot-bt-summary.sh` says when a read failed instead of printing `(none)` | main |
| AC1, AX1, AX2 | 43, 67 | `bt-actions` keeps to the asked boot and to the controller's VID:PID; the kernel's own reset attributed (with KR1) | main |
| TA1 | 26 | an unreadable window is not "clean" | main |
| KM1, DG1 | 39, 62 | the kernel-mechanism tool reads the module that runs (`updates/` first) and labels it; test 6193-6242 gains the E3 case | main, suite |
| M1, EV1, SW3 | 3, 31, 32 | no tool opens MGMT or sends HCI by default; this also removes the `bluetoothctl` trigger of BT-4 (comms 2026-10-18T15:32Z, item 3: a D-Bus read through `busctl` opens no MGMT socket) | main |
| BS-1, BS-2, BP1, HR1, HR2, HR3, CX1, CX2, BB1, DG2, LV3, AX3 | 40, 53, 54, 58, 59, 60, 62, 66, 67 | bound every whole-boot read; resolve the controller by VID:PID | main |
| RT3 | 84 | the whole-boot-read invariant catches every spelling. Land it first and expect it to fail on the tools above; that failure is the work list | suite |
| WD1 | 17 | (phase 2) | |
| IN1, AWC1 | 80 | the coverage instruments include `scripts/`; awk coverage counts programs that never ran | suite |

**Then re-derive the published numbers** with the fixed instruments: the 74/0 links of E1 and E3,
the 20/0 on `-38`, and the rows of `results.tsv`. §69 found the ledger sound on the recorded
evidence. If a number changes, the correction goes beside the original with both derivations.

## Phase 7 — the other MED items, and two lower ones

| item | § | what to do | owner |
|---|---|---|---|
| SM1, SM2 | 19 | the SMTP check tells a connect failure from a revoked password; the password goes on stdin, not the command line | main |
| SN1 | 18 | `bt-snapshot` resolves presence and adapter by VID:PID; test 9934-9944 gains a second, non-controller adapter listed first | main, suite |
| CL2 | 45, 75 | before `--functional` runs on the laptop, establish where the harness runs `btvirt` | ci-local, then the operator |
| DS4 | 85 | `devtools/status`: "cannot confirm" is a non-zero exit and the summary says "push NOT confirmed"; test 13193-13202 asserts the summary | suite |

## Phase 8 — LOW and INFO

Section by section, in the review's order. Grouped by owner:
- **suite:** the suite's own findings:
  - RT1 (the split, UT-12, and the stale "9,700 lines" header);
  - RT2, RT4, RT5, RT6;
  - RT7 (before the split);
  - UD1.
- **main:**
  - RS3's two comments;
  - in the retest kit and the phase-5 scripts: QT1, KM2, TR1 and CP2 (they matter only if those
    scripts are reused);
  - the remaining LOW items of §1-§80.

## Cross-cutting: one guard per recurring pattern

Fixing a pattern once covers its future instances. Each guard below is an invariant in the suite or
a refusal in the tool, test-first like the rest.

1. **Siblings** — where a defect has a greppable shape, the suite checks the shape tree-wide:
   - `COLUMNS=` before a `btmon` call;
   - whole-boot journal reads (RT3);
   - `\|\| true` after a search whose emptiness matters.
2. **Rules held in prose** — the suite fails if any tool prints `install.sh --apply` or suggests
   `bt-mode mitigation`, and if any guest-only tool lacks its guard.
3. **Fixtures that encode an assumption** — stubs and fixtures are cut from real output:
   - the `btmon` stub shortens headers as `btmon` does;
   - journal fixtures carry systemd 255's wording;
   - the journal contract reads a real journal (JC1).
4. **A gate that reports success on what it did not see** — every gate says NOT RUN rather than
   PASS when its tool produced no summary line, and the suite drives each gate with a crashing tool
   once.

## Order and dependencies, in short

1. Phase 0 (the operator).
2. Phase 1, then the operator's deploy decision.
3. KR1 at the head of phase 2, while E3 #2 runs.
4. The rest of phases 2 and 3.
5. Phase 4 before any next send.
6. Phases 5 to 7.
7. Phase 8 alongside the others.

The project completion plan, beside this file, places this work among the project's other open
items.
