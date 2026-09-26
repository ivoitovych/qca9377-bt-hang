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

**Last updated: 2026-09-26 · newest exhibit on `main`: EX-053; the held branch has EX-049 and
EX-050 (the exhibit tool numbers from `main` alone — now past them, so it numbers correctly
again), so the next exhibit on `main` is EX-054** — no tip hash: it rotted within hours (`R2-13`).

> **E1 BOOTED 2026-09-26 17:11 (`EX-055`).** The stock controller was on bare ROM firmware
> (rom `0x302`, build `0x111`, status `0x20`); E1 loaded rampatch build `0x3e8` + NVM, and the
> controller now advertises **202 commands incl. Enhanced Setup/Accept** (stock: 197 without).
> First 4 h 29 min: **0 timeouts, 0 LE `unexpected event`** — but **no SCO setup yet** (A2DP
> only), so the fatal path is not yet tested. **Next: a wideband call, then hang up.**
>
> **RESUME HERE (2026-09-26 ~14:50) — EXPERIMENT E1 IS INSTALLED.** A diagnostic `btusb.ko`
> (`0.8-e1`, srcversion `0FF3E900DE4D28718D8573F`, sha256 `f635c447…`) is in
> `/lib/modules/7.0.0-34-generic/updates/`: `13d3:3503` gets **QCA ROME setup, no automatic
> reset**; wideband, legacy `0x0428` and alt 1 unchanged (patch and facts: private branch
> `diag/btusb-e1`). It loads from the first cold boot after 14:50. **After that boot:**
> `cat /sys/module/btusb/version` must read `0.8-e1`; `journalctl -k -b 0 --grep 'E1:|QCA|rampatch|NVM'`
> for the firmware state; `scripts/supported-commands-survey.sh` for 197 vs 200 commands; then
> the operator's usual hard test. Survival under wideband calls → the fix is the upstream
> entry `dc16388d45ec` (stable backport); the same first-command death → E2 (minus the
> Enhanced-setup quirk). **Undo:** `scripts/module-updates.sh --module btusb remove`, reboot.
> Before it: the `EX-053` window stayed untreated **12 h 34 min**, USB silent (`EX-054`), and
> the controller advertised Enhanced Setup only 08-14…08-19 (6 of 159 replies,
> `scripts/supported-commands-survey.sh`).
>
> **Earlier (2026-09-25 ~23:30).** **Two more alt-1 deaths on 09-25** — `EX-051` (15:29,
> `-31`, the dying command is `0x0c1a` Write Scan Enable, not Disconnect) and `EX-052` (18:32,
> the first on **`7.0.0-34`**); both ended by a reboot, `EX-052` about 13 min after the fault.
> In `EX-052`'s window **`tcpdump` issued two usbfs `GET_DESCRIPTOR` transfers** to the
> wedged device (both `-110`): this project's own capture touched it — find which unit runs
> that `tcpdump` before the next window. The held kernel patch (`kernel/mgmt-flush-status`,
> private remote) **was sent on 2026-09-24 at 19:11** after four external reviews; the list's
> CI bot passed 13 of 14 (its `mesh-tester` failure is the bot's standing one); the full
> record is on that branch. **Private remote:** `private` =
> `github.com/ivoitovych/qca9377-bt-hang-private`; `devtools/held status|sync|edit|commit`
> handles it; `origin` never gets `kernel/*`. **Machine:** stock `bluetooth.ko` on
> `7.0.0-34`. **New headset (09-25): Shure AONIC 50.** ⚠️ **RETRACTED (09-26):** "its HFP
> never completes, so it cannot reach the alt-1 path" — true of one connection at 23:14
> (`RFCOMM receive command before SLC completed: AT+%QAC=0`), false as a rule: under the
> operator's testing its HFP came up and it died at 02:09 (`EX-053`) — **the third headset
> model with the same signature**. It is a live trigger, not a safe headset.

---

## 1. The bug, current best statement

> When the QCA9377 (`13d3:3503`) negotiates **transparent (mSBC / WBS)** SCO, `btusb` falls
> back to **USB alternate setting 1** — a **9-byte** isochronous endpoint — and sends each
> 27-byte SCO buffer as **three 9-byte packets** (`__fill_isoc_descriptor`; `len 27 mtu 9` is
> that split, ⚠️ not an overflow — `DR-02`). **The first HCI command observed after the
> stream starts gets no response** — `HCI_CMD_TIMEOUT` (2.0 s) after it, whether issued 34 ms
> or 9.65 s after link-up (`EX-043`); the named dying commands are `0x0406 Disconnect` and,
> in `EX-051`, `0x0c1a Write Scan Enable` — the opcode does not matter — and
> the controller then answers nothing, including USB control transfers. Only a **full
> power-off** recovers it. Reproduced under stock power management (`EX-043`).

Introducing commit, verified at five tags by the test-suite maintainer (08-24, received
09-18): **`517b693351a2`** — Trent Piepho, 2020-12-09, *"Bluetooth: btusb: Always fallback to
alt 1 for WBS"* — ancestor of v5.12, not v5.11. Its message assumes adapters without alt 6
work on alt 1; this part has alts 1–5 and no 6 (its descriptors are also in `dc16388d45ec`),
so the fallback *applies* to it — whether it is *compatible* is the question (`DR-04`).
**Control window is v5.8–v5.11 only** (below v5.8 alt 1 is reachable via `new_alts = sco_num`).

## 2. The signature — `n = 12`, four kernels, three peripherals, both configurations
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
| **`EX-051`** | **09-25** | `-31` | **original** | 1857¹ | (`0x0c1a` Write Scan Enable) | 3.672 s; 2.020 s cmd→timeout |
| **`EX-052`** | **09-25** | **`-34`** | **original** | 3605¹ | (`0x0406`, reason `0x13`) | 2.051 s cmd→timeout |
| **`EX-053`** | **09-26** | `-34` | **original** | 2432¹ | **7,331 ms** (`0x0406`, reason `0x13`); **Shure AONIC 50** | **9.421 s** |
| *survival* | 09-01 | `-30` | modified | **8** | — | *lived* |

¹ window-scoped. ⚠️ **The "2.15 s interval" was an artefact of six fast teardowns** (first
command 34–279 ms after link-up); the invariant is *first command + `HCI_CMD_TIMEOUT`*,
and `EX-043` shows the stream itself running 9.65 s without harm until a command is sent.
Where the log names the dying command it is `0x0406 Disconnect, reason 0x13`, except
`EX-051`: `0x0c1a Write Scan Enable`, the first command after the stream started — so the
fault is not specific to Disconnect.

## 3. Settled

- **`0x0428` IS answered** — a connection handle is allocated every time.
- **alt 1 is directly observed**, not inferred — `sysfs` `bAlternateSetting 1` +
  `wMaxPacketSize 0009`, read 5× during live wedges (`tools/bt-usbstate`).
- **The first HCI command observed after the stream starts gets no response** (`EX-043`):
  none in flight for 9.65 s; the first issued died. ⚠️ Whether that command *wedges* the
  controller or *discovers* one the stream already wedged is **not established** (`DR-03`).
- **The original configuration reproduces it** (`EX-043`, `autosusp=Y, power=auto`, live).
- **The wedge is below HCI** — USB control transfers (`GET_DESCRIPTOR`) return `-110`.
- **An rfkill cycle on a wedged controller** (operator, 09-24, `EX-048`): the power-off itself
  fails (`-110`), and on unblock two USB resets leave the device off the bus (`000`, hci0
  DOWN) — USB loss once more only *after* an intervention.
- **Every recovery tried on an already-wedged controller failed** (`EX-039`); the one reset
  issued *before* any timeout recovered it, and it failed again 132 s later (`EX-004`).
  `hdev->reset` is NULL on the kernels run here — `13d3:3503` had no quirks entry ⚠️ **until
  `dc16388d45ec`** (master, 2026-08-07, for a BLE-scan fault; not in v7.0, 6.6.y, 6.12.y as
  checked 09-19) — and that entry's setup/reset path is **untested here** (`DR-01`).
- **`hci0` is never unregistered** (not the stage-2 shape).
- ⚠️ *Corrected 2026-09-26:* this line used to read "the CVSD controls survived (`mtu 17`,
  `EX-031`)". `EX-031` is **not** a CVSD control: it is a **transparent (wideband) link on
  alt 1** (`evt 5`, `len 27 mtu 9`) that ran ~17 min and survived — set up by **Enhanced**
  `0x043D`, while all twelve deaths used legacy `0x0428`. So entering alt 1 is not
  sufficient; which setup command the host chose may matter. The kernel uses `0x043D` only
  when the controller's supported-commands bitmap advertises it (`commands[29] & 0x08`) and no
  quirk forbids it; why it did on 08-18 (`-28`) and not on the boots that died is **not
  known**. ⚠️ Upstream's QCA ROME path (`dc16388d45ec`) sets
  `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`, forcing `0x0428` for this device.

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

