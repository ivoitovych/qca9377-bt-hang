# BRIEF — read this first when resuming the work

**What this is.** Internal working state for whoever resumes the investigation: what is
true, what is retracted, what is open — and the rules that were paid for, **with the why**.
A rule without its reason gets re-learned; that is what this file exists to prevent.

**What it is not.** Not evidence (`evidence/exhibits/`, index in its `README.md`), not
narrative (`HISTORY.md`), not tooling (`docs/tooling-index.md`), not working habits
(kept outside this repository), **not the current snapshot** — that is `docs/STATUS.md`, one dated row
per issue and submission, the only page that says what is *current* — and **not the public
summary** — a stranger reads `README.md`. Nothing here is derivable from those: this is the
layer that says which claim holds, which was retracted, and what each rule cost.

⚠️ **Budget: 1200 lines** (`devtools/save` warns above it; 200 until 2026-09-19, 500 until
2026-10-01, 750 until 2026-10-11, 1000 until 2026-10-22, the operator's call each time). At 200 every addition cost a *why* somewhere else.
This file is what carries the work from one working period to the next, and the settled foundation (what BT-1 was, what E3 is) is what a reader most needs from it.
So, when over budget, cut the oldest *finished episode* (a closed experiment's running notes, a superseded block), never the foundation;
never cut a reason to fit a fact. **One hand-off block, not a stack**: on 2026-10-03 nine
stacked "RESUME HERE" blocks (205 lines, three of them contradicting each other on the mesh
series) were moved to the end of `HISTORY.md`; the block below is replaced, not
topped up. **Sections name their owner**; each owner writes theirs and points at the long form
(`lessons/`, `reviews/`) rather than reproducing it.

## 0. Start here, every time the work resumes

**Read in this order before any technical claim:**
1. this section;
2. the hand-off block below;
3. `docs/STATUS.md`;
4. `docs/tooling-index.md`, before typing any pipeline.

Do it at the start of every working period. A hand-over note or a recollection of earlier work records what happened *recently*. It is not the state of the project.

**Any hand-over note carries forward:**
- the state block below, as it stands;
- every open operator decision and every pending send;
- the instruction to reread this file first.

Recent detail may be shortened. Settled state is never dropped.

### Foundation — settled; what a reader needs first

- **The device.** The laptop's controller is a QCA9377 with USB ID **`13d3:3503`** (IMC Networks).
  `0cf3:e300` is a *different* QCA device that stock btusb already lists; it is only the
  positive control of `scripts/btusb-has-device.py`. FOUND on `0cf3:e300` shows that the check
  works and says nothing about this laptop.
- **BT-1, solved at the cause.** On a transparent (mSBC) SCO link btusb uses alt setting 1; the
  first HCI command after the stream starts gets no reply, and only a power-off recovers the
  controller (12 deaths, `EX-033`…`EX-053`, §2). Cause: `13d3:3503` was missing from btusb's
  device table, so the controller ran its ROM firmware. The upstream entry **`dc16388d45ec`
  (Tibor Harcsa, not ours)** gives it `BTUSB_QCA_ROME`, which loads the QCA rampatch and NVM
  (boot log: `QCA: patch rome 0x302 build 0x3e8`). E1 (that firmware setup only) and E3 (the
  exact upstream entry) ran 74 links with 0 timeouts (§3). What the ROM firmware does wrong is
  not known and not claimed (§4).
- **E3 and kernel updates.** E3 is btusb with that entry, built for one kernel ABI into
  `/lib/modules/<krel>/updates/`. Before any new kernel boots, run `scripts/btusb-has-device.py`
  on its **stock** btusb (default ID `13d3:3503`) with the control; if ABSENT, E3 is rebuilt for
  it first. A changelog or a version number proves nothing (backports).
- **Dangerous on this machine, and why.**
  - Never unload, reload, rebind or swap btusb or `bluetooth.ko` on the running system: a
    reload kills even a *healthy* controller here (`EX-046`, 09-23), and recovery needs a
    power-off. Module tests go through `updates/` + `depmod` + a cold boot, on the operator's
    word (§9.9).
  - Never `install.sh --apply`: its watchdog's USB reset drove a wedged controller off the bus
    three times (`EX-023`, `EX-026`). After any `--tools-only` deploy run `bt-mode status`: it
    silently reverted the baseline on 08-19 and 09-01 (§7).
  - In an untreated window only sysfs reads are safe; `bt-mode` writes live, so check
    `bt-window` before any mode switch.
- **BT-9 follows from the fix.** The quirk the entry sets (`HCI_QUIRK_SIMULTANEOUS_DISCOVERY`)
  exposes a core race in which discovery never stops and every later scan is refused Busy.
  Fixed upstream by `96d006ae6445` (Jiajia Liu); our backports carry it to 6.12, 6.6 and 6.1.
- **Separate from BT-1:** the BlueZ crash fixes (BT-7) and the kernel MGMT fix `86ef0f58bdec`
  (BT-8) are other defects found on the way.
- **Retracted claims are in §5.** Read them before asserting anything about the signature.
- **Which record is current:** the submission rows of `docs/STATUS.md` for every upstream state;
  STATUS's issue rows and the list below follow them.

**The state at a glance (2026-10-28; the submission rows of `docs/STATUS.md` win):**
- **BT-1's fix in stable:** released in 7.2.10 and 6.18.56 (10-11), 6.12.113 (10-15) and 6.6.160
  (10-21); in the 6.1, 5.15 and 5.10 release candidates of 10-17, still unreleased on 10-28
  (`EX-061`; STATUS). Ubuntu's `7.0.0-38` stock btusb lacks it, and so do `-39` (noble-proposed
  since 10-01) and **`7.0.0-42`, pending in noble-updates since 10-27** (its base is v6.18.55 /
  v7.2.9; CO-09). **E3 is rebuilt for `-42` before it ever boots** (§0; its source is prepared in
  `cache/ubuntu-7.0.0-42`, the entry applies at offset 12).
- **Accepted upstream, ours:**
  - kernel `86ef0f58bdec` (BT-8): in v7.3 (released 10-18; first in v7.3-rc7); released in 7.2.11, 6.18.57 and 6.12.113 (10-15) and 6.6.160 (10-21); in 6.1.191-rc1 (10-17);
  - BlueZ `a734b06059cb` and `0bed9886cff3` (BT-7);
  - BlueZ `ae23df052290` and `6f5eeb402d3b` (M-3);
  - BlueZ `8da7e648a9fb` (emulator hook leak) and `f3344d20d904`, `2942883d2738`, `49a70562f0bf`
    (the BT-9 test), applied 10-12, identical to what was sent (same patch-id and message, checked 10-17);
  - BlueZ `b79d4a887` (A1, the a2dp duplicate check) and `7bc9684dc` (A2, the emulator VLA), applied 10-19, identical to what was sent (same patch-id, checked 10-20);
  - the BT-9 stable backports of `96d006ae6445`: released in 6.12.113 (10-15, `9a328ae01489`) and 6.6.160 (10-21, `80861f424fe5`); 6.1 in its 10-17 release candidate (5.15 and 5.10 rightly get the entry without it: the code it fixes is first in v6.1);
  - the `Tested-by` on 6.6.160-rc2 (CO-10, sent 10-21).
- **Submitted, under review:** CO-02, "[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse" (`Cc: stable`) and its BlueZ sco-tester test, sent 2026-10-27 17:50 +0100 (patchwork 14919266–14919269). The list bot passed both (the BlueZ test with its expected smatch note); no human reply on 10-28. If Luiz Augusto von Dentz's pending tester series (patchwork series 1191414, sco-tester off GLib) lands first, the test needs a port.
- **Waiting for replies (re-checked 2026-10-28):** CO-02 (above); the Tested-by on Hui Peng's
  mesh_tx leak patch (10-06; still `new`); the #1554 retest by a second affected user (nothing
  since 10-14). Every other authors' mesh fix is still `new` with no maintainer reply (STATUS,
  the mesh row). Stable: 6.1, 5.15 and 5.10 are still at their 10-17 rc1, with ours in; no review
  mail found for them (lore refuses this machine, 403; CO-28 waits).
