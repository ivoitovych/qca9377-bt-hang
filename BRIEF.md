# BRIEF — read this first, after any context reset

**What this is.** The concentrated state of knowledge: what is true, what is retracted,
what is open. Facts only, with pointers instead of explanations.

**What it is not.** Not evidence (`evidence/exhibits/`, 42 of them), not narrative
(`HISTORY.md`, 2800 lines), not tooling (`docs/tooling-index.md`), not working rules
(auto-loaded memory). Nothing here is derivable from those — it is the layer that says
which of them still holds.

⚠️ **Budget: 200 lines.** Over that, it stops being cheaper than reading the source, which
is the only reason it exists. Cut the oldest settled item before adding.

**Last updated: 2026-09-13 · newest exhibit: EX-041 · tip `7c9427b`**

---

## 1. The bug, current best statement

> When the QCA9377 (`13d3:3503`) negotiates **transparent (mSBC / WBS)** SCO, `btusb` falls
> back to **USB alternate setting 1** — a **9-byte** isochronous endpoint — and streams
> **27-byte** mSBC frames into it. After ~2 s of that the controller stops answering,
> including plain USB control transfers. Only a **full power-off** recovers it.

Regression candidate: `BTUSB_USE_ALT1_FOR_WBS` went from a Realtek-only opt-in to an
unconditional fallback in **v5.11 → v5.12**. Untested prediction: a ≤ v5.11 kernel should
not take this path.

## 2. The signature — `n = 5`, three kernels, two peripherals

```
0x0428 answered  →  evt 5  →  "Looking for Alt no :6" → ":3"  →  27-byte frames on mtu 9  →  bare tx timeout
```

| exhibit | date | kernel | `len 27 mtu 9` | setup→fault |
|---|---|---|---|---|
| `EX-033` | 08-22 | `-29` | 835 | 2.076 s |
| `EX-036` | 08-25 | `-30` | 87 | 2.152 s |
| `EX-037` | 09-01 | `-30` | 680 | 2.151 s |
| `EX-038` | 09-13 | `-31` | 682 | 2.191 s |
| `EX-040` | 09-13 | `-31` | 1562¹ | 2.140 s |
| *survival* | 09-01 | `-30` | **8** | *lived* |

¹ window-scoped, not link-up-to-fault. Interval spread **115 ms**. Dying command is queued
**34–39 ms** after link-up in 4 of 5 (`EX-036` is 279 ms and is the only one where the log
names it: `0x0406 Disconnect, reason 0x13`).

**Fastest path** (`EX-040`): incoming HFP connect → SCO at +1.008 s → dead at +2.140 s =
**3.148 s**, machine untouched. ⚠️ Not a general rule — `EX-038` reached the same sequence
with HFP already connected.

## 3. Settled

- **`0x0428` IS answered** — a connection handle is allocated every time.
- **alt 1 is directly observed**, not inferred — `sysfs` `bAlternateSetting 1` +
  `wMaxPacketSize 0009`, read 3× during live wedges (`tools/bt-usbstate`).
- **The wedge is below HCI** — USB control transfers (`GET_DESCRIPTOR`) return `-110`.
- **No software recovery exists.** `hci_cmd_timeout()` calls `hdev->reset()`, which is NULL
  ( `13d3:3503` matches no quirks entry); Linux has no periodic USB device recovery; and the
  GUI toggle fails with `Opcode 0x0c03 (HCI_Reset) failed: -110` (`EX-039`).
- **`hci0` is never unregistered.** The device stays enumerated and cannot initialise — this
  is *not* the stage-2 "off the bus" shape.
- **CVSD is safe.** `mtu 17`, 4669 packets, controller healthy throughout.

## 4. Not settled

- **Mechanism.** Correlation across 5 deaths / 1 survival. *How* the traffic wedges the
  controller is unknown — needs driver instrumentation or an mgmt/btmon trace.
- **No controlled comparison.** Nobody has forced alt-1 with a sustained stream on demand,
  or blocked alt-1 and shown survival under identical use. The survival was the
  peripheral's choice, not an intervention.
- **What decides WBS-sustains vs falls-back-to-CVSD.** This is the whole difference between
  death and survival and is not understood.

## 5. ⚠️ RETRACTED — do not re-assert these

