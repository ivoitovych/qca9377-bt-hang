# Front-door review — 2026-09-17T2251Z

**Covers:** the tree at `0f25bea` (`origin/main` tip, 2026-09-18 "BRIEF: back to 200 lines").
**Branch:** `review/2026-09-17T2251Z`. **Predecessor:** `2026-09-16T0420Z-comprehensive-code-review.md`
(every file, at `3cf4dd6`) and the maintainer's reaction
`comms/2026-09-16T2300Z-…`, which closed R2-01/R2-100, R2-58, R2-76, R2-114, R2-117 and
parts of R2-04/R2-105.

**Scope and method.** Not every file — five: `README.md`, `BRIEF.md`,
`patches/bluez/README.md`, `docs/bug-report.md`, `docs/issues.md`, plus the two patch
files. Each is read twice, as two strangers: **(M)** a BlueZ or kernel maintainer who has
just received the patches by mail and opened the repository to see where they came from
and whether the runtime claim holds; **(U)** a person with a Bluetooth fault on a
different controller, headset or distribution, deciding in two minutes whether this
project helps them. Findings are `FD-nn`, appended per file; the deliverables — a README
skeleton, the patch mail-body note, and the order of work — are §7, written last.
Severity: **HIGH** (a reader is misled or turns away), **MED** (a reader has to hunt),
**LOW**, **NOTE**, **GOOD** (keep).

## 0. What the two readers arrive with

**(M)** arrives from a `[PATCH BlueZ]` mail. They want, in this order: is the fix
correct (the commit message must carry that alone); has the guard ever fired (EX-041,
four times); what hardware and what circumstances (one paragraph); and, only if curious,
how the crash site was found in a stripped binary. They will spend two minutes on the
front page. They will not read HISTORY.

**(U)** arrives from a search for "Bluetooth stops working Linux" or a `command tx timeout`
line in their own journal. They want: is this my hardware; if not, is this my symptom; can
I run one thing to find out; what does it cost to try; what transfers if my controller is
different.

Both want the same three things on the first screen: what this is, what is established
now, and where the evidence is. Neither wants to be told which sections are stale.

## 1. `README.md` (746 lines)

- **FD-01 [HIGH] The page disowns 660 of its own 746 lines, and both readers hit the
  disowned part on their second screen.** Line 79: "Sections below this point were written
  earlier and are being rewritten … treat `BRIEF.md` as authoritative". What follows is
  the retired model presented in the present tense: "Established driver mismatch" (line
  159, the missing-quirk thesis), "A candidate fix" (443, the one-line `BTUSB_QCA_ROME`
  patch, with a `REVIEWED-KEEP` marker protecting its hedges), the `BT_EARLY` watchdog
  section (372) built on precursors the project has refuted, and a Status table (608)
  whose rows are from the `n = 2` era. **(M)** reads the good patches paragraph at line
  30 and, scrolling for the hardware context, meets a kernel patch the project no longer
  proposes. **(U)** reads "Install … `--apply` — install and arm" (247) two screens after
  being told the armed watchdog has "three controlled demonstrations of destroying the
  controller". A front page cannot carry a section it tells the reader not to trust; the
  rewrite the banner promises is the whole fix, and §7 gives the skeleton.