- **Operator decisions open** (the one list; the hand-off block below points here; re-read 2026-10-28):
  - **`7.0.0-42`:** hold the HWE update until E3 is built for it, or install it and build E3 before the first reboot (CO-09);
  - **sends:** CO-34 (BT-12, ready); a stable request for BT-10's fix (CO-35; 7.2.y as is, the older lines need backports); CO-04's independent fix when it is ready; CO-05 after its review; any reply to CO-02's reviewers;
  - **the CO-02 module on the laptop:** keep it (it runs since 10-23) or remove it (`module-updates.sh remove` + a cold boot);
  - **deploying `main`'s tool set on the laptop** (the review is done, `reviews/review-comprehensive-code-review-20261019-014718.md`; phase 1 of its reaction plan comes before the deploy, and of it SR1 and T1 are left, 2026-10-19): until the deploy every shutdown with a trial open probes the controller and can lose a row (Machine, below);
  - installing a rebuilt bluetoothd (5.72-0ubuntu5.8's source, the BT-7 fixes, U12's `a14d59725`): the running build lacks five CVE fixes of 2026-10-07 (STATUS), then the U12 backport request (CO-03);
  - restarting the raw-capture archive timer (gone since the 10-13 reboot; the desktop capture's recorders run again since 10-23 22:12, STATUS);
  - an Ubuntu SRU for `dc16388d45ec` (less pressing: Ubuntu's next stable base should carry it; an inference);
  - the U6 SRU; the U7 and U17 PipeWire reports and the U15/U20 quirk entries (PipeWire's rules: the operator writes); the U11 opt-in proposal; U19's Launchpad report;
  - a reply on Jiale Yao's power-off patch (patchwork 14864878; its comparison must be re-run first, CO-06);
  - debug builds: GNOME Settings, and `btusb` for U8;
  - shellcheck; a second copy of the capture archive (§7); recording the running `bluetoothd` in `bt-trial` (§8a);
  - a sweep of older public text for the neutral wording (new text follows it already; on 10-28 the documentation review found "public/private" and "the family laptop" in older lines of `devtools/README.md`, `reviews/README.md`, `docs/mesh-tester-ci/README.md` and this file's §9.6).
- **Machine:**
  - **Since 2026-10-11 16:26 the laptop runs `7.0.0-38` with E3 built for it** (`updates/btusb.ko`, the exact upstream entry; srcversion `D1DEA96A0C95BFAB05CEE01`; the boot log shows `patch rome 0x302 build 0x3e8`, so the QCA firmware is loaded). The build is on private `diag/e3-btusb-for-7.0.0-38-20261010`.
  - `-38`'s **stock** btusb still lacks the entry. A kernel update that does not carry it needs E3 rebuilt before the next boot.
  - `-38` also carries the BT-9 fix (`96d006ae6445`). The discovery stuck since 10-04 had already ended on 10-10 at 15:02, at the operator's adapter power cycle (§5; corrected 2026-10-14).
  - The trial E3 #1 on `-34` **lost its results row** at the 2026-10-11 16:24:45 shutdown; `bt-trial-auto` then opened a new "E3 #1" on `-38` at 16:26 (`docs/STATUS.md`). Every shutdown risks the same until the fixed `bt-trial` is installed. The fix is on `main` (`4c26c5d`, cherry-picked from `d5272a6` on `tests/unit-testing-introduction`, plus `25dfc68`, and since 2026-10-18 the close writes its row before `bt-state`, `bt-mark` and the SCO decode; the decode, `btmon` over 48 GB of captures, took trial 14's close 53 minutes and was running when trial 15's close stopped without a row) but not on the machine. **The trial of the 10-13 boot was therefore closed by hand on 2026-10-18 at 17:03** (`scripts/trial-close-now.sh --reopen`: `main`'s closer from the checkout, passive, row first; 13 SCO setups, 0 timeouts; STATUS), and E3 #2 opened at 17:05:04, mid-boot. Until the deploy, a shutdown with a trial open still decodes the captures before the row if the trial saw a call, and the installed `autostop` and `bt-mark` send HCI Read Local Name up to four times (STATUS, the machine's warnings). The only sound route is the whole tool set: `install.sh --tools-only`, `daemon-reload`, `bt-verify-install`, `bt-mode status`. `bt-trial` alone is a partial deploy (STATUS). The stop timeout is 90 s now (systemd's default) and 30 s once `main`'s unit is loaded. When is the operator's decision.
  - **On 2026-10-13 at 20:26 the laptop stopped abruptly** (no shutdown sequence in the journal; cause not recorded) and rebooted at 20:29. The second "E3 #1" lost its row too, and the fix could not have prevented that: an abrupt stop runs no ExecStop. Its E3 result is whole in the journal: 7 links, 0 timeouts (`scripts/sco-ledger.sh -1`).
  - **On 2026-10-19 at 21:52:54 the laptop stopped abruptly again**, in the middle of a
    call (a wideband link up for 2 h 12 min), with no shutdown sequence and no Bluetooth
    error. The cause is unknown; the operator thinks a forced power-off by someone at the
    laptop is possible. E3 #2 lost its row; its result is in the journal: 8 links, 7
    hang-ups answered, 1 open at the stop, 0 timeouts. A new "E3 #2" opened at 21:53:22 in
    the same directory (STATUS). The shutdown step's redesign: §9.11.
  - **Since 2026-10-23 11:04 (boot `257d1599`, uninterrupted to 10-28) the laptop also runs the
    CO-02 series' `bluetooth.ko`** (`updates/`, srcversion `0D084A056A9EEFB98E8F331`, `EX-071`;
    the same code change as the series sent on 10-27, `EX-082`), installed on the operator's word
    on 10-23 09:40 after E3 #2 was closed by hand (row: 55 SCO setups, 0 timeouts). The boot unit
    opened **E3 #3**, labelled E3 but carrying the CO-02 module, so its row stays apart from E3's
    counts (`evidence/trials/E3/trial-03/NOTE-not-plain-E3.txt`). Rollback: `module-updates.sh
    remove` + a cold boot. The desktop capture runs again since 10-23 22:12:30 (STATUS).
  - Only the operator touches the machine's Bluetooth or kernel.
  - **Raw HCI captures are archived** into `archive/bt-trace/` (git-ignored) by `scripts/bt-trace-archive.py`, on a transient timer. It has been paused since 2026-10-11 17:23 (free space then; 108 GB free on 10-17), and the 10-13 reboot removed the timer. Restarting it is the operator's decision. On 10-17, 159 archived files still stood in front of the first unarchived capture: about three weeks at the current rate (`docs/STATUS.md`). Rules: §7, "Evidence".
- **Open investigations:** `U10`, the Tronsmart T8 silent on SBC-XQ (waiting on the operator's test-sound check); `U13`/`U18` and `U16`, BlueZ defects with the laptop's headsets, needing reproducers and patches; CO-04's independent fix for the mesh use-after-free; on 6.12.114 an iso-tester stall with a lockdep warning, not analysed (STATUS, BT-11) (`docs/issues.md`).
- **Who works where:**
  - **Active development is on `main`** (operator, 2026-10-13). The held documentation branch, the E3 build branch and `ci/upstream-ci-local` were landed on `main` that day; the held branch as new commits with its privacy fixes, never as a merge.
  - The test-suite maintainer works on `tests/unit-testing-introduction` and `tests/unit-testing-introduction-ready-for-main`, and merges `main` into them on their side (`comms/`).
- **Sending:** nothing is sent without the operator's word. Before any send, run the receiving project's CI on base and on base plus ours (§8).

**Last updated: 2026-10-28** (the documentation review: every foundation document checked
against the facts re-verified that day; the state block above rewritten; the hand-off of
2026-10-18 to 10-23 moved to `HISTORY.md` verbatim and replaced below). The trail of earlier
updates is in `HISTORY.md` and `git log -- BRIEF.md`, not here: until 2026-10-28 this line
carried a running list of every update since 10-14, which grew to about 2,800 characters
(`reviews/2026-10-28T0300Z-documentation-alignment.md`). **Newest exhibit on `main`: EX-083**
(EX-067 to EX-083 are CO-02's hardware run and code comparisons). No tip hash: it rotted within
hours (`R2-13`).

> **HAND-OFF (2026-10-28, after CO-02 was sent, every possible submission was re-checked
> upstream, and the foundation documents were reviewed).** Current state of every issue and
> submission: `docs/STATUS.md`. The open decisions: "Operator decisions open" above. The previous
> block (2026-10-18, with its 10-19 to 10-23 items) is at the end of `HISTORY.md`, verbatim.
>
> - **In flight:** CO-02 under review since 10-27 (bot passed; answer reviewers technically; the
>   BlueZ test may need a port to Luiz Augusto von Dentz's tester series). CO-28 waits for the
>   6.1/5.15/5.10 review mails.
> - **Ready or near, each the operator's send:** CO-34 (BT-12, one line, `pre-send-check.sh` OK);
>   CO-35 (BT-10: `32d86e048d8ef` + `608e0b7a675b2`, 7.2.13 passes, 111/111; backports for older
>   lines still to make); CO-05 (needs an outside review of the written patches).
> - **Next work, agreed with the operator on 10-28:**
>   1. the sent-mail check: an inventory of every mail as sent (file, Message-ID, patchwork id,
>      SHA-256), a one-time comparison with the copy upstream received (cached in `cache/`), and
>      a hash guard on every save and push so a sent file never changes again;
>   2. CO-04: an independent fix for syzbot's mesh_send_sync use-after-free (`log.md` there).
> - **Before any reboot:** if `7.0.0-42` is installed, E3 for it first (CO-09's recipe).
> - **Method lessons of 2026-10-28:**
>   - a bisect across a range where a second, newer bug gives the same symptom finds that bug's
>     end; apply the newer bug's fix at each step that has it (CO-35, `bisect2-step.sh`);
>   - "applies" is not "builds": the BT-10 pair applies to 6.18 and fails on its lock
>     annotations;
>   - a distribution tree has no shared history: `scripts/commit-in-tree.py` with a base and a
>     positive control answers "does it carry this fix";
>   - the documentation review's causes and guards: `reviews/2026-10-28T0300Z-documentation-alignment.md`.


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
  `dc16388d45ec`** (master, 2026-08-07, for a BLE-scan fault; mainline v7.3-rc1; in stable 7.2.10 and
  6.18.56 since 2026-10-11, 6.12.113 since 2026-10-15 and 6.6.160 since 2026-10-21; in the 6.1, 5.15 and 5.10 release candidates of 2026-10-17) — and that entry's setup/reset path was **untested here** (`DR-01`)
  until 2026-09-26. ✅ *Since then:* the setup half alone (E1) ran 58 links / 3 boots /
  2 headsets with 0 timeouts (`EX-055`, `EX-056`, `EX-058`); the exact entry (E3) ran 16 links /
  2 headsets with 0 timeouts (`EX-057`). **The missing entry is the cause**: on ROM firmware the
  first command after the stream dies; with the QCA firmware loaded it did not, in 74 links.
  The stable backport request went out 2026-10-02 (`docs/STATUS.md`).
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

- **Mechanism.** Correlation across 12 deaths / 1 survival (§2; "7" when this was written,
  09-18). *What the ROM firmware does wrong* with alt-1 traffic is unknown and is not claimed;
  the host-side remedy (load the firmware the entry provides) is validated, §3.
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
| "the discovery stuck since 10-04 lasted until the reboot into `7.0.0-38` (10-11)" | **FALSE** — the operator's adapter power cycle ended it on 10-10: powered again 15:02:44.156, the next Start Discovery answered Success 24 ms later, and no `Status: Busy` in any capture from then to the 10-11 shutdown; the control, 05:10:31 the same day, is refused Busy (`docs/STATUS.md`, BT-9) |

## 6. The BlueZ patches — status: **APPLIED UPSTREAM 2026-09-21**

**Both v1 patches are in BlueZ master, committed by the maintainer 2026-09-21T10:10-04:00 exactly
as sent: `a734b0605` (adapter), `0bed9886c` (a2dp).** Thirty-eight days from first crash to tree.
Every URL — kernel.org commits, lore, patchwork v1/v2, bot PRs — in the status table at the top
of `patches/bluez/README.md`; no BlueZ release tag carries them yet (master is `5.87-397-gfa6ba5502` on 2026-10-17).
⚠️ The v2 mails (22:47 CEST the same day) were sent 6.5 h *after* that, checked against a
month-old cached checkout instead of a fetched `origin/master` — redundant, bot said "does not
apply" for `0001`, all-PASS for `0002`. Lesson in code: `scripts/pre-send-check.sh` fetches and
reports ALREADY APPLIED before any mail. **Verified at kernel.org itself** (`ls-remote` tip
`17e624d1c`, both commits served with his `From:`). Sequence UTC: v1 09-19 18:44 → applied 09-21
14:10 → v2 20:47 → bot 22:42/23:20; **neither v2 arrived before the merge** — `0002` v2 "passed"
only because a pure insertion applies twice (PR #2559 would add the guard a second time, lines
2697 and 2702). **Decision 09-22: send nothing on the v2 threads**; watch their patchwork states
(14836499 / 14836500, both `new`). Patchwork's *superseded* on the v1 rows is automatic.
*Since:* the maintainer applied the a2dp v2 too, on 2026-10-07 (`d84171e6cd68`, the check twice
in a row), and A1 removed the duplicate (`b79d4a887`, 2026-10-19). Patchwork still shows both v2s
`new` (2026-10-28): it did not match the applied one.

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

⚠️ **This section and §8 are the DURABLE copy.** They were once kept only outside the
repository, where a reclone, reinstall or moved directory would lose them. Working habits
stay outside; everything that is true regardless of who is working lives here, in git.

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
- **Never force-push without a backup branch first.** A rewrite with a mistake deletes
  work, and mistakes are made all the time. Before any history rewrite: push the branch as
  it stands to the `private` remote as `<branch>-backup-<YYYYMMDD>-<HHMMSS>-utc`, verify
  the remote has it, then rewrite, then push with `--force-with-lease` only. Set
  2026-10-11, when `ci/upstream-ci-local` was rebuilt so that patchwork mail headers (the
  relays' addresses) never entered its history; the backup is
  `ci/upstream-ci-local-backup-20261011-144932-utc` on `private`.
- **Evidence, decided 2026-10-11 by the operator.**
  - **What is committed** is the incident window: complete inside the window (every relevant source, no line filtered out, a margin before and after), and nothing outside it. GitHub space serves everyone, so no bulk history goes into git, public or private.
  - **Evidence is never deleted,** fixed bugs included: a deletion does not shrink history, and a bug can return.
  - **Raw captures are never left to rotation.** `scripts/bt-trace-archive.py` keeps them all, compressed, in `archive/bt-trace/` (git-ignored, 10 GB budget, never deletes). Windows are cut from there.
  - **Device addresses:**
    - real addresses may be committed to the **private** repository;
    - public files carry **pseudonyms** from a privately kept table: the manufacturer prefix is real, the rest random, one per device for good, with the statement that says so;
    - BSSIDs, key material (a raw capture carries link keys) and personal device names are never published.
  - **Why the address rule changed:** until 2026-10-11 no address went into any commit, private included. That kept the T8 captures out of git altogether.
- **What upstream has already published is public (operator, 2026-10-13; written here 2026-10-21).**
  - **Never mask, elide, substitute or remove:**
    - mail addresses in sign-offs and trailers;
    - the addresses of maintainers, contributors and lists;
    - Message-IDs;
    - lore, patchwork and patchew links that contain addresses.

    They are mirrored and indexed worldwide, so hiding them protects no one and costs every
    reader the link.
  - **Privacy covers only what is not already public:** private correspondence and its
    addresses, personal device names, real device addresses (pseudonyms above), keys and
    BSSIDs, and mail-relay infrastructure in raw headers.
  - **Why this is written here:** the rule lived only in one maintainer's notes. On
    2026-10-20 and 10-21 that maintainer still removed a Message-ID from STATUS, patchwork
    links from outside reviews, and a reply's public recipient list, each time because
    `devtools/repo-scan` flagged them. The scan now accepts the tokens listed in
    `devtools/repo-scan-public-addresses`:
    - published addresses and whole Message-IDs, matched exactly;
    - `@host` only for mailing-list hosts.

    A first version also passed whole organisation domains and address suffixes. Outside
    reviewers found that within hours, and it was fixed with tests. When the scan refuses a
    published address, add it to the list. Never cut it from the text.
    - The maintainer's own address passes exactly, or as their own git send-email
      Message-ID; kernel.org addresses are listed one by one (both since 2026-10-21, after
      the second recheck).
    - A made-up address that an outside review quotes is nobody's published address. It
      goes into `devtools/repo-scan-quoted-examples` with the file that quotes it, and passes
      only there.
- **Nothing we write exists only on this disk (operator, 2026-10-11).** Whatever cannot go public goes to the private remote.
  - **Pushed:** branches, worktrees, notes, and the commits made inside upstream checkouts under `cache/`. Those go as patch exports, never as the trees themselves (`scripts/export-local-work.py` → a branch on the private remote). `scripts/unpushed-survey.py` lists what is still local.
  - **Exceptions, kept local on purpose:**
    - **the raw capture archive** (`archive/`, up to 10 GB). It is bulk, not windows, and GitHub space is not for it;
    - **upstream source trees**, which can be fetched again;
    - **build outputs and the bulk of `tmp/`**, which can be regenerated.
  - **The archive's one weakness** is that it lives on one laptop disk. A copy elsewhere (an external disk) is the operator's call.
- **Do not send the patches** until the operator says so.
- **An untreated window is the most valuable state there is.** Do not touch Bluetooth;
  `sysfs` reads are safe, anything through usbfs is not. ⚠️ **`bt-mode` writes
  `power/control` live** — check `bt-window` before any mode switch. `bt-state`, `bt-status`,
  `bt-incident` are probe-free since 09-18; `--probe` sends an HCI command and is an intervention.
- **Kernel findings are recorded on `main` as they are found** (operator's decision,
  2026-10-09; first: `EX-062`). From 2026-09-17 to 2026-10-09 the rule was the opposite —
  a kernel finding stayed off `main` until its patch could follow at once — so the work of
  that period sits on the `private` remote (`ivoitovych/qca9377-bt-hang-private`):
  `kernel/mgmt-flush-status`, `diag/*`, `plan/*`, `postponed/*`, `review/*`. It comes back as
  **new commits that copy vetted files**, each naming its source branch and commit, never as a
  `git merge`: a merge would publish the branch history, which also holds working-session
  material that is not project content. The held-branch machinery stays: `repo-save` still
  pushes `kernel/*`, `diag/*`, `plan/*`, `review/*`, `attribution/*`, `postponed/*` and
  `config/*` to `private` only (tested; `scripts/prove-held-branch-guard.sh`), for work that
  is private for other reasons.
- **Verify operator accounts against logs** — he asked not to be trusted. Find the record or
  label the claim.
- **Every claim ships with its extraction command and exact verbatim output**, plus exit
  status and whether it was redacted. A claim without a re-runnable derivation is not
  evidence. This is why `evidence/exhibits/` exists in the shape it does.
- **Write identifiers in full** — branch names, paths, boot ids. Never `…`, never a short
  form after first use. Five branches here differ only by a trailing UTC timestamp; eliding
  them makes them indistinguishable exactly when the difference matters. Short SHAs are fine.
- **Attribution is the operator's.** `repo-save` refuses a commit whose author or committer
  identity is missing or was assigned by the environment (a reinit reset a collaborator's git
  config on 09-18; caught by eye, now gated). Upstream sign-off is `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` — title case. ⚠️ The name and
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
- **The tools we forget, and what forgetting cost.** The full list is `docs/tooling-index.md`;
  these were the ones skipped when they existed:
  - `scripts/copy-tree.sh` for any copy with a flag (`cp -a`/`-p`/`-r`): forgotten 10-10,
    three times.
  - `scripts/pre-send-check.sh` before any BlueZ mail (fetches today's master): BlueZ v2 went
    out 6.5 h after v1 had been applied, 09-21.
  - `scripts/mail-lint.sh` on every mail: the 10-10 stable note had three lines of 73-76
    columns, found by a reviewer, not by us.
  - `scripts/get-maintainers.sh` plus the previous mail's Cc: the 10-10 stable mails nearly
    went to Luiz's sign-off address instead of his MAINTAINERS one.
  - `scripts/stable-queue-check.sh <short stem>` with a positive control, and
    `scripts/series-backport-check.sh <tag>` (tags, not branch names).
  - `scripts/patchwork-checks.sh` and `tmp/bt9-repro/ratatoskr-scan.py`. lore refused fetchers
    earlier (403); on 2026-10-18 it answered a plain non-browser user agent with an Atom feed
    (`curl -A "qca9377-bt-hang/check" "https://lore.kernel.org/linux-bluetooth/?q=s:transport_cb&x=A"`
    → `200 application/atom+xml`).
  - `devtools/save <msgfile>` then `devtools/ci --wait <sha>`; `scripts/stop-own-process.sh`.
- **Run the receiving project's CI before sending, on base and on base plus ours.** The 10-10
  BT-9 sends drew three red bot marks, none of them ours
  ([`ci-bot-2026-10-10.md`](patches/kernel/bt9-stable/results/ci-bot-2026-10-10.md)):
  smatch's VLA at upstream `btdev.c:479`, a TestFunctional pairing timeout that failed the
  same way on an unrelated patch, and the kernel bot's apply step on a stable backport. We
  were clean by scope, not by checking. A lone local run only repeats the bot's noise; the
  difference against the base is what tells ours from theirs. A failure that is theirs is a
  candidate fix of its own, once we know it is not already reported. (The pairing timeout
  was: Pauli Virtanen's patchwork 14879847 of 10-10 fixes it; found 2026-10-18.)
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

*Written 2026-09-24, replacing the reservation; updated 2026-10-17. Each rule cost something; the instance
that taught it and what it cost are in
[`lessons/2026-08-22T1101Z-test-suite-maintainer.md`](lessons/2026-08-22T1101Z-test-suite-maintainer.md)
and [`lessons/2026-08-27T1200Z-test-suite-maintainer.md`](lessons/2026-08-27T1200Z-test-suite-maintainer.md).*

- **A new check must be observed to fail.** Write it, break what it guards, watch it go
  red, restore. Checks that *could not* fail keep reaching this suite green. The seventh
  was `rg … || true`, where a missing binary made a negative search read as a clean one;
  the eighth (2026-09-24) was in the check policing this very rule — a drift guard that
  matched its stem in a *comment*, so the code could drift and it stayed green. Strip
  comments before asserting on source. `devtools/mutate` found more on 2026-09-29.
- **A step that passes when it skips must say why, where someone reads it.** CI's system
  round trip, the only test of `install.sh`'s apply branch on a real system, printed
  "skipped" and passed on every run until 2026-10-16: it asked `systemctl
  is-system-running`, which exits non-zero for `degraded` as well, and a CI VM is
  commonly degraded. Ask for exactly what is needed (systemd as PID 1), print the state
  that was seen, and read a green step's log the first time it goes green.
- **State the premise in code, not in a comment.** An assertion that says "this host has a
  readable journal" and never asks has two meanings and tests one. On a journal-less host
  it accepted `bt1_status=not_observed` — *"we looked and BT-1 did not happen"* — for a
  trial where looking was impossible, on every run and every CI run since the classifier
  was written. It then derived the premise from the host, so a bare host checked one
  answer and the laptop the other; since 2026-09-29 the journal is an input — readable
  in one test, absent and unreadable in another — and both answers run on every host.
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
  `BT_DESTDIR`), and fixtures carry placeholders (`AA:BB:CC:…`, `192.0.2.x`,
  `example.com`) — never real-but-shortened data. `bt-trial` writes in two places, so two
  variables guard it: `BT_REPO` (its `results.tsv`) and `BT_EVIDENCE_REPO` (the incident
  `bt-incident` collects on a failed trial). Every call goes through a wrapper that sets
  both, a check requires that of each wrapper, and `BT_EVIDENCE_REPO` points at the
  declared machine for the whole run (tests/README.md, rule 4). The seam is complete **as
  measured**, not as believed: every machine tool answers from a tripwire unless a test
  declares it, `/proc`, `/sys` and the install paths resolve to a declared machine for the
  whole run (empty, but for a fixture `/proc`), nothing the run starts may outlive it, and
  CI runs the suite in `devtools/sandbox`'s decoy world, which fails on any call, read or
  write that reaches the real machine (tests/README.md, rule 5).
- **A stub that answers with silence is not the real neighbour.** The suite's PATH guard
  answers every name `install.sh` installs with a recording stub that prints nothing, so no
  test ever ran a tool beside the project's own tools it calls where they are installed.
  `bt-trial`'s close calls `bt-state` and `bt-mark`, and the real `bt-state` reads the
  whole boot's kernel journal with no budget: it sat ahead of the results row, and with the
  real tools on the PATH the slow-journal close was killed with no row written (rc=124,
  2026-10-16). Where a tool calls a sibling "if installed", run it once with the real
  sibling, in `install.sh`'s layout.
- **A deploy is an upgrade.** A fresh-install round trip cannot see what an upgrade does.
  `install.sh` took the project's own older copies for foreign files (15 of them on the
  investigation machine) and kept them for an uninstall to put back. Rehearse the
  transition that will actually happen: the installed version and its state (a trial open,
  the mode), the new deploy, the shutdown that runs the new code over the old state, and
  back (`tests/system-upgrade`, CI).
- **A section stands alone.** The suite runs its sections in parallel workers, each with a
  fresh setup, so a section reads only that setup. Shared fixtures go there; a section that
  reads another's definitions says so (`# PARALLEL: runs after "<heading>"`). Established by
  running each section alone and comparing the two modes check by check (2026-10-18;
  tests/README.md, rule 9). The instruments measure the parallel run; CI keeps one serial
  run, the one that shows a section breaking a later one.
- **Rehearse with the stimulus present.** The rehearsal's trial saw no SCO setup and had no
  captures, so the close's slowest step never ran in it: a `btmon` decode of every capture,
  ahead of the row, with no budget (2026-10-18). A close is tested with what a real trial
  leaves: a call in the kernel journal, captures on disk.
- **Ids on `main` are `main`'s.** `main` takes work as new commits, so a test-branch
  commit's id is not on `main` even when its change is. Say where an id is: `main`'s own
  id for what is on `main`, or the branch, by name, that holds it.
- **A leak is only visible where the mock and the world disagree.** For weeks the suite
  called the real `journalctl`, `systemctl`, `logger` and `lsmod` — 312 calls a run — and
  every one passed, because on a bare host and in CI the real machine answered *nothing*,
  which is exactly what an empty fixture returns. On the laptop the same calls read its
  real journal and wrote 20 fake trial lines into it. A check that the suite is hermetic
  has to run in a world that answers differently from every fixture, and has to prove on
  itself that it would catch a leak.
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

1. ✅ **Closed 10-03: `docs/bug-report.md` is a historical pre-fix draft, labelled as such.**
   The kernel-side report it prepared was overtaken: the cause is the missing entry, fixed
   upstream by `dc16388d45ec`; what went out instead is the stable backport request (10-02).
   As written 09-18: rewritten around `EX-037`–`EX-043`; it leaves only with a kernel patch.
2. Six tasks delegated to the Test Branch Maintainer (source review, instrumented `btusb`
   logging of the chosen `new_alts`, bug-report audit, `BL-09`, `bt-crash` tests, device
   survey). **State 2026-10-19** (their handoff, `comms/2026-10-19T0504Z-…` §10.5): the source
   review, `BL-09` and the `bt-crash` tests are done; the bug-report audit is moot (item 1); the
   `new_alts` logging was never built and is dropped unless KR1's evaluation needs it; the device
   survey has no record of its scope on either side, so it stays open until the operator says
   what it was or drops it.
3. `bt-trial` does not record which `bluetoothd` is running, so pre- and post-patch trials
   pool under identical labels. Fix changes the results-file fingerprint — operator's call.
4. ⚠️ **CI was red again on every push from 2026-09-26 to 10-02 — thirty runs** — for the
   same reason as before with a new twist: the suite refuses while a trial is open, a trial was
   open throughout E1/E3, so nothing ran locally, and `devtools/save` printed "CI will run it
   on push" thirty times. Four invariants, all in that week's code: two `| grep -q` pipelines
   (`backport-check.sh`, `bt-trial`), a `tx timeout` spelling in `sco-ledger.sh`, four `bt-trial`
   calls outside `trial()` in the suite, and **one real defect**: `journalctl --grep` exits 1
   when nothing matched (systemd 255), which the new closer read as an unreadable journal —
   every clean trial would have closed `unknown` once the 09-28 tool was installed. Fixed
   10-03 (`fix/ci-invariants-2026-10-03`, green on CI, merged); `scripts/prove-trial-nomatch.sh`
   carries the proof for open-trial days. The coverage exclusions had rotted too, behind the
   red step. Lesson: a red badge nobody reads is the same as no CI; `devtools/ci` after every
   push on days the suite cannot run here.
   **The first episode:** red from `d70cb2e` (09-01) to `3cf4dd6` (09-14) and nothing
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
6. ✅ **Done 09-26 → 10-01: E1 (setup only) and E3 (the exact entry) ran, 0 timeouts in 74
   links; the stable request followed (§3, `docs/STATUS.md`).** As it was planned:
   **The next experiment is a kernel, not more logging (deep review 2026-09-20).** Every
   reproduction ran on a kernel that treated `13d3:3503` as generic; `dc16388d45ec` gives it
   `BTUSB_QCA_ROME`, which installs *both* QCA firmware setup and a reset-on-timeout callback.
   Those must be separated ("Build B": setup on, automatic reset off) or a failure and its
   treatment land in one trial. Ladder: A baseline on one fixed tree → B setup only → E setup
   on, alt-1 blocked for this ID → D as upstream. **A kernel build on the family laptop —
   the operator's decision.** Kernel version alone no longer predicts behaviour (backports):
   check the running `btusb` for the entry (`tools/bt-verify-kernel-mechanism`), never the version.
7. **BlueZ — CLOSED: both applied upstream 2026-09-21 (§6).** The v2 mails of 22:47 CEST were
   moot; **no reply is sent** — watch the v2 patchwork states instead (*since:* the a2dp v2 was
   applied as well on 10-07, `d84171e6cd68`, and its duplicate check removed by A1, `b79d4a887`,
   10-19; the adapter v2 is still `new`, checked 2026-10-28). Never again send without
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

9. ✅ **Closed: the patch ran here 09-24 with no regression and was applied upstream 09-29
   (`86ef0f58bdec`).** The record below is kept as written.
   **Kernel-patch runtime test — prepared 09-23, waits for a closed window and the operator.**
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
   the way, a `BT-4` instance (the test now points `BT_TRACE_DIR` at a directory that does
   not exist, and the suite declares `BT_HEALTH_DIR` for the whole run). Both fixed in the
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
    uptime, not with the tests. `.github/workflows/checks.yml:8` said *"the suite is
    ~2 s and hermetic"* until 2026-09-29; it now says about a minute, hermetic as measured
    in the decoy world. Also: the five gates that each re-run the whole suite then cost
    **6 min 53 s** here, and four concurrent runs finish in 68 s, so the split (`UT-12`)
    buys ~3×. **Done 2026-09-29 for the machine half:** every tool in
    `tests/machine-tools` answers from a tripwire for the whole run, `/proc`, `/sys` and the
    install paths resolve to a declared empty machine, and an invariant fails on any call
    that reached the machine — 274 did on the first run; none now. `devtools/sandbox`
    measured the rest (312 calls, 12 machine-dependent verdicts) and CI runs the suite in its
    decoy world on every push (tests/README.md, rule 5). **Still open:** the gates that each
    re-run the suite (seven in CI's check job on 2026-10-17, an eighth in the audit job of
    the test-suite branch), and the split.
11. **Trial evidence must not depend on the shutdown (operator, 2026-10-21).**
    **Trial rows were lost at four stops:**
    - trial 15 (09-30): the close stopped inside the SCO decode;
    - E3 #1 on `-34` (10-11), a normal shutdown: the installed closer reads and decodes
      before it writes the row;
    - two abrupt stops with no shutdown sequence: 10-13 20:26, and 10-19 21:52 in the
      middle of a call (STATUS).

    **The operator's direction:** make the shutdown step short. Copy raw evidence without
    processing it, and process it after the reboot or in the next session. To think through
    before any code:
    - **Two failure modes, two remedies.**
      - A slow close at a normal shutdown is what `main`'s fix shortens: the row first,
        about 21 s. It is not deployed.
      - A forced power-off runs no ExecStop at all. Nothing done at shutdown helps there;
        only what is already on disk counts.
    - **The raw record already survives.**
      - The persistent journal and the HCI captures are written continuously, and
        `scripts/sco-ledger.sh -1` rebuilt both lost rows' call results.
      - What is lost is the trial's own state. `/run/bt-trial/current` is on tmpfs, and the
        next boot's `bt-trial-auto` opens a new trial with the same number in the same
        directory, overwriting `state-before.txt` and `steps.log` (git keeps the tracked
        versions).
    - **The likely shape**, to design with the test-suite maintainer, test-first:
      - the shutdown step writes only a marker (boot id, time, trial directory) and computes
        nothing;
      - the trial's state lives on disk, not in `/run`;
      - at the next boot, `autostart` first closes any trial the previous boot left open,
        from that boot's journal (`-b -1`) and captures, with no time budget, and only then
        opens the next trial under a new number;
      - the SCO decode and every other heavy step run there, never at shutdown.
    - **Open questions:**
      - Is a periodic checkpoint during the trial still needed once the next boot closes
        from the journal?
      - How much of the last seconds before a power cut reaches the disk (journald's sync
        interval, the page cache)? That is an inference, not measured.

## 10. Where detail lives

| | |
|---|---|
| evidence, one claim + extraction each | `evidence/exhibits/` (`bt-exhibit index`) |
| the current snapshot, one dated row per issue and submission | `docs/STATUS.md` |
| one dossier per possible contribution: findings, experiments, log, references | `contributions/` (index: `contributions/README.md`) |
| narrative, why things were believed | `HISTORY.md` (37 phases, dated chapters to 2026-10-28, and the retired hand-off blocks) |
| which tool answers which question | `docs/tooling-index.md` |
| the patches, their reasoning and BlueZ's measured conventions | `patches/bluez/` |