⚠️ **This section and §8 are the DURABLE copy.** They were only in a local notes store
outside the repository — uncommitted, and lost to any reclone, reinstall or moved
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
- **Attribution is the operator's.** `repo-save` refuses a tool *author/committer identity*
  as well as a generated-by trailer (a reinit reset a collaborator's git config on 09-18;
  caught by eye, now gated). Upstream sign-off is `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` — title case. ⚠️ The name and
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

*Written 2026-09-24, replacing the reservation. Each rule cost something; the instance
that taught it and what it cost are in
[`lessons/2026-08-22T1101Z-test-suite-maintainer.md`](lessons/2026-08-22T1101Z-test-suite-maintainer.md)
and [`lessons/2026-08-27T1200Z-test-suite-maintainer.md`](lessons/2026-08-27T1200Z-test-suite-maintainer.md).*

- **A new check must be observed to fail.** Write it, break what it guards, watch it go
  red, restore. **Eight** checks have reached this suite green that *could not* fail. The
  seventh was `rg … || true`, where a missing binary made a negative search read as a clean
  one (`6a7c7a4`); the eighth was written **this week**, in the check policing this very
  rule — a drift guard that matched its stem in a *comment*, so the code could drift and it
  stayed green. Strip comments before asserting on source.
- **State the premise in code, not in a comment.** An assertion that says "this host has a
  readable journal" and never asks has two meanings and tests one. On a journal-less host
  it accepted `bt1_status=not_observed` — *"we looked and BT-1 did not happen"* — for a
  trial where looking was impossible, on every run and every CI run since the classifier
  was written. Now it derives the premise and asserts the opposite answer on each side.
