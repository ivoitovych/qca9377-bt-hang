# Project completion plan — 2026-10-19 04:57 UTC

How this project reaches its logical end from where it stands today. It is written beside the
comprehensive code review of the same day
([`review-comprehensive-code-review-20261019-014718.md`](review-comprehensive-code-review-20261019-014718.md))
and its reaction plan
([`review-reaction-plan-20261019-045758.md`](review-reaction-plan-20261019-045758.md)), which
cover the repository's own code. This plan covers everything: the bugs found, the contributions
in flight, the laptop, the record, and the watch for bugs still to be found.

The current state is taken from `docs/STATUS.md` (as of 2026-10-18) and `BRIEF.md`; where they
disagree, STATUS's submission rows win. This plan is a snapshot. When a row's state changes,
STATUS changes, not this file.

## The end state

The project is finished when all of the following hold:

1. **Every issue in STATUS has a terminal state**, and each terminal state carries its reason and
   evidence. The terminal states are:
   - fixed upstream and released to where the laptop gets it;
   - reported upstream, with nothing more owed by us;
   - closed as by design;
   - closed as withdrawn;
   - closed as not reproduced.
2. **Every submission has a terminal state:**
   - accepted and released;
   - superseded by another author's change;
   - withdrawn, with a note.
3. **The laptop runs stock software for Bluetooth.** That means:
   - a distribution kernel whose own `btusb` carries the `13d3:3503` entry, with E3 retired from
     `updates/`;
   - a `bluetoothd` decided on with the facts in hand;
   - the investigation's instruments either removed or left in a documented passive state.
   
   Each of these steps is the operator's decision.
4. **One confirmation on stock software:** mSBC calls on the headsets that died on the stock driver,
   with no command timeout. This is recorded as the closing exhibit of BT-1.
5. **The record is final:**
   - README states the outcome;
   - BRIEF is reduced to the closing state;
   - STATUS rows are terminal;
   - HISTORY has a closing chapter;
   - `docs/issues.md` is current (register row R2-21: it stops at `EX-021`);
   - every row of the action register in `reviews/README.md` is closed or explicitly kept.
6. **The review's findings are worked or explicitly kept** (the reaction plan).
7. **A watch period has passed** after the last release reaches the laptop, with no regression found
   in our contributions (section 4).

## 1. Where each item stands, and what closes it

### Issues

