# Comprehensive project review: consistency across documents, registers, code and evidence

- **Started:** 2026-11-15T00:57Z (UTC)
- **Reviewed commit:** `da23558` (branch tip at the start of the review)
- **Kind:** a review of the whole repository, with inconsistencies as the first interest.
- **State of this file:** complete. Findings were written down as they were found (section 3),
  in the order of the review; the summary (section 4) was written last.

## 1. Plan

### 1.1 What was measured before reading

Tracked files: 7,046, about 140 MB (roughly 35 million tokens at 4 bytes per token). That is
far more than one reader can hold, so the review is split.

| part | files | bytes | what it is |
|---|---|---|---|
| root (`README.md`, `BRIEF.md`, `HISTORY.md`, `install.sh`, `uninstall.sh`) | 7 | 0.58 MB | foundation documents, installer |
| `docs/` | 107 | 1.6 MB | registers (`STATUS.md`, `issues.md`), plans, drafts |
| `contributions/` | 3,862 | 82 MB (2.7 MB of it Markdown) | one dossier per possible contribution; the rest is logs and run output |
| `results/` | 1,496 | 36 MB | dated run results |
| `evidence/` | 530 | 8.2 MB | exhibits, sessions, trials |
| `reviews/` | 107 | 4.0 MB | earlier assessments and their register |
| `retest/` | 186 | 2.7 MB | the mesh_tx leak retest |
| `patches/` | 175 | 1.4 MB | patches as sent, their notes |
| `tests/` | 244 | 1.1 MB | the suite and its fixtures |
| `scripts/`, `tools/`, `bin/`, `devtools/` | 236 | 1.5 MB | shell, awk and Python |
| `comms/`, `lessons/`, `systemd/`, `etc/`, `.github/` | 96 | 0.5 MB | messages, lessons, units, CI |

### 1.2 Who reads what

- **Read in full by the lead reviewer:** `README.md`, `BRIEF.md`, `docs/STATUS.md`,
  `docs/issues.md` (the issue register), `contributions/README.md` (the contribution
  register), `contributions/rd-2026-11-14.md`, `reviews/README.md` (the action register).
- **Read by worker reviewers, each with one bounded part and a written checklist:** the shell,
  awk and Python source; the test suite; `HISTORY.md`; the exhibits index against the
  exhibits; the dossiers under `contributions/`; `patches/`; `docs/` other than the
  registers; `comms/`, `lessons/`; CI and systemd units.
- **Not read line by line:** raw logs, captures, VM output and other machine-produced files
  (about 130 MB). They are checked only where a document quotes a number from them.

Worker findings are leads until the lead reviewer has checked them on the file; each finding
below says whether it was checked.

### 1.3 What the review looks for

1. **Facts stated in more than one place that disagree**: dates, version numbers, commit ids,
   counts (links, timeouts, exhibits, commits, stable lines), patchwork ids, states
   ("sent", "ready", "applied", "released") between `README.md`, `BRIEF.md`,
   `docs/STATUS.md`, `docs/issues.md`, `contributions/README.md`, each dossier and
   `HISTORY.md`.
2. **Stale text**: a section dated earlier than a later fact that contradicts it, with no
   note; "current" blocks that are no longer current.
3. **Register integrity**: every `BT-n`, `U-n`, `CO-nn`, `EX-nnn` referenced exists;
   every dossier directory has a register row and the reverse; numbering gaps explained;
   status of the same item equal in every register.
4. **Broken references**: paths, scripts, sections and anchors named in documents that do not
   exist in the tree; tools listed in `docs/tooling-index.md` that are missing, and tools
   present that are not listed.
5. **Rules against practice**: the rules in `BRIEF.md` §7, §8, §8a and the README's "Method"
   against what the tree shows (elided identifiers, claims without commands, a zero without a
   positive control, labels such as `BT-1` in stranger-facing files, privacy rules).
6. **Code**: defects in the shell, awk and Python (error handling, quoting, `set -e` and
   pipefail traps, exit codes against the documented contract, unsafe actions against the
   documented machine constraints), documentation that describes behaviour the code does not
   have, install and uninstall symmetry, units against the scripts they start.
7. **Tests**: checks that cannot fail, tests that do not test what their name says, fixtures
   that contradict the seam rules, coverage claims against the files.
8. **Patches and send packages**: the patch as filed against what the documents say about it
   (subject, trailers, base, version), a package said to be ready with files missing.
9. **Privacy and publication**: real device addresses, BSSIDs, key material, private mail
   addresses or host paths that the project's own rules say must not be here.

### 1.4 Severity used below

- **High**: a wrong statement a reader would act on (a wrong state of a submission, a wrong
  safety instruction, a defect that loses evidence or touches the controller).
- **Medium**: two places disagree and one of them is wrong; a broken reference on a main route.
- **Low**: stale wording, cosmetic drift, a note that is missing.

## 2. Progress log

1. Plan written; `README.md` and `BRIEF.md` read in full (3.1).
2. Tree-wide scan for wording about the working arrangement (3.2).
3. Twenty worker reviewers started, one bounded part each, each writing its findings to its
   own file as it went.
4. `docs/STATUS.md` read (3.3, 3.5); worker reports written into 3.4 as they arrived, the
   highest-rated claims re-read on the files first.
5. Three of the same workers given a second task: `docs/issues.md` against STATUS (3.7).
6. Mechanical checks over the tree (3.6); summary written (4).
7. Finished 2026-11-15T01:14Z. No file other than this report and its companion was changed.

## 3. Findings, in the order found

### 3.1 Foundation documents: `README.md` against `BRIEF.md` (lead reviewer, read in full)

**F-01 (Medium, stale): `README.md` describes the machine as it was before 2026-11-12.**
`README.md:148` is headed "Current direction — 2026-11-12" and `README.md:161-162` says
"Until it is installed the laptop runs the entry as a self-built `btusb`, rebuilt before any
new kernel boots"; the Environment block (`README.md:199-202`) ends at "7.0.0-42-generic with
E3 and the stock bluetooth.ko since 2026-10-30". `BRIEF.md:120-123` says the laptop runs
Ubuntu `7.0.0-43` with the stock btusb since 2026-11-12 22:55 and "E3 is retired". The
README's own text at `README.md:141-143` already knows `-43` is published. The public page
is two days behind the hand-off on the one fact its "QCA9377 result" section is about.

**F-02 (Medium, stale): the start-up failure count.** `README.md:163-166`: "Twice (boots of
2026-11-05 and 11-11)". `BRIEF.md:229`: "BT-16 (third occurrence 11-13 on `-43` stock)". The
third occurrence is also the first on the stock driver, which matters for the README's
heading "A start-up failure on the fixed driver".

**F-03 (Medium, stale): the README's list of next candidates is shorter than the hand-off.**
`README.md:173-180` names CO-35, CO-04, CO-05, CO-22, CO-37, CO-38 and CO-11 as having "send
packages ready". `BRIEF.md:183-191` (2026-11-14) adds CO-44, CO-43 (E and A), CO-21, CO-20 and
CO-02 v2, and names CO-05 together with CO-26. The README does not mention CO-43 or CO-44 at
all.

**F-04 (Low, wording): "the four BlueZ fixes are in code every Linux Bluetooth adapter
runs"** (`README.md:46-47`). The opening (`README.md:13`) counts "four fixes, two cleanups,
and five test or emulator changes". The only way to reach four fixes from the table is
`a734b06059cb`, `0bed9886cff3`, `ae23df052290` and `8da7e648a9fb`; the last is
`emulator: Free hooks in btdev_destroy`, which no adapter runs. Either the count of fixes in
daemon code is three, or the sentence should say which four.

**F-05 (Low, stale): the repository map's line for `results/`** (`README.md:255-256`: "the
list's CI run locally; the L2CAP hang sweep") describes 2 of the 18 entries now in
`results/`.

**F-06 (Medium, contradiction inside `BRIEF.md`): the raw-capture archive budget.**
`BRIEF.md:424` (§7, the durable rules): "`archive/bt-trace/` (git-ignored, 10 GB budget,
never deletes)" and `BRIEF.md:462`: "(`archive/`, up to 10 GB)". `BRIEF.md:113` and
`BRIEF.md:144`: restarted "with a 20 GB budget", and the desktop capture archive raised to
10 GB and then 20 GB. §7 is the section the file calls "the DURABLE copy"; it carries the
older figure.

**F-07 (Medium, stale block presented under a current date): "The state at a glance".**
`BRIEF.md:79` dates the block "2026-10-28; machine lines 2026-10-30", while `BRIEF.md:151`
says "Last updated: 2026-11-14". Inside the block, still in the present tense:
- `BRIEF.md:98-105` "Waiting for replies (re-checked 2026-10-28)": "Stable: 6.1, 5.15 and
  5.10 are still at their 10-17 rc1 … CO-28 waits"; all three were released on 10-30
  (`BRIEF.md:82`, same block).
- `BRIEF.md:107` "Operator decisions open": the `7.0.0-42` item (whether to install the
  CO-02 module on `-42`); the machine left `-42` on 11-12.
- `BRIEF.md:109` "sends": CO-35 as "7.3.y + 7.2.y request and three backport series"; the
  hand-off (`BRIEF.md:186`) names `send-20261114/` on "stable tips of 11-14".
- `BRIEF.md:112`: CO-03 "waits for the operator's word to install"; the hand-off
  (`BRIEF.md:181-182`) says it is staged on disk since 11-13.
- `BRIEF.md:145` "Open investigations" names BT-11; the hand-off's newer BT-16, BT-17, BT-24
  and BT-25 are not in the block.
The file's own rule (`BRIEF.md:18-20`) is "One hand-off block, not a stack … replaced, not
topped up"; the state block has become the second stack, amended in place by dated
insertions (11-02, 11-12) inside 10-28 sentences.

**F-08 (Low, contradiction inside `BRIEF.md`): one survival or two.** `BRIEF.md:320`:
"Correlation across 12 deaths / 1 survival (§2 …)", and the table's survival row
(`BRIEF.md:275`) is the 09-01 link with 8 packets. `BRIEF.md:308-311` records a second link
on alt 1 that survived: `EX-031`, "a transparent (wideband) link on alt 1 … that ran ~17 min
and survived". §2 does not list it and §4 does not count it.

**F-09 (Low, arithmetic, to check against `patches/bluez/`): the bot's answer time.**
`BRIEF.md:358`: v1 sent "09-19 18:44" UTC. `BRIEF.md:375`: "The list's CI bot answered both
v1 mails within 90 min (09-19 22:05/22:10 UTC)". From 18:44 to 22:05 is 3 h 21 min. One of
the three figures is wrong, or two of them are in different time zones.

**F-10 (Low, stale): "answered in all 5 alt-1 instances"** (`BRIEF.md:333`, the retraction
table) was written when five instances existed; the count is twelve (§2). The row is a
retraction and may be kept as written, but nothing marks the 5 as historical, unlike
`BRIEF.md:320` ("'7' when this was written").

**F-11 (Low, rule against practice): the hand-off's procedures depend on files outside the
repository.** `BRIEF.md:211` ("run `tmp/port-check/check.sh <dir>`"), `BRIEF.md:536`
(`tmp/bt9-repro/ratatoskr-scan.py`, in the list of "tools we forget") and `BRIEF.md:205`
(`/root/exp/agent-work/lane<N>-*-20261114/`) point at git-ignored or machine-local paths.
`BRIEF.md:459` says "Nothing we write exists only on this disk". A reader of a fresh clone
cannot follow these steps.

