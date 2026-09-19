# BRIEF — read this first, after any context reset

**What this is.** Internal working state for whoever resumes the investigation: what is
true, what is retracted, what is open. Facts only, with pointers instead of explanations.

**What it is not.** Not evidence (`evidence/exhibits/`, 43 of them), not narrative
(`HISTORY.md`, 2800 lines), not tooling (`docs/tooling-index.md`), not working rules
(auto-loaded memory), and **not the public summary** — a stranger reads `README.md`, whose
Status block is a dated copy of §1–§3 and §6, checked on every commit like this file
(`FD-09`). Nothing here is derivable from those — it is the layer that says which holds.

⚠️ **Budget: 200 lines.** Over that, it stops being cheaper than reading the source, which
is the only reason it exists. Cut the oldest settled item before adding.

**Last updated: 2026-09-18 · newest exhibit: EX-043** — no tip hash: it rotted within hours (`R2-13`).

---

## 1. The bug, current best statement

> When the QCA9377 (`13d3:3503`) negotiates **transparent (mSBC / WBS)** SCO, `btusb` falls
> back to **USB alternate setting 1** — a **9-byte** isochronous endpoint — and streams
> **27-byte** mSBC frames into it. **The first HCI command issued while that stream is
> running is never answered** — the fault surfaces `HCI_CMD_TIMEOUT` (2.0 s) after that
> command, whether it comes 34 ms or 9.65 s after link-up (`EX-043`) — and the controller
> then answers nothing, including USB control transfers. Only a **full power-off** recovers
> it. Reproduced under stock power management (`EX-043`); the modified configuration is not
> a factor.

Introducing commit, verified at five tags by the test-suite maintainer (08-24, received
09-18): **`517b693351a2`** — Trent Piepho, 2020-12-09, *"Bluetooth: btusb: Always fallback to
alt 1 for WBS"* — ancestor of v5.12, not v5.11. ⚠️ Its own message states the assumption this
hardware falsifies: *"I have been unable to find any [adapters that support alt 6]"* — build
the upstream report on that sentence. **Control window is v5.8–v5.11 only**: below v5.8 alt 1
is reachable by a different route (`new_alts = sco_num`), so "≤ v5.11" was wrong.

## 2. The signature — `n = 7`, three kernels, two peripherals, both configurations

```
0x0428 answered → evt 5 → "Looking for Alt no :6" → ":3" → 27-byte frames on mtu 9 → FIRST command issued → +2.0 s tx timeout
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
| *survival* | 09-01 | `-30` | modified | **8** | — | *lived* |

¹ window-scoped. ⚠️ **The "2.15 s interval" was an artefact of six fast teardowns** (first
command 34–279 ms after link-up); the invariant is *first command + `HCI_CMD_TIMEOUT`*,
and `EX-043` shows the stream itself running 9.65 s without harm until a command is sent.
Both instances where the log names the dying command name `0x0406 Disconnect, reason 0x13`.

## 3. Settled

- **`0x0428` IS answered** — a connection handle is allocated every time.
- **alt 1 is directly observed**, not inferred — `sysfs` `bAlternateSetting 1` +
  `wMaxPacketSize 0009`, read 5× during live wedges (`tools/bt-usbstate`).
- **The first HCI command into a running alt-1 stream is never answered** (`EX-043`): zero
  commands were in flight for 9.65 s of streaming; the first one issued died. The stream
  alone does not wedge the controller — a command into it does.
- **The original configuration reproduces it** (`EX-043`, `autosusp=Y, power=auto`, live).
- **The wedge is below HCI** — USB control transfers (`GET_DESCRIPTOR`) return `-110`.
- **No software recovery exists.** `hci_cmd_timeout()` calls `hdev->reset()`, which is NULL
  ( `13d3:3503` matches no quirks entry); Linux has no periodic USB device recovery; and the
  GUI toggle fails with `Opcode 0x0c03 (HCI_Reset) failed: -110` (`EX-039`).
- **`hci0` is never unregistered** (not the stage-2 shape); **CVSD (`mtu 17`) is safe.**

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

## 6. The BlueZ patches — status

Two NULL-deref fixes, built from the machine's own `5.72-0ubuntu5.5` + 31 Ubuntu patches,
running since 08-25. **Unsent. Two independent reviews (09-18, 09-19): accept both; message-only
corrections applied; no code change. Sending is the operator's word.** Written to BlueZ's
*measured* conventions (`HACKING` + last 300 commits): ⚠️ **no `Signed-off-by` — BlueZ calls it
an error**; 50/72; subjects 49/46; checkpatch 0 errors under BlueZ's own config; `git am` 6/6.
**BlueZ takes patches by mail (`linux-bluetooth@vger.kernel.org`), never PRs; no bug report is
needed — the patch is the report.** `0002` has no `Fixes:` on purpose (pickaxe: a 2015 refactor).

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
  whose USB reset has **3 controlled demonstrations of destroying this controller**. Use
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
  once.** The BlueZ patches need no report at all.
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
  sign-off is `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` — title case. ⚠️ Name and email
  use *different* transliterations (2011 rule change). **Correct as is; do not "fix" either.**
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
   carries the alt-1 evidence lines (also verified on boot `e9399c8c`). Still owed: one
   alt-1 capture with the counters under the original configuration.

## 10. Where detail lives

| | |
|---|---|
| evidence, one claim + extraction each | `evidence/exhibits/` (`bt-exhibit index`) |
| narrative, why things were believed | `HISTORY.md` (36 phases) |
| which tool answers which question | `docs/tooling-index.md` |
| the patches, their reasoning and BlueZ's measured conventions | `patches/bluez/` |