| id | today (STATUS 2026-10-18) | what closes it | whose step |
|---|---|---|---|
| BT-1 | cause confirmed; the entry `dc16388d45ec` (not ours) is released in 7.2.10, 6.18.56 and 6.12.113, and is in the 6.6.160, 6.1.191, 5.15.224 and 5.10.273 release candidates of 2026-10-17. Ubuntu's `-38` and `-39` lack it. The laptop runs E3. | (a) those four stable releases; (b) an Ubuntu kernel carrying the entry, through a later stable patchset or an SRU request; (c) E3 retired and the confirmation on stock software (end state 3 and 4) | (a) watch; (b) the SRU request is the operator's decision, and an outside review ranks it first; (c) the operator |
| BT-2 | fixed by the same commit as BT-1 (its message names the 0x2005 symptom) | closes with BT-1 | — |
| BT-3, BT-5 | superseded | closed | — |
| BT-4 | `btmon` aborts while capturing. A `bluetoothctl` MGMT open is one trigger (2026-10-18). Matches BlueZ issue #1104, STRONGLY INDICATED, not proven. | either confirm with a `btmon` built from BlueZ master or a symbolised trace, and close as "fixed upstream by `fdbfe0018`/`dca0f10fd`, nothing to report"; or close as "not confirmed" with the reason. Meanwhile our own tools stop opening MGMT (reaction plan, M1/EV1/SW3), which removes the trigger we cause. | main; any run on the laptop is the operator's |
| BT-6 | observed once | close as not reproduced, at the end | main |
| BT-7 | both BlueZ patches accepted (2026-09-21); no BlueZ release since | a BlueZ release carrying them; then the `bluetoothd` decision (section 3) | watch; the operator |
| BT-8 | ours, `86ef0f58bdec`: in mainline v7.3-rc7; released in 7.2.11, 6.18.57 and 6.12.113; in 6.6.160-rc1 and 6.1.191-rc1 | the 6.6.160 and 6.1.191 releases (and v7.3 final) | watch |
| BT-9 | fixed upstream by `96d006ae6445` (Jiajia Liu); our backport released in 6.12.113; in 6.6.160-rc1 and 6.1.191-rc1. The BlueZ test series and the leak fix are accepted. | the 6.6.160 and 6.1.191 releases | watch |
| M-1 | mesh: v3 written; being split into separate contributions; steps (1) and (2) done | steps (3) to (6) of STATUS's mesh row, each sent, or explicitly dropped because upstream work superseded it (section 2, phase C) | main; every send is the operator's |
| M-2 | narrowed to non-mesh extended advertising by `87a49b610708` | a reproducer in QEMU (Add Advertising with a timeout of 66 s or more), then a patch or a closing note | main |
| M-3 | accepted (2026-10-08) | a BlueZ release | watch |
| U1 | fixed upstream in PipeWire 1.1.81/1.2.0; Ubuntu 24.04 has 1.0.5 | the decision whether an Ubuntu backport is worth asking for | the operator |
| U2 | observed; what wrote the volume is unknown | a `bt-ui-capture` capture, then report or close | the operator (capture), main |
| U3, U5 | design / withdrawn | closed | — |
| U4 | observed; related open GNOME reports #3710, #3715 | a capture; a debug patch only if the panel's own decision must be logged; then a report or a pointer to those reports | the operator, main |
| U6 | confirmed; fixed in GNOME 47.0 | one recorder reading, then a Launchpad SRU request quoting the six commits | the operator's send |
| U7 | confirmed race; no PipeWire fix | a capture, then a report to PipeWire citing pipewire #5506 and bluez #2562; the host side examined separately first | the operator's send |
| U8 | observed | capture a silent link; check offline whether valid frames arrive; then decide | the operator, main |
| U9 | by design; a prior upstream decision found | close as by design, or a narrow opt-in proposal with the maintainers' agreement first | the operator |
| U10 | observed | the test sound per mode with `bt-mark`, then Dual Channel vs bitrate, then PipeWire's decision path | the operator, main |
| U11 | by design | close, or an opt-in proposal; `module-switch-on-connect` is the operator's local choice | the operator |

### Submissions

