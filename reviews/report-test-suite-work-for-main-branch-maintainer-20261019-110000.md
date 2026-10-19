# Report: the test-suite work, for the main branch maintainer

```
from:     test-suite maintainer
to:       main branch maintainer
date:     2026-10-19, begun about 11:00Z
purpose:  one place that says what the test-suite work is, why it is built the way it is, what
          was done today and why, what stands on which branch, and what is yours to land or decide
marks:    [verified] seen run, or read in the repository, today; [hypothesis] reasoned, not run;
          [recommendation] mine, yours to decide. Unmarked statements of design are the design
          as I hold it.
method:   written first from the day's working record, then checked against the repository
          sentence by sentence; the second commit of this file holds the corrections
```

## 0. Where things stand, on one screen

- **The ready line**, `tests/unit-testing-introduction-ready-for-main`, is at `022a1ec`. It holds
  every commit of the test-suite work that `main` does not have, and it contains `main`
  (`8f1396f`). Its tip is green on both workflows, `checks.yml` and `access-audit.yml`.
  `checks.yml` was green on every commit along the way; the access audit was red on seven
  consecutive commits for one wrong allow-list line, now corrected (§4.14).
- **The working branch**, `tests/unit-testing-introduction`, is at `9e56eb9`, and its tree is the
  ready line's. Nothing of the test-suite work is held back anywhere else, except two branches
  that are not meant to land as they are (§2).
- **What is yours**, in order: land the ready line; land the VI1 and MODE2 rehearsal checks with
  your fixes for them; decide the 41 journal reads listed in `tests/whole-boot-reads.txt`;
  decide whether `sco_sent` counts the Enhanced setup, and whether the two trial scripts stay.
  The smaller items are in §7.
- **The suite**, at the tip: 1086 checks in a parallel run (one fewer serially: the check that
  every section finished in one worker exists only in a parallel run). On this 4-core container
  a parallel run takes about 59 s and a serial one about 142 s. Gates: bash coverage 87% (floor
  80), awk statement coverage 97.7% (floor raised today from 85 to 95), Python line coverage
  89% (floor 80), comprehensiveness at or above 75% for every unit.

## 1. The aim, and the operator's decisions behind it

The operator's aim, as relayed today: everything the test-suite branches hold should be on
`main` and used there, in the main line of development. That means the acceleration (the
parallel runner), the coverage and comprehensiveness gains, tests for the newest tools, and tests
for the flaws found recently, the dangerous sections among them.

Your four recommendations of this morning, which the operator accepted:
1. the `btmon` width fix: yes, and first, before the laptop's deploy;
2. the device survey: dropped;
3. the access audit: a workflow of its own, still run on every push, so that the normal CI keeps
   its two and a half minutes;
4. the 16-core measurement: at the next hand close before a planned shutdown, if at all.

And one standing decision of the operator's that shaped the whole acceleration: **parallelism,
not fewer runs.** The operator was explicit that cutting runs would cut quality. So no
instrument was dropped and none runs on a sample: every push still runs the suite under every
instrument, and the time was won by running sections in parallel inside a run and jobs in
parallel inside CI.

Your reply of 05:41Z (`comms/2026-10-19T0541Z-from-main-branch-maintainer-to-test-suite-maintainer.md`)
set the conditions this work followed:
- bring the working branch's eleven code commits through the ready line, the access audit first;
- split the checkout world into sections before it lands;
- the audit must not make the CI verdict wait: a workflow of its own, reported by `devtools/ci`
  on a line of its own;
- the agreed order: phase 1 (the `--columns` fix, the btusb guard, CK1, SU1), then BT-4's
  `bluetoothctl` reads, `devtools/ci`'s 30-run limit after `8ecf3fd`, and tests for your three
  trial scripts;
- I write both the test and the tool side on the ready line, and you review the tool hunks.

## 2. Branches, and the rules they move by

| branch | at | what it is |
|---|---|---|
| `main` | `8f1396f` | yours; it held the whole earlier ready line by this morning |
| `tests/unit-testing-introduction-ready-for-main` | `022a1ec` | the ready line: what is offered to `main` |
| `ci/deploy-rehearsal-20261017` | `022a1ec` | where each candidate commit is pushed first, so that CI runs before the ready line moves; its name is historical (made for the deploy rehearsal of 2026-10-17) |
| `tests/unit-testing-introduction` | `9e56eb9` | the working branch; today it only merged the ready line |
| `tests/deploy-rehearsal-checks-awaiting-main-fixes` | `2589dee` | one commit on `11c8039`: the VI1 and MODE2 assertions, red on today's tools, for you to land with your fixes |
| `ci/deploy-rehearsal-red-checks-20261019` | `3e804de` | CI only, never to land: the reload guard reverted, to show the rehearsal's three new checks red |
| `ci/deploy-rehearsal-red-installer-20261017` | `d24f332` | CI only, from 2026-10-17: the rehearsal against `install.sh` before its upgrade fix |

The rules:
- Between branches, merges, never rebases. The ready line moves only by fast-forward, and only to
  a commit CI has passed that contains `main`.
- A force-push only after a dated backup branch, and then with `--force-with-lease`. None was
  needed today.
- Every commit through `devtools/repo-save`, after every gate CI runs has passed here; never
  `--no-verify`. One identity, and no attribution lines of any kind.
- Nothing is installed or changed on the laptop without the operator's word. Nothing was.
- No tracked file is edited or staged in a checkout while its suite or an instrument runs: the
  suite's own end-of-run checks (the tracked-file footprint, the checkout world's untouched
  check) would report the edit as damage, and they did, once, earlier in this work.
- Push promptly: the working container can be reclaimed.

## 3. The suite: what it is, and why it is built this way

### 3.1 Shape