**F-12 (Privacy, High for the author's stated concern; needs a tree-wide scan): wording
that describes the working arrangement.** `BRIEF.md:205` names a directory
`/root/exp/agent-work/lane<N>-…`; `BRIEF.md:158-159` says "the agents bullet ended";
`BRIEF.md:176-177`, `205-209` speak of "five work lanes" whose "results are leads until
checked on copy". `BRIEF.md:8-9` says working habits are "kept outside this repository".
A tree-wide scan for such wording is in section 3.2.

**F-13 (Low, layout): footnote ² of the signature table is printed above the table**
(`BRIEF.md:255`), before the heading's code block, while footnote ¹ is below it
(`BRIEF.md:277`).

Checked and found consistent between the two files: the 58 + 16 = 74 links; the seven stable
releases of `dc16388d45ec` and their dates; the five stable releases of `86ef0f58bdec`; the
eleven BlueZ commit ids; CO-02's send date; the three BT-9 backport releases; "thirty-eight
days" (2026-08-14 to 2026-09-21); v2 "6.5 h" after the merge (14:10 to 20:47 UTC).

### 3.2 Wording and paths that describe how the work is done (lead reviewer, tree-wide scan)

The author treats the working arrangement as private (`BRIEF.md:8-9`: working habits are
"kept outside this repository"; `BRIEF.md:476-478`: "working-session material that is not
project content"; `contributions/CO-25-qualcomm-rom-report/log.md:68` records the check "No AI
tool names" before a send). The scan below was made with `git grep -I` over tracked files.
Names of products are not repeated here; the lines are given so they can be read in place.

**P-01 (High, privacy): the work-area path `/root/exp/agent-work/…` is in 2,716 tracked
files, 11,068 lines.** Command: `git grep -l -I 'agent-work' | wc -l` → `2716`;
`git grep -I -c 'agent-work' | awk -F: '{s+=$2} END{print s}'` → `11068`. Most are build and
run logs under `contributions/CO-04-…` (686 files), `contributions/CO-05-…` (682),
`results/bt17-emulation-2026-11-13` (172), `results/laptop-only-work-2026-11-11` (114); but
the path is also in authored text and scripts: `BRIEF.md:205`, `HISTORY.md:5264`, `5378`,
`5538`, `5599`, `contributions/CO-02-…/log.md:870`, `904`, `958`,
`contributions/CO-02-…/send-v2-20261114/CHECKS.md:3`, every script under
`contributions/CO-02-…/send-v2-review-fixes-20261114/scripts/` (`W=/root/exp/agent-work/lane7-sco-20261114`),
`contributions/CO-04-…/send-20261114/README.md:3`, `contributions/CO-05-…/send-20261114/mk-cover.py:3-10`,
`contributions/CO-07-…/build-20261114/README.md:4`. The directory name says what kind of
worker used it, and the `lane<N>` suffix says how many ran in parallel. `BRIEF.md:212-216`
lists what to leave in the work area when porting (addresses, other people's packaging); the
work area's own name is not on that list, and `devtools/repo-scan` does not refuse it.

**P-02 (High, privacy): the same arrangement in plain words.**
- `HISTORY.md:5378`: "Both agents FINISHED and ported (worktrees under …)"; `HISTORY.md:5395`:
  "the coordinator's"; `HISTORY.md:5580` and `contributions/CO-11-…/log.md:139`: "an agent
  asked to reproduce U28 was stopped …".
- `BRIEF.md:158-159`: "the agents bullet ended"; `BRIEF.md:113`: "the coordinator's choice";
  `BRIEF.md:176-177`, `205-209`: "the five work lanes", "Lanes still running at this writing".
- `contributions/CO-05-…/experiments/results-2026-10-29.md:5`: "worker's `tmp/mesh/`".
- A tracked directory is named
  `contributions/CO-43-…/experiments/instrumentation-lane1-20261114/`.
- "worker" or "workers" appears in 48 authored files; "lane N" or "work lanes" in 20; "coordinator" in 6.

**P-03 (High, privacy): product names and tool-specific paths.**
- `contributions/CO-25-qualcomm-rom-report/log.md:273`: the names of two settings files of a
  coding assistant, with their directories; `log.md:275`: "`<session transcript>`" and "15
  distinct app passwords in the transcript".
- `scripts/user-audio-streams.sh:11` and `docs/STATUS.md:109` (U21): a microphone indicator
  and a browser tab "labelled" with an assistant's product name.
- `reviews/2026-10-28T0300Z-documentation-alignment.md:33` (row D10): quotes the two strings
  that the same review removed from `BRIEF.md` and `docs/issues.md` ("four … workers", a
  rules-file name), so the removal left them in the tree one directory away.
- `contributions/review-2026-11-02/build/build.py:27-30` and `followups-build.py:13`: the list
  of forbidden words itself (assistant names, the words for the workers and their directory, and a word
  for the shortening of a long conversation). A filter that names what it hides, committed
  next to its output, tells a reader what was hidden.
- Not findings: "Sashiko", the kernel list's automated reviewer (`BRIEF.md:746`,
  `patches/kernel/README.md:94`, `reviews/README.md:69` and others), is an upstream fact; and
  `contributions/CO-37-…/work/review-20261101/results/facts.txt:189-195` quotes an upstream
  security policy.

**P-04 (Medium, security hygiene, needs the author's check): `contributions/CO-25-…/log.md:272-277`**
records that app passwords were present in a session transcript ("15 distinct app passwords")
and that the one used was "Revoked". The text does not say that all fifteen were revoked.

Why this is one finding and not many: the guard against such wording exists only where a
person remembered it (the CO-25 send, the review-round builder, the 10-28 documentation
review). The save path (`devtools/save`, `devtools/repo-scan`) is to be checked by the
`devtools/` reader for whether it refuses any of these strings; see G-02 for the result.

### 3.3 `docs/STATUS.md`, submissions and issue rows (lead reviewer, lines 1–181 read in full)

**S-01 (High, stale across every register): the hand-off and the registers do not know the
last five commits of 2026-11-14.** `BRIEF.md` was last changed at 09:01 (+0100) on 11-14
(`git log -1 -- BRIEF.md` → `13ceedc`), `contributions/rd-2026-11-14.md` and
`contributions/README.md` at 13:23 (`29a9ba5`), `README.md` on 11-13. After that, commits
`589d9a9` (14:59), `f9fd185` (15:43), `f84f686` (16:30) and `da23558` (22:00) answered the
outside review of that day and added, beside the packages the hand-off calls "ready to send":
- `contributions/CO-02-…/send-v2-review-fixes-20261114/` (two layouts of the series, reworded
  mails, the stable line changed from "6.18.y and 7.2.y" to "6.18.y and 7.3.y");
- `contributions/CO-04-…/review-fixes-20261114/`, `contributions/CO-05-…/review-fixes-20261114/`;
- `contributions/CO-21-…/review-fixes-20261114/` (a new cover letter and two patches);
- `contributions/CO-35-…/review-fixes-20261114/` (with its own `NOTES-FOR-OPERATOR.md`).
`grep -c review-fixes` gives 0 for `BRIEF.md`, `README.md`, `docs/STATUS.md`,
`contributions/README.md` and `contributions/rd-2026-11-14.md`. Only
`reviews/2026-11-14T0300Z-…` and `reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md`
name them. `BRIEF.md:183-191` therefore sends the operator to `send-20261114/` and
`send-v2-20261114/`, which are no longer the newest text of five packages, and none of the
older directories is marked superseded. For someone about to send, this is the most
dangerous inconsistency found so far. (Found by the CO-02 reader for CO-02; extended to the
other four and checked by the lead reviewer.)

**S-02 (Medium, contradiction inside one row): `docs/STATUS.md:67` (BT-9).** The state cell
says "**not yet released for 6.1** (in 6.1.191-rc1, 2026-10-17, still open on 2026-10-28 …)";
the next cell of the same row says "released in 6.6.160 (2026-10-21) and 6.1.191
(2026-10-30) … done (corrected 2026-11-12 …)". The 11-12 correction was applied to one cell.

**S-03 (Medium, stale): `docs/STATUS.md:59` (BT-1), the "next" cell.** "those four releases
(still at their 10-17 rc1 on 2026-10-28) … **no boot into `-42` without E3 built for it** …
more headsets on E3 meanwhile". The state cell of the same row was corrected on 11-12; the
laptop has run `-43` with the stock driver since 11-12 22:55 (`BRIEF.md:120-123`). The
"Laptop-only work" block at `docs/STATUS.md:170` also still ends "not installed; E3 ends when
it is installed".

**S-04 (Medium, stale): `docs/STATUS.md:68` (BT-10 / CO-35).** The last dated entry is
2026-11-02 ("send package written 2026-10-28 (CO-35 `send/`)", "the request becomes 7.3.y
only"). The hand-off names `send-20261114/` on the stable tips of 11-14, `BRIEF.md:109` still
says "7.3.y + 7.2.y request", and a `review-fixes-20261114/` exists (S-01). Three documents,
three states of the same package.

**S-05 (Low, label): `docs/STATUS.md:74` (BT-16).** Issue cell: "At three boots"; component
cell: "with E3 on `7.0.0-42`"; state cell: "**observed twice** … **Third, 2026-11-13** … on
`7.0.0-43` with the **stock** btusb". The bold state and the component were not updated when
the third was added; `README.md:163` says "Twice" (F-02; also reported by the reader of
`results/`, with `docs/issues.md:1003` "3 occurrences now").

**S-06 (Medium, path): the follow-ups file has two addresses.** `docs/STATUS.md:39` (CO-02):
"decisions D1/D2 in the review follow-ups (`tmp/review-doc-20261102/followups.md`)", a
git-ignored path. `BRIEF.md:108`, `225`: `contributions/review-2026-11-02/followups.md`.
Related (CO-02 reader, Low): `BRIEF.md:226` glosses "D1/D2" as the error-code choice, while
in `followups.md:27-28` D1 is the timing and the label and only D2 is the error code.

**S-07 (Low, contradiction): when the raw-capture archiver stopped.** `docs/STATUS.md:140-141`:
"has been stopped since 10-13". `BRIEF.md:144`: "Paused from 2026-10-11 to 10-29".
`docs/STATUS.md:151`: "bt-trace: 10, the operator's figure of 10-11" for the budget that
`BRIEF.md:113` gives as 20 GB since 10-29 (F-06).

**S-08 (Low, stale): `docs/STATUS.md:96` (U8).** "a btusb debug patch is written, installable
only after trial E3 #1 closes". E3 #1 was closed by hand on 2026-10-18 (`BRIEF.md:127`) and
E3 itself is retired.

**S-09 (Low, order): the mesh rows are in the order M-1, M-4, M-5, M-3, M-2**
(`docs/STATUS.md:84-88`).

**S-10 (Medium, rule against practice): identifiers are elided in the registers and in the
file that forbids it.** The rule, `BRIEF.md:486-488`: "Write identifiers in full — branch
names, paths, boot ids. Never `…`". Instances: `docs/STATUS.md:37` (`contributions/CO-25-…/send/report.eml`,
"SHA-256 `1f81392a…cbf7`"), `:39` (`contributions/CO-02-…/patch/v7-candidate/send/`), `:52`
(`655b5286…2abc`), `:71`, `:76`, `:78`, `:79`, `:85`, `:86` (`CO-43-…/`, `CO-44-…/`,
`CO-14-…/`, `CO-04-…/`), `:95` (boot `257d1599…`), `:120` (`36175938…`); `README.md:157`
(`contributions/CO-02-…`); and in `BRIEF.md` itself: `:255` (`66D38200…`), `:730`
(`reviews/2026-09-21T0900Z-…`), `:740` (`reviews/2026-09-22T1700Z-…`), `:670`
(`comms/2026-10-19T0504Z-…`), `:803` (`815e7378…b90b72`). A hash cut in the middle cannot be
compared, which is the reason the rule gives.

**S-11 (privacy, adds to P-01/P-02):** `docs/STATUS.md:114` and `:115` cite evidence at
`agent-work/u25-settle-20261101/runs/q1-*` and `agent-work/co37-release-20261102/`;
`docs/STATUS.md:103` (U15) says "no tool-written MR text"; `docs/STATUS.md:109` (U21) says
"the operator's screenshot (in the session, not saved)" and "stopped the dictation in the
session window"; `docs/STATUS.md:152-153` says "the session-start hook prints a ⚠️ … so the
warning reaches every session". Each tells a reader what kind of session it is. Also local
home paths: `/home/i/` in `docs/ui-capture-research.md:244` and
`results/laptop-only-work-2026-11-11/headset-session/SESSION-CHECKLIST.md:77` (35 lines), and
`/root/exp/` in about 4,670 lines of 612 files under `docs/` and `results/` (reader of
`docs/`, counts not rechecked).

Checked and consistent in the submission rows: every send date, Message-ID and patchwork id
against `README.md` and `BRIEF.md`; "eight BlueZ rows" released in 5.88 (eight rows carry the
note); 228 + 3 + 2 = 233 leaked allocations; the stable commit ids per line.

### 3.4 Worker reports received so far (leads; "checked" where the lead reviewer re-read)

**T-01 (High, code defect, checked): `tools/bt-sco --window` with no value never returns.**
`tools/bt-sco:44-49`: `--window) WINDOW="${2:-2}"; shift 2 ;;` inside `while (( $# ))`, with
`set -uo pipefail` and no `-e` (`:33`). When `--window` is the last argument, `shift 2` fails,
`$#` stays 1 and the loop spins. Reproduced with the same loop in a scratch shell (prints
`LOOPS`). `docs/tooling-index.md:84` documents exactly the bare form `tools/bt-sco --window`.
The same shape, a two-word option as the last argument, is in `tools/bt-actions:68-72`,
`tools/bt-capdiff:60-64`, `tools/bt-context:41-44`, `tools/bt-logvolume:44-48`,
`tools/bt-phase:67-70`; `tools/bt-stage2` guards it with `|| exit 2`.

**T-02 (Medium, stale comment, checked): `tools/bt-window:8-11`** says "`bt-status` and
`bt-state` run `hciconfig <dev> name`". Both are probe-free since 09-18 (`BRIEF.md:469-470`);
the worker found `hciconfig`/`btmgmt` only under `--probe`. A reader of this header would
conclude the opposite of the safety rule.

**T-03 (Medium, exit contract, likely): `tools/bt-diagnose`** with no readable boot prints
"not observed" and exits 0; `README.md:119-120` promises 2 for "cannot determine". This is the
project's own rule "`ENUMERATED == 0` is a refusal" (`BRIEF.md:586-589`).

**T-04 (Medium, overstatement): `README.md:132-133` "every tool takes `BT_VID`/`BT_PID`".**
21 of 28 tools never read either; `tools/bt-status` hard-codes the `13d3:3503` default.

**T-05 (Medium): `docs/tooling-index.md` lists git-ignored paths as tools** (`:86`
`tmp/raw-archive-timer/install-timer.sh`, `:126-134`, `:151` `cache/…`, `tmp/…`) and omits 15
executables: `devtools/access-classify`, `devtools/assert-test-catches`, and in `scripts/`
`dbg-autostop-calls.sh`, `exhibit-relabel-boot-id.py`, `export-kernel-review.sh`,
`patch-id-compare.sh`, `prove-ci-cwd.sh`, `prove-ci-stub.sh`, `prove-dr-followup.sh`,
`prove-dr-review.sh`, `prove-neg-search.sh`, `r2-checks-2.sh`, `r2-checks.sh`,
`suite-timing.sh`, `uncovered-code-report.py`.

**T-06 (Low): help text.** `tools/bt-sco -h` prints lines 2–26 and omits `--window`;
`tools/bt-incident --help` cuts its header one line short; `bt-incident` skips the timeline
silently when `bt-timeline` is not on the PATH. `tools/sanitize-logs.sh` matches the README's
claim; not covered by it: IPv6, `aabb.ccdd.eeff` and bare 12-hex addresses, and its verifier
exempts any `aa:bb:cc:00:00:NN`.

**T-07 (Medium, test defects, `tests/run-tests` lines 5200–10400):**
- `:7572-7575` the bt-capdiff window check matches `*"agree"*`, which the tool's own title
  "Capture path agreement" (`tools/bt-capdiff:117`) always satisfies, and so does "coverage
  question, not agreement", the case the comment says it excludes: the check cannot fail.
- `:7846/7857`, `:7914/7925` "evidence/sessions untouched": `BT_EVIDENCE_REPO` points at the
  declared machine for the whole run (`:543`), so a leak would be written there and these
  checks look in the checkout; they cannot go red.
- `:10280` `! grep -q -- '--replace' calls.log` passes if `calls.log` was never created.
- `:5408`, `:5465`, `:7788` glob assertions satisfied by any later digit; the comment at
  `:5405` says this flaw was fixed once.
- `tests/README.md:64-65` (rule 4) says every spelled-out `tools/bt-trial <verb>` call fails
  the guard; the guard (`:15144/15147`) covers six verbs, and `:9541` (`audit --help`) and
  `:5503` (`report`) are outside it.
- `:8034` and `:8494` share one description; `:9459-9499` build a fixture from the real
  `evidence/trials/results.tsv`; comments at `:6318`, `:6347`/`:6391`, `:6486`, `:9561` are stale.
Clean there: wrappers set both variables, no real-looking fixture data, PARALLEL markers.

**C-01 (Medium, CO-02 dossier, partly checked):** the dossier `README.md:3-12` (state
2026-11-12) and `log.md` (ends 2026-11-02) predate the v2 package; the dossier README keeps
the reading "a bot sweep, not a review" that `docs/STATUS.md:39` corrected on 11-13, and so
does `README.md:154-155`. In `send-v2-20261114/`, `sha256sum -c SHA256SUMS` reports 64 lines
that are not OK (checked): log files listed and not committed, and `CHECKS.md` and
`NOTES-FOR-OPERATOR.md` changed after the sums; `NOTES-FOR-OPERATOR.md` cites
`logs/run-l2cap-p123-1.log` and `-3.log`, which are not in the tree, and refers to "the task
brief". The dossier `README.md:10` links `reviews/2026-11-12T1508Z-…md` relative to the
dossier, where no such file is. Exhibit ranges differ: EX-067…EX-074 (`docs/STATUS.md:95`)
and "EX-067 to EX-073" (`log.md:451`); the laptop run is "10-23 to 10-25" in the dossier and
"10-23 to 10-29" in `README.md:156`. Consistent: the send record, both Message-IDs, the
SHA-256 of all five sent files against `docs/sent-mails.tsv`, tags, no Signed-off-by on v2.

**D-01 (Medium, `docs/` and `results/`):** `docs/external-cache.md:27-31` places the cache at
`/var/cache/bt-investigation/`, while `BRIEF.md:460-464` and `.gitignore` use `cache/` in the
checkout; the manifest names `bluez/` where the clone is `cache/bluez-upstream`, and
`docs/external-cache-manifest.tsv` row 4 has a commit id in the SHA-256 column and `22M` in
the bytes column, row 3 an elided hash. `docs/source-map.md` and `docs/source-access.md`
describe 2026-08-23 ("GNOME rows are blind", git.kernel.org refused) without a date label,
and nothing links to them. `results/bluez-5.88-release-check-2026-11-07/README.md` claims a
5.87 control ("11 lines, each NOT in 5.87") whose output is not in the directory, and
`BRIEF.md:353` and `README.md:52` rest on it. `docs/mesh-tester-ci/README.md` does not list
`instrumentation-from-cache-20261114/`. The Tested-by mail pins commit `ccfc358e2cd8…` of this
repository, which the 50-commit clone cannot confirm. Consistent: 159 VM logs; no broken
relative link in 75 files; no real-looking device address in `docs/` or `results/`.

**T-08 (High, evidence loss, checked): a journal prefix can be
replaced by a shorter archive.** `tools/bt-backup-journal:124-131` re-archives a boot whose
archive is marked a PREFIX ("re-archiving in full"), which calls `tools/bt-archive` with
`--replace`; `tools/bt-archive:288-290` then only refuses when the output exists and
`--replace` was not given. The worker found no comparison of the new export's record count
with the old one before the old file is replaced, while the header of `bt-backup-journal`
itself records (10-23) that a live boot loses its oldest journal files. If that has happened
by the time of the re-archive, the prefix was the only copy of the early records and the
"repair" shortens it. `bt-archive`'s usage text omits `--replace`. This is against
`BRIEF.md:414` ("Never lose code, tests or evidence. Priority 1"). Confirmed by
reading `tools/bt-archive:294-325`: the new export is checked only against itself (records
exported equal records read back, and more than zero), then `mv -f "$TMP" "$OUT"` replaces
the old archive; the old file's record count is never read.

**T-09 (Medium, code against `BRIEF.md`, `tools/bt-trial`):**
- `start` (`tools/bt-trial:351-359`, checked) does `mkdir -p "$dir"` and then
  `bt-state > "$dir/state-before.txt"` and `: > "$dir/steps.log"`: a reused directory is
  truncated. Only `autostart` (`:405-416`) renames an existing directory to
  `.unclosed-<stamp>`. `BRIEF.md:852-855` says the next boot's `bt-trial-auto` opens the same
  number "in the same directory, overwriting `state-before.txt` and `steps.log`": true of the
  installed tool, not of `main`'s code, and the text does not say which.
- `BRIEF.md:805-806` "`bt-trial` labels them `build=stock`": `autostart` now relabels from
  the btusb version suffix (`:238-246`, `:395-399`), so this holds only for a replaced
  `bluetooth.ko` or a btusb without a suffix.
- Probes: a manual `ok` runs `hciconfig name` twice (`:777`, `:937`), a manual `hang` once,
  `start` once (`:346`); `autostop` only with `BT_TRIAL_PROBE=1`. The manual verbs are
  interventions and the usage text does not say so.
- `hci_alive` returning 2 ("cannot tell", no `hciconfig`) is read as dead (`:121`, `:777`,
  `:937`): a manual `ok` on a machine without `hciconfig` records `trial_result=failed`.
- Reads of `journalctl -u …`, `-b -1 -n 400` and `--list-boots` on the close path (`:737`,
  `:900-925`, `:980`, `:1004`) have no timeout and run before the row (needs a measurement).
- The header says `abort` discards; it renames and keeps. Usage (`sed 2,18p`) omits
  `status`, `autostart`, `autostop`, `--discard`. The comment at `:880-882` says `bt-state`
  sends raw HCI (stale, as T-02); the header of `tools/bt-snapshot` says `autostop` probes at
  every shutdown (stale since 09-19).

**T-10 (Medium, a failed read counted as a clean result):**
- `tools/lib/trial-summary.awk` and `tools/lib/trial-sco-table.awk` count a row with
  `trial_result=failed` and `bt1_status=not_observed` as a survival, with no warning. Checked
  against the data: `evidence/trials/results.tsv:18-26`, nine of the eleven E3 rows are
  `not_observed` + `failed` (E-02 below).
- `tools/bt-trial-audit:215-223`: a failed or empty journal read gives `expect=none`, so the
  row "agrees".
- `tools/lib/journal.sh:262-285` (`bt_journal_kernel_fast`) drops per-file `journalctl` exit
  codes and skips unreadable files: a partial journal with exit 0.
These are three instances of the rule in `BRIEF.md:586-589`.

**T-11 (Medium): `tools/bt-exhibit new`** with `--claim`, `--why`, `--cmd` or `--boots` as the
last argument loops forever (the same defect as T-01; reproduced by the worker).
Low, same worker: `tools/bt-snapshot:177` hard-codes USB path `3-3`; `tools/bt-trial-audit`
calls its detectors independent of `bt-trial`'s while the regexes are identical;
`tools/bt-retention`'s closing note contradicts its header; `bt-trial abort --discard` runs
`rm -rf` on untracked evidence; `tools/bt-journal-files` has no inside-repository guard.

**E-01 (Medium, checked in part): the signature table's survival row.** `BRIEF.md:275` puts
"**8**" in the column `len 27 mtu 9`. The exhibits reader reports that `EX-037:14-23` gives
0 `len 27` frames for the 09-01 survival and that the 8 are `len 90 mtu 9` packets, and that
`EX-033:11-12` says "carries none". Also `BRIEF.md:271`: EX-042's "~90 ms" first-command
delay is not in EX-042 (nearest: "0x0428 answered +83.8 ms"). The other eleven rows agree
with their exhibits.

**E-02 (Medium, checked): `evidence/trials/results.tsv` against `BRIEF.md`.**
- `BRIEF.md:139-142` says E3 #3 "has **no row**". `results.tsv:18` is a row for E3 #3
  (2026-10-30 19:52, 1752 s, `failed`): a later trial that reused the number of the CO-02
  one. E3 #5 and E3 #11 were also opened twice (the reader; `docs/STATUS.md:180` knows #5).
- Rows 18–26 (E3 #3 to #11) read `failed`; only #3, #4 and #5 have a note saying this is the
  closer's artefact. #6 (`usb_lost` 82), #7, #8, #10 and #11 have none; with T-10 they are
  counted as survivals by the summary and look like failures to a reader of the file.
- Rows 16 and 17 (13 and 55 setups, 0 timeouts) match `BRIEF.md:127` and `:138`.

**E-03 (Medium): the exhibits index does not carry the exhibits' own corrections.** Marked
superseded or corrected in the exhibit and unmarked in `evidence/exhibits/README.md`:
EX-093 (its row still says "the controller is not involved"), EX-086, EX-007 (refuted),
EX-006 (superseded in part by EX-009), EX-058 (corrected 2026-10-29), EX-033 and EX-036
(corrected 2026-09-02). Only EX-018 and EX-020 are marked.

**E-04 (Low):** EX-043, the exhibit the argument leans on most, is the only one of 97 without
the `exit status` and `redacted` rows. EX-056's 7 links lie inside EX-058's boot `226965f1`,
so the 58 links are EX-058's alone (34 + 21 + 3), not a sum over "`EX-055`, `EX-056`,
`EX-058`" as `README.md:90` reads; EX-055 has no links. EX-057 says "all 16 hang-ups
answered" next to "Opcode 0x0406 failed: -107" (`:39-40`, needs a reading). EX-031 never
says "alt 1", which `BRIEF.md:309-310` attributes to it. `EX-038:42` has an elided command.
`evidence/README.md` omits `off-topic/` and lists 4 of 29 sessions. Consistent: 97 rows and
97 files, EX-041's four firings, EX-059, EX-061, EX-062, EX-023, EX-026, EX-046, EX-006,
`baseline.tsv` (287 timeouts, 13 of 34 boots); no real address, IP or key in `evidence/`.

**R-01 (Medium, contribution register; first item checked):**
- `BRIEF.md:183` says each ready package has `NOTES-FOR-OPERATOR.md`. None is in
  `contributions/CO-04-…/send-20261114/` or `contributions/CO-38-…/send-20261114/` (checked:
  they have `notes.txt` / `README.md` / `CHECKS.md`), nor for CO-05, CO-12, CO-22; CO-35's is
  in another directory; CO-02's later directory has `OPERATOR-NOTES.txt`.
- `contributions/README.md:83` (CO-37): U24's fix `7e3212fa233e` "(not released)"; the 11-14
  `CHECKS.md` and the Ubuntu bundle say it is in 5.88. `docs/STATUS.md:112` also says "in no
  release, the newest tag is 5.87".
- CO-03's content: the dossier `README.md:6`, `docs/STATUS.md:100` and `BRIEF.md:112` say
  `5.72-0ubuntu5.9~co03.1` carries the BT-7 fixes; `contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md:23`
  and `CHECKS.md:30` say the final candidate left them out.
- D1–D14 are all open in `contributions/review-2026-11-02/followups.md`, yet the register and
  the bundle build CO-37's backports into the one Ubuntu upload against D6's recommendation,
  recommend the CO-12 clamp against D5's, and the CO-02 notes cite D2 as support.
- Rows without a directory and without a pointer to their material: CO-29, CO-31, CO-32,
  CO-33. `contributions/README.md:122-123` says a dossier is opened "as soon as anything is
  written"; CO-22 is ready to send and has none.
- Stale rows against 11-14 results: CO-38, CO-39, CO-07 ("not built"; a `build-20261114/`
  exists), CO-34 ("release tracking"). `BRIEF.md`'s ready list omits CO-23, CO-37, CO-39,
  CO-41 and CO-12, which have 11-14 packages.
- `reviews/2026-11-13T0120Z-registers-and-contributions-status.md` says "All twelve" BlueZ
  commits; every other place says eleven.
- `docs/contributions-roadmap.md` §6 puts E3 first; `contributions/REVIEW-ROUND-2026-11-01.md`
  says the CO-12 fix is not in the repository. Neither is marked superseded.
Consistent: 46 rows, the same 46 in `rd-2026-11-14.md`, no directory without a row, no
undefined CO id in the foundation documents, no broken link in 14 files.

**D-02 (Medium, `docs/`, first set):**
- `docs/kernel-send-package.md` has no historical label and says (`:27`, `:35`) the BT-1
  patch "does not exist yet"; `:129` quotes a README sentence the README does not have; it
  cites `BRIEF.md` §9.6 and §9.9 for content that those sections no longer hold.
- `docs/pre-submission-checklist.md:23-24`: a history purge that "must happen before
  submission"; 27 mails are in `docs/sent-mails.tsv`.
- `docs/missing-quirks-entry.md`, which `README.md:103-105` calls "the full argument", lacks
  the author's name, v7.3-rc1, the stable releases, the totals 74 and 12, and the kernels
  after `-34`; `:18` still says the entry is "absent from v7.0, 6.6.y, 6.12.y" and gives the
  kernels as "7.0.0-28…31" (`README.md:199`: -29, -30, -31, -34); its second banner
  (`:10-20`) still says "untested here".
- `docs/external-review-brief.md` ("Hand this to a reviewer as-is", "What we currently
  believe"), `docs/review-task-bluez-patches.md` ("before they are mailed") and
  `docs/related-reports.md:172` have no date label. `README.md:266-267` says the plans and
  drafts are "each labelled".
- `docs/bug-report.md`: no `BT-n`, `CO-nn` or `U-n` label, but about 36 `EX-nnn` references
  (the test gates only BT-1 to BT-4; `BRIEF.md:499-500` says it "carries none");
  `:174` "seven deaths and one survival".
- `docs/sent-mails.tsv`: the 2026-10-02 stable request has "not kept in the repository" and
  no hash, while `patches/diag/stable-request-dc16388d45ec.md` holds it.
- `README.md:257` "the two applied BlueZ patches" for `patches/bluez/`, against eleven.
Consistent: 27 rows well-formed, all 25 hashes re-computed equal, the seven lore Message-IDs
in `README.md` match, all relative links resolve.

**T-12 (Medium/Low, `tests/`, lines 1–5200 and `tests/README.md`):** `tests/README.md:422`
gives the coverage floors as "80, 85, 80 and 75"; `.github/workflows/checks.yml:301` has
`devtools/awk-coverage --min 95` (checked). The README says the upgrade rehearsal has 17
checks; `tests/system-upgrade` has 20. The bt-trial guard (`tests/run-tests:15144`) omits the
verb `autostop`. Checks that cannot fail: `:3357-3363` (`ok` in both branches), `:2164-2167`
(`|| true`), `:3381-3388` (vacuous if the live `results.tsv` is missing). All 41 entries of
`tests/whole-boot-reads.txt` have the reason "pending". `--section` drops `--serial`
(`:129-133`, `:161`). Stale counts in comments (`:259`, `:475` "80 mktemps", now 183).

**I-01 (High, safety, checked): `uninstall.sh` reloads btusb on the investigation machine.**
`uninstall.sh:284-308`, step "[5/5] restore btusb default": when btusb is loaded and its use
count is 0 it runs `modprobe -r btusb` and `modprobe btusb`. `BRIEF.md:60-63`: "Never unload,
reload, rebind or swap btusb … a reload kills even a *healthy* controller here (`EX-046`,
09-23), and recovery needs a power-off." `install.sh` has guards for a wedged controller and
an open trial (`:310`, `:694-755`) and skips its own modprobe block under `--tools-only`;
`uninstall.sh` has none, and `docs/restore-original-state.md:84-85` does not warn. (On the
QCA firmware loaded by the current stock driver a reload may be survivable; the documents do
not say so, and the rule as written is absolute.)

**I-02 (Medium, checked): a unit with one machine's absolute path is enabled by every
install.** `systemd/bt-raw-archive.service:15`:
`ExecStart=/root/exp/qca9377-bt-hang/scripts/raw-capture-archive-all.sh`; `install.sh:537-538`
installs it and `install.sh:680` runs `systemctl enable --now bt-raw-archive.timer`. On any
other checkout path the service fails at every timer tick. `BRIEF.md:113`, `:144` describe
this timer as "transient: gone at every reboot", which an installed, enabled unit is not;
`docs/tooling-index.md:86` says "installed by install.sh".

**I-03 (Medium): installed set against the code.**
- `tools/bt-journal-files` and `systemd/bt-journal-files.service`, `.timer`,
  `bt-journal-files-shutdown.service` are neither installed by `install.sh` nor removed by
  `uninstall.sh`; `docs/tooling-index.md:78` says "installed in /usr/local/bin".
- For a device other than the default, `install.sh:385-401` writes the `BT_VID`/`BT_PID`
  drop-in for `bt-health-snapshot.service` only; the udev-triggered
  `bt-health-snapshot-event.service` keeps describing `13d3:3503`.
- `bin/bt-evidence` (`snapshot_state`) sends `hciconfig <hci> name` on `start` and on `stop`
  with no way to turn it off, the probe that was removed from `bt-mark`.
- `bin/bt-usbmon` says its directory "must stay root-only" and sets no umask or mode; its
  unit has no `UMask=`; `docs/changes-applied.md:312` says capture directories are `0700`
  (needs a check on a machine).
- `etc/` modprobe options `dyndbg=+p` enable every site of `btusb.c` and `hci_core.c` at
  load, including the per-packet ones `bt-dyndbg` turns off; the comment that
  `bt-dyndbg.service` "covers reload by hand" is wrong (a boot-time oneshot); `bt-mode
  experiment` renames that file although its header says dynamic debug stays on in both modes.
- `uninstall.sh` lists `20-verbose.conf`, which nothing creates; `tools/bt-verify-install`
  prints "missing in repo" without counting it and can exit 0.

**I-04 (Medium, contradiction, checked): two or three controlled demonstrations.**
`install.sh:11` and `:36`, `docs/tooling-index.md:231`, `docs/fix-proposal.md:9`,
`docs/investigation-plan.md:55` say "three controlled demonstrations". `README.md:288-291`,
`BRIEF.md:64-66`, `:406-408`, `docs/install.md:6`, `:26`, `:45`, `docs/issues.md:454` say two,
plus one after a reset the project did not issue. `BRIEF.md:153-155` records the correction
to two on 2026-11-12; it was not carried to the installer's own warning text.

**I-05 (Medium, stale): `docs/install.md` and `docs/changes-applied.md`.** `docs/install.md:78-79`
says `bt-verify-install` prints `./install.sh --apply` (it prints `--tools-only`); `:85-86`
(step 7) still checks for E3 (`srcversion` `D1DEA96A…`, `updates/btusb.ko`); "What it
installs" lists three items against about 70 files and 9 enabled units.
`docs/changes-applied.md` §5 "Manual — the complete set" stops at 2026-08-13 and would leave
nine units running. `docs/restore-original-state.md:46` says restoration is "deletion of
added files, not restoration from backup", while `uninstall.sh` moves
`.pre-qca9377-bt-hang` copies back. `BRIEF.md:409-413` dates do not match `install.sh`'s own
comments (the 51 rule on 09-18); the claim "all 3 skip now" is correct in the code.
Consistent: every installed file is in `uninstall.sh`'s list; `TimeoutStopSec=30`.

**C-02 (High, checked for CO-21 and CO-20; extends S-01): two more packages are replaced by
directories no register names.**
- `contributions/CO-21-…/review-fixes-20261114/README.md:3`: "These patches replace
  `../send-20261114/` for the send". `contributions/README.md:66`,
  `contributions/rd-2026-11-14.md:76` and `send-20261114/NOTES-FOR-OPERATOR.md` name
  `send-20261114`. The new directory has no operator notes and no recipients file, and its
  cover letter says "Changes since the first draft" in a first posting.
- `contributions/CO-20-…/patch1-standalone-20261114/NOTES.md`: all five reviewers want patch 1
  alone and patch 2 held; the register and `send-20261114/NOTES-FOR-OPERATOR.md` describe a
  two-patch package.
- `contributions/CO-04-…/review-fixes-20261114/` and `CO-05-…/review-fixes-20261114/` say
  "replace `../send-20261114/patch/` for the send"; CO-05 has an open choice between variants
  A and B for CO-26's `Fixes:` tag.
- `contributions/CO-23-…/patch/send/` (10-29, "files to send, exactly as they stand", with a
  working `send.sh`) is not marked superseded by `patch/send-20261114/`, which has no send
  script; the dossier README points at the old one.
- `contributions/CO-11-…`: the front page and the register row point at `ready-20261102/`,
  whose package versions were taken by unrelated uploads on 11-10; `ready-20261114/` and the
  bundle are not named there; two different uploads claim `5.72-0ubuntu5.9`.

**C-03 (Medium, dossiers CO-01 to CO-35):**
- CO-35: `send-20261114/` has no operator notes; all six backport patches carry the author's
  `Signed-off-by` (identical to 11-02), against `BRIEF.md:190-191` "Packages made since 11-13
  carry no Signed-off-by" (stable backports need one; the package does not say so). The
  dossier `README.md:5` calls `send-20261102/` final; `docs/issues.md:876` says "7.3.y and
  7.2.y"; the package is a 7.3.y request, a separate SCI request and three series.
- `README.md:175`: "an L2CAP hang that every released kernel has". The request covers 7.3.y,
  6.18.y, 6.12.y and 6.6.y; 6.1, 5.15 and 5.10 hang only with the non-default
  `enable_ecred` parameter and are not covered (`docs/STATUS.md:68` says the same).
- CO-25: `docs/STATUS.md:37` names `drafts/reply-1-zijun-hu.eml` and stops at v3; the dossier
  `log.md:331` calls that draft "wrong where it matters" and v4 is the one ready.
- CO-30: `rfc-20261114/README.md:3` gives its base as `../co02-v2/kernel/`, which does not
  exist; it was tested on the earlier CO-02 v2, before `send-v2-review-fixes-20261114`.
- CO-09: banner "done", body "State: waiting … not yet in updates or security"; the banner
  gives 22:57 for the boot, every other place 22:55.
- CO-03: README and register row say the operator installs and tests; `docs/STATUS.md:193`
  says staged 11-13.
- CO-27 still owns the GNOME report that CO-42 now holds; `BRIEF.md:102` "CO-28 waits" while
  CO-28 is closed; old "State:" lines under newer banners in CO-01, CO-06, CO-07, CO-10;
  CO-34's `patch/send/README` says "not sent".
- `SHA256SUMS` files that fail or list files not in the tree: CO-30, CO-35 (two scripts
  changed after the sums), CO-04, CO-05, CO-12, CO-14.
- Needs a check: mgmt-tester totals 515 (CO-14) and 526 (CO-04/CO-05) on the same tip
  `da3cc02587c6`; CO-01's cover patchwork id 14157860 against patches 14875449–14875454;
  CO-25's pinned commits `4b56813d311d` and `cb645f5` and its public evidence page, which
  uses `EX-nnn` ids and points to `BRIEF.md`.
Consistent: CO-10, CO-25 and CO-34 send records and hashes; author lines; no
`@example.invalid` in mails; cover-letter patch counts.

**PA-01 (Medium, `patches/`):**
- F-09 resolved: `BRIEF.md:375`, `patches/bluez/README.md:145`,
  `reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4` and `reviews/README.md:71` all label
  the v1 bot mails "22:05/22:10 UTC"; the mailbox is CEST, so they were most likely
  20:05/20:10 UTC (81 and 86 minutes after 18:44). The label is wrong in four places; "within
  90 min" is right.
- `patches/kernel/README.md:3`, `:7`: the fix "reaches mainline with the next bluetooth-next
  pull"; no mention of v7.3 or the five stable releases; `:259-283` "How to send" reads as
  pending.
- `patches/diag/README.md`: E1 as "37 links, two boots, one headset" (58, three, two
  elsewhere), no E3 result, and a "running since" section for `-42`.
- `patches/bluez/checkpatch-check.sh` does `cd "$TREE"` before expanding a relative
  `BT_PATCH_DIR`, and nothing checks perl's exit status, so it can print "0 error(s)" when
  checkpatch never ran; `git-am-check.sh` passes the relative path to `git -C`. The README
  documents the relative form (read, not run).
- `patches/kernel/bt9-stable/README.md`: "totals 497-498 of 506" against 496 in
  `compare-full-recheck.txt:3`.
- `docs/sent-mails.tsv`: the hashes of the three stable backport rows and the Tested-by body
  are of address-elided copies, not of the bytes mailed.
- `README.md:257-263` map: `patches/diag` holds only the E1 patch; `patches/bluez/sent/`,
  `v2/`, `btdev-vla/`, `send-2026-10-13/` unlisted. `HISTORY.md:4802` cites a directory
  `…-on-d84171e6c-2026-10-08/` that is named `…-on-d84171e6c/`.
Consistent: subjects 49/46, trailers, every Message-ID, patchwork id and commit id; no relay
headers in any tracked mail.

**T-13 (Medium, `tests/`, lines 10400–15600):** `tests/machine-tools` lacks tools the shipped
code calls: `gsettings`, `pw-metadata`, `dbus-monitor`, `dpkg`/`dpkg-query`, `getent`, `ps`,
`df`, `pgrep` (`tools/bt-ui-capture:149`, `229`, `235`, `242`, `365`;
`tools/verify-restored.sh:155`; `bin/bt-trace:106`; `bin/bt-usbmon:118`); the suite stubs
three of them by hand (`tests/run-tests:11627`, `11638`, `11642`). `tests/system-roundtrip:70-73`
(the experiment-mode gate) cannot fire after `:60-63`; `:181-193` passes on an empty derived
list. Silent skips with no note: `tests/run-tests:14039`, `14475`, `14515`, `14026`, `10440`.
Negative greps ending in `|| true`: `:10628`, `:11050-11054`, `:11278-11282`. Every staged
`--apply` test uses `0cf3:e300`; the default device is covered by the dry run only.
Consistent: the system tests' skip condition and CI's `BT_SYSTEM_TEST=required`; 231 fixture
files with placeholders only.

**C-04 (High, checked): CO-43's patch A exists in three versions and the registers point at
the uncorrected one.** In `contributions/CO-43-btusb-runtime-resume-failure/`:
`send-20261113/A/0001-…patch` and `send-series-20261114/0001-…patch` use plain `bt_dev_err`
(`grep -c ratelimited` → 0 for both) and keep the commit message the 11-14 review called
wrong; `send-20261113/A-review-fixes-20261114/0001-…patch` has `bt_dev_err_ratelimited` (→ 1)
and the corrected message. `docs/STATUS.md:78` (BT-20), `BRIEF.md:185` and
`send-20261113/A/NOTES-FOR-OPERATOR.md` say the old A is "ready, dry run OK". The corrected
directory has no notes, recipients or send commands, and its README says the bot was not
re-run on it.

**C-05 (High, checked): CO-43's series contradicts its own dossier.**
`contributions/CO-43-…/README.md:74-81`: "D v2 (patch 3 of `send-series-20261114/`) breaks
the system-resume rebind … Patch 3, and patch 2 which needs it, are held". `docs/STATUS.md:76`
(BT-18): "D v2 … runtime matrix 18/18; the system path unchanged by reading only";
`BRIEF.md:188-190` says "D's system path rests on source reading". Patch 3's message and the
cover letter still say the system path stays as it is. `send-series-20261114/` has no README
and no notes (checked: six files, the cover and five patches). The series puts patch 2 (B2)
before patch 3 (D v2) although the cover says 2 depends on 3. Patches 4 and 5 differ from
`send-bt24-bt25-20261114/` patches 1 and 2, with no ruling on which pair stands.
`docs/issues.md` BT-24 says "not reproduced, no fix yet" and BT-25 "Next: a kmemleak run",
while `docs/STATUS.md:82-83` says reproduced and fixed; the kmemleak count for E alone is "11
of 12 runs" in one result set and "12 of 12" in the other.

**C-06 (Medium, checked): the placeholder `<AUTHOR-EMAIL>` is committed in the `From:` line of
14 patches**: `contributions/CO-38-…/send-20261102/` (5 files),
`contributions/CO-37-…/work/patches/master-final-6-20261102/` (6) and `…/5.72-3-20261102/`
(3) (`git grep -l 'AUTHOR-EMAIL'`; also in three CO-11 `ready-20261102/` debdiffs).
`BRIEF.md:215-216` says placeholders become the real address in authored files. CO-37's
`send-20261114` README says these stayed in the work area.

**C-07 (Medium, dossiers CO-36 to X1):** the dossier READMEs of CO-37, CO-38, CO-39, CO-40
and CO-41 stop between 11-02 and 11-12 and do not link their 11-14 packages (CO-41: "idea, no
patch yet"). `contributions/rd-2026-11-14.md`'s table contradicts its own "Results so far"
for CO-38, CO-39, CO-40, CO-41, CO-43 (and CO-22, CO-35). CO-38 `send-20261114/`: the README
says the flake is "not shown", its `CHECKS.md` §5 says settled; both the old 0/3 BlueZ series
and `bluez-split-20261114` are present with no choice recorded; two `SHA256SUMS` lines fail.
The Ubuntu bundle: `BUNDLE.md` says the changelog trailer is a placeholder while the file has
the real address; 7 `SHA256SUMS` lines fail and 1,188 of 1,239 listed files are not in the
tree. CO-44's `patch/` is not marked superseded by `send-20261113/kernel`. CO-39's notes cite
a "v3 cover letter file" that is not in the tree. Consistent: the CO-44 and CO-43 E/A dry
runs, no Signed-off-by since 11-13, patch counts, bases `da3cc02587c6` and `20ffd285b58f`,
X1's ids.

**G-01 (High, checked): `devtools/repo-save` checks the identity against the checkout's own
configuration.** `devtools/repo-save:142-147`: `want_name="$(git config user.name)"`,
`want_mail="$(git config user.email)"`, and the author and committer are compared with that.
`README.md:320-321` ("authored and committed by the project author; `devtools/repo-save` and
CI check both fields") and `BRIEF.md:489-491` ("refuses a commit whose author or committer
identity … was assigned by the environment") describe a check against one fixed person. A
checkout whose configuration was reset to an environment's default, the 09-18 incident the
gate was written for, passes it. Only CI's `WANT: "Iaroslav Voitovych <…>"`
(`.github/workflows/checks.yml:51`) is fixed, and it runs after the push. Further (not
rechecked): the push-range check uses `git rev-list "$br" --not --remotes`
(`devtools/repo-save:179`); CI's identity job examines 0 commits on a force-push
(`checks.yml:55-72`); a plain `git commit` is unchecked until a push goes through `repo-save`.

**G-02 (Medium, `devtools/`, not rechecked):**
- `devtools/repo-scan --range` scans the net diff (`:59`): a leak added and removed inside
  one push is published unscanned.
- `devtools/repo-scan:224-232` passes more addresses than `BRIEF.md:445-458` documents:
  `^systemd-` at any host, `noreply@` at any host, `modprobe@`, example.org, one hard-coded
  private-looking address; in CI the allowed own address falls back to the tip's author.
- It refuses none of the working-arrangement strings of section 3.2 (the answer to P-04's
  closing question): its patterns are addresses, MAC/BSSID shapes and Message-IDs.
- `devtools/repo-validate:125` parses Python only for `*.py`; `bin/bt-capture`,
  `devtools/access-classify` and `devtools/mutants` are never parsed.
- Gates that exit 0 when they could not run: `devtools/awk-coverage` on a red suite or
  without gawk, `devtools/journal-contract` without journalctl, `devtools/ci --recent` when
  `gh` fails.
- `devtools/hooks/test-pre-push.sh`, `devtools/test-bt-journal-files.sh` and
  `devtools/test-journal-fast.sh` are run by nothing; the last hard-codes 2026-10-22.
- `README.md:278-280` cites a branch convention "in `reviews/README.md`" that the file does
  not contain, and `review/*` branches are pushed to the separate remote only.
- `.github/workflows/checks.yml:26` says "EIGHT JOBS" and defines nine. `BRIEF.md:821-823`
  says the workflow "now says about a minute"; no such text exists. `BRIEF.md:830-832` calls
  the job split open; `checks.yml:26-35` records it done 2026-10-18.
- `.gitignore:6-8` says only `*.sanitized.log` may be committed; 147 tracked evidence logs
  have other names.
Consistent: the 1200-line warning, the held-branch push rule, `BT_SYSTEM_TEST=required`, the
public-address list (no organisation domain), every `coverage-exclude` entry.

**H-01 (Medium/Low, `HISTORY.md`, read in full by a worker):** structure as stated: 37
phases, 19 dated chapters in order, the last "(2026-11-13 → 11-14)" at `:4434`, every retired
hand-off block present; `BRIEF.md`'s pointers to Phases 14, 17, 19, 25 and 29 are right;
every retraction of `BRIEF.md` §5 has its correction note.
- `BRIEF.md:877`: "dated chapters to 2026-10-28" (they reach 11-14); `HISTORY.md:11-15` ends
  its own summary at 11-07; `HISTORY.md:5-7` says the BlueZ patches are in Phase 36 (they
  are in 37, `:3185`, `:3371`).
- `HISTORY.md:901` calls EX-004's reset "the first EARLY reset ever captured"; Phase 10
  (`:383-410`) records an early reset a day before; `BRIEF.md:297-298` counts one.
- `HISTORY.md:2715` still says "27-byte mSBC frames pushed into a 9-byte endpoint" with no
  note; `:3215-3218` says that wording was "withdrawn everywhere it stood".
- Elided Message-IDs, hashes and paths in text after 09-18 (`:4473`, `:4875`, `:4877`,
  `:4903`, `:5194`, `:5368` and about twenty more); all but `:4473` are inside blocks marked
  "moved verbatim", so the elision rule and the verbatim label cannot both hold there.
- `:3261` "Eight residual sentences" names seven; 1836 s (`:1774`) and 1837 s (`:1850`) for
  one window; "9 of 12 boots" (`:4100`, `:5088`) and "8/12" (`:5384`) for one comparison.

**K-01 (High, safety, checked): `scripts/runtime-mgmt-test.sh` still performs the module swap
that wedged the controller.** Its header (`:2-7`) says "Everything is reversible"; `load` and
`restore` run `modprobe -r` on btusb and bluetooth (`:101-108`) whenever `guard()` sees no
open window and no open trial; the warning about `EX-046` is a comment below the lines the
usage prints (`sed -n '2,20p'`). `guard()` (`:36-48`) compares the output of
`tools/bt-window` and `tools/bt-trial status` with fixed strings, so a missing or failing
tool passes it. `BRIEF.md:761-763` still presents `load`/`restore` as the runbook, and
`BRIEF.md:770-771` says they "must not be run"; only `docs/tooling-index.md:150` says "never
run". The code does not refuse.

**K-02 (Medium, checked): `scripts/compile-mgmt-at.sh:29` refuses a patch that applies cleanly.**
`patch -p1 -d "$OUT" < "$PATCH" | grep -E "Hunk|FAILED" || { echo "patch did not apply"; exit 1; }`
under `set -uo pipefail` (`:15`). A clean apply prints only "patching file …", so grep finds
nothing and the script stops with "patch did not apply"; it goes on only when `patch` printed
a "Hunk … succeeded at … (offset)" line. A rejected hunk is caught, by `pipefail` and not by
the grep. (The worker rated this High and gave line 165; the file has 39 lines, and with
`pipefail` the unpatched-compile case it feared does not happen.)

**K-03 (High): `scripts/smtp-login-check.sh:28-45`.** Exit 1 means REVOKED, the wanted result
per the header; a timeout, a refused connection or a TLS error ends in a traceback that also
exits 1 (checked: the `SMTP_SSL(...)`/`starttls()` calls are outside the `try`). A network
failure therefore reads as "the password is revoked". This is the check behind P-04.

**K-04 (Medium, `scripts/`, a zero or a pass without a control; not rechecked):**
- `scripts/sco-ledger.sh` and `scripts/sco-ledger-boots.sh`: a boot whose journal cannot be
  read prints "links 0 hang-ups answered 0 timeouts 0" and is added to the total. This is the
  tool behind the E1/E3 link counts and every "0 timeouts" in `docs/STATUS.md:59`.
- `scripts/ci-local.sh` exits 0 when checks did not run (its header: "2 = could not run"); a
  checkpatch that fails to start counts as PASS; `scripts/ci-local-publish.sh` leaves a file
  unsanitised in the tracked results directory and exits 0 when the sanitiser refuses.
- `scripts/bluez-tester-compare.sh`: a tester with no summary gives "REGRESSIONS: 0".
- `scripts/bluez-release-contains.sh`: a bad tag prints "NOT in <tag>" and exits 0 (this is
  the tool of the 5.87 control whose output is not shipped, D-01).
- `scripts/btusb-has-device.py`: any error exits 1, the same as ABSENT; `.ko.xz` and `.ko.gz`
  read as ABSENT. `BRIEF.md:56-58` makes this the gate before a new kernel boots (it fails
  towards rebuilding, the safe side, but says the wrong thing).
- `scripts/build-bluetooth-fulltree.sh:46`: a failed `patch` is not detected.
- `scripts/discovery-stop-race.py` ignores btmon's exit status (a truncated decode reads as
  "never stopped"); `scripts/journal-archive-grep.py`: a decompressor failure gives "0
  match(es)"; `scripts/bt-device-record.sh` unreadable store reads as "no stored device".
- `scripts/prove-trial-closer.sh`, `prove-trial-nomatch.sh`, `prove-trial-build-label.sh`,
  `prove-ci-cwd.sh`, `prove-audio-policy-metadata.py` exit 0 whatever happens;
  `scripts/bot-ci-local/harness.py:158-165` exits 0 when no test ran.
- `scripts/sco-switch-windows.sh:19-21`: `|| true` now hides a btmon abort.
- `scripts/desktop-capture-archive.sh`: its 3 GB default overwrites `BUDGET_GB`, so the
  archive the operator raised to 20 GB reads FULL in `scripts/archive-budget-check.py`.
- `scripts/bt17-provoke.py` exits 0 on FAILURE.

**K-05 (Medium, `scripts/`, one machine's paths and stale headers):** `/root/exp/…` is
hard-coded in `scripts/move-brief-block.py:11` (it rewrites `BRIEF.md` and `HISTORY.md`
there, `HISTORY.md` first, with no range check), `prove-archive-budget-check.py:16`,
`prove-bt-trace-archive.py:17`, `prove-held-branch-guard.sh:6`,
`bt17-review-pack/build.py:13-14`, `cd-trace/x1-check-submission.py:13`; the desktop user `i`
and uid 1000 in the `user-*.sh` and `cd-trace` scripts. `scripts/export-kernel-review.sh` and
`scripts/build-v2.sh` describe a held branch and an undecided v2 that are long past;
`scripts/gitlint-check.sh:2-3` and `scripts/ci-local.sh:21-23` say opposite things about
which gitlint file the bot uses; `scripts/kernel-preflight.sh` says `C=2` and runs `C=1`;
relative paths break after `cd` in `get-maintainers.sh` and `kernel-preflight.sh`.
`scripts/README.md:20-24` says the scripts are "tracked and tested"; of the four it names
only `sco-ledger.sh` has tests. `scripts/cd-trace/README` says nothing there changes a
setting; `cdda-remount.sh` unmounts and remounts.
Consistent: all 53 path and SHA-256 pairs of
`reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md` match the tree
(so that document embeds the pre-review-fix files, S-01); `docs/sent-mails.tsv` 26 hashes;
`scripts/trial-close-now.sh` is passive; `scripts/module-updates.sh` does what `BRIEF.md`
says; no address, key or account detail in any script.

**M-01 (High, contradiction between the hand-off and the messages): the two commits of
`ci/upstream-ci-local`.** `BRIEF.md:219-220`: "land or drop `ci/upstream-ci-local`'s
`eb2e6d6`/`6ada2a1`", after
`comms/2026-11-13T0100Z-from-test-suite-maintainer-to-everyone.md:85-86` ("Its two commits are
not on `main`"). `comms/2026-10-18T1532Z-from-main-branch-maintainer-to-test-suite-maintainer.md:18`:
"Also landed: the ci-local line's `eb2e6d6` and `6ada2a1`" (checked), and `BRIEF.md:147` says
the branch was landed on 10-13. Their content is on `main` (the worker names the files).
`main` takes work as new commits, so an ancestry test says "not on main" for work that is
(the rule "Ids on `main` are `main`'s", `BRIEF.md:637-639`). The same hand-off line asks the
operator to delete 16 remote branches with "the command in the test-suite maintainer's 11-13
note": the note has no command, and says every branch but `main` and `tests/test-suite` goes,
which is wider than 16. A branch deleted on the strength of "landed" that is in fact wrong,
or of "not landed" that is in fact landed, is the kind of loss `BRIEF.md:414` forbids; here
the content appears safe, and the instruction is still wrong.

**M-02 (Medium, `reviews/`, `comms/`, `lessons/`):**
- `reviews/README.md` calls itself the register of the directory; about 58 of 107 files are
  named nowhere in it (the BT-17 and kernel-patch rounds of 11-12 to 11-14, the 10-19 plans,
  09-26, 09-27, the 08-13 set); its last report row is 11-07.
- In it: R2-21 (`:310`) and R2-25 (`:311`) are open though their own verify commands pass;
  R2-64/65 (`:312`) open while DR-07/F5 (`:392`) says the defect is fixed; the CO-01…CO-10
  block (`:443-453`) contradicts `contributions/README.md` (CO-09 open, CO-10 blocked) under
  the sentence "this table is the current truth"; HC-04 says awk `--min 85` (95 in CI);
  `:283` shell floor "now 65" against `:202` and CI's 80; `:170` "329 invariants".
- `BRIEF.md:148` names the branches `tests/unit-testing-introduction` and
  `-ready-for-main`; the 11-13 note retired them for `tests/test-suite`, which no foundation
  document mentions. `README.md:278` and `reviews/README.md:63`, `:326` still describe
  `review/<timestamp>` branches.
- `BRIEF.md:668-674` (§9.2): the "six tasks" are not the six of `comms/2026-08-22T1215Z` §3,
  and the "device survey" it keeps open was dropped (`comms/2026-10-19T0601Z`: "the operator
  accepted … the device survey dropped").
- `BRIEF.md:562-565` sends the reader to two `lessons/` files for the instance behind each
  rule of §8a; the files stop at 08-27 and about 11 of 17 rules have their instance only in
  `comms/`.
- Requests in `comms/` with no recorded answer: 11-13 (main to take `tests/test-suite`),
  11-07 §4 (four questions, confirmed open on 11-09 and 11-13), 10-19T1739Z (T1, SR1), 10-21
  (two questions).
- 23 of 70 messages lack the front matter `comms/README.md` requires; naming in `reviews/`
  follows three schemes where the README admits one exception.
- Privacy (adds to 3.2): `comms/2026-10-20T0020Z` ("forty working-rule files", "the root
  session's", "hand-off file"), `comms/2026-10-19T2330Z`, `T2355Z`, `T2258Z` ("another
  account on the same laptop"), `comms/README.md:4-6`. `comms/` is append-only by its own
  rule, so this is a decision for the author, not an edit.
- Note for every commit id in the registers: this clone has 50 commits, and
  `comms/2026-10-19T2258Z` says about 30 commits are absent from the public history; ids such
  as `456daba`, `d016249`, `400c5df` cannot be resolved here.

### 3.5 `docs/STATUS.md` machine and repository-health sections, `docs/issues.md` head, `contributions/README.md` head (lead reviewer)

**S-12 (Medium, rule against practice): "Do not add a second 'current' paragraph anywhere
else"** (`docs/STATUS.md:414-416`). Places that carry their own current-state text today:
`README.md:148` ("Current direction — 2026-11-12"), `BRIEF.md:79` ("The state at a glance"),
`BRIEF.md:174` (the hand-off), `docs/issues.md:15`, `:33`, `:50`, `:57`, `:77`, `:110` (six
stacked "Current state" blocks, the newest dated 11-12), `contributions/rd-2026-11-14.md`
(which `BRIEF.md:176` calls "the page of record for today's work"), `reviews/README.md:443`
("this table is the current truth"), and inside STATUS itself the block "Laptop-only work of
2026-11-11 (supersedes the rows above where they differ)" (`:168`) and a header paragraph
with six "as of" dates (`:3-19`). Most of the contradictions in this review are between two
of these. This is the root cause, more than any single stale line.

**S-13 (Medium, stale and broken evidence paths, checked): the work areas deleted on
2026-11-14.** `docs/STATUS.md:311-319` (commit `645e164`, 15:06): nine work areas deleted,
among them `co43-ea-send-20261113`, `bt17-emu-20261113`, `co44-send-20261113`,
`co37-release-20261102` and `u25-settle-20261101`; "Old dossier paths into those areas now
point at deleted copies."
- `BRIEF.md:221-223` still lists as open "whether to delete the 11-13 work areas
  (`co43-ea-send-20261113`, `co44-send-20261113`, `bt17-emu-20261113`)".
- `docs/STATUS.md:114` (U26) and `:115` (U27) give as their evidence
  `agent-work/u25-settle-20261101/runs/q1-*` and `agent-work/co37-release-20261102/`: both
  deleted, so the only cited evidence of two registered defects is in a private backup.
- The same paragraph records one debug-only commit lost.
The paragraph itself is the plainest statement of the working arrangement in the tree
("nine finished agent work areas", "6,046 agent-written files", "the private procedure");
see 3.2.

**S-14 (Low, stale): `docs/STATUS.md:404-405`** (branches surveyed 10-18) lists
`ci/upstream-ci-local` as "Not on `main`, fit to land" (M-01), and `:221-229` keeps the
`-42` machine paragraph in the present tense ("the next kernel update needs E3 rebuilt")
under the 11-14 bullet that retires E3; `:224` says of the CO-02-labelled E3 #3 "It has no
row (below)" while a later E3 #3 has one (E-02).

**IS-01 (Low/Medium, `docs/issues.md:1-31`):** the opening counts "sixteen `BT`, three `M`,
thirty-one `U`, and four off-topic `X`" "by 2026-11-12" (`:4-5`); the file and
`docs/STATUS.md:59-88` now hold BT-1 to BT-25 and M-1 to M-5. The newest "Current state"
block is dated 11-12 and names BT-16 as the last new issue, although its last bullet was
edited to 11-14 ("read 11-14"); BT-17 to BT-25, M-4 and M-5 are in no block. `:11` says the
issues "are numbered `BT-n`"; four other series exist. `:89-92` (the 10-03 block) is dated
and may stand.

**R-02 (Low, `contributions/README.md`, head and tail read):** the states defined at `:29-31`
(idea … released, waiting, blocked, dropped) are not the states the rows use ("stalled
upstream", "backported and tested in VMs", "five patches written and tested in emulation",
"measured, recorded", "queued upstream"). `:55` (CO-03) "trigger 0/70 → 70/70" reverses the
direction of `docs/STATUS.md:100` ("lost A2DP 70/70 before and 0/70 after"), as one counts
passes and the other losses without saying so. `:100` (CO-43) "five patches … A, B, D, E"
against the series of `docs/STATUS.md:76-83` (E, then A, B2, D v2 and the two fixes for BT-24
and BT-25). `:3-5` and `:39` use "working sessions" and "work lanes" (3.2).

### 3.6 Mechanical checks over the whole tree (lead reviewer)

- **Relative Markdown links:** 588 checked in every tracked `.md` except the verbatim outside
  reviews; 2 do not resolve, both the placeholder `UPLOAD` in
  `contributions/X1-gvfs-cdda-readahead/REVIEW-ACTIONS.md:269` and `submission-drafts.md:150`.
  No finding.
- **Paths in backticks** in `README.md`, `BRIEF.md`, `docs/STATUS.md`, `docs/issues.md`,
  `contributions/README.md`, `contributions/rd-2026-11-14.md`, `docs/tooling-index.md`,
  `tests/README.md`, `devtools/README.md`, `scripts/README.md`, `reviews/README.md` and
  `evidence/exhibits/README.md`: all resolve except **L-01 (Low)**:
  `docs/STATUS.md:178` names `scripts/usbip-bt-emu.py`; the file is at
  `results/laptop-only-work-2026-11-11/btusb-modules-and-emulator/scripts/usbip-bt-emu.py`
  and `results/co43-co21-co20-packages-2026-11-14/harness/usbip-bt-emu.py`.
  `docs/issues.md:1055` names `tools/suspend-cycles.py`; it is
  `results/incident-2026-11-12-1803/tools/suspend-cycles.py`. `reviews/README.md:188` names
  `tools/lib/device.sh`, which does not exist (the row itself says the implementation took
  another form). `BRIEF.md:127`, `:148` and `docs/STATUS.md:263`, `:402` name the retired
  branches `tests/unit-testing-introduction…` (M-02).

### 3.7 `docs/issues.md` against `docs/STATUS.md` (three workers, second task; lines 145–2056)

**IS-02 (High for a reader of the register, checked against STATUS by the lead reviewer):
BT-24 and BT-25.** `docs/issues.md:1155`: BT-24 "not reproduced; no fix yet";
`docs/issues.md:1182`: BT-25 "Next: a kmemleak run". `docs/STATUS.md:82-83`: both reproduced
on 2026-11-14 and fixed by series patches 4 and 5 (kmemleak 11 of 12 runs on E alone, 0 of 12
with the fix). `docs/issues.md` is the page `docs/STATUS.md:23` names for "each issue's
evidence and falsifiers".

**IS-03 (Medium):** the sections for BT-18, BT-19, BT-20, BT-21 and BT-23 in `docs/issues.md`
stop at 11-13 ("fix candidate", patches B and the wide D); `docs/STATUS.md:76-81` has B2,
D v2 and the 11-14 packages, and neither has the `needs_binding` finding of C-05. BT-21's
evidence is `agent-work/bt17-mgmt-timeout/`, one of the deleted areas (S-13).
`docs/issues.md:1082` and `docs/STATUS.md:75` say CO-43 is "five patches".

**IS-04 (Medium): U24.** `docs/issues.md:1217` "not released" and `docs/STATUS.md:112` "in no
release, the newest tag is 5.87"; `7e3212fa233e` is in BlueZ 5.88 per the 11-14 `CHECKS.md`
and the bundle (R-01). `docs/STATUS.md:112` still plans "a later CO-03 package" for the 5.72
backport that is patch 3 of the Ubuntu bundle.

**IS-05 (Low):** U23 keeps CO-03's counts ("3 of 10", "2 of 10 with the backport") beside
CO-37's "10/10 → 0/10" in both registers with no reconciling sentence. U22 to U31 exist only
as table rows in `docs/issues.md`, while earlier issues have sections. Evidence cited from
`agent-work/`, `cache/linux` and `tmp/ui-screenshots/`; `docs/issues.md:1290-1291` truncates a
screenshot path and its SHA-256.


**IS-06 (Medium, checked): the closing sections of `docs/issues.md` predate the cause.**
`docs/issues.md:2012-2035` ("On the wider claim"): Windows "drives this controller … without
failure, so hardware alone is not a sufficient explanation. It may still be a controller or
firmware defect that only Linux's command sequence reaches", and "our own evidence points at
the SCO and isochronous path". `README.md:210-211`: "Windows loads the controller's firmware,
which is what the missing entry withheld on Linux". The next section says "The only fix is a
cold power-off" and "roughly fifteen purpose-built tools" (`tools/` and `bin/` hold about
fifty). Neither section has a date or a "kept as written" label, unlike the BT-1 body.

**IS-07 (Medium, stale sections in `docs/issues.md`):**
- U12 (`:1636-1642`): "Next" is to build the 5.72 bluetoothd with `a14d59725`;
  `docs/STATUS.md:100` says it was built on 10-31 and tested 70/70 → 0/70. The section lists
  three occurrences and calls 10-19 the first; `results/laptop-only-work-2026-11-11/…/u12.txt`
  has nine within 1 s, four of them before 10-19 (10-11, 10-14, 10-17), as
  `docs/STATUS.md:177` says. Nothing joins the two histories.
- U8 (`:1486`): "that test is next"; `docs/issues.md:1197` and `docs/STATUS.md:176` say it is
  answered (the silence is on the earbuds' side).
- U13: `docs/STATUS.md:101` gives the GNOME report to CO-27; CO-42 holds it (a comment on the
  existing #18 and !137, not a new report); the U13 section names neither. U29's section
  names none of CO-39 to CO-42.
- M-3 (`:707`) stops at "accepted 2026-10-08"; BT-9's header (`:789`) and "Next: replies"
  (`:818`) are stale but followed by a "Since:" paragraph.
- The "Evidence model" section (`:200-212`, `:358-363`, `:400-402`) still says "n = 2, both
  censored", "fifteen windows", and lists "whether stage 2 occurs at all without
  intervention" as unknown, with no "kept as written" banner; later exhibits (EX-025, EX-029,
  EX-033, EX-054) are untreated windows beyond that count.
- U10's "858 Dual Channel frames" against `contributions/README.md:53` (CO-08: every SBC-XQ
  test sound was single-channel) (likely).

**IS-08 (Low, register integrity):** M-1 and M-2 have rows in `docs/STATUS.md:84`, `:88` and
no section in `docs/issues.md`; U21 to U28, U30 and U31 have table rows only, and the file
does not say so; the M sections sit between BT-8 and BT-9; U8's section follows U9's.
`docs/issues.md:1752` cites the untracked `tmp/u16-dup-check/cmp.sh` as proof;
`:1913` gives `/root/exp/agent-work/u29-t1-a2dp-backport/`; elisions at `:905`, `:922`,
`:944`, `:1839`, `:1906`, `:1938`. Consistent: every BT-1 to BT-25 row has a section; every
U1 to U31 and X1 to X4 row is in both registers; BT-2 to BT-16 numbers, dates, commit ids and
exhibit numbers agree; no retraction of `BRIEF.md` §5 is re-asserted; the counts 87 (U14)
and 325 (U19) match their result files.

## 4. Summary

Written after every part was read. Ids refer to section 3. "Checked" means the lead reviewer
re-read the lines or re-ran the command; the rest are worker findings with quoted evidence in
the companion file (section 5).

### 4.1 What the review covered

| part | how | by |
|---|---|---|
| `README.md`, `BRIEF.md` | read in full | lead reviewer |
| `docs/STATUS.md` | lines 1–181 in full; 182–416 with long lines cut at about 500 characters | lead reviewer |
| `docs/issues.md` | lines 1–144 in full by the lead reviewer; 145–2056 by three workers against STATUS | both |
| `contributions/README.md`, `contributions/rd-2026-11-14.md` | head and tail by the lead reviewer; in full by a worker | both |
| `reviews/README.md` | in full | worker |
| `HISTORY.md` | in full | worker |
| `bin/`, `tools/`, `scripts/`, `devtools/`, `systemd/`, `etc/`, `install.sh`, `uninstall.sh`, `.github/` | every file, read not run | six workers |
| `tests/run-tests` (15,600 lines), `tests/README.md`, system tests | read, not run; about 2,500 lines of 10850–14000 skimmed | three workers |
| `evidence/` | index against all 97 exhibits, `results.tsv`, privacy scan | worker |
| `patches/`, `docs/` (other than the registers), `results/`, `retest/` | Markdown, patch headers, scripts | three workers |
| `contributions/` dossiers | Markdown, patch headers, notes, checksums; raw logs not read | five workers |
| `comms/`, `lessons/` | from 2026-10-15 in full, earlier skimmed | worker |
| tree-wide | relative links, backticked paths, wording scan, checksum files | lead reviewer |

Not done: nothing was run (no suite, no tool, no installer); raw logs, captures and VM output
(about 130 MB) were opened only to verify a quoted number; the correctness of the patches'
code was not reviewed; upstream facts (lore, patchwork, kernel.org) were not re-fetched; the
109 outside reviews under `reviews/` were not read; commit ids that are not among this
clone's 50 commits could not be resolved.

### 4.2 The findings that matter most

**A. A reader who follows the hand-off today would send the wrong files.** (S-01, C-02, C-04,
C-05, checked.) On 2026-11-14 after 13:23 the outside review of that day was answered in new
directories (`review-fixes-20261114/` in CO-04, CO-05, CO-21, CO-35;
`send-v2-review-fixes-20261114/` in CO-02; `A-review-fixes-20261114/` in CO-43;
`patch1-standalone-20261114/` in CO-20; also newer packages in CO-23 and CO-11). Several say
in their own README that they replace the earlier package. `BRIEF.md`, `README.md`,
`docs/STATUS.md`, `contributions/README.md` and `contributions/rd-2026-11-14.md` name only the
earlier packages as "ready to send", none of which is marked superseded. For CO-43 the
dossier itself says patches 2 and 3 of the series are held because patch 3 breaks the
system-resume rebind, while STATUS and BRIEF describe the series as awaiting review only. The
one document for outside reviewers (`reviews/2026-11-14T0300Z-…`) embeds the earlier files;
its 53 checksums match the tree, so it is consistent with itself and out of date as a
description of what would be sent.

**B. The same fact is kept current in about ten places, and they have drifted.** (S-12, with
F-01 to F-07, S-02 to S-05, S-13, IS-01 to IS-04, R-01, C-03, C-07, D-02, PA-01, M-02.)
`docs/STATUS.md:414-416` forbids a second "current" paragraph; there are current-state texts
in `README.md`, two in `BRIEF.md`, six stacked in `docs/issues.md`, one in
`contributions/rd-2026-11-14.md`, one in `reviews/README.md`, every dossier's front page, and
three layers inside STATUS itself. Examples of the drift: BT-16 is "twice" in `README.md` and
three times elsewhere; BT-9's row says "not yet released for 6.1" and "released in 6.1.191"
in adjacent cells; BT-24 and BT-25 are "not reproduced, no fix" in `docs/issues.md` and
reproduced and fixed in STATUS; U24's fix is "not released" in three registers and in 5.88
per the 11-14 checks; the machine runs `-42` with E3 in `README.md` and `-43` stock in
`BRIEF.md`; the watchdog's demonstrations are "three" in `install.sh` and "two" in
`README.md`; the archive budget is 10 GB in `BRIEF.md` §7 and 20 GB in its state block; the
work areas are "whether to delete" in `BRIEF.md` and deleted in STATUS. Corrections are
applied to one cell or one file and marked "corrected <date>" there; the copies stay.

**C. Three pieces of code can do what the project's first rules forbid.** (Checked.)
- `uninstall.sh:284-308` unloads and reloads btusb (I-01) and `scripts/runtime-mgmt-test.sh`
  still swaps `bluetooth.ko` (K-01); `BRIEF.md:60-63` says never, with `EX-046` as the reason.
- `tools/bt-backup-journal` with `tools/bt-archive --replace` can replace a journal prefix by
  a shorter export without comparing the two (T-08); `BRIEF.md:414` puts evidence first.
- `tools/bt-sco --window` and five other tools, and `tools/bt-exhibit new`, loop forever when
  a two-word option is the last argument (T-01, T-11).

**D. Several checks return a clean answer when they could not look.** The project's own rule
(`BRIEF.md:586-589`). `devtools/repo-save` compares the commit identity with the checkout's
configuration, not with the author (G-01, checked); `scripts/sco-ledger.sh` prints "0
timeouts" for a boot it could not read (K-04); `tools/lib/trial-summary.awk` counts a
`failed` row as a survival and nine of eleven E3 rows are such rows (T-10, E-02, checked);
`tools/bt-diagnose` exits 0 for "cannot determine" (T-03); `scripts/smtp-login-check.sh`
reads a network error as "revoked" (K-03, checked); gates in `devtools/` and `scripts/` that
exit 0 when their tool is missing (G-02, K-04); about fifteen assertions in `tests/run-tests`
that cannot fail (T-07, T-12, T-13).

**E. The working arrangement is written into the repository.** (Section 3.2, S-11, S-13,
M-02.) The work-area path is in 2,716 tracked files; `BRIEF.md`, `HISTORY.md`,
`docs/STATUS.md` and `comms/` describe workers, lanes, sessions, a session-start hook and a
private procedure in plain words; three files carry product names or tool-specific paths;
the filters that exist run only where someone remembered them, and `devtools/repo-scan` has
no such pattern. Because most of the lines are in logs already pushed, removing them is a
history question (`BRIEF.md:415-420` on force-pushes applies) and a decision for the author.

**F. The evidence core is sound where it was checked.** The 97 exhibits and their index
match one to one; eleven of the twelve rows of the signature table agree with their exhibits
(E-01 for the exceptions: the survival row's "8" and EX-042's "~90 ms"); the E1/E3 totals,
the 159 VM logs, every send record, Message-ID, patchwork id and commit id, the SHA-256 of
every sent mail, the eleven BlueZ commits and the stable release lists agree across the
documents; `HISTORY.md`'s structure and every retraction note are as `BRIEF.md` says; no real
device address, BSSID, IP or key was found in `evidence/`, `tests/`, `docs/`, `results/`,
`patches/` or `scripts/`; no relay header in any tracked mail; 588 relative links resolve.

### 4.3 Counts

Findings recorded in section 3, by the severity defined in 1.4 (a finding with several
bullets counts once):

| severity | ids |
|---|---|
| High | P-01, P-02, P-03, S-01, T-01, T-08, I-01, C-02, C-04, C-05, G-01, K-01, K-03, M-01, IS-02 |
| Medium | F-01, F-02, F-03, F-06, F-07, P-04, S-02, S-03, S-04, S-06, S-10, S-11, S-12, S-13, T-02, T-03, T-04, T-05, T-07, T-09, T-10, T-11, T-12, T-13, E-01, E-02, E-03, R-01, D-01, D-02, C-01, C-03, C-06, C-07, I-02, I-03, I-04, I-05, G-02, H-01, K-02, K-04, K-05, M-02, PA-01, IS-03, IS-04, IS-06, IS-07 |
| Low | F-04, F-05, F-08, F-09 (resolved by PA-01), F-10, F-11, F-13, S-05, S-07, S-08, S-09, S-14, T-06, E-04, R-02, L-01, IS-01, IS-05, IS-08 |

### 4.4 Suggested order of work (for the author to decide; nothing was changed by this review)

1. Before any send: one line per package in `BRIEF.md`'s hand-off and in
   `contributions/README.md` naming the directory that is to be sent, and a "superseded by"
   line at the top of each older package's README (A).
2. The three safety items in code (C): a refusal in `uninstall.sh` and
   `scripts/runtime-mgmt-test.sh`, a record-count comparison before `bt-archive --replace`,
   and `|| exit 2` after each `shift 2`.
3. `devtools/repo-save`: a fixed identity, as CI has (G-01).
4. One place for "current": make the README's direction block, the BRIEF state block, the
   issues.md current-state blocks and the dossier front pages point at STATUS rows instead of
   restating them, or generate them (B).
5. The clean-answer defects (D), starting with `sco-ledger.sh`, the trial summary and
   `bt-diagnose`, because published numbers rest on them.
6. The author's decision on E, with the list in 3.2 as the inventory.

## 5. Companion file

[`review-comprehensive-project-consistency-review-20261115-005742-detailed-findings.md`](review-comprehensive-project-consistency-review-20261115-005742-detailed-findings.md) holds every worker finding as written, with the quoted lines, about 340 KB.
Where this report and the companion differ, this report is the later reading.