- **FD-02 [HIGH] Nothing on the page is written for the reader who arrives from a patch.**
  The patches paragraph (30–38) is accurate and well placed, but it does not link EX-041,
  the crash-site review, or say how the patches were verified (checkpatch clean under
  BlueZ's own config, `git am` clean on master both orders); those live in
  `patches/bluez/README.md`, which the paragraph links only by directory. **(M)** wants,
  on this screen: the two subjects, "fired four times, EX-041", "resolved from the
  stripped binary, `reviews/2026-08-23T2340Z`", "how to re-check". Six lines.
- **FD-03 [HIGH] The Status table contradicts BRIEF and contradicts the page itself.**
  "Kernel patch ❌ written, not built or tested" — that is the retired quirks patch;
  BRIEF §1 says no kernel patch exists. "Failure localised to synchronous-audio link
  transitions ⚠️ … `EX-006`, `EX-009`" — the two-instance reading, now seven with a
  named invariant. "Observational denominator ✅ re-derivable — 34 boots, 287 timeouts"
  (621) against "⚠️ That baseline is no longer re-derivable" (344) — the same
  contradiction R2-05 reported on 09-16, still on the page. The **"strongest current
  lead"** paragraph below the table ("not a single command … what the two failures share
  is the transition") is the 08-15 statement. A status table on a front page must be
  generated from, or be a copy of, BRIEF §2/§3 — never a third hand-kept version.
- **FD-04 [MED] For (U), reuse is stated once, at line 647, after the install and
  watchdog material.** "All work with any USB Bluetooth controller, not just 13d3:3503"
  is true of `bt-diagnose`, `bt-state`, `bt-boots`, `sanitize-logs.sh`, and of the
  incident/exhibit/fault-window discipline, and it is the sentence a stranger with a
  Realtek or Intel part needs on the first screen. The only "Different controller?"
  heading (317) is about installing the watchdog with `BT_VID`/`BT_PID`, on a page that
  warns the watchdog destroys this controller. Two paragraphs are missing: "if your
  hardware differs, this transfers: …" and "if your symptom differs, this project
  separates four failure modes that look identical; here is how to tell which you have".
- **FD-05 [MED] No branch map, no CI, no register.** The layout tree (552) is good for
  directories and silent on branches: `main`, `review/*` (report + reaction, per the
  convention in `reviews/README.md`), `claude/unit-testing-intro-*` (the test-suite
  maintainer's line, currently 9 commits past its merge), the evidence and verify
  branches. A maintainer who runs `git branch -r` sees 19 branches and no legend. Nor is
  there a sentence on CI (`.github/workflows/checks.yml`, green since 09-16, read by
  `devtools/ci`) or on `reviews/README.md` as the live action register.
- **FD-06 [MED] Retired numbers remain load-bearing.** "287 timeouts across 34 boots"
  appears four times; the "Not a *recent* regression" table (509) lists four kernels
  with "Hangs? yes" for the old phenotype while BRIEF's signature table carries the
  three kernels that matter; the `BT_EARLY` lead-time table (409) and the "five for five"
  late-reset count are watchdog-era measurements the page itself calls historical and
  not re-derivable. Each is true as history and wrong as a front page.
- **FD-07 [LOW]** `docs/issues.md` is labelled "the AUTHORITATIVE current claims" in the
  layout block (565) and "not kept current past `EX-021`" at line 79. The Contributing
  section asks for "confirmation that the patch works, if you build it" and "whether
  13d3:3503 is present in the quirks table in current mainline" — requests for the
  retired model; the current one wants a ≤ v5.11 kernel run, other alt-1 controllers, and
  a `btmon` capture of an Enhanced Setup that survived.
- **FD-08 [GOOD]** Lines 1–60 are the right front page in miniature: the one-sentence
  symptom, the affected part, the three-stream table with where each lives, the
  seven-reproduction sentence, "four distinct failure modes that look identical". The
  layout tree, the Publishing-logs paragraph (reason with the rule), and the tests
  block's refusal to quote a number are all worth keeping verbatim. `REVIEWED-KEEP §1.1`
  markers intact — two of them now guard text that should leave the front page for
  `docs/`, which is a move, not a removal.

## 2. `BRIEF.md` (231 lines, 200 non-blank)

- **FD-09 [MED] README sends strangers to BRIEF as "authoritative", and BRIEF is a
  working-memory document addressed to the operator and the assistant.** Its title is
  "read this first, after any context reset"; §7 says "This section and §8 are the DURABLE
  copy … only in an assistant-side memory store", "Family laptop", "Verify operator
  accounts against logs — he asked not to be trusted", "Do not send the patches until the
  operator says so", and the transliteration note on the sign-off. All of that is right
  where it is, and none of it is for **(M)** or **(U)**. Sections 1–4 and 6 are exactly
  the public state; 5 (retractions) is valuable to a maintainer too; 7–9 are house rules
  and open threads. Either the README carries its own copy of §1–§3 and §6 (the skeleton
  in §7 does this, ~40 lines) and stops delegating, or BRIEF is split into a public
  `STATE.md` and an internal `BRIEF.md`. The first is cheaper and keeps the 200-line
  budget meaningful.
- **FD-10 [LOW] Four counts inside BRIEF are one step stale:** "`evidence/exhibits/`, 42 of
  them" (43; EX-043 is the newest exhibit named three lines later); §4 "Correlation across
  5 deaths / 1 survival" beside §2's `n = 7`; §10 "`HISTORY.md` (34 phases)" while Phase 36
  was added in the same commit series; §2 footnote "Both instances where the log names the
  dying command" is correct but §3's "read 5× during live wedges" and EX-042's "fourth
  direct read" / EX-043's "fifth" should agree (they do: 5) — noted only because the
  README says "five live wedges" and BRIEF §3 says 5×, so this one is consistent.
- **FD-11 [GOOD]** §1's statement, §2's table with the first-command column and the
  survival row, §3's settled list and §5's retraction table are the best 60 lines in the
  repository for a maintainer: the claim, the evidence per instance, and what was wrong
  before. §6 is the six-line "for maintainers" block README lacks (FD-02), already
  written. The "no tip hash here: it rotted" note is the right lesson applied.

## 3. `patches/bluez/` (README + 0001 + 0002)

- **FD-12 [HIGH] The mails carry no way back to the record.** Neither patch body, nor the
  "How to send" section, nor the README mentions the repository, EX-041, or the crash-site
  review. The README itself says of the falsification "**Worth citing in the submission** —
  a maintainer will reasonably ask how a crash site was located in a stripped binary", and
  the commit messages, correctly, no longer carry that route. So the one question the
  README predicts has no answer in what the maintainer receives. The place is the mail
  body **below the `---` line**, which `git am` discards and BlueZ's `HACKING` rules do not
  govern; `git send-email --annotate` or a `format-patch --notes` puts it there. Text in
  §7.2. Do not put it in the commit message: the rewrite on 09-16 was right to strip the
  route, and a URL in a `Fixes:`-shaped position would be read as a bug tracker.
- **FD-13 [MED] The verification the README quotes is not re-runnable.** "`$ bash
  git-am-check.sh  # scratch worktree of the BlueZ tree at c73fa2f9a`" — the script is not
  tracked (`git ls-files` finds nothing), so the six PASS lines are a transcript of a
  command a reader cannot run, which is the exact thing `evidence/exhibits/` exists to
  prevent. Track it (under `patches/bluez/` or `devtools/`), or replace the block with the
  five plain commands it wraps.
- **FD-14 [MED] For (M), the README's order is the project's order, not the reader's.**
  The first screen after the table is the mechanism caveat for 0001 (what an earlier
  revision got wrong about Command Status); "What has been verified", the runtime evidence,
  prior art and how to send come after. A maintainer's order is: environment (QCA9377
  `13d3:3503`, Ubuntu 24.04, `bluez 5.72-0ubuntu5.5`, BlueZ master `c73fa2f9a`), the
  two subjects, runtime evidence (0002 ×4, 0001 premise seen once), verification
  (checkpatch, `git am` ×4), prior art, how to send — then the history notes ("an earlier
  revision said…", the `lore` 403 story, the `--depth 50` trap) under one heading at the
  end. Nothing needs rewriting; the sections need moving.
- **FD-15 [LOW]** "Built against BlueZ 5.87 … `--disable-*`" is the compile check; the
  runtime evidence comes from the `5.72-0ubuntu5.5` rebuild running on the machine, which
  the README does not say in one place — the maintainer will want to know the guard that
  fired four times is in the 5.72 build, not a 5.87 one. One sentence.
- **FD-16 [GOOD]** Both commit messages are as good as this class of patch gets: the
  defect shown in the code, the crash line and the disassembly, the runtime firings stated
  with dates and pointer counts, the two prior hardenings cited for what they did and did
  not cover, no claim about which mgmt event arrived. The conventions section measured from
  BlueZ's own tree (no `Signed-off-by`, 50/72, `[PATCH BlueZ]`, `Fixes:` usage) and the
  "two invocations, not a range" warning are exactly what a first-time submitter gets
  wrong. The runtime paragraph separating 0002 (watched) from 0001 (premise seen, guard not
  fired) is the honest statement R2-117 asked for.

## 4. `docs/bug-report.md` (699 lines)

- **FD-17 [HIGH] The report argues for the fix the project no longer proposes, and against
  the evidence it now has.** Title: "`13d3:3503` is absent from the QCA ROME quirks, so it
  gets neither firmware setup nor a reset callback". Proposed fix: "Add `13d3:3503` to
  btusb's QCA ROME quirks entries". The report's own body then spends two sections
  establishing that the reset this entry would install "destroyed a device that was
  otherwise stable and enumerated" in two controlled tests, and that "this report does not
  recommend it as a fix". A maintainer reads a title that asks for X, a body that shows X
  is harmful, and a "Proposed fix" that asks for X. Meanwhile BRIEF §1 has the finding a
  maintainer could act on — alt-1 fallback, first command into the stream dies, `n = 7`,
  regression candidate v5.11→v5.12 — and the report does not contain the string `alt` in
  that sense at all. R2-25 named the timing line; the whole document is the finding.
- **FD-18 [HIGH] Two blocking banners with no owner.** "⛔ Do not send this without
  working through `pre-submission-checklist.md`" and "🔬 Under active revision … Do not
  submit this report until [the firmware hypothesis] is resolved — it may change the
  framing substantially". The firmware hypothesis was the pre-alt-1 explanation for
  Windows; BRIEF does not list it among open threads. A document that tells its reader
  twice not to send it, for a reason the project has moved past, is a document nobody
  will send. BRIEF §7's rule is the actual gate: the kernel report goes only with its
  patch. Say that once, at the top, and remove the two stale gates.
- **FD-19 [MED] Numbers and counts inside the report disagree with BRIEF and with each
  other.** "SCO setup → first timeout is a distribution, not a constant: 7.6–16.2 s across
  n = 4" (R2-25; measured 2.076–2.191 s in six instances and 11.874 s in the seventh,
  from a different anchor). "Regression: No" in the header against BRIEF's v5.12
  regression candidate. "Kernel 7.0.0-28 … also 6.17.0-29/35/40" against the three
  kernels of the signature table. The `hci_cmd_timeout` root-cause section is correct as
  far as it goes and is now the second-order story. The five-window terminator table
  (EX-016/021/023/025/029) is good and current, and survives a rewrite intact.
- **FD-20 [MED] The report is written to a subsystem list that will read it cold, and
  it opens with a correction history.** Four "earlier revisions of this report said…"
  passages, a `REVIEWED-KEEP` HTML comment, and internal labels in a document BRIEF §7
  says must carry none (checked: no `BT-1` in the body — that gate holds; the marker
  comment is invisible when rendered but visible in the mail). A submitted report should
  be the current claim, the evidence per instance, the reproduction shape ("put the link
  on alt 1, stream, issue any command"), the environment, and what has been ruled out —
  in that order, without its own revision history. HISTORY.md holds the history.
- **FD-21 [GOOD]** The Windows framing ("Linux drives this controller into a state that
  Windows does not", with fault assignment left open) and its `REVIEWED-KEEP` reason;
  the methodological caveat ("the reproductions were not a controlled procedure"); the
  two-headset table (EX-024); the "an intervention can look harmless and not be" bullet
  (EX-034); the system-information block; the re-derivable baseline command. These are
  the paragraphs a rewrite keeps.

## 5. `docs/issues.md` (503 lines)

- **FD-22 [HIGH] The register that README calls "the AUTHORITATIVE current claims" stops
  at EX-021 and says nothing about the finding.** BT-1's body is the two-stage debate of
  mid-August: "Both instrumented failures involve SCO link handling — setup unanswered in
  one case (`EX-006`), teardown unanswered in the other (`EX-009`)"; "the right-hand branch
  has been walked twice … `n = 2`, both censored"; "the leading discriminant … at least five
  logically distinct possibilities"; "the experiment that settles it … do nothing" — an
  experiment since run seven times (EX-023, EX-025, EX-029, EX-042: 3 h 22 m, 2 h 28 m,
  13 h 9 m, 11 h 12 m, all with zero USB-layer lines). The word `alt` appears only inside
  "alternate-setting switch" as one of five candidates. There is no entry for the alt-1
  fallback, none for the `bluetoothd` crashes (EX-032, two patches — R2-22), and BT-5
  ("SCO link established, then carries almost no data … observed once") is now answered
  by EX-043's stream running 9.65 s unharmed. R2-21 stands, and it is the register a
  maintainer is pointed at.
- **FD-23 [MED] BT-3 still says the missing quirk "may be the cause of BT-1".** BRIEF §3
  has moved it to "no software recovery exists: `hdev->reset` is NULL" — a consequence for
  recovery, not a cause. The entry's both-directions argument (`REVIEWED-KEEP §1.3`) is
  still the right shape; its status line and first paragraph are not. BT-4 (btmon aborts)
  is genuinely still open and correctly separated from EX-032; BT-2 is still the easiest
  thing to report and nobody has.
- **FD-24 [MED] For (U), the two most useful passages are at the bottom of the file
  nobody is sent to.** "Why this class of bug goes unreported" (rare per user, recovery
  destroys the evidence, default logging insufficient, instrumentation costs more than
  the bug seems worth) and "On the wider claim" (what the Windows and Android comparisons
  do and do not support) are exactly what a stranger with a different controller needs
  to decide whether the method transfers. They belong on the front page, shortened.
- **FD-25 [GOOD]** The evidence model (three-state reading of two capture paths; the probe
  is an intervention; the six levels a timestamp must survive) is the project's method in
  one page and is current. The four-alternative A–D framing and the "experiment that
  settles it" were right when written and have since been run, which is the best fate a
  register entry can have — it needs closing, not deleting.

## 6. Cross-cutting — the two readers, scored

| what the reader needs on the first screen | (M) maintainer | (U) different controller |
|---|---|---|
| what this is, in a sentence | ✅ line 3 | ✅ |
| what is established now | ✅ lines 40–48 … then ❌ contradicted by 159–633 | same |
| where the evidence is, two clicks | ⚠️ `evidence/exhibits/` linked; index fixed (R2-114) | ⚠️ |
| the patches: what, fired?, verified how | ⚠️ paragraph, no EX-041 link, no verification | — |
| how the crash site was found | ❌ not linked from README or from the mails (FD-12) | — |
| reproduction shape | ❌ only in BRIEF §9.1 / EX-043 | — |
| environment (distro, kernels, bluez) | ❌ only in `bug-report.md` §System information | ❌ |
| does this transfer to my hardware / symptom | — | ❌ one sentence at line 647 |
| what to run first | ✅ `bt-diagnose` at line 86 | ✅ |
| branch map, CI, register | ❌ | ❌ |
| the retired model presented as current | ❌ 660 lines | ❌ |

Five of the eleven rows are answered by material that already exists in BRIEF §1–§3 and
§6, `patches/bluez/README.md` and `docs/issues.md`'s last two sections. The front-door
problem is placement, not absence: the project has written everything both readers need
and has not put it where they look.

## 7. Deliverables

### 7.1 README skeleton (≈150 lines; everything else moves to `docs/`)

```
# qca9377-bt-hang
<one-sentence symptom>  ·  <part, USB ID>  ·  <"an open investigation aimed at an upstream fix">

## Status (<date>, EX-043)            ← copy of BRIEF §1 statement + one line "n = 7, three
                                         kernels, two peripherals, both power configurations";
                                         one line: what is NOT established (mechanism);
                                         one line: no kernel patch yet, two BlueZ patches ready

## For maintainers                    ← BRIEF §6 verbatim: the two subjects, 0002 fired 4×
                                         (EX-041), 0001 premise seen, checkpatch + git am,
                                         crash site resolved from the stripped binary
                                         (reviews/2026-08-23T2340Z), how to re-check; the
                                         reproduction shape ("alt 1, stream, issue a command")

## The evidence                        ← three-stream table (keep); the signature table from
                                         BRIEF §2; "each exhibit carries its command, verbatim
                                         output and exit status"; link the index

## Is this your problem?               ← bt-diagnose block (keep); the four failure modes that
                                         look identical (EX-030/031/032 + the wedge) and which
                                         tool tells them apart; "if your controller differs:
                                         what transfers" (bt-diagnose, bt-state, bt-boots,
                                         sanitize-logs, bt-incident, bt-exhibit, the journal
                                         seam; what is QCA-specific); "why this class of bug
                                         goes unreported" in four lines

## Environment                          ← the System information block from bug-report.md

## Method, in five rules                ← every claim ships with its command; zero needs a
                                         positive control; the probe is an intervention;
                                         separate what the operator did from how the controller
                                         responded; retractions are kept (BRIEF §5)

## Repository map                       ← the layout tree (keep) + a branch legend (main;
                                         review/<ts> and its reaction; claude/unit-testing-*;
                                         evidence/*, verify/*, backup/*) + CI + reviews/README
                                         as the live register

## Install / tooling / tests / contributing / license
                                         ← three lines each, linking docs/install.md (the
                                         current Install, --tools-only, tunables, BT_EARLY
                                         and watchdog material, moved whole with its
                                         REVIEWED-KEEP markers), docs/tooling-index.md,
                                         tests/README.md; Contributing asks for a ≤ v5.11
                                         run, other alt-1 controllers, a survived Enhanced
                                         Setup capture
```

Rules for the rewrite: no number on the page that is not in BRIEF §2 or re-derivable by a
printed command; no section the page tells the reader not to trust; no `BT-n` label without
its plain name first; the Status block is a copy of BRIEF §1, dated, and `devtools/save`'s
BRIEF check extends to it ("does README's status name the newest exhibit?").

### 7.2 The note below `---` in each patch mail (FD-12)

```
---
Context, not part of the change: the crash was recorded on a QCA9377
(13d3:3503) laptop under Ubuntu 24.04 / bluez 5.72-0ubuntu5.5 and the
site was resolved from the stripped distro binary, then checked against
a retained core. The record, including the four logged firings of this
guard (EX-041) and the crash-site method, is public:
https://github.com/ivoitovych/qca9377-bt-hang  (patches/bluez/README.md)
```

Adjust the second sentence for 0001 ("the guard has not fired; its premise was logged once,
see patches/bluez/README.md"). Insert with `git send-email --annotate` or `git format-patch
--notes`; never above the `---`, never as a trailer.

### 7.3 Order of work

1. README rewrite to §7.1 (moves, not deletions; `docs/install.md` receives the watchdog
   material with its markers). Gate: `repo-scan`, the label test, and a new `devtools/save`
   line that README's status names the newest exhibit.
2. `docs/issues.md`: close BT-1's stage-2 question with the four windows, add the alt-1
   entry and the EX-032 entry, restate BT-3, close BT-5 against EX-043 (FD-22/23).
3. `patches/bluez/README.md`: reorder to the maintainer's order, track the verification
   script, add the 5.72-build sentence (FD-13/14/15); then the mail-body note (7.2).
4. `docs/bug-report.md`: rewrite around BRIEF §1–§3 with the terminator table, the
   two-headset table, the Windows framing and the environment block kept; one gate at the
   top ("goes only with its patch"), no revision history (FD-17–20). This is last because
   BRIEF §7 says it does not leave without a kernel patch, and there is none.

### 7.4 Is a deeper review needed now?

Not a comprehensive one. The tree at `0f25bea` is two days past a full review whose
reaction is still landing, and every finding above is a placement or currency problem in
five files, not a defect in the tools or the evidence. The next full review is due after
items 1–3 land and before the BlueZ patches are mailed — that is the tree the maintainers
will open, and it should be reviewed once as the thing they will see. A short check that
the README skeleton was followed (one hour, the eleven rows in §6 as the checklist) is
enough in between.

**Findings:** 25 — 6 HIGH, 9 MED, 3 LOW, 7 GOOD. No source file changed on this branch;
register row and action block added to `reviews/README.md`.