| submission | today | terminal when |
|---|---|---|
| A1, A2 (BlueZ, sent 2026-10-18) | `new`, CI passed (A2's one failure is a known upstream flake with a pending fix) | applied; or, under the send rules of `patches/bluez/send-2026-10-18/`, an unchanged v2 no earlier than 2026-11-01, on the operator's yes; or dropped with a note |
| Stable backports of `96d006ae6445` and `dc16388d45ec` | released on some lines, in release candidates on the rest | released on every line they were queued for |
| `Tested-by` on the mesh_tx leak fix (another author's patch) | `new`; a later patch by another author carries the same hunk | applied, or superseded by that patch; nothing owed either way |
| Reply on BlueZ issue #1554 | posted; a second affected user will check | that user's answer, or the issue's closure |
| Mesh v3 | being split | M-1's steps |
| BlueZ fixes and tests already accepted | in master | a BlueZ release (watch only) |

## 2. Phases

### Phase A — this week (from 2026-10-19)

- **The 6.6.160-rc1 review window closes today, 16:02:05 UTC.** BT-8's fix, the BT-9 backport and
  the entry are all in it. Nothing is owed. Read the replies afterwards for any report that names Bluetooth. The
  6.1.191-rc1 review mail had not appeared by 2026-10-18 15:29 UTC.
- **The operator's two decisions** from the reaction plan: CAP1 (the capture archive) and the
  timing of the tools deploy.
- **E3 #2 runs** (open since 2026-10-18 17:05). Until `main`'s tools are deployed, a shutdown with
  a trial open can lose its row (STATUS). The hand-close procedure that saved E3 #1 is
  `scripts/trial-close-now.sh --reopen`; using it is the operator's call.
- **The test suite merges `main`** (the test-suite synchronization plan, step 1).

### Phase B — the next three weeks

- The reaction plan's phases 1 to 3, then the deploy, on the operator's word.
- The stable releases land: 6.6.160, 6.1.191, 5.15.224 and 5.10.273. Check each by subject and
  revert-aware (after STB1's fix), and record each in STATUS.
- **The Ubuntu path for the entry.** Re-check Launchpad and `-proposed` for a kernel carrying
  `0x13d3, 0x3503`, the same way as on 2026-10-18. Bring the SRU request to the operator with the
  facts. Before any new kernel boots, run `scripts/btusb-has-device.py` on its stock `btusb`; if
  the entry is ABSENT, E3 is rebuilt for that kernel first (BRIEF §0).
- A1 and A2: watch master, patchwork and the list. No v2 before 2026-11-01.

### Phase C — the following weeks

- **Mesh**, in STATUS's order:
  1. Weigh `87a49b610708`, Cen Zhang's 14880941 and Igor Putko's 14888791 against v3 before any
     more mesh work.
  2. The power-off fix: the outside review recommends a review reply on Jiale Yao's 14864878,
     framed as one shared problem, with no Tested-by. Sending it is the operator's decision.
  3. The question to the list on what Count means.
  4. The core ownership patches, only after the lifetime work upstream settles, or a note that
     upstream's work made them unnecessary.
  5. M-2's reproducer, then a patch or a closing note.
- **The desktop items (U2, U4, U6, U7, U8, U10).** Each needs a capture with `bt-ui-capture`,
  whose recorders are inactive since the 10-11 reboot; restarting it is the operator's decision.
  Then each one is reported or closed. Every report is a send, on the operator's yes.
- **BT-4's confirmation**, if the operator wants it run.
- The reaction plan's phases 4 to 8. Phase 4 must come before any send above.

### Phase D — the end game

1. **An Ubuntu kernel with the entry reaches the laptop.** `btusb-has-device.py` says FOUND on its
   stock `btusb`, with the `0cf3:e300` control.
2. **E3 retired** (the operator): remove it from `updates/` (`scripts/module-updates.sh remove`),
   run `depmod`, and cold boot. Never reload it live.
3. **The confirmation on stock software:** calls on each headset that died on the stock driver,
   recorded as BT-1's closing exhibit. Before it, decide with the operator how the trial is
   labelled, so it does not pool with the stock-era trials (BRIEF §9.3 notes that labels pool).
4. **The `bluetoothd` decision** (the operator):
   - the laptop runs a patched rebuild from `/usr/local` (drop-in `20-patched-bluetoothd.conf`;
     the package binary is intact);
   - keep it until the distribution carries the two fixes, or return to the package, knowing
     which crash sites the stock daemon still has.
5. **The instruments** (the operator):
   - what stays on the laptop;
   - what `bt-ui-capture stop` and `unstage` undo;
   - whether the project is uninstalled.

   `uninstall.sh` must not run before the reaction plan's UN1 and UN2 are fixed: today it can
   reload `btusb` live and its advice deletes unarchived captures. Evidence archives stay either
   way.
6. **The record:**
   - README (the open register rows R2-05 and R2-07: the central finding is still missing);
   - `docs/issues.md` (R2-21);
   - the exhibits index;
   - BRIEF reduced to the closing state;
   - HISTORY's closing chapter;
   - STATUS with every row terminal;
   - `docs/contributions-roadmap.md` (as of 2026-09-26) marked historical.
7. **The watch period** (section 4) runs for one stable release cycle after the last release reaches
   the laptop.

## 3. Open threads outside STATUS's rows

These are written down elsewhere and must be closed or kept before the end:

- **BRIEF §9.2:** six tasks delegated to the test-suite maintainer:
  - source review;
  - instrumented `btusb` logging of the chosen `new_alts`;
  - bug-report audit;
  - `BL-09`;
  - `bt-crash` tests;
  - device survey.

  Their state is to be confirmed (synchronization plan, step 5).
- **BRIEF §9.3:** `bt-trial` does not record which `bluetoothd` runs; changing the results
  fingerprint is the operator's call. It matters for phase D's confirmation.
- **BRIEF §9.4:** one read of the 18 red CI runs of 2026-09-01 to 09-14, for anything else that
  went red meanwhile, is still owed.
- **BRIEF §9.10:** the gates that each re-run the suite, and the split of `tests/run-tests` (UT-12).
- **The action register** in `reviews/README.md`: 25 rows are open, partial or blocked as of today.
  Some look done already; run each row's deciding command and update it. For example:
  - DR-12's repository-derived allowlist is asserted by `tests/run-tests` 12671-12716;
  - `autostop` is passive in `main`'s source (R2-65).
- **What the ROM firmware does wrong** is not known and not claimed (BRIEF §4). Pursuing it is
  optional and not needed for completion. It would need long windows on the laptop, which are
  asked for only with a concrete plan.

## 4. Finding more bugs, and the bugs that follow our contributions

The end state assumes more bugs will be found. This section says where they come from and where
they go.

### 4.1 Where a new bug goes

- **On the laptop:** the instruments that run there (trial rows, the SCO ledger, the captures, the
  journal) find it. It becomes:
  - a STATUS row in the lifecycle words (observed, hypothesis, confirmed, …);
  - a `docs/issues.md` entry with its falsifier;
  - an exhibit with its extraction command and exact output.

  No claim goes past its evidence. A bug in another component gets its upstream route checked
  before any report, and every report is a send on the operator's yes.
- **In our tools, tests or CI:** a dated review in `reviews/`, or a row in the action register.
  The review's four recurring patterns are the checklist for whether one bug is a class.

### 4.2 Bugs that follow our contributions

Changes made after ours can break what we contributed, or show that it disagrees with what others
assume. This has already happened, in both places:
- **Inside this repository:**
  - CI was red for weeks, twice, because changes on `main` broke suite invariants while the suite
    could not run on the laptop (BRIEF §9.4);
  - the suite's `btmon` stub printed full header names that the real `btmon` never prints, so a
    broken decode passed every test (comms 2026-10-18T06:15Z).
- **Upstream:** the list bot's mesh-tester failed on every kernel patch from June until another
  author's `87a49b610708`. A known flaky functional test (`test_bluetoothctl_pair_bredr`) fails
  about 7 times in 26 bot runs, ours included.

The watches below look for this:

| watch | what can go wrong | how to look | cadence |
|---|---|---|---|
| **Our tests upstream** | a later BlueZ commit breaks or disables the tests we contributed: the simultaneous-discovery-stop cases in `mgmt-tester` (`f3344d20d`, `2942883d2`, `49a70562f`), the `unit/test-mgmt` cases (converted by the maintainer to the tester framework in `866b0b8b1`), the hook-leak fix `8da7e648a9fb` | the bot's `TestRunner_mgmt-tester` and unit results on recent patches (`scripts/patchwork-checks.sh`); `git log` on those files in a fresh BlueZ fetch; our case names present and passing in a QEMU run of master | weekly, and before any BlueZ send |
| **Our patches upstream** | a revert, a rework, or a `Fixes:` that names one of ours: `86ef0f58bdec`, `a734b06059cb`, `0bed9886cff3`, `ae23df052290`, `6f5eeb402d3b`, `8da7e648a9fb`, the BT-9 backports | `git log --grep` on the subject and on `Revert "<subject>"`, and on `Fixes: <hash>`, in fresh `bluetooth`, `bluetooth-next`, mainline and stable fetches (after STB1's fix) | weekly |
| **Stable fallout** | a regression report against a release that carries our commits or the entry | the replies to each rc review that carries them; the stable list for "Bluetooth" | at each rc |
| **Distribution fallout** | an Ubuntu kernel or BlueZ upload that drops, reverts or conflicts with a fix the laptop relies on | Launchpad uploads and changelogs for `linux-hwe-7.0` and `bluez`; `btusb-has-device.py` before each new kernel boots | at each upload |
| **Upstream flakes we meet** | a bot failure on our patch that is the baseline's | `scripts/patchwork-checks.sh --failed-functional`; never answered by a resend | at each send |
| **Inside this repository** | a change on one line breaks the other's tests or tools | CI on every push, read with `devtools/ci`; the synchronization plan's cadence; the review's pin maps when a tool changes | every push |
| **Laptop vs source** | the installed tools, modules or daemon drift from what the record says runs | `python3 -I scripts/installed-vs-commit.py . <installed> main`; `bt-verify-install`; `scripts/module-updates.sh status`; srcversions | after each deploy and boot change |

When a watch finds something, it goes through 4.1: an observation first, then its evidence, then
the route.

## 5. What stays in force until the end

- **Sends:** nothing is sent, posted or mailed without the operator's own yes. Relayed or pasted
  reviews are never consent.
- **The laptop:**
  - nothing changes on it without the operator's word;
  - never `install.sh --apply`;
  - never a live reload of `btusb` or `bluetooth.ko`;
  - only a power-off recovers the controller.
- **BlueZ's testers** run in QEMU guests, as every run so far has, not on the laptop.
- **Evidence** is never deleted; corrections go beside the original.
- **Addresses:** published text carries pseudonyms, never a real device address.
- **Every claim** ships with its extraction command and exact output.