`tests/run-tests` is one bash file of a little over 15,200 lines: a setup, then about fifty
sections, each opened by a heading `echo` and a rule `echo`; the last section is the report.
UT-12 plans to split it into parts. Every self-scan already reads the derived file set
`SUITE_FILES`, not the entry file, so that a split cannot silently shrink what a scan covers;
today's RT7 closed the last exception.

### 3.2 The isolation layers, and the incident behind each

The suite runs on the investigation machine, which carries a live experiment. Each layer exists
because something escaped without it.

- **It refuses while a trial is open.** On 2026-08-14 a coverage measurement closed a live
  two-hour trial and wrote a results row whose treatment fingerprint the test stubs had made up.
  The refusal reads the real trial state before anything runs; the end of the run compares it.
- **The PATH guard.** No PATH a test builds may re-add `/usr/bin` or `/bin`; an invariant counts
  every PATH construction (142 at the last count) and checks each.
- **The machine tripwire.** `tests/machine-tools` lists the machine tools (51); each resolves to a
  tripwire that logs the call and the assertion before it. A canary proves the tripwire is armed
  in every worker, and the run fails on any call that reached it.
- **The declared machine.** `SUITE_MACHINE` is a tree of empty machine state, and every seam
  whose default is a machine path is declared into it for the whole run (`BT_HEALTH_DIR`,
  `BT_TRIAL_STATE_DIR`, `HOME`, the sysfs and usbfs roots, and about thirty more). A test that
  needs a seam sets it, as every test did; a test that forgets one meets this empty machine
  instead of the one it runs on. `machine_stub` gives quiet stubs for the machine tools a tool
  meets in passing. `real_tool` is the one door to the real machine, and it tags its call
  `BT_MACHINE_CONTRACT=<check>` so that the decoy world and the access audit class the read as a
  contract read.
- **The footprints**, before and after the run: the system binaries (`/usr/bin`, `/usr/sbin`,
  `/bin`, `/sbin`, by stat), after a symlink farm wrote through to `/usr/bin/systemctl` on a
  development container; the repository's tracked files; `evidence/sessions`; the real trial
  state; and since today the files the project installs (RT4, §4.11).
- **The run marker**, `SUITE_RUN_ID`, carried by every process of a run: the orphan scan finds
  leftovers by it, and since `3ed9dc4` a suite started inside a suite run refuses at once.
- **Worlds that prove themselves before anything runs in them.** The namespace world runs
  `bt-ui-capture`'s shipped defaults in a user and mount namespace. The checkout world runs
  `devtools/held`, `save` and `review-open` in place, in an overlay of the checkout with a network
  namespace (§4.8). A world that cannot be built is reported NOT ASKED; one that builds and fails
  its proof is a red check, and nothing runs in it.
- **The decoy world**, `devtools/sandbox`: the suite in a world whose every answer is marked, and
  four detectors that must stay silent. Its first run (2026-09-29) counted 312 calls of real
  machine tools per suite run and 12 verdicts that changed with the machine.