- **`ENUMERATED == 0` is a refusal; `CHECKED == 0` is a result.** The same defect, in the
  producer: `journalctl` **exits 0** with no journal files at all, so a checked exit status
  said "read succeeded" and a numeric zero became a clean survival. Exit 0 is not evidence
  that there was anything to read.
- **A bounded search that reports absence is reporting its bound.** Twice a `--depth 50`
  clone answered a question about history: once `unknown revision` read as "no such
  commit", once 141 commits read as the total where the full clone has 401. Put the bound
  in the same sentence as the number, or widen it before answering.
- **A red suite is also a claim about the machine.** Five sanitiser assertions failed with
  "a raw UUID survived verification"; the leak was mawk 1.3.4 mishandling ERE intervals on
  groups, not the sanitiser. Gate assertions that need a capability on a probe for it — and
  verify the gate **both ways**: it runs where the capability exists, and where it does not
  the refusal itself is asserted, because a refusal that still wrote output is the
  dangerous outcome and a silent skip would never see it.
- **Tests never touch the real evidence tree.** Everything reads through a seam
  (`BT_JOURNAL_FIXTURE`, `BT_COREDUMP_FIXTURE`, `BT_CAPTURE_SOURCE`, `BT_SNAPSHOT_DIR`,
  `BT_REPO`, `BT_DESTDIR`), and fixtures carry placeholders (`AA:BB:CC:…`, `192.0.2.x`,
  `example.com`) — never real-but-shortened data. ⚠️ The seam is **not complete**: a run
  still reaches the real `journalctl`, `systemctl` and `bluetoothctl`, which is why the
  suite costs a minute here and far more on the machine (§9).
- **The suite must not run in the live tree.** It drives actuators, so it refuses while a
  trial is open — on 2026-08-14 a coverage run closed a live two-hour trial and wrote a
  results row fabricated by stubs. Run it from a separate worktree there; and when a tool
  drops to its read-only validators, make it **say so**, because believing the suite ran is
  worse than knowing it did not.
- **Sampling one convention does not license the next one.** `Fixes:` usage was *measured*
  across 400 upstream commits; the sign-off convention beside it was *assumed*, and was
  wrong — that project's own `HACKING` calls the trailer an error.
- **A converging measurement is not proof the anchor is right.** Two instances agreeing to
  76 ms was read as confirmation; a third showed the anchor was only *less* wrong. Agreement
  bounds noise, never systematic error.
- **An ahead-count is not a relationship.** The push gate says how many commits the local
  branch has that the remote lacks, never whether the remote's are contained in yours. Two
  incidents, opposite correct answers. Compare tips.

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
   ✅ **REMOVED again 2026-09-24 ~05:40 (`scripts/module-updates.sh remove`)** for the stock
   control run: boots from then on load the STOCK `bluetooth.ko`; check with
   `scripts/module-updates.sh status`. History of the install:
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
10. **The fixture seam does not cover the machine tools, and the suite's cost says so**
    (test-suite maintainer, 09-24). Profiled: the suite is **~60 s here**, ~70 % of it
    process creation (24,603 processes, ~30 per invariant), only ~5.5 s idle — but per run
    it still reaches the **real** `journalctl` (42×, including an unbounded `-k -b 0
    --grep`), `systemctl is-active` (106×) and `bluetoothctl devices Connected` (each
    behind `timeout 8`). Those are instant on a journal-less container and expensive on the
    machine — worst exactly when the controller is wedged — so runtime there scales with
    uptime, not with the tests. `.github/workflows/checks.yml:8` still says *"the suite is
    ~2 s and hermetic"*; both halves are now false. Also: the five gates that each re-run
    the whole suite cost **6 min 53 s** here, and four concurrent runs finish in 68 s, so
    the split (`UT-12`) buys ~3×. Nothing changed yet — the fix is to stub those tools for
    the whole run and add an invariant that counts fall-throughs to the real binaries,
    detecting the effect rather than the shape, as the `/usr/bin` footprint check does.

## 10. Where detail lives

| | |
|---|---|
| evidence, one claim + extraction each | `evidence/exhibits/` (`bt-exhibit index`) |
| narrative, why things were believed | `HISTORY.md` (36 phases) |
| which tool answers which question | `docs/tooling-index.md` |
| the patches, their reasoning and BlueZ's measured conventions | `patches/bluez/` |
