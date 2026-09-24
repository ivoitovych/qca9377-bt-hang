# BRIEF — read this first, after any context reset

**What this is.** Internal working state for whoever resumes the investigation: what is
true, what is retracted, what is open — and the rules that were paid for, **with the why**.
A rule without its reason gets re-learned; that is what this file exists to prevent.

**What it is not.** Not evidence (`evidence/exhibits/`, 43 of them), not narrative
(`HISTORY.md`, 3000 lines), not tooling (`docs/tooling-index.md`), not working rules
(auto-loaded memory), and **not the public summary** — a stranger reads `README.md`, whose
Status block is a dated copy of §1–§3 and §6, checked on every commit like this file
(`FD-09`). Nothing here is derivable from those — it is the layer that says which holds.

⚠️ **Budget: 500 lines (~40 KB, ~10k tokens).** It was 200 until 2026-09-19; at 200 every
addition cost a *why* somewhere else (three trims in one day), and the operator's measure —
a post-compaction context of ~200k tokens — makes 10k for the one file that says what holds
cheap. Over 500 it stops being cheaper than the source. Cut the oldest settled item before
adding; never cut a reason to fit a fact. **Sections name their owner**; each owner writes
theirs and points at the long form (`lessons/`, `reviews/`) rather than reproducing it.

**Last updated: 2026-09-19 · newest exhibit: EX-043** — no tip hash: it rotted within hours (`R2-13`).

---

## 1. The bug, current best statement

> When the QCA9377 (`13d3:3503`) negotiates **transparent (mSBC / WBS)** SCO, `btusb` falls
> back to **USB alternate setting 1** — a **9-byte** isochronous endpoint — and sends each
> 27-byte SCO buffer as **three 9-byte packets** (`__fill_isoc_descriptor`; `len 27 mtu 9` is
> that split, ⚠️ not an overflow — `DR-02`). **The first HCI command observed after the
> stream starts gets no response** — `HCI_CMD_TIMEOUT` (2.0 s) after it, whether issued 34 ms
> or 9.65 s after link-up (`EX-043`); both named dying commands are `0x0406 Disconnect` — and
> the controller then answers nothing, including USB control transfers. Only a **full
> power-off** recovers it. Reproduced under stock power management (`EX-043`).

Introducing commit, verified at five tags by the test-suite maintainer (08-24, received
09-18): **`517b693351a2`** — Trent Piepho, 2020-12-09, *"Bluetooth: btusb: Always fallback to
alt 1 for WBS"* — ancestor of v5.12, not v5.11. Its message assumes adapters without alt 6
work on alt 1; this part has alts 1–5 and no 6 (its descriptors are also in `dc16388d45ec`),
so the fallback *applies* to it — whether it is *compatible* is the question (`DR-04`).
**Control window is v5.8–v5.11 only** (below v5.8 alt 1 is reachable via `new_alts = sco_num`).

## 2. The signature — `n = 9`, three kernels, two peripherals, both configurations
² self-built `bluetooth.ko` from `updates/` (srcversion `66D38200…`); signature unchanged.

```
0x0428 answered → evt 5 → "Looking for Alt no :6" → ":3" → len 27 mtu 9 (3×9-byte packets) → FIRST command observed → +2.0 s tx timeout
```

| exhibit | date | kernel | config | `len 27 mtu 9` | first cmd after link-up | setup→fault |
|---|---|---|---|---|---|---|
| `EX-033` | 08-22 | `-29` | modified | 835 | 36 ms | 2.076 s |
| `EX-036` | 08-25 | `-30` | modified | 87 | 279 ms (`0x0406`) | 2.152 s |
| `EX-037` | 09-01 | `-30` | modified | 680 | 39 ms | 2.151 s |
| `EX-038` | 09-13 | `-31` | modified | 682 | 35 ms | 2.191 s |
| `EX-040` | 09-13 | `-31` | modified | 1562¹ | 34 ms | 2.140 s |
| `EX-042` | 09-16 | `-31` | modified | 1595¹ | ~90 ms | 2.147 s |
| **`EX-043`** | **09-17** | `-31` | **original** | 910 | **9,650 ms** (`0x0406`) | **11.874 s** |
| **`EX-045`** | **09-22** | `-31` | **original** | 735 | (`0x0406`, reason `0x13`) | 2.018 s cmd→timeout |
| **`EX-047`** | **09-24** | `-31`² | **original** | 717 | (`0x0406`, reason `0x13`) | 2.053 s cmd→timeout |
| *survival* | 09-01 | `-30` | modified | **8** | — | *lived* |