- **The access audit**, `devtools/access-audit` with `devtools/access-classify`: the whole suite
  under `strace`, every file access, made or attempted, classified by where it landed (scratch,
  the checkout, system software, a namespace world's own mounts, the machine). A machine access
  fails the audit unless `tests/access-allowlist` names it with a reason, and an allow line that
  nothing matched fails it too. Its first run (2026-10-09) found nine kinds of access the decoy
  world had passed: the host user's `~/.jq`, git's global ignore and attributes, Python's user
  site-packages, the real trial state, the real `/var/log/bt-health/trace`, the real `/etc` and
  `/usr/local` read by `uninstall.sh`'s dry run and by `verify-restored.sh`, and `/tmp` outside
  the run.

The principle across all of them: **isolation is measured, not claimed.** The workflow's header
said "~2 s and hermetic" until the first decoy-world run proved otherwise.

### 3.3 The parallel runner (2026-10-18)

Why: a serial run had grown past 100 s, and CI ran it under five instruments one after another,
about nine minutes in one job. The operator's answer was parallelism.

How:
- The parent lists the sections (`suite_sections`) and starts workers, each a fresh
  `tests/run-tests` with `SUITE_UNIT`, `SUITE_UNIT_DIR` and `SUITE_UNIT_PARENT` set; a process
  that has `SUITE_UNIT` set but no parent's run id refuses.
- Each worker builds the whole setup afresh (its own guard, tripwire, declared machine and temp
  tree), then runs its sections from a copy of their lines padded to their own line numbers and
  named `tests/run-tests` (`suite_copy_lines`), so that a trace, an error message and coverage
  see the real file and line.
- Where a section reads what another built, it says so:
  `# PARALLEL: runs after "<heading>", in the same worker:`. Three such chains exist. A section
  marked `# PARALLEL: long` is started first.
- Each worker returns its pass and fail counts, its `*_SKIPPED` variables (for the NOT ASKED
  report), its tripwire log and its orphans; the parent sums them, runs the report, and names the
  three longest units on its last line, so the next section to split is always named.
- `--serial` runs one process in file order; `--jobs N` caps the workers.
- `tests/README.md`, rule 9: **a section stands alone.** It sees the setup and nothing else,
  whatever ran before it in the file.

Measured on this container's 4 cores: on 2026-10-18, 97 s serially and 41 s in parallel; today,
with the access audit's checks and the checkout world in the suite, about 142 s and 59 s. Under
the instruments (2026-10-18 figures), serial against parallel: bash coverage 120 s and 56 s, awk
162 s and 97 s, Python 119 s and 45 s, comprehensiveness 118 s and 53 s. On 16 cores the floor is
the longest unit, not the processor: today about 21 s is predicted (§4.8). It has not been
measured: no 16-core host has run it.

### 3.4 The instruments, each of them measured too

- `devtools/coverage`: bash line coverage under a trace, floor 80; exclusions in
  `devtools/coverage-exclude`, each derived by content and self-checked (an exclusion that matches
  nothing, or hides an executed line, fails the gate).
- `devtools/awk-coverage`: awk statement coverage under `gawk --profile`, floor 95 since today.
- `devtools/py-coverage`: Python line coverage, floor 80.
- `devtools/test-comprehension`: per unit, the share of modes, refusals, seams and branches the
  suite drives; every unit at 75% or more.
- `devtools/sandbox`: the decoy world, with `--self-test`.
- `devtools/access-audit`: the trace, with `--self-test` (19 planted accesses and controls).
- `devtools/mutate` and `devtools/mutants`: each decision flipped alone in its own namespace, the
  suite run on it; a survivor is a missing test or an equivalent change. `--self-test`.
- `devtools/journal-contract`: the journal fixtures' shapes against the real `journalctl`,
  including a phase that builds a real journal with `systemd-journal-remote`.
- `devtools/repo-validate`: every tracked file parsed by its kind (bash, awk, Python by
  `ast.parse`, units, rules, json), then the suite, the documentation-drift alarm and
  `doc-main-hashes`; `--no-suite` skips the suite and says so.
- `devtools/repo-scan`: the publish gate (addresses, BSSIDs, UUIDs, IPv4, email addresses, tool
  attribution, binary captures), over staged additions or `--all`.

`tests/README.md`, rule 7, **an instrument is measured too**: `devtools/awk-coverage` runs the
suite, so the suite never ran it, and its counting was trusted unseen. Pointed at a toy suite
whose answer was worked out by hand, it showed three counting errors, all making the figure low
(§4.7).

### 3.5 CI

- `.github/workflows/checks.yml`: eight jobs in parallel on eight runners, each with the same
  preamble (full-history checkout, the public `main` fetched for `doc-main-hashes`, the same
  packages, a version line):
  1. suite: `repo-validate` with the suite in parallel, the journal contract, the full-tree scan;
  2. serial: `tests/run-tests --serial`;
  3. coverage, floor 80;
  4. comprehension, floor 75;
  5. awk-coverage, floor 95;
  6. python-coverage, floor 80;
  7. isolation: the sandbox's and mutate's self-tests, then the suite in the decoy world;
  8. system: the system round trip and the deploy rehearsal in both modes, installing for real on
     the runner VM (`BT_SYSTEM_TEST=required`, so a skip fails).
  About two and a half to three and a half minutes.
- `.github/workflows/access-audit.yml`, since `3ed9dc4`: the audit's self-test, then the whole
  suite under the trace, about ten minutes; its report kept as an artifact when it fails. Its
  verdict is not the CI verdict.
- `devtools/ci` reads the verdict from `checks.yml`'s run by name, and prints the audit's run on a
  line of its own (green, red with how to read its failing lines, running, or none), never
  changing its exit status.

## 4. Today's work, in order, with the reason for each step

### 4.1 The handoff, and the synchronization

- The handoff note of 05:04Z (`comms/2026-10-19T0504Z-…`) described the whole state of the
  test-suite work for you; you landed it on `main` (`13317ba` to `78e243d`), with `cf9b304` as
  `62d5deb` and the six earlier notes as `8dc1039`.
- `main` (`8f1396f`) was merged into the ready line (`401e201`: no conflict, and `git diff
  origin/main 401e201` empty) and the ready line into the working branch (`a4ece69`).
- The progress note `comms/2026-10-19T0601Z-from-test-suite-maintainer-to-main-branch-maintainer.md`
  was opened at the start and kept as a log through the day, so that what was done and why
  survives in the repository and not in anyone's memory. Its last section lists what is yours.

### 4.2 T2/SW1: the btmon width, and BT-4's mechanism [verified]

The finding (yours, 2026-10-18): written to a pipe, `btmon` 5.72 fits each header line into 80
columns and ignores `COLUMNS`. So `COLUMNS=200 btmon -T -r` printed
`< HCI Command: Se.. (0x01|0x0028) plen 17`, and every filter on a command name matched nothing:
every trial's `sco-params.txt` has been the fallback line. The suite never saw it, because every
`btmon` stub printed full names.

Checked against the real thing. Ubuntu's `bluez` 5.72 (`apt-get download bluez`, unpacked, not
installed) was run here on a synthetic capture in `bin/bt-capture`'s monitor format, placeholder
addresses only (`tests/btmon/real/mkcap.py` builds two captures: seven records, and a privileged
MGMT open). It confirmed the width finding, and it reproduced BT-4:
- `btmon -T -r` aborts (`*** buffer overflow detected ***`, exit 134, all buffered output lost) on
  one record, a privileged MGMT Open, `@ MGMT Open: bluetoothctl (privileged) version 1.22`;
- the mechanism is `print_packet`'s `max_len` in `monitor/packet.c`: the space for the text is
  `col - len(ident label) - len(extra) - len(the right-hand block) - 3`; at `max_len <= -2` the
  fortified `snprintf` gets a size that wraps, and glibc aborts;
- predicted threshold col 80 aborts, col 81 survives: measured exactly so (79 and 80 abort; 81
  decodes with the label corrupted to `MGMT O..n`; 82 and up are clean);
- upstream fixed it in 5.80 (`monitor: Fix crash due to negative max_len`); STATUS's BT-4 row had
  it as strongly indicated, not proven;