| claim | status |
|---|---|
| "`0x0428` is submitted and never answered" | **FALSE** — answered every time |
| "alt probes, then silence" (`EX-033`/`036`) | **FALSE** — artefact of those exhibits' own grep; data was flowing |
| "the dying command is anonymous *by construction*" | **OVERSTATED** — anonymous to the printk, not the log |
| "patch `0002`'s guard has never fired" | **FALSE** — fired 4× (`EX-041`); came from grepping one boot |
| "`EX-038` boot id `c128a59a`" | **FALSE** — it is `f5de8066`; value copied forward |
| "`evt 5` = Synchronous Connection Complete" | **FALSE** — it is `HCI_NOTIFY_ENABLE_SCO_TRANSP` |
| "`0x0428` means CVSD" | **FALSE** — air mode comes from the `btusb_notify()` value |
| "autosuspend mitigation works (0/4 vs 3/4)" | **FALSE** — `EX-038` wedged under `autosusp=N`; the split is chronological |
| "the 287-timeout denominator can't be re-derived" | **FALSE** — `evidence/baseline/baseline.tsv` reproduces it |
| "lore.kernel.org is unreachable" | **FALSE** — UA block fronting a JS challenge; a browser gets 200 |
| "the recovery ladder destroyed nothing" | **FALSE** by the next boot (`EX-034`) |

## 6. The BlueZ patches — status

Two NULL-deref fixes, built from the machine's own `5.72-0ubuntu5.5` + 31 Ubuntu patches,
running since 08-25. **Unsent — the operator has not released them.**

- **`0002`** (a2dp `setup->stream`): **fired 4×** — 08-26, and 3× on 09-02. Four crashes
  prevented, not merely absent (`EX-041`). Strongest runtime evidence either patch has.
- **`0001`** (zero-length start-discovery reply): guard **never fired**. Its *premise* was
  observed — `command 0x23 status: 0x00`, success with a too-short reply. Stands on coredump
  analysis, which is an ordinary and sufficient basis.
- ⚠️ **Neither relates to `BT-1`.** The wedge has occurred **4×** with both installed.
- ⚠️ **A third, unrelated crash exists**: bad `free()` under `g_main_loop_run`, 09-08, at
  neither patched site. Cleared of being ours. **Do not fold it into the submission.**

## 7. Operating constraints — non-negotiable

- **Family laptop.** A dead controller costs the household. Never request long windows on
  spec; capture what is already open.
- **Never `install.sh --apply`** on the investigation machine — it arms `bt-hang-watchdog`,
  whose USB reset has **3 controlled demonstrations of destroying this controller**. Use
  `--tools-only`.
- **Never lose code, tests or evidence.** Priority 1; keep clutter over any deletion.
- **Do not send the patches** until the operator says so.
- **An untreated window is the most valuable state there is.** Do not touch Bluetooth;
  `sysfs` reads are safe, anything through usbfs is not.
- **Verify operator accounts against logs** — he asked not to be trusted. Find the record or
  label the claim.

## 8. Method rules that were paid for

- **A zero from a capped scan is not a result.** Every zero needs a positive control.
  Broken twice, most recently `EX-041`.
- **Let the datastore filter.** `journalctl … | grep` over this journal does not finish in
  10 min; `journalctl _COMM=bluetoothd … | grep` takes 30 s. The scan too slow to finish and
  the scan too narrow to be true are the same mistake.
- **A number in a summary is a claim** and inherits its filter's assumptions.
  `8 daemon crashes` was true of the machine, false of Bluetooth.
- **Present ≠ complete.** 9 of 21 journal archives were prefixes reading as complete.
- **Read provenance, never copy it forward.** Wrong boot id twice, wrong kernel five times.
- **Fewer prompts = fewer pipes, never more allow rules.** 2344/3584 calls contained
  compound shell against 364 rules already granted. New scripts under `tools/` or
  `devtools/` are pre-granted and silent.

## 9. Open threads

1. Finish the upstream kernel report — the alt-1 statement is ready; the mechanism is not.
2. Six tasks delegated to the Test Branch Maintainer (source review, instrumented `btusb`
   logging of the chosen `new_alts`, bug-report audit, `BL-09`, `bt-crash` tests, device
   survey).
3. `bt-trial` does not record which `bluetoothd` is running, so pre- and post-patch trials
   pool under identical labels. Fix changes the results-file fingerprint — operator's call.
4. The suite has not run in a while: `run-tests` refuses while a trial is open, correctly.
5. `btmon` dumps core repeatedly (33 in one 5-hour boot) — our capture tool losing evidence.

## 10. Where detail lives

| | |
|---|---|
| evidence, one claim + extraction each | `evidence/exhibits/` (`bt-exhibit index`) |
| narrative, why things were believed | `HISTORY.md` (34 phases) |
| which tool answers which question | `docs/tooling-index.md` |
| the patches and their reasoning | `patches/bluez/` |
| working rules for the assistant | auto-loaded memory (`MEMORY.md`) |