¹ window-scoped. ⚠️ **The "2.15 s interval" was an artefact of six fast teardowns** (first
command 34–279 ms after link-up); the invariant is *first command + `HCI_CMD_TIMEOUT`*,
and `EX-043` shows the stream itself running 9.65 s without harm until a command is sent.
Both instances where the log names the dying command name `0x0406 Disconnect, reason 0x13`.

## 3. Settled

- **`0x0428` IS answered** — a connection handle is allocated every time.
- **alt 1 is directly observed**, not inferred — `sysfs` `bAlternateSetting 1` +
  `wMaxPacketSize 0009`, read 5× during live wedges (`tools/bt-usbstate`).
- **The first HCI command observed after the stream starts gets no response** (`EX-043`):
  none in flight for 9.65 s; the first issued died. ⚠️ Whether that command *wedges* the
  controller or *discovers* one the stream already wedged is **not established** (`DR-03`).
- **The original configuration reproduces it** (`EX-043`, `autosusp=Y, power=auto`, live).
- **The wedge is below HCI** — USB control transfers (`GET_DESCRIPTOR`) return `-110`.
- **Every recovery tried on an already-wedged controller failed** (`EX-039`); the one reset
  issued *before* any timeout recovered it, and it failed again 132 s later (`EX-004`).
  `hdev->reset` is NULL on the kernels run here — `13d3:3503` had no quirks entry ⚠️ **until
  `dc16388d45ec`** (master, 2026-08-07, for a BLE-scan fault; not in v7.0, 6.6.y, 6.12.y as
  checked 09-19) — and that entry's setup/reset path is **untested here** (`DR-01`).
- **`hci0` is never unregistered** (not the stage-2 shape); **the CVSD controls survived**
  (`mtu 17`, `EX-031`) — a statement about the observed controls, not a safety guarantee.

## 4. Not settled

- **Mechanism.** Correlation across 7 deaths / 1 survival. *How* the traffic wedges the
  controller is unknown — needs driver instrumentation or an mgmt/btmon trace.
- **No controlled comparison.** Nobody has forced alt-1 with a sustained stream on demand,
  or blocked alt-1 and shown survival under identical use. The survival was the
  peripheral's choice, not an intervention.
- **What decides WBS-sustains vs falls-back-to-CVSD.** This is the whole difference between
  death and survival and is not understood.

## 5. ⚠️ RETRACTED — do not re-assert these

| claim | status |
|---|---|
| "`BT-1` *is* `0x0428` submitted and never answered" | **FALSE as a general claim** — answered in all 5 alt-1 instances. ⚠️ But `EX-006` (Phase 19) did record one genuinely unanswered, so "never answered" is wrong, and "always answered" is too |
| "alt probes, then silence" (`EX-033`/`036`) | **FALSE** — artefact of those exhibits' own grep; data was flowing |
| "the dying command is anonymous *by construction*" | **OVERSTATED** — anonymous to the printk, not the log |
| "patch `0002`'s guard has never fired" | **FALSE** — fired 4× (`EX-041`); came from grepping one boot |
| "`EX-038` boot id `c128a59a`" | **FALSE** — it is `f5de8066`; value copied forward |
| "`evt 5` = Synchronous Connection Complete" | **FALSE** — it is `HCI_NOTIFY_ENABLE_SCO_TRANSP` |
| "`0x0428` means CVSD" | **FALSE** — air mode comes from the `btusb_notify()` value |
| "autosuspend mitigation works (0/4 vs 3/4)" | **FALSE** — `EX-038` wedged under `autosusp=N`. The split is chronological **because `--tools-only` reverted the baseline on 08-19** (`R2-58`): every `autosusp=Y` row is before that deploy, every `autosusp=N` row after. Not a treatment effect — a deployment accident |
| "the 287-timeout denominator can't be re-derived" | **FALSE** — `evidence/baseline/baseline.tsv` reproduces it |
| "lore.kernel.org is unreachable" | **FALSE** — UA block fronting a JS challenge; a browser gets 200 |

## 6. The BlueZ patches — status: **APPLIED UPSTREAM 2026-09-21**