- `bin/bt-capture`'s timestamps decode to the right date (`(unix - UNIX_2000) * 1e6 +
  0x00E03AB44A676000`); a 2056 date seen on the way was my generator's error, not the tool's.

[hypothesis, not runnable here: no Bluetooth] Live packets carry the sender's `comm[pid]` in the
label, so at 80 columns a privileged open goes negative even without dates. `bin/bt-trace` ran
`btmon -w "$CURRENT"`, whose discarded decode still runs at 80 columns and can kill the capture.
`--columns=200` there should stop these aborts whatever opens the socket (`bluetoothctl`, a
probe, `btmgmt`), and may make the D-Bus rework of the `bluetoothctl` reads unnecessary. One
trial after the deploy will show: the row's `btmon_aborts` column.

The commits:
- `48118c3`: the finding in the progress note, and `tests/btmon/real/` (the generator, the two
  captures' real `btmon` output at 80, 160 and 200 columns, and its provenance).
- `f5b2508`: `tests/btmon/render`, a renderer that prints header lines as the real `btmon` 5.72
  does: it parses `--columns=N` and `-CN` (default 80), splits each header into ident, label,
  text, extra and the right-hand block, cuts only the text with btmon's "..", pads as btmon does,
  and where btmon would abort prints nothing and exits 134. The suite checks it byte for byte
  against the real output at three widths, under gawk and mawk. Red first, with a one-column
  drift.
- `9667943`: every `btmon` stub in the suite now prints through the renderer. With the tools
  unchanged, 10 checks went red, which is what the laptop's tools do today: the close's SCO decode
  twice, `bt-actions` ("0 MGMT rows"), `bt-sco` six times, the decoded window. Then the fix at
  twelve call sites, not the seven named: `tools/bt-trial`, `bt-sco`, `bt-actions`, `bt-capdiff`
  and `bt-ctrl-window` (which had no width at all) get `--columns=200`; `bin/bt-trace` and
  `scripts/runtime-mgmt-test.sh` (live `btmon -w`) get `--columns=200`;
  `scripts/mgmt-replies.sh` and `discovery-stop-race.py` get `--columns=200`;
  `scripts/capture-window.sh` and `supported-commands-survey.sh` keep their 160 as `--columns=160`
  (their comments: btmon overflows above 255). `scripts/trial-sco-decode.py` already passed
  `--columns=200`. A new check that `bt-trace` starts every `btmon` with `--columns=200`, red
  before; the lifecycle check that pins the closer's `btmon` call now expects the width.
- `bf50fa4`: the Enhanced Setup Synchronous Connection (0x01|0x003d). `bt-sco`'s counts, block
  filter and `--raw`, the close's filter and its emptiness test, and `lib/sco-window.awk`'s marker
  matched only the plain command, so at any width an Enhanced request was not counted, printed,
  windowed or kept. A fixture (`tests/btmon/sco-enhanced.txt`) and two checks, red first. One
  lesson on the way: the close's check first passed without the fix, because its record inherited
  the filter's `keep` from the record before it; placed after an out-of-window record, it went red
  for the right reason.

Left for you [recommendation: yes]: `bt-trial`'s `sco_sent` counts `opcode 0x0428` in the kernel
journal and not `0x043d`, and `bt-actions` names only 0x0428. On a controller that is sent the
Enhanced form, the trial row would say no SCO was sent.

### 4.3 The btusb reload's second guard, `98af393` [verified]

Under `--tools-only`, `run()`'s gate withheld `modprobe -r btusb` and `modprobe btusb`, but the
reload block was still entered: it read the whole boot's kernel journal (about 20 s of quiet on
the laptop, minutes on a long boot) and chose the reload. One regression in `run()` was all that
stood between a tools-only deploy and a reset of the controller being measured. The block is now
`if (( APPLY && ! TOOLS_ONLY ))`.

The test: a copy of `install.sh` with `run()`'s tools-only gate cut out (six lines, verified),
run from a tree that links the rest of the checkout, staged under `BT_DESTDIR`, so the staging
gate still withholds every command. Red first: "--tools-only reached the btusb reload without
run()'s gate (rc=0, 1 journal read(s)): staging: NOT executed (system command): modprobe -r
btusb". A control shows the same copy reaches the reload on `--apply` with an idle btusb and a
quiet journal, so the check can fail.

`docs/install.md`'s deploy step 2 changed with it [for your review]: it told the operator to
expect `modprobe -r btusb` and `modprobe btusb` as `tools-only: NOT executed`, and 20 s of quiet;
now it says to expect no `modprobe` line and no journal read, and what an older `install.sh`
prints. This also closes I2's deploy-day half: `--tools-only` no longer reads the whole boot.

### 4.4 CK1, `30b6f31` [verified]

On the laptop `devtools/check` always ended NOT READY TO COMMIT: its first step runs the suite,
and the suite refuses while a trial is open, which on the laptop is every boot. It now does what
`repo-save` does: with a trial open it runs `repo-validate . --no-suite`, says so before its
first step, and ends "ready, WITHOUT the suite (a trial is open; CI runs it on push)". Red first,
on a copy of `devtools/check` beside spies for the three validators (the real ones would run the
suite inside itself); a second check pins that nothing changes with no trial open.

### 4.5 SU1, `11c8039`, and the checks that wait for your fixes [verified]

The deploy rehearsal (`tests/system-upgrade`, run in CI's system job: the 2026-09-18 tools
installed for real, a trial opened by the old `bt-trial`, this checkout deployed with
`--tools-only`, `daemon-reload`, the trial unit stopped as at shutdown, uninstall; in mitigation
and in experiment mode) stopped one step short of `docs/install.md`'s checklist. It now runs the
last two steps, `bt-verify-install` (against the checkout, as the operator runs it against the
evidence checkout) and `bt-mode status`, and prints what each said. And it runs `--tools-only`
with `journalctl` behind a spy that logs every call and runs the real one, failing on a kernel
read bounded by neither time nor priority (I2; the VM's journal is seconds old, so only the call
log can show it).

Shown red in CI on `ci/deploy-rehearsal-red-checks-20261019` (`3e804de`: the reload block's old
guard, plus the two assertions below), in both modes:
- I2: "--tools-only read the whole boot's kernel log: journalctl -k -b 0 --no-pager";
- VI1: "the checklist's last steps advise what the deploy must not do: Run: sudo ./install.sh
  --apply";
- MODE2: `bt-mode status` printed each inactive passive unit's state and then a second
  `inactive`, from `systemctl is-active "$u" 2>/dev/null || echo inactive`.

The VI1 and MODE2 assertions are on `tests/deploy-rehearsal-checks-awaiting-main-fixes`
(`2589dee`), one commit on `11c8039`, red on today's tools; they are kept off the ready line and
are yours to land with the fixes. On the laptop meanwhile the operator must ignore the verifier's
`--apply` advice; `docs/install.md` step 3 already says so.

### 4.6 The working branch's eleven code commits, re-cut as six

The working branch carried eleven code commits that `main` did not have: `8ecf3fd`, `d3aef99`,
`2418779`, `9e2606c`, `08e748a`, `ce1a527`, `7f50843`, `7c973d4`, `8a4aef8`, `0660ed5`,
`b270cd6`. Cherry-picking them one by one onto a ready line that had moved would have meant
resolving each against a different `tests/run-tests`. Instead the working branch's net change
over the ready line at the last merge (`git diff 401e201 a4ece69`, about 2,100 lines added in 34
files) was applied to the ready line's tip (only `devtools/coverage-exclude` conflicted), the
result was run green in a full clone (1067 checks, the checkout world included), and then the net
change was cut into commits by topic, hunk by hunk, with a small hunk splitter. The end state
equals the working branch's except where you asked for a difference: the audit's own workflow,
`devtools/ci`'s two workflows, the checkout world split. The commits, in order:

1. `ab74973` `devtools/ci` asks the repository the branch is pushed to (from `8ecf3fd`). Left to
   itself gh asks origin's repository; the held branches are pushed to `private`, and on
   2026-10-10 and 10-11 this tool said "no run found" while eleven red runs of one held branch sat
   there, until an outside reviewer found them. Now it asks the repository of the remote the
   branch tracks, or `--repo`, and every answer names the repository it asked.
2. `3ed9dc4` **the isolation, measured by an exact trace** (from `d3aef99`, `2418779`, `9e2606c`,
   `08e748a`, `ce1a527`): the gaps the trace found, closed (the run's own home, git attributes
   and Python user site off, the trial state declared, every tool's trace, capture and usbmon
   directory derived from `BT_HEALTH_DIR`, `uninstall.sh`'s dry run and `verify-restored.sh`
   staged, `bt-verify-kernel-mechanism` writing under TMPDIR, `bt-boot-stats` running its sibling
   `bt-boot-list` first, `bt-ui-capture`'s `BT_UI_GID`, the AT-SPI test's recorder stopped by its
   pid instead of `pkill -f`, `repo-validate`'s Python errors reported without reaching apport,
   the journal contract's phase 2 skippable through `BT_JOURNAL_REMOTE`); `tests/machine-tools`
   gains `sudo`, `runuser` and `gh`; `tests/system-resources.md` catalogues every seam with a
   machine default, and an invariant derives the list from the code and requires each catalogued
   and declared; the audit and the classifier themselves; the nested-run refusal; `--section`
   moved to the top. **New in this commit:** `.github/workflows/access-audit.yml`, and
   `devtools/ci` asking for `checks.yml`'s run by name (with two workflows a commit has two runs,
   and "the newest" would have been whichever finished last) and printing the audit's run on its
   own line. Red first for that: gh was asked with no `--workflow`, and no audit line.
3. `64530ee` `devtools/awk-coverage` measured against a toy suite; the CI floor 85 to 95 (from
   `7f50843`'s awk half). It had to come before the checkout world: with the world in and this
   not, awk coverage fell to 76%, below the floor, because the world's `repo-save` run inside the
   suite parse-checks every awk file over `/dev/null`, and the old counting filed each as a
   program that never saw data. The three counting errors: one program run by three scripts filed
   three times (keyed on caller and hash); gawk's `BEGIN {` and `END {` headers, which never carry
   a count, counted as statements that never ran; the parse checks. Here 89.6% of 2224 statements
   became 97.7% of 1447.
4. `a2a4931` **the checkout world, in four sections, each proving its own world** (from `7f50843`,
   `7c973d4`, `8a4aef8`, and `8ecf3fd`'s save-budget check). Details in §4.8.
5. `0326578` `bt-usbmon` and `bt-trace`: an idling daemon takes its `sleep 3600` with it on TERM
   (from `0660ed5`). Stopped outside systemd, which kills only the main process, both left their
   idle sleep running for the hour; CI runners reaped five of them at the end of every job.
6. `38c313f` the tooling index names the test tools, with the floors CI holds; `repo-validate`'s
   documentation-drift alarm is driven both ways in a scratch history with hand-set dates (from
   `b270cd6`).

`tests/README.md` gained rule 7 (an instrument is measured too) and rule 8 (an access that answers
nothing is still an access); "a section stands alone" became rule 9, and every reference to it
(BRIEF, `checks.yml`, the audit's workflow, `devtools/README.md`, the tooling index) moved with it.

The working branch then merged the series (`b761a00`): every conflict resolved to the ready
line's side, and `checks.yml`, which merged cleanly but kept the old in-workflow audit job, taken
from the ready line too. Its tree has equalled the ready line's since.

### 4.7 Why awk-coverage's counting mattered

A floor is only as good as its count. With the three errors the figure read 89% and could only
fall as tests were added that parse-check files; with them fixed it reads 97.7%, and the floor
could rise to 95 without any new test. The toy suite now pins each of the three: one program
named by the caller that ran it most, the parse checks set aside or counted as they should be,
the total and the floor at 75 and 76, `--uncovered` naming the two statements that never ran,
and a refusal of a suite it cannot run.

### 4.8 The checkout world, and the split

What it is: `devtools/held`, `devtools/save` and `devtools/review-open` act on the checkout they
live in. They switch branches, commit and push, so no test could run them where they are, and a
copy elsewhere is a different file to coverage and a different repository to git. So they run in
place: `unshare -Urmn`, an overlay of the checkout mounted over its own path (every write lands
in a throwaway upper layer), a network namespace (nothing can leave), scratch bare repositories
as `origin` and `private` through `GIT_CONFIG_*`, hooks off, a trial marked open so that
`repo-save` takes its no-suite path instead of running the suite inside itself.

Its proof, before anything runs: a marker file and a commit made inside are there inside and
absent outside; HEAD, every ref and the status unchanged outside (with `--no-optional-locks`, so
the check itself does not write `.git/index`); origin unreachable, by listing the namespace's
interfaces (only `lo`) and connecting to an address literal rather than resolving a name, which
would read the host's resolver files. It is built only where the checkout holds its own git
directory: from a git worktree on 2026-10-18 the proof's commit landed in the shared repository
and the world's own git identity replaced the shared `.git/config` identity (`8a4aef8`'s guard).

The split (your condition): its helpers moved to the setup (`co_world`, `co_snapshot`,
`co_git_inside`, `co_prove`, `co_setup`, `co_sect`, `co_untouched`), and the one section of about
40 s became four, each building and proving its own world in its own scratch directory and
checking afterwards that the checkout is as it was:
- **held**: status, the origin check (and a refusal when origin carries a `kernel/*` branch),
  edit, commit through `repo-save` to `private` only, a dirty tree, usage, origin unreachable;
  plus the worktree guard;
- **held sync**: main merged into the held branch, pushed to `private` only; an exhibit-index
  conflict regenerated from both sides' exhibits; a conflict elsewhere named, the branch left on
  the held branch; a dirty tree refused;
- **save**: its refusals, the hand-off warnings (BRIEF and STATUS lagging the newest exhibit;
  BRIEF over its budget, the budget read from `devtools/save` because a restated number broke the
  check when the budget rose from 750 to 1000), a commit through `repo-save` that pushes nothing;
- **review-open**, on a register written for it (an R2 prefix, bold, a two-word closed status, an
  unlisted status word, a row too short).

Two defects in the tools, found by these tests on the working branch and fixed: `held status`
printed "origin carries no kernel/* branch ✓" about an origin it could not reach (a failed
`ls-remote` counted 0 lines); `review-open` answered any unknown option as if asked for the open
rows.

The effect on time: the longest unit went from about 40 s to about 20 s (held's and save's, each
one `repo-save` run that validates and scans the whole checkout inside the world). On 4 cores a
parallel run is 59 s and a serial one 142 s; on 16 cores the prediction is about 21 s, 20 s for
the longest unit and under a second for a worker's setup. The next speed-up is in those two
units, not in more workers [recommendation: a narrower validation for the world's `repo-save`
runs, if one can be made without losing what they test].

### 4.9 The intermittent red, named, `2fb4251` and `6563c2e` [verified, with one hypothesis]

The audit's run of `a2a4931` went red: nothing outside the allow list, but one suite check failed
under the trace, and the audit printed only "FAILED: 1 of 1072". The next commit's audit, with
the same checkout world, was green, and a full audit of the tip here was green too. So:
- `2fb4251`: the audit now prints the failing checks and shell errors of the run it traced, as
  `devtools/coverage`, awk-coverage and py-coverage have since `62d5deb`. Red first, with a traced
  command that prints one check that held and one that failed.
- The very next red (the audit of `da6e22e`, a comms-only commit) named itself:
  "unbind/bind wrote '3-3'/'', expected 3-3".
- The cause: the watchdog section read `$WD/drv/unbind` and `bind` after the next scenario, a
  failed USB reset, which writes the same two files. `wd_until` stops that run the moment it logs
  "escalating to USB unbind/bind", and in `bin/bt-hang-watchdog` the log line comes before both
  writes, three seconds apart. A stop that took longer than that, as under a trace, could land
  between the shell's truncating open of `bind` and its write. The first scenario had finished
  normally in that run (its exit-status check passed), so only the second could have emptied the
  file.
- `6563c2e` moves the read before the second run. The watchdog is unchanged.
- Not reproduced deterministically: delaying the stop by 3.2 s let the second run finish its
  write, and the old layout passed; the window is the one between two system calls, which a
  trace's stops widen.
- [hypothesis] This may also be the coverage trace's two unexplained reds of 2026-10-18 (two in
  about thirty runs); those runs did not name their check.

### 4.10 `scripts/trial-sco-decode.py` under the suite, `dcddb95` [verified]

Your script decodes a trial window's SCO requests at full width from both capture paths and
matches each kernel setup (`opcode 0x0428` or `0x043d`) against each path. The operator ran it by
hand; nothing had run it here. A section of its own now does, with `journalctl` and `btmon` as
stubs (the journal prints three setups; `btmon` prints, through the renderer, the fixture mapped
to each capture file; the capture path holds both setups' files, the trace path only the first).
Five checks: each setup against both paths, the Enhanced one NOT FOUND in the trace path; every
setup, its Command Status and its completion kept whole with addresses and device names
redacted; each chosen capture decoded once, with `--columns=200`; the same script without
`--columns=200` keeps nothing; only what lies inside the window is kept, and an empty path says
so. The script passed as it is; each check was seen red against a mutant of it.

Your other two scripts, `trial-close-now.sh` and `trial-snapshot.sh`, are not under test, and as
written cannot safely be: they run `bt-trial` under `env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin`,
which drops every seam and the suite's tripwire, so a test would meet the real journal and tools.
[recommendation] Retire both once the deploy lands, since they exist to work around the
installed 2026-09-18 closer; if they stay, they need a PATH and state seam first, which is your
decision.

### 4.11 RT4: the footprint watches the files the project installs, `d9de559` [verified]

The damage footprint watched the system's binaries and not where the project installs. The
2026-08-14 escape acted through an installed tool, and a test that wrote through to one, or to a
unit, a udev rule or the modprobe override, changed nothing the footprint saw. The setup now stats
each file `uninstall.sh` removes (its FILES list, 75 files, which an invariant keeps equal to
`install.sh`'s destinations), with its `.disabled` and `.pre-qca9377-bt-hang` siblings: size,
mtime, ctime and inode, wherever one exists. Named files, not a scan of directories, because the
access audit cannot follow `find`'s descriptor-relative reads, and every read should be one it
sees and the allow list names. Red first in this disposable container: a planted
`/usr/local/bin/bt-actions.pre-qca9377-bt-hang` failed the run by name, and nothing else did.

### 4.12 DS4: `devtools/status`, `c711e92` [verified]

With origin unreachable, the pushed row said "could not reach origin — cannot confirm" and the
summary under it "Repository: everything committed and pushed.", exit 0, the false all-clear the
tool was written against, one line lower; the suite's check excluded only the ✓ row and passed.
A branch origin never had gave the same. `ls-remote --exit-code` now tells them apart: 2 (the
remote answered, without the branch) is "origin has no branch <b> — never pushed", exit 1; no
answer is "push NOT confirmed", exit 3. Red first, both. No caller reads its exit status.

### 4.13 RT7, RT2, the comments, RT3

- `14a7485` RT7: an invariant counts scans of `tests/run-tests` by its literal name; the parallel
  runner's two reads of section boundaries are the only ones allowed. The contract-tag scan, the
  third, now reads every suite file, and still catches a planted stray tag.
- `bf07959` RT2: the suite read `results.tsv` columns by position, the thing it forbids every
  consumer. Measured first: `bt-trial` writing one harmless extra column turned 21 checks red,
  nearly all naming the wrong field. `tsv_cells` in the setup reads cells by header name (and
  prints `?no-column:<name>` for a missing one); every positional read uses it; after, with the
  same extra column, everything holds.
- `0fb90ad` RT1 (the suite's header said 9,700 lines), RT6 (the `bt-diagnose` comment's stock-era
  model; the assertions test the stock-kernel answer, as before), RS3 (the held-branch rule's
  reason, as BRIEF §7 now gives it).
- `a28ba03` **RT3, for you.** The whole-boot invariant named one spelling, `bt_journal -k -b 0`,
  and eight of the review's findings sat under it, green. A scan now reads every tool (`tools/`,
  `bin/`, `install.sh`, `uninstall.sh`), joins continuation lines, and reports each journal read
  that names a boot or passes an argument array and is bounded by none of `--grep`, `-n`,
  `--since`, `--until`, `-p` or a `| head`. It finds 41 reads in 21 files: your BB1, DG2, HR2,
  BS-1, PM2, LV3, AX3 and CX2 among them, and `install.sh`'s two (the `--apply` paths). Which of
  them are whole by design (an export, a snapshot of a boot) is a decision about each tool, so
  `tests/whole-boot-reads.txt` lists all 41 as "pending": bound a read and delete its line, or
  write its reason there. A read not in the list fails, and so does a listed read the tools no
  longer make.
- UD1 and RT5 were already closed by `3ed9dc4` (the uninstall dry run staged; `verify-restored`'s
  clean-machine case runs on every host).

### 4.14 The audit's seven reds, `0189fee` [verified]

From `d9de559` to `a28ba03` the audit was red on every commit, each time on one line: "STALE allow
entry: read /usr/local/bin/lib/* — nothing in this run matched it". RT4's footprint does stat
those files, but the classifier classes a name under `/usr/local/bin` that is not a project
tool's as host software before it consults the list, so that line could never match. Removed,
with a note saying why. `checks.yml` stayed green throughout, as the split intended. A full audit
here afterwards: nothing outside the allow list, every check holding under the trace. My
mistake: I relied on CI for the audit of a change to the audited reads; I should have run the
full audit locally before pushing, as I did after.

### 4.15 The fast-forwards and merges

The ready line moved `63e9ecc` → `98af393` → `11c8039` → `64530ee` → `0189fee` → `022a1ec`, each
time to a commit green on CI that contains `main`. The working branch merged it at `b761a00`,
`118352e` and `9e56eb9`.

## 5. The laptop, and what the deploy will change

Nothing was installed or changed on the laptop. The deploy is yours and the operator's, after
`main` takes the ready line; its procedure is `docs/install.md` (on the investigation machine:
`sudo ./install.sh --tools-only` typed exactly, with plain `sudo`; then `daemon-reload`,
`bt-verify-install`, `bt-mode status`).

What the deploy changes, as I expect it [hypothesis where not run]:
- `bt-trace`'s live `btmon` runs at 200 columns: BT-4's aborts on `bluetoothctl` opens should stop;
  the next trial's `btmon_aborts` will say.
- The close's SCO decode keeps records for the first time: `sco-params.txt` will hold the
  window's setups instead of the fallback line, Enhanced ones included.
- `--tools-only` prints no `modprobe` line and reads no journal at the end.
- The tools' trace, capture and usbmon directories come from `BT_HEALTH_DIR`, whose default is
  the same `/var/log/bt-health`: no change on the laptop.
- The daemons' idle sleep goes with them on a stop outside systemd.

What still wants care on deploy day:
- the verifier's `Run: sudo ./install.sh --apply` on drift (VI1) and `devtools/status`'s `sudo
  ./install.sh --apply` remedy (DS1): the operator must not follow either;
- `bt-mode status`'s doubled `inactive` (MODE2), cosmetic;
- the tools with whole-boot reads (§4.13): on a days-old boot with dynamic debug, some take
  minutes.

## 6. Lessons this work keeps relearning, kept here so they need not be relearned

- **Red first, every time, and red for the right reason.** A check that has never failed proves
  only that it ran. Today's examples: the Enhanced close check that passed on inherited state; the
  DS4 check that excluded the ✓ row and not the summary under it.
- **Derived lists, never written by hand.** The footprint's targets come from `uninstall.sh`, the
  seam catalogue from the code, the whole-boot reads from a scan; where a decision is needed, the
  list records the decision (`tests/whole-boot-reads.txt`), not the absence of a check.
- **One finding, then its siblings.** The btmon width was seven call sites by your count and
  twelve by a sweep; the whole-boot rule was one spelling and 41 reads.
- **An instrument that fails must say what failed.** The audit's red cost a guess until it named
  its check, and then the check named the race.
- **Measured, not claimed, and marked as which.** The 16-core figure is a prediction, and it is
  written as one everywhere.
- **The checkout is shared with its suite.** Never edit a tracked file while the suite runs in
  it; `repo-save` stages everything (`git add -A`), so a note edited beside a code change goes in
  the same commit (it did, twice, harmlessly).
- **A worktree is not a checkout for the checkout world**, which therefore runs only in a full
  clone; the ready line's work today ran in one.
- **Exclusions move when lines above them move**: `devtools/coverage-exclude`'s ranges are
  re-derived by content after every edit above them, and the gate catches the ones that were not.

## 7. Yours: to land, to decide, to fix

1. **Land the ready line** `tests/unit-testing-introduction-ready-for-main` at `022a1ec`. The tool
   hunks for your review are named in each commit's message.
2. **VI1 and MODE2**: your fixes, with `2589dee`'s checks.
3. **`tests/whole-boot-reads.txt`**: 41 reads, each to bound or to give its reason.
4. **`sco_sent` and `0x043d`**, and `bt-actions`' naming of it [recommendation: count both].
5. **The two trial scripts** [recommendation: retire after the deploy].
6. **I2's second half**: the `--apply` path's whole-boot timeout counts (`install.sh`'s two
   listed reads) could use the `-p err` index, as `bt-trial` does.
7. **DS1, SR1, MODE1**: one advice wording everywhere (`--tools-only`, then `daemon-reload`,
   `bt-verify-install`, `bt-mode status`; never `--apply`, never `bt-mode mitigation`).
8. **BT-4's `bluetoothctl` reads**: possibly unnecessary after `--columns=200`; one trial decides.
9. **The 16-core measurement**, the operator's, at a hand close before a planned shutdown.

## 8. Open, and what I would do next

- `devtools/ci`'s 30-run limit (your item after `8ecf3fd`): not done. With two workflows each
  asked by name the limit is now per workflow, but a commit older than the last 30 runs of
  `checks.yml` is still "no run found".
- The coverage trace's two unexplained reds of 2026-10-18: possibly §4.9's race; the next one, if
  any, will name itself.
- The two longest units (held's and save's checkout worlds, about 20 s each) are the floor of a
  16-core run.
- UT-12, the split of `tests/run-tests` into parts: the scans are ready for it.
- The CI-only branches (`ci/deploy-rehearsal-red-checks-20261019`,
  `ci/deploy-rehearsal-red-installer-20261017`) can be deleted once you have read their runs.
- Your pinned tests as your fixes come (the reaction plan's table): each pinned test changes in
  the same commit as the fix it pins.

## 9. Appendix: the ready line since `8f1396f`, in order

| commit | what |
|---|---|
| `401e201` | merge of `main` `8f1396f` |
| `313e7b1` | the progress note opened: plan and log |
| `48118c3` | BT-4's abort reproduced; the width finding confirmed; `tests/btmon/real/` |
| `f5b2508` | `tests/btmon/render`, pinned to the real btmon's output |
| `9667943` | `btmon --columns` at twelve call sites; the stubs print as btmon does |
| `2f66306` | note: the width fix ready to land |
| `bf50fa4` | the Enhanced setup is a setup |
| `98af393` | `install.sh`: the reload block asks `--tools-only` itself |
| `30b6f31` | CK1: `devtools/check` with a trial open |
| `11c8039` | SU1: the rehearsal's last two steps; no whole-boot read |
| `ab74973` | `devtools/ci` asks the branch's own repository |
| `3ed9dc4` | the isolation measured by an exact trace; the audit's own workflow |
| `64530ee` | awk-coverage against a toy suite; floor 95 |
| `a2a4931` | the checkout world, four sections |
| `0326578` | the daemons' idle sleep on TERM |
| `38c313f` | the tooling index; the drift alarm both ways |
| `2fb4251` | the audit names a red run's failing checks |
| `da6e22e` | note: the series, the audit's one red |
| `dcddb95` | tests for `scripts/trial-sco-decode.py` |
| `d9de559` | RT4: the install-target footprint |
| `c711e92` | DS4: "push NOT confirmed", exit 3 |
| `6563c2e` | the watchdog test's race |
| `14a7485` | RT7 |
| `bf07959` | RT2: `results.tsv` by column name |
| `0fb90ad` | RT1, RT6, RS3 |
| `a28ba03` | RT3: `tests/whole-boot-reads.txt` |
| `0189fee` | the stale allow line |
| `aaa81ed` | note: item 4's findings |
| `022a1ec` | note: what is yours now |
