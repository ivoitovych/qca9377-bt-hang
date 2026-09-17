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