**Both v1 patches are in BlueZ master, committed by the maintainer 2026-09-21T10:10-04:00 exactly
as sent: `a734b0605` (adapter), `0bed9886c` (a2dp).** Thirty-eight days from first crash to tree.
Every URL — kernel.org commits, lore, patchwork v1/v2, bot PRs — in the status table at the top
of `patches/bluez/README.md`; no BlueZ release tag carries them yet (267 commits past 5.87).
⚠️ The v2 mails (22:47 CEST the same day) were sent 6.5 h *after* that, checked against a
month-old cached checkout instead of a fetched `origin/master` — redundant, bot said "does not
apply" for `0001`, all-PASS for `0002`. Lesson in code: `scripts/pre-send-check.sh` fetches and
reports ALREADY APPLIED before any mail. **Verified at kernel.org itself** (`ls-remote` tip
`17e624d1c`, both commits served with his `From:`). Sequence UTC: v1 09-19 18:44 → applied 09-21
14:10 → v2 20:47 → bot 22:42/23:20; **neither v2 arrived before the merge** — `0002` v2 "passed"
only because a pure insertion applies twice (PR #2559 would add the guard a second time, lines
2697 and 2702). **Decision 09-22: send nothing on the v2 threads**; watch their patchwork states
(14836499 / 14836500, both `new`). Patchwork's *superseded* on the v1 rows is automatic.

