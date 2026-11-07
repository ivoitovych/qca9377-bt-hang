# Documentation alignment review — 2026-10-28

**Scope.** The foundation documents (`README.md`, `BRIEF.md`, `docs/STATUS.md`, `HISTORY.md`,
`docs/issues.md`, `contributions/README.md`) and the significant subdirectory READMEs
(`contributions/*`, `patches/*`, `results/*`, `devtools/`, `reviews/`, `docs/mesh-tester-ci/`,
`evidence/`, `scripts/`, `tests/`, `comms/`, `lessons/`), checked against facts re-verified the
same day from their primary sources (git, patchwork, kernel.org, Launchpad, the laptop):
`tmp/doc-review-20261028/facts.md` (F1–F17). The core documents were read in full by the main
maintainer; HISTORY's October chapters, `docs/issues.md` and the subdirectory READMEs by six
low-cost reviewers given the same facts. **Every reviewer finding was verified against the file
before it counted**; findings that were only dated statements, true on their date, were
discarded (for example HISTORY's "A1 and A2 are still `new`" at 10-19 22:36 UTC, which is what
patchwork showed then).

**Method for each finding:** where it is; the evidence it is wrong (the fact or the line it
contradicts); **why it happened** (from `git log -S`, the commit that should have touched it, or
the machine's journal); the fix. Nothing was "fixed from whatever is another": the correct side
was taken from the primary source each time.

## Findings

| # | where | what was wrong | cause (investigated) | fix |
|---|---|---|---|---|
| D1 | `README.md` badges, intro | "BlueZ: 8 applied", "eight BlueZ commits", "3 backports, 1 released" | A1/A2 were applied 2026-10-19 and 6.6.160 released 10-21; the commits recording them, `2a687e9` (10-20) and `c3bb813` (10-23), were scoped "STATUS, BRIEF"; README's last content change was `4522ae3` (10-18) | 10 applied; 2 released; the cleanups row added |
| D2 | `README.md` "Submitted 2026-10-18, waiting for review" | A1/A2 applied 10-19 | as D1 | replaced by the CO-02 submission of 10-27 |
| D3 | `README.md` accepted and backport tables, QCA9377 result, "If you have a QCA9377" | 6.6 named as a release candidate; the 6.6.160 release (10-21) missing | as D1 | 6.6.160 added everywhere; Ubuntu `-42` named |
| D4 | `README.md` "Current direction — 2026-10-18" | CO-02 (sent 10-27), CO-10, BT-10–13, `-42` absent; "an Ubuntu request is next" contradicts CO-09's "waiting" | as D1; the line about Ubuntu was never revisited after CO-09 was opened (10-21) | rewritten as of 2026-10-28 |
| D5 | `README.md` Environment | no mention that the laptop runs the CO-02 `bluetooth.ko` since 10-23 | the install (10-23, `880821d`) was recorded only as a BRIEF hand-off item | added (`EX-071`) |
| D6 | `README.md` repository map | `contributions/`, `results/`, `patches/kernel`, `patches/diag`, `patches/mesh-tester`, `patches/wireplumber`, `cache/`, `tmp/` absent | directories added after the map was written (contributions/ on 10-21) without a map update; nothing checks the map | added |
| D7 | `BRIEF.md` state block "(2026-10-18)" | "6.6 … release candidates", 10-20 "waiting for replies", an operator-decision list from 10-18; no CO-02 send | every BRIEF commit since 10-18 appended a "New, date" item to the hand-off instead of editing the state block; `c3bb813` (10-23) added "6.6.160 released" as a new item 60 lines below the block that still said "release candidates" | state block rewritten as of 10-28 |
| D8 | `BRIEF.md` hand-off | eight stacked "New, date" items, 10-18 to 10-23, including superseded CO-02 v1/v2 items — against BRIEF's own rule ("one hand-off block, not a stack") | as D7: `scripts/brief-handoff-to-history.py` was last run on 10-18 | the block moved verbatim to `HISTORY.md` with the script; a fresh block written |
| D9 | `BRIEF.md` "Last updated" | dated 10-22 while the block held 10-23 items; a running list of every update since 10-14, about 2,800 characters; "newest exhibit EX-064, next EX-067" while exhibits run to EX-083 | the line was extended at each update rather than replaced; the exhibit number was not updated by the CO-02 sessions (EX-065 to EX-083); `devtools/save` warned "BRIEF.md does not mention EX-083" at every save on 10-28 | replaced by a short line naming EX-083 |
| D10 | `BRIEF.md` hand-off, `docs/issues.md` U15 | AI tool or model names: "four Sonnet workers"; "`CLAUDE.md`" (PipeWire's contributor-rules file) | written on 10-21 and 10-23 before a check for such names existed on the save path | neutralised (before the hand-off was moved, so HISTORY does not carry them) |
| D11 | `BRIEF.md` §3, §6, §9.7, §10 | 6.6 "release candidates"; "watch the v2 patchwork states" though the a2dp v2 was applied on 10-07 and its duplicate removed on 10-19; HISTORY "dated chapters to 2026-10-18" | §3/§6/§9 are not touched by the per-event updates (D7); the a2dp v2 application was recorded in `patches/bluez/README.md` and STATUS only | corrected, with "since" notes |
| D12 | `docs/STATUS.md` header "As of 2026-10-21" | rows changed on 10-23 to 10-28 under an old date | the date line was not part of the per-row edits | 2026-10-28, with what was re-checked |
| D13 | `docs/STATUS.md` machine section | no mention of the CO-02 module (since 10-23), trial E3 #3, or `-42` | the CO-02 hardware run was recorded in the U7 row and the dossier (`ee52148`), the install in BRIEF's hand-off; the machine section is updated only by machine-focused sessions | added from `scripts/module-updates.sh status` and `journalctl --list-boots` |
| D14 | `docs/STATUS.md` desktop capture paragraph; BRIEF's decision list | "recorders inactive (read 10-18)"; "restarting … the recorders" as an open decision | `bt-ui-capture start` ran on 2026-10-23 at 22:12:30 (`bt-mark`: "ui-capture START session=20261005T003712Z"; `systemctl show`: both units active since that second), during the CO-02 hardware run, and was **never recorded** (`git grep` finds no note) | paragraph rewritten from `bt-ui-capture status` of 10-28 |
| D15 | `docs/STATUS.md` BT-1, BT-8, BT-9 rows and five "next" cells | 6.6 as release candidate; "watch the 6.6.160 … releases" | as D7/D12: the 10-23 update changed the submission rows only | corrected |
| D16 | `docs/STATUS.md` U7 row | "Next: the operator reads the mails; then the operator's send" | the send day (`335812f`) updated the submission row only | marked sent |
| D17 | `contributions/CO-02-…/README.md` | "the package to send is `patch/v6/send/`", "Not sent", "Next: the operator's send" | last changed `34db728` (10-26); the send commit `335812f` (10-27) updated `log.md` and STATUS only | a dated SENT state on top; the old state kept below |
| D18 | `contributions/README.md` CO-02 row | "v5 code final; run on the laptop done" | the index row was not part of any CO-02 commit after 10-23 | corrected (the first pass of 10-28) |
| D19 | dossiers CO-05, CO-06, CO-08, CO-10, CO-12, CO-27 | "Next" steps already done; CO-06 "evidence is ready" though its comparison predates `87a49b610708`; CO-08 an experiment its own log ruled out (joint stereo at 504 kb/s); CO-12 "not in mainline yet" (in mainline since this week's merge window); CO-27 without #2700 or U18 | each dossier's `log.md` is append-only and was updated; its front page (`README.md`) was not, because the log entry was the session's only write | each front page brought to its log |
| D20 | `docs/issues.md` BT-3 | "read as a consequence for recovery, not a candidate cause"; the entry "**not proposed**" — the pre-E1 position, contradicting BT-1 and BRIEF §0 | when E1/E3 settled the cause (09-26 to 10-01), BT-1 and the "Current state" were updated but BT-3's status paragraph was not | superseded note on top; the old text kept |
| D21 | `docs/issues.md` "BT-2 and BT-4 are reportable *today*" (written 09-18) | contradicted by each issue's own later section | a summary sentence in the evidence model, never revisited | dated note added |
| D22 | `docs/issues.md` BT-9 "Next: replies"; U17 "to be weighed before the series is sent" | both done | the register's per-issue "Next" lines stopped being maintained once STATUS became the current page (2026-10-03) | "since" notes |
| D23 | `docs/issues.md` | no sections for BT-10 to BT-13; the heading "U1–U10" over U1–U20; current-state blocks ending 2026-10-11; the intro's counts as of 10-11 | as D22: new issues were registered in STATUS and dossiers only | sections added; heading, counts and a 10-28 current-state block |
| D24 | `HISTORY.md` | no chapter for 2026-10-12 to 10-15 or 2026-10-23 to 10-28 | the BRIEF hand-off (D8) carried those days; the "BRIEF and HISTORY: the state of …" commits stopped at 10-22 | a 10-23 → 10-28 chapter; a pointer for 10-12 → 10-15 |
| D25 | `patches/bluez/README.md` l.124 | "the v2s are on the list with an open state", while l.100 of the same file records the a2dp v2 applied on 10-07 | the later paragraph was written before 10-07 and not revisited when l.100 was added | corrected; the adapter v2 checked still `new` |
| D26 | `patches/diag/README.md` E3 for `-38` | "not yet booted", "takes effect when -38 is first booted" | written 10-10; the boot of 10-11 was recorded in STATUS/BRIEF | a "since" note |
| D27 | `results/bt10-l2cap-hang-2026-10-23/README.md` | "Next: bisect" | done 10-28 (CO-35) | a "done" note |
| D28 | `devtools/README.md` | 17 scripts and directories without a row (`save`, `status`, `ci`, `held`, `hooks/` …) | added over September and October without a table row; nothing checks the table against the directory | rows added from each script's own header |
| D29 | `docs/mesh-tester-ci/README.md` | 18 files not named | ported in bulk on 10-09 with a README written for the reading order | listed |
| D30 | `reviews/README.md` | many reports have no row in its Reports table (e.g. `2026-09-26-source-review-report.md`, `2026-10-13T0200Z-u11-outside-research*.md`); several file names break its own `<UTC timestamp>-<topic>.md` convention | the register is updated when a reaction plan is opened, not when a report file lands | **open** (this report is added; the backfill is a separate pass) |
| D31 | about 140 lines in some 60 files (documents, notes, reviews, code comments) | "the family laptop", "household", mentions of a repository, branch or remote kept separately | written before the neutral-wording rule; the sweep of older text waited for the operator's decision | **fixed** on the operator's decision of 2026-10-28: "the laptop", "kept separately"; the tooling's remote keeps its name |
| D32 | CO-02 verbatim reviews (`contributions/CO-02-…/reviews/`) | outside reviewers' text on matters outside this repository's scope | verbatim records | **fixed** on the operator's decision of 2026-10-28: those passages cut |

## The causes, and guards that would have caught them

1. **Per-event updates scoped to two files** (D1–D5, D15): a fact changes in five places, and the
   commit touches the two its title names. *Guard:* when STATUS's submission rows change, the save
   step lists README's and BRIEF's lines that mention the same version or commit.
2. **Append instead of replace** (D7–D9, D24): BRIEF's hand-off and "Last updated" line grew for
   ten days; the replacement script existed and was not run. *Guard:* `devtools/save` already warns
   about the newest exhibit; it could also warn when the hand-off holds more than one dated "New"
   item, or when BRIEF's "Last updated" date is older than the newest STATUS change.
3. **The log is written, the front page is not** (D17–D19): a dossier session writes `log.md`
   and stops. *Guard:* warn when a dossier's `log.md` has an entry newer than its `README.md`.
4. **Registers outside the update loop** (D20–D23, D28–D30): `docs/issues.md`, the devtools table,
   the reviews register. *Guard:* a check that every `BT-n`/`U-n` in STATUS has a section, and that
   every file in `devtools/` and `reviews/` has a row.
5. **Machine changes not written down** (D14): the desktop capture was restarted with no record.
   *Guard:* the session-start state read (`tools/bt-snapshot`) could list the capture's units and
   compare them with STATUS.

None of the guards is built yet; each is a proposal for the operator and the test-suite maintainer.

## Open after this review

D30 (the reviews register's backfill).