Two NULL-deref fixes, built from the machine's own `5.72-0ubuntu5.5` + 31 Ubuntu patches,
running since 08-25. **Sent 2026-09-19 to `linux-bluetooth` as two mails (Message-IDs in
`patches/bluez/README.md`) after three independent reviews (09-18, 09-19 ×2).** Written to BlueZ's
*measured* conventions (`HACKING` + last 300 commits): ⚠️ **no `Signed-off-by` — BlueZ calls it
an error**; 50/72; subjects 49/46; checkpatch 0 errors under BlueZ's own config; `git am` 6/6.
**BlueZ takes patches by mail (`linux-bluetooth@vger.kernel.org`), never PRs; no bug report is
needed — the patch is the report.** `0002` has no `Fixes:` on purpose (pickaxe: a 2015 refactor).
**v2 of both sent 2026-09-21** (message-only: quoted code re-indented, two lines wrapped).
**The list's CI bot answered both v1 mails within 90 min (09-19 22:05/22:10 UTC; register §CB):** every
build, smatch, scan-build, valgrind and distcheck PASS; CheckPatch the one known quoted-line
warning; **GitLint B3 — hard tabs in the quoted C of both messages — the only actionable item
(v2 with spaces: operator's call, CB-02)**; TestFunctional FAIL is the bot's own — the same two
`test_bap_unicast_set_transport_*` tests fail on 12 patches from 10 unrelated series since
09-17 (`scripts/patchwork-checks.sh --failed-functional 60`). No reply to the bot is owed.
Patchwork ids `14831546` / `14831547`, series 1169362 / 1169363.

- **`0002`** (a2dp `setup->stream`): **fired 4×** — 08-26, and 3× on 09-02. Four crashes
  prevented, not merely absent (`EX-041`). Strongest runtime evidence either patch has.
- **`0001`** (zero-length start-discovery reply): guard **never fired**. The 08-14 crash is
  reconstructed from the daemon log (`EX-041` ⚠️ block): Command Status `0x00` for the Start
  Discovery (`0x0023`, not service discovery) sent 2.05 s earlier, client list empty. Premise 5×.
- ⚠️ **Neither relates to `BT-1`.** The wedge has occurred **4×** with both installed.
- ⚠️ **A third, unrelated crash exists**: bad `free()` under `g_main_loop_run`, 09-08, at
  neither patched site. Cleared of being ours. **Do not fold it into the submission.**

## 7. Operating constraints — non-negotiable

⚠️ **This section and §8 are the DURABLE copy.** They were only in an assistant-side memory
store outside the repository — uncommitted, and lost to any reclone, reinstall or moved
directory. Tool-specific habits stay there; everything that is true regardless of who or
what is working lives here, in git.

**Goal.** The endgame is an **upstream kernel patch**, not a local workaround. Three parallel
streams: evidence, workarounds, the real fix. Workarounds must never be mistaken for it.

- **Family laptop.** A dead controller costs the household. Never request long windows on
  spec; capture what is already open.
- **Never `install.sh --apply`** on the investigation machine — it arms `bt-hang-watchdog`,
  whose USB reset has **3 controlled demonstrations of driving an already-wedged controller
  off the USB bus until power is removed** (`EX-023`, `EX-026`; not permanent damage). Use
  `--tools-only` — and ⚠️ **run `bt-mode status` after any deploy.** Until 2026-09-16
  `--tools-only` reinstalled the two files `bt-mode experiment` moves aside, so the
  baseline was silently reverted on 08-19 and again on 09-01 while the stamp still read
  *experiment* (`R2-58`, `EX-042`). A 09-16 fix guarded 2 of 3 files; the 3rd reverted on
  09-18 and was caught in minutes; all 3 skip now. The stamp is not evidence, the files are.
- **Never lose code, tests or evidence.** Priority 1; keep clutter over any deletion.
- **Do not send the patches** until the operator says so.
- **An untreated window is the most valuable state there is.** Do not touch Bluetooth;
  `sysfs` reads are safe, anything through usbfs is not. ⚠️ **`bt-mode` writes
  `power/control` live** — check `bt-window` before any mode switch. `bt-state`, `bt-status`,
  `bt-incident` are probe-free since 09-18; `--probe` sends an HCI command and is an intervention.
- **Never publish the kernel (alt-1) bug report without its patch ready to follow at
  once.** The BlueZ patches need no report at all. **Held `kernel/*` branches live on the
  `private` remote** (`ivoitovych/qca9377-bt-hang-private`, created 2026-09-23) — so a disk
  failure cannot take the patch, and nothing public shows it. `repo-save` pushes a `kernel/*`
  branch to `private` and refuses `origin` (tested; `scripts/prove-held-branch-guard.sh`).
  On send day the branch merges into `main` and goes public with the mail.
- **Verify operator accounts against logs** — he asked not to be trusted. Find the record or
  label the claim.
- **Every claim ships with its extraction command and exact verbatim output**, plus exit
  status and whether it was redacted. A claim without a re-runnable derivation is not
  evidence. This is why `evidence/exhibits/` exists in the shape it does.
- **Write identifiers in full** — branch names, paths, boot ids. Never `…`, never a short
  form after first use. Five branches here differ only by a trailing UTC timestamp; eliding
  them makes them indistinguishable exactly when the difference matters. Short SHAs are fine.
- **Attribution is the operator's, never a tool's.** No AI/assistant attribution in commits,
  patches or docs; `repo-save` refuses an AI *author/committer identity* as well as an AI trailer
  (a reinit reset a collaborator's git config on 09-18; caught by eye, now gated). Upstream
  sign-off is `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` — title case. ⚠️ The name and
  the email use *different* transliterations of the same Ukrainian name: Ukraine changed its
  Latin transliteration rules in 2011, after the gmail address was created, and the passport
  spelling followed the new rules. **The mismatch is correct; do not "fix" either to match the
  other** — both have already been "corrected" once by a well-meaning reader.
- **`BT-1`…`BT-4` are this project's own invented labels** — they exist in no kernel, BlueZ
  or external convention. The register (`docs/issues.md`) keeps them; that is what issue ids
  are for. ⚠️ Anything a stranger may read names the fault **plainly**, and may carry the
  label only as a parenthetical search handle — `(BT-1)` — for someone who followed the repo
  link. `docs/bug-report.md`, the only file that leaves on its own, carries **none**.
  Gated in `tests/run-tests`. A maintainer owes us nothing; invented tokens tax them and buy
  them nothing.
- **If access to something is blocked, diagnose it and ask** — never ship "I could not
  access X" inside the operator's deliverable. A 403 from one client is not proof of
  unreachability: check whether it is a refused tunnel, a status from a server that did
  answer, or a UA block fronting a challenge (this exact case cost a false caveat about
  `lore.kernel.org` nearly reaching a patch submission).

## 8. Method rules that were paid for

- **A zero from a capped scan is not a result.** Every zero needs a positive control.
  Broken twice, most recently `EX-041`.
- **"Verified standalone" by a hand-picked subset is not verification.** Run the block that
  changed, and read the verdict that runs on push (`R2-100`: red for 3 weeks, unread).
- **Let the datastore filter.** `journalctl _COMM=bluetoothd …` takes 30 s where a bare
  `journalctl … | grep` never finished; the scan too slow and the scan too narrow are one mistake.
- **A number in a summary is a claim** and inherits its filter's assumptions (`8 daemon
  crashes` was true of the machine, false of Bluetooth). **Present ≠ complete** — 9 of 21
  archives were prefixes reading as complete.
- **Extract the repeated question into a tool**, not the repeated command; one script
  replaced 226 recurring pipelines. If a question recurs and no tool answers it, that is the bug.
- **Check whether the tool already does the step you are prefixing.** `git add -A` was typed
  before `repo-save` for weeks; `repo-save` had always staged on its own.
- **Trim output inside the script, never with a pipe.** Quiet on success, everything on
  failure — a summary that hides a gate failure is worse than the noise it saved.
- **Separate what the operator DID from how the controller RESPONDED** (Phase 14). The
  reproductions were never a controlled procedure; every trigger attribution is an inference
  read backwards out of logs. Response measurements survive that; trigger claims do not.
- **A flag is not one behaviour** (Phase 17): `BTUSB_QCA_ROME` installs six things, so an
  A/B toggling it isolates none. Check what a switch carries before designing around it.
- **One observation is an anecdote — build the tool that checks the corpus** (Phase 25):
  `bt-stage2` turned one boot into 22, and the answer changed shape.

## 8a. The test suite — rules the maintainer paid for (owner: the test-suite maintainer)

*Reserved on 2026-09-19 at the operator's request. The test-suite maintainer writes this
section — the rules, each with its reason, ten to thirty lines — and points at the long
form in [`lessons/2026-08-22T1101Z-test-suite-maintainer.md`](lessons/) and its
successors. Nothing here is written by the main branch; a placeholder until he does.*

- (his first rule, with its why, goes here)

## 9. Open threads

1. **`docs/bug-report.md` rewritten around `EX-037`–`EX-043`** (front-door fixes, 09-18).
   It still leaves only with a kernel patch (§7). The driver test shape is exact: alt 1,
   stream, issue a command, it dies. Next: the operator's third-party review of the patches.
2. Six tasks delegated to the Test Branch Maintainer (source review, instrumented `btusb`
   logging of the chosen `new_alts`, bug-report audit, `BL-09`, `bt-crash` tests, device
   survey).
3. `bt-trial` does not record which `bluetoothd` is running, so pre- and post-patch trials
   pool under identical labels. Fix changes the results-file fingerprint — operator's call.
4. ⚠️ **CI was red on every push from `d70cb2e` (09-01) to `3cf4dd6` (09-14)** and nothing
   read it — `devtools/save` printed "CI will run it on push" twelve times. Two invariants
   of this side's own (`R2-100`) never passed anywhere; fixed 09-16. **Green confirmed** on
   `456daba`, `00138a7`, `2839ecc`, `f6173a8`, `573fb68`. `devtools/ci` reads a verdict on
   the machine and `devtools/status` shows it (`R2-105`). Still owed: one read of the 18
   red runs for anything else that went red meanwhile.
5. **Decided 2026-09-16 — return to the original configuration.** The baseline was
   reverted by deploy on 08-19 (`R2-58`); trials 6–13 and `EX-033`–`EX-042` ran under
   `autosusp=N,power=on` with an *experiment* stamp. That is **runtime configuration of
   unchanged code** (a module parameter and a sysfs write — verified, `EX-042`), so the
   evidence collected under it **stands and is kept**, labelled by the treatment string each
   exhibit already carries — *modified configuration*, not "mitigated". **`bt-mode
   experiment` run 2026-09-17 13:40**, after the 11 h 12 m window closed by power-off:
   `bt-mode status` shows stamp and files agreeing (`autosusp=Y`, `power=auto`, both
   overrides `disabled`); `bt-dyndbg status` shows 166 sites still on — the service alone
   carries the alt-1 evidence lines (also verified on boot `e9399c8c`). **Delivered 09-22:
   `EX-045`**, the eighth death, original configuration, 735 alt-1 packets, `0x0406` dies —
   recorded from journal and sysfs only, 8.5 h into an untreated window still open at 00:21
   on 09-23. ⚠️ **While that window is open, nothing touches Bluetooth** — the kernel-patch
   runtime test (§9.9) waits for the operator's power-off.
6. **The next experiment is a kernel, not more logging (deep review 2026-09-20).** Every
   reproduction ran on a kernel that treated `13d3:3503` as generic; `dc16388d45ec` gives it
   `BTUSB_QCA_ROME`, which installs *both* QCA firmware setup and a reset-on-timeout callback.
   Those must be separated ("Build B": setup on, automatic reset off) or a failure and its
   treatment land in one trial. Ladder: A baseline on one fixed tree → B setup only → E setup
   on, alt-1 blocked for this ID → D as upstream. **A kernel build on the family laptop —
   the operator's decision.** Kernel version alone no longer predicts behaviour (backports):
   check the running `btusb` for the entry (`tools/bt-verify-kernel-mechanism`), never the version.
7. **BlueZ — CLOSED: both applied upstream 2026-09-21 (§6).** The v2 mails of 22:47 CEST were
   moot; **no reply is sent** — watch the v2 patchwork states instead. Never again send without
   `scripts/pre-send-check.sh` against a fetched `origin/master`. How the v2 came about:
   the bot's only actionable finding is hard tabs in the quoted C
   of both commit messages. A v2 with spaces clears GitLint and changes no code; a v2 for a
   linter before a maintainer has replied may read as noise. Operator's decision. **v2 is
   prepared in `patches/bluez/v2/`** (`scripts/build-v2.sh`, diff byte-identical to v1):
   gitlint 0, checkpatch 0/0, `git am` 6/6; `BT_PATCH_DIR=patches/bluez/v2 scripts/build-mails.sh`
   lays changelog, note, diffstat. Two separate mails as before, on his word only.
   **The workflow, measured 09-21 (`reviews/2026-09-21T0900Z-…`), not assumed:** the GitHub
   PRs (#2554/#2555) are the bot's CI vehicle — 0 of 1073 ever merged, "only for CI and
   testing purposes" in the maintainers' own bot text; **never comment, push or open a PR
   there.** A v2 is a new patchwork series id and so a **new PR by the maintainers' design**
   (`sync_patchwork.py`: "a resent series comes with a new series id") — that is correct, not
   a discourtesy. Lint is advisory: 25 of 63 accepted series carried a CheckPatch/GitLint
   fail/warning when applied, the maintainer's own included; Rule 2 of
   `doc/maintainer-guidelines.rst` exempts verbatim logs from the line limit. A v2 by mail is
   the contributor's outlet for a bot finding and is within practice either way.

8. **Kernel submission workflow measured 2026-09-22 (`reviews/2026-09-22T1700Z-…`), before any
   kernel patch is tested or sent.** Route: mail to `linux-bluetooth`, both maintainers on Cc,
   `Signed-off-by` required, `Fixes:` normal (173/300), `Cc: stable` on mainline-bound fixes
   (61/300; never to the stable list directly — Greg KH's form letter). Same bot, kernel check
   set; **acceptance is silent** (patchwork-bot "applied"), 53 % of accepted series had a bot
   fail/warning, 33 % a tester fail, only `VerifyFixes` is never failed; 39 % were v2+. ⚠️
   **Sashiko** (Linux Foundation LLM reviewer) reviews every list submission and the maintainer
   quotes it — so the external review before sending is the right rehearsal. Rebase against
   **both** `bluetooth/master` and `bluetooth-next/master` on send day. Tips fetched into
   `cache/linux` (`bluetooth-next`, `bluetooth`, `stable`, mainline remotes) — refresh with
   `git fetch` before any claim about them; they move daily.

9. **Kernel-patch runtime test — prepared 09-23, waits for a closed window and the operator.**
   `bluetooth.ko` for the running `7.0.0-31-generic` is built from **Ubuntu's own source**
   (v7.0 + the `linux-hwe-7.0_7.0.0-31.31~24.04.1` diff, which touches `mgmt.c` and nine other
   Bluetooth files — vanilla would have been wrong), unpatched and patched, vermagic matching,
   under `tmp/runtime/` (rebuild: `BT_KSRC=cache/ubuntu-7.0.0-31 scripts/build-bluetooth-module.sh`).
   Secure Boot off, `sig_enforce=N`. The patched daemon runs from `/usr/local` via drop-in
   `20-patched-bluetoothd.conf`; the stock package binary is intact (`dpkg -V bluez` clean), so
   "stock daemon" = disable that drop-in. Runbook: `scripts/runtime-mgmt-test.sh` — refuses
   while `bt-window` is open or a trial is open; `load`/`restore` swap the module, `trigger`
   captures the management channel around a power cycle. A reboot restores all.
   ⚠️ **Attempted 2026-09-23 01:08–01:20 and it wedged the controller (`EX-046`)**: the first
   `btusb` unload/re-probe, still on the STOCK module, ended with HCI Reset `0x0c03` timing out
   (`-110`) and hci0 registered with an all-zero address, DOWN; two further re-probes the same.
   No SCO involved — **a driver reload on a healthy controller is itself fatal on this part**
   (no firmware-setup path without `BTUSB_QCA_ROME`), which is also why every reset/rebind
   recovery in the record failed. `bt-window` does not see this state (no tx-timeout line).
   Consequences: (a) **never swap `bluetooth.ko` on a live system here** — the swap tooling
   stays for the record, `load`/`restore` must not be run; (b) the runtime test needs the
   patched module in place **before the first probe**: `/lib/modules/$(uname -r)/updates/`
   + `depmod` + a cold boot, reverted by deleting that file + `depmod` + reboot — the
   operator's decision; (c) the machine needs a power-off to recover, again. Getting the swap
   to unload at all took four fixes in the runbook: D-Bus re-activation of `bluetoothd`
   (mask for the swap), socket holders that re-load modules on the spot (WirePlumber,
   ModemManager, this project's `bt-capture`/`bt-trace`), dependency order, and a
   `lsmod | grep -q` under pipefail that skipped loaded modules.
   **For the test-suite maintainer (§8a):** with no trial open the suite ran locally for the
   first time in weeks and two invariants failed **only on this machine**, both green in CI:
   `bt-capture`'s "no monitor socket" test opened a real socket as root with `bluetooth.ko`
   loaded (now run under `unshare -Ur`, which drops `CAP_NET_RAW` for root too — same refusal
   on every host), and `bt-actions` read the machine's real btsnoop captures in its second pass
   and added 10 MGMT rows to a 46-line fixture — `btmon` aborted on one of those captures on
   the way, a `BT-4` instance (test now sets `BT_TRACE_DIR` to nothing). Both fixed in the
   suite with the reason beside them; `BRIEF §8a` remains his.
   **State 2026-09-23 after the power cycle:** controller healthy, all boots archived complete.
   **Three independent external reviews** of the held patch (details on the held branch only,
   `patches/kernel/README.md` ER1–ER3): all say the one-line diff is correct and should go in;
   message corrected twice, diff unchanged; regenerated with `format-patch --base` on
   `bluetooth-next`; in-tree checkpatch `--strict` 0/0/0, `W=1 -Werror` clean, sparse 0 new
   (`scripts/kernel-preflight.sh`; ⚠️ Ubuntu's sparse 0.6.4 is silently skipped by 7.x — a
   current one is built in `cache/sparse`, and the script refuses without a CHECK line).
   **Operator approved the runtime test via `updates/` + cold boot on 2026-09-23.** Removal
   (`0x11`) is not tested on hardware: it needs a `btusb` unbind, which wedges this part (`EX-046`).
   ⚠️ **INSTALLED 2026-09-24 00:5x: `/lib/modules/7.0.0-31-generic/updates/bluetooth.ko`**
   (patched, Ubuntu source, srcversion `66D38200362CD82D3F68A9D`, sha256 `815e7378…b90b72`),
   `depmod -a` done; not in the initramfs, so it loads from the first boot after. Checked first:
   `scripts/check-modversions.sh` — all 9 dependants (btusb, btintel, btbcm, btrtl, btmtk,
   btqca, rfcomm, bnep, hidp) accept its CRCs, 0 mismatches. **Every trial and exhibit from
   that boot on runs the PATCHED `bluetooth.ko`** — `bt-trial` labels them `build=stock`
   (§9.3); read the boot's srcversion, not the label. **Undo:** `rm` that file, `depmod -a
   7.0.0-31-generic`, reboot. What the runtime check looks for, and its results: the held
   branch only. **Runtime result 2026-09-24 (01:19–03:39, operator's heavy use, dozens of
   power cycles, pairing, 2 h of audio): no regression**; the ninth alt-1 death (`EX-047`)
   happened on this build, unchanged in signature. ⚠️ **Publication slip, 09-22→09-24:**
   earlier revisions of this section, HISTORY and the runbook header described the held
   finding's test case on public `main`. Neutralised on 09-24; the text remains in git history
   (removal would need a force-push — the operator's call). The closing move is to send the patch.

## 10. Where detail lives

| | |
|---|---|
| evidence, one claim + extraction each | `evidence/exhibits/` (`bt-exhibit index`) |
| narrative, why things were believed | `HISTORY.md` (36 phases) |
| which tool answers which question | `docs/tooling-index.md` |
| the patches, their reasoning and BlueZ's measured conventions | `patches/bluez/` |
