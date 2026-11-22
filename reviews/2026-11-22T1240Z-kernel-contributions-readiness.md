# Linux kernel contributions — readiness, state and what each one is (2026-11-22)

**Scope.** Every Linux kernel contribution of this project, sent or possible:
- our own patches;
- stable backport requests and backports;
- reports and replies to kernel maintainers and vendors;
- tests of other authors' patches;
- registered kernel defects that have no patch yet.

BlueZ, PipeWire, WirePlumber, gvfs, systemd and Ubuntu packaging work is out of scope.

**Read window:** 2026-11-22 12:40–14:35 UTC.

**Sources.** For each contribution, the order of authority is:
1. its own dossier (`contributions/CO-nn-*/`: README, log, the current send directory named in
   `contributions/README.md`, "What to send");
2. `docs/STATUS.md`;
3. `contributions/README.md`;
4. `BRIEF.md`;
5. older reports in this directory.

Upstream state was read live today: patchwork's API, the public stable queue
(`scripts/stable-queue-check.sh`), and the bluetooth-next and stable mirrors on GitHub. Every
disagreement found while reading is a numbered finding (`F-nn`) in the work log beside this
report, `2026-11-22T1240Z-kernel-contributions-review-worklog.md`. This report cites them and does
not repeat them.

**Earlier reports on the same subject** were used only as cross-checks, because their contents are
older than the dossiers:
- `2026-11-12T1537Z-all-contributions-explained.md`;
- `2026-11-13T0120Z-registers-and-contributions-status.md`;
- `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md` and its answers
  `2026-11-14T1400Z-…-checks.md`;
- `2026-11-15T0115Z-submitted-contributions-status.md`.

---

## 1. What changed upstream since the records were written (read today)

The project's records were last re-read against upstream on 11-15 and 11-16. Four things have
happened since, and each changes a readiness value below:

1. **The maintainer fixed the mesh transmit path himself, and it is applied** (F-41). Luiz Augusto
   von Dentz's "Bluetooth: mgmt: Fix mesh transmission locking and lifetime" was posted 11-17 and
   accepted 11-18 as patchwork 14998382. It is bluetooth-next `1d7a52778858`, committed 11-19,
   and the tip `cf357cfc025e` (11-20) contains it. By its message it:
   - takes `hdev->lock` around every `mesh_pending`/`adv_instances` access in the cmd_sync
     callbacks;
   - stops passing a raw `mesh_tx` pointer (the use-after-free);
   - clears `HCI_MESH_SENDING` only when the transmission is removed;
   - flushes the transmissions left at power-off and index removal.

   That is the ground of **CO-04, CO-05 1/2, CO-14 (M-4) and CO-06**, all of which are capped below
   until our harnesses are run on the new tip.
2. **The stable team queued CO-35's 7.3.y request on its own** (F-21, F-28). `608e0b7a675b` and
   `32d86e048d8e` are in `queue-7.3`, and so is the BT-15 SCI fix `5874f8d03268`. On 11-14 none
   was. CO-35 narrows to its 6.18.y, 6.12.y and 6.6.y backports, and its two 7.3.y mails are not
   to be sent.
3. **Cen Zhang posted v2 of "Fix advertising instance accesses without hdev->lock"** on 11-19
   (series 1215537, `new`) (F-19). Its 1/2 takes the same lock in `mesh_send_sync()` as CO-05 1/2,
   and changes the extended-advertising duration code that CO-12 changes.
4. **bluetooth-next moved** from our packages' base `da3cc02587c6` (11-12) to `cf357cfc025e`
   (11-20). It took accepted changes in `hci_conn.c` (CO-02's file), `mgmt.c` (CO-38's and
   CO-44's file) and `hci_sync.c` (CO-12's file) (F-42). Every package needs an apply check on the
   new tip before it is sent.

Unchanged and confirmed today (F-20):
- CO-02's four mails are still `new`, with no human reply.
- The mesh_tx Tested-by thread is `new`.
- The other authors' patches that overlap ours are `new`.
- CO-22's ASUS entries are still in no stable queue and not on 6.18.y (F-29).

## 2. How readiness is measured

Readiness answers one question: **how much of the work needed before this could be sent is
done and verified, in the package's current form?** It does not include the operator's word,
which every send needs anyway, or the open decisions. Those are listed in their own column.

Nine gates, each scored on fixed levels:

| gate | max | full marks | lower levels |
|---|---|---|---|
| **defect** | 10 | reproduced here (VM or the laptop), mechanism known | 8 shown by an outside reproducer plus source · 6 source only · 3 claimed, evidence not in the repository |
| **patch** | 10 | the current package is final | 5 written, with a structural choice open or a known package fault · 2 built on a withdrawn base or with a known breakage |
| **tests** | 10 | the package supplies an upstream test that fails before and passes after | 5 no upstream test can reach the code (btusb under vhci), and the emulation is described instead · 0 none |
| **VM** | 15 | fail-before and pass-after plus the regression suites, on the current form | 10 partial on the current form · 8 an earlier form only · 5 a fragment |
| **HW** | 5 | run on the laptop in the current form | 3 an earlier form · 0 not run · n/a where this controller cannot reach the code (Bluetooth 4.2: no extended advertising, no ECRED) or the device is not here |
| **review** | 15 | outside reviewers saw this form and said send | 12 changed after review exactly as the reviewers asked · 7 an earlier form reviewed, code changed since · 3 reviewed with a "hold" or "keep local" verdict · 0 none found |
| **bot CI** | 10 | the list bot's checks run here on base and patched, on this form | 5 an earlier form or one side only · 0 not run |
| **external** | 10 | upstream, queue and competing work checked within 7 days, nothing new | 7 checked 8–10 days ago · 5 the tree moved with accepted changes in the same file, apply not re-checked · 3 older than 10 days · 2 another author's posted (not accepted) overlapping patch · 0 an accepted upstream change or the stable queue covers it |
| **send** | 5 | send commands and a dry run with RCPT TO checked, on the current file | 2 one of the two · 0 neither |

`readiness = 100 × points ÷ maximum of the applicable gates`, rounded. A gate marked n/a leaves the
denominator. **Cap:** where an accepted upstream change or the stable queue covers the same defect,
readiness is capped at 10, until a re-check on the new tip shows a gap left for us. The points
per gate are in table B. They were computed by `tmp/kernel-readiness-20261122/score.py` (a
machine-local helper in the git-ignored `tmp/`, so not in a clone), so the ranking can be
recomputed when a gate moves.

## 3. Summary table A — every kernel contribution, sorted by readiness

Kinds:
- **P**: our patch;
- **B**: stable backport or request of another author's fix;
- **R**: report, reply or question;
- **T**: test of another author's patch.

"Rev." gives the outside review rounds and whether the current form was among them. "Last
external" is the newest upstream or competing-work check.

| # | item | kind | subsystem / files | patches | test with it | VM | laptop | rev. | bot CI | last external | send cmds / dry run | upstream state | open decisions (operator) | **readiness** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | CO-43 E — anchor a deferred URB under txlock (BT-23) | P | `btusb_main.c` `submit_or_queue_tx_urb()` | 1 | none possible (emulation in notes) | QEMU+usbip: parked 3/3 → 0; stress 20×2,000 cycles clean | no | 11-14 round: 5 of 5 send; current | base+patched, 11-14 | 11-15 (prior art, Willmer 14973994 applies) | yes / yes (11-14) | not sent | `Cc: stable`; goes first of CO-43 | **89** |
| 2 | CO-44 — timeout reported as Authentication Failed (BT-21) | P | `mgmt.c` `mgmt_errno_status()` + BlueZ mgmt-tester | 1 + 1 BlueZ | new mgmt-tester case: 0x05 before, 0x08 after | 526→527 of 527; l2cap 144, smp 8 unchanged | no (bug seen there on 11-12) | 11-13 four + R7; 11-14 5 of 5 send | base+patched, 11-13 | 11-13; `mgmt.c` moved since (F-42) | yes / yes (11-14) | not sent | `Cc: stable`, `Link:`, subject, send order | **89** |
| 3 | CO-38 — Read Advertising Features hides instances | P | `mgmt.c` `read_adv_features()` + BlueZ test | 1 + 1 BlueZ | new mgmt-tester case: fails base, passes | `-p Add` 119→120/128; mesh 8/10 both | no | 11-02 + 11-14 5 of 5 send kernel | base+patched, 11-14 | 11-14; `mgmt.c` moved (F-42) | to make | not sent | `Cc: stable` (D12 says yes; patch has none, F-38) | **83** |
| 4 | CO-22 — stable: two ASUS QCA ROME IDs (+ owners' call) | B, R | `btusb.c` device table | request v3 (+ call v2) | n/a | cherry-pick + build on 7 lines | n/a (not our device) | 11-02 + 11-14 send after queue refresh (done) | n/a | **today**: in no queue (F-29) | to make | not sent | both sends; the call's venue (D7) | **80** |
| 5 | CO-43 BT-24/25 — deferred URBs on failed resume / close | P | `btusb_main.c` resume failure path, `btusb_close()`, `play_deferred()` | 2 + cover | none possible | kmemleak 2–5 leaked → 0; anchor 3/3 → empty | no | extraction asked by 4 of 5 (11-14); not re-reviewed | base+patched, 11-14 | 11-15 | to make | not sent | stable form; after E | **80** |
| 6 | CO-35 — L2CAP ECRED deferred-accept hang: 6.18/6.12/6.6 backports | B | `l2cap_core.c`, `l2cap_sock.c` (another author's fix) | 3 covers × 2 backports (or the reduced prerequisite) | upstream l2cap-tester case | hang on base, pass with the pair on 4 lines; 111 cases same verdict for full and reduced | n/a (no ECRED on 4.2) | 10-28 six, 11-02, 11-14 5 (reduced variant new since) | 11-02 only (F-30) | **today**: not queued for 6.18/6.12/6.6 | to make | not sent | full or reduced prerequisite; reword covers (7.3 now queued) | **79** |
| 7 | CO-43 A — report a failed runtime resume (BT-20) | P | `btusb_main.c` `btusb_waker()` | 1 | none possible | base 0 lines, patched 2 per run | no | 11-14 5 of 5 after the message fix (done) | 11-14, not re-run after a note rewrap | 11-15 | commands yes / dry run on the old file | not sent | subject; after E | **77** |
| 8 | CO-20 patch 1 — SCO receive failures by cause | P | `btusb_main.c` `btusb_recv_isoc()` | 1 (patch 2 held) | none possible | "corrupted" 21/21/24 → 0 per run | no (captures only) | 11-14 5 of 5: patch 1 alone | base+patched, 11-14 | 11-01 (F-27) | to make | not sent | whether to send at all | **76** |
| 9 | CO-25 R — reply to Qualcomm (Zijun Hu), draft v4 | R | (report; `qca_devices_table`, `btusb_setup_qca()`) | 1 mail | n/a | n/a | the evidence is the laptop's | 11-02 five (v3), v4 after | n/a | 11-15 thread read | neither (F-32) | report sent 10-29; reply unsent | send the reply; the "three headset models" check first | **74** |
| 10 | CO-21 — SCO alt setting from the links that are up | P | `hci_event.c`, `hci_core.h`, `btusb_main.c` `btusb_notify()`/`btusb_work()` | 2 + cover | none possible | usbip 5 scenarios 0/10 → 10/10; transition test 3/3 → 0 | no (needs two modules) | 11-01 "not ready"; 11-14 split → revised as asked | base+patched, 11-14 | 11-11 (Hitalo 14875454) | to make | not sent | stable form, subject, laptop run, mixed CVSD+mSBC policy | **72** |
| 11 | CO-43 Q — linux-usb question for BT-18 | R | USB core rebind after runtime reset-resume | 1 draft | n/a | emulation 5/5 | n/a | asked for by R3, R7; the draft itself: not found | n/a | 11-14 | neither | drafted, **not sent** (F-18) | send it, or mirror `needs_binding` in D | **57** |
| 12 | CO-12 — extended advertising duration overflow (M-2) | P | `hci_sync.c` `hci_enable_ext_advertising_sync()` | 1 | tests held in CO-38's series B | AdvDur 9–10/22 → 20/22; Add 128/128 with CO-38 | n/a (no extended advertising on 4.2) | 11-02 split (D5); not in the 11-14 round | **not run** (F-36) | **today**: Cen Zhang v2 touches it (F-19) | to make | not sent | D5: clamp now or RFC first | **52** |
| 13 | CO-02 v2 — SCO connection reuse, v2 | P | `hci_conn.c` `hci_connect_sco()`, `hci_abort_conn()` + BlueZ sco-tester | 2 (+ mismatch patch later) | sco-tester tests exist, not in the candidate dir (F-22) | sco 35 pass/2 fail (mismatch cases)/7 not run; mgmt 526, iso 213; l2cap not run | v1 on the laptop 10-23→25; v2 no | ~17 rounds on v1; 11-14 five; 11-15 five → the 2/2 replaced | **not run** on the candidate | **today**: v1 still `new`; Wentao 14942649 conflicts; `hci_conn.c` moved | to make | v1 sent 10-27, no reply; the bot asks for a resend | trailer form, split, when (D1/D2) | **47** |
| 14 | CO-43 D v2 — recover after a runtime reset-resume (BT-18) | P | `btusb_main.c` new `reset_resume` | 1 (held) | none | runtime 18/18 | no | 11-14: blocker (breaks system-resume rebind) | series 11-14 | 11-14 | — | held | linux-usb first, or mirror `needs_binding` | **44** |
| 15 | CO-43 B2 — don't wait for a resume in the timeout (BT-19) | P | `btusb_main.c` `btusb_reset()` | 1 (held) | none | 5.38 s → 0.002 s; wedge case 3/3 | no | 11-14: hold (5 of 5) | series 11-14 | Willmer 14973994 conflicts | — | held | needs D | **42** |
| 16 | CO-01 — Tested-by on Hitalo Souza's SCO series | T | `hci_conn.c`/SCO, btusb notify | — | their tests | 68 guest runs (11-01) | no | 10-21 four | n/a | stalled upstream, no v4 | — | nothing drafted | laptop run / Tested-by | **40** |
| 17 | CO-30 — defer a SCO connect (RFC on CO-02) | P | `sco.c` | 1 RFC | research case only | on the **withdrawn** 2/2 only (F-05) | no | 11-02: hold | patched side only | 11-14 | to make | not sent | after CO-02 v2 | **37** |
| 18 | CO-43 C — no runtime suspend for 13d3:3503 on Ryzen (RFC) | P | `btusb_probe()` | 1 RFC, local | none | partial guest check | no | "stays local" | not run | — | — | local | waits for a recurrence | **24** |
| 19 | CO-04 — `mesh_send_sync()` use-after-free (syzbot) | P | `mgmt.c` mesh path | 1 | none | 4-CPU QEMU, lockdep 2/35 → 0; KCSAN clean | no | 11-14: send after wording (done) | patched 11-14, not re-run | **today**: covered by `1d7a52778858` (F-41) | to make | not sent | — until re-checked | **10 (cap)** |
| 20 | CO-05 + CO-26 — `hdev->lock` in `mesh_send_sync()`; stop on a failed add | P | `mgmt.c` `mesh_send_sync()` | 2 + cover (variant A/B) | none | lock-assert warnings 3 → 0; fault injection | no | 11-02 "wait"; 11-14 narrow (done) | patched 11-14 | **today**: covered by `1d7a52778858`; Cen Zhang v2 (F-19, F-41) | to make | not sent | — until re-checked; CO-26 may stand alone | **10 (cap)** |
| 21 | CO-06 — review reply on Jiale Yao's mesh power-off patch | R | `mgmt.c` mesh completion | — | — | comparison 8→21/26 (11-01) | n/a | 10-13 one | n/a | **today**: covered by `1d7a52778858` | — | nothing drafted | — | **10 (cap)** |
| 22 | CO-14 — free pending mesh sends at controller removal (M-4) | P | `mgmt.c` `mgmt_index_removed()` | 1 (no package) | none | kmemleak 86 → 0 in 10 boots; mgmt-tester incomplete | no | none | not run | **today**: covered by `1d7a52778858` | — | not sent | — until re-checked | **10 (cap)** |
| 23 | BT-13 — `-ENOLINK` path drops a hold never taken | (P) | `hci_conn.c` `hci_connect_sco()` | none | — | not reproduced | no | — | — | Wentao 14942649 fixes this branch (F-25) | — | — | Tested-by or nothing | **9** |
| 24 | CO-13 — mesh "Count" question | R | MGMT Mesh Send uAPI | none | — | measurements not in the repository (F-40) | — | — | — | — | — | — | — | **9** |
| 25 | CO-35 7.3 — the two 7.3.y requests | B | as row 6 + `hci_event.c` (SCI) | 2 mails | — | as row 6 | n/a | as row 6 | — | **today**: all three commits queued for 7.3 | — | **not to send** | — | **0 (superseded)** |

## 4. Summary table B — the points behind each readiness value

| rank | item | readiness | defect /10 | patch /10 | tests /10 | VM /15 | HW /5 | review /15 | bot CI /10 | external /10 | send /5 | points | cap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | CO-43 E | **89** | 10 | 10 | 5 | 15 | 0 | 15 | 10 | 10 | 5 | 80/90 | — |
| 2 | CO-44 | **89** | 10 | 10 | 10 | 15 | 0 | 15 | 10 | 5 | 5 | 80/90 | — |
| 3 | CO-38 | **83** | 10 | 10 | 10 | 15 | 0 | 15 | 10 | 5 | 0 | 75/90 | — |
| 4 | CO-22 | **80** | 10 | 10 | n/a | 10 | n/a | 12 | n/a | 10 | 0 | 52/65 | — |
| 5 | CO-43 BT-24/25 | **80** | 10 | 10 | 5 | 15 | 0 | 12 | 10 | 10 | 0 | 72/90 | — |
| 6 | CO-35 | **79** | 10 | 5 | 10 | 15 | n/a | 12 | 5 | 10 | 0 | 67/85 | — |
| 7 | CO-43 A | **77** | 10 | 10 | 5 | 15 | 0 | 12 | 5 | 10 | 2 | 69/90 | — |
| 8 | CO-20 p1 | **76** | 10 | 10 | 5 | 15 | 0 | 15 | 10 | 3 | 0 | 68/90 | — |
| 9 | CO-25 R | **74** | 10 | 5 | n/a | n/a | n/a | 12 | n/a | 10 | 0 | 37/50 | — |
| 10 | CO-21 | **72** | 10 | 10 | 5 | 15 | 0 | 12 | 10 | 3 | 0 | 65/90 | — |
| 11 | CO-43 Q | **57** | 10 | 5 | n/a | 15 | n/a | 0 | n/a | 7 | 0 | 37/65 | — |
| 12 | CO-12 | **52** | 10 | 5 | 5 | 15 | n/a | 7 | 0 | 2 | 0 | 44/85 | — |
| 13 | CO-02 v2 | **47** | 10 | 5 | 5 | 10 | 3 | 7 | 0 | 2 | 0 | 42/90 | — |
| 14 | CO-43 D v2 | **44** | 10 | 2 | 5 | 8 | 0 | 3 | 5 | 7 | 0 | 40/90 | — |
| 15 | CO-43 B2 | **42** | 10 | 5 | 5 | 8 | 0 | 3 | 5 | 2 | 0 | 38/90 | — |
| 16 | CO-01 | **40** | 10 | 0 | n/a | 8 | 0 | 7 | n/a | 3 | 0 | 28/70 | — |
| 17 | CO-30 | **37** | 10 | 2 | 5 | 5 | 0 | 3 | 5 | 3 | 0 | 33/90 | — |
| 18 | CO-43 C | **24** | 6 | 5 | 0 | 5 | 0 | 3 | 0 | 3 | 0 | 22/90 | — |
| 19 | CO-04 | **10** | 8 | 5 | 0 | 15 | 0 | 12 | 5 | 0 | 0 | 45/90 | 10 |
| 20 | CO-05+26 | **10** | 10 | 5 | 0 | 15 | 0 | 12 | 10 | 0 | 0 | 52/90 | 10 |
| 21 | CO-06 | **10** | 10 | 0 | n/a | 8 | n/a | 7 | n/a | 0 | 0 | 25/65 | 10 |
| 22 | CO-14 | **10** | 10 | 5 | 0 | 8 | 0 | 0 | 0 | 0 | 0 | 23/90 | 10 |
| 23 | BT-13 | **9** | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 8/90 | — |
| 24 | CO-13 | **9** | 3 | 0 | n/a | 0 | n/a | 0 | n/a | 3 | 0 | 6/65 | — |
| 25 | CO-35 7.3 | **0** | 10 | 10 | 10 | 15 | n/a | 15 | 5 | 0 | 0 | 65/85 | 0 |

**How to read the top of the table.**
- **No package scores 100.** The laptop column is 0 for every patch: none of the current packages
  ran on the laptop.
- **Only two packages have send commands and a checked dry run:** CO-43 E and CO-44.
- **The outside reviews of 11-14 did not run the code** (F-16). Five reviewers read the packages,
  and two applied them to their bases, but none built or tested them. Every test number comes from
  this project.
- **Applying to the current tip is not checked for any package.** The tip moved on 11-17 → 11-20
  (F-42).

## 5. Already sent, applied or closed (kernel)

| item | what | sent | upstream outcome | evidence |
|---|---|---|---|---|
| BT-8, `86ef0f58bdec` (ours) | MGMT: pending commands flushed at power-off answered with a status read from the wrong object | 2026-09-24 | applied 09-29; mainline v7.3 (10-18, first in -rc7); stable 7.2.11, 6.18.57, 6.12.113, 6.6.160, 6.1.191 | `patches/kernel/`, STATUS l.63, l.79 |
| stable request for `dc16388d45ec` (Tibor Harcsa's QCA9377 entry, the BT-1 fix) | an option-2 request with the cherry-pick and build verified on every line (`EX-059`) | 2026-10-02 | queued for all seven live lines; released 7.2.10, 6.18.56, 6.12.113, 6.6.160, 6.1.191, 5.15.224, 5.10.273 | `patches/diag/stable-request-dc16388d45ec.md`, STATUS l.65 |
| BT-9 backports of `96d006ae6445` (Jiajia Liu's fix) to 6.12.y, 6.6.y, 6.1.y | three backports, each with a new mgmt-tester case that fails without it | 2026-10-10 | released 6.12.113 (`9a328ae01489`), 6.6.160 (`80861f424fe5`), 6.1.191 (`dafb564a498e`) | `patches/kernel/bt9-stable/`, STATUS l.55 |
| Tested-by on Hui Peng's "MGMT: fix mesh_tx leak…" (14831271) | the leak reproduced and his exact patch compared with a control in QEMU (159 VM logs) | 2026-10-06 | his patch still `new` (today). The maintainer's `1d7a52778858` now handles "none … stranded if queueing fails" (F-41), and Wentao Liang's 14942650 is an identical patch (F-25) | `retest/mesh-tx-leak/`, STATUS l.61 |
| CO-10: Tested-by on 6.6.160-rc2 | every BlueZ CI tester suite on the rc and its base in QEMU, case by case | 2026-10-21 | 6.6.160 released the same day; nothing owed | STATUS l.62 |
| CO-02 v1: "[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse" + the BlueZ test | see §6, CO-02 | 2026-10-27 | all four `new` (today); bot 24/24; Sashiko: patch 2 `fail` (high); the CI bot asks for a resend (11-12) | STATUS l.52 |
| CO-25: "[REPORT] btusb: QCA9377 13d3:3503 on ROM firmware…" | the ROM-firmware hang, two questions to Qualcomm | 2026-10-29 | Zijun Hu replied that QCA9377 "is not ROME"; our records show the opposite; reply v4 drafted (row 9) | STATUS l.50 |
| CO-09 | the entry in Ubuntu's kernel | — | done by Ubuntu: `7.0.0-43` carries it; the laptop runs it since 11-12 | `contributions/CO-09-…/` |
| CO-28 | Tested-by on 6.1.191, 5.15.224, 5.10.273 | — | closed, nothing sent: deadlines passed, all released 10-30 with our backports | `contributions/CO-28-…/` |
| CO-45 | xHCI ep0 maxpacket on an Enabled slot (BT-22) | — | another author's fix (Michal Pecio), queued 11-09; not ours; watch only | `docs/issues.md` BT-22 |

## 6. Each contribution explained

The order follows table A. "Mechanism" is the bug. "Fix" is what the patch does. Numbers are as
recorded in the dossier named, unless marked "today".

### CO-43 E — "Bluetooth: btusb: Anchor a deferred URB under txlock" (BT-23) · readiness 89

- **What and where.** `drivers/bluetooth/btusb_main.c`, `submit_or_queue_tx_urb()`.
  `Fixes: 7bee549e197c` (2009), so present on every stable line.
- **Origin.** From BT-17, the 2026-11-12 18:03 laptop incident in which the controller stopped
  answering at a resume. It was rebuilt in QEMU with an emulated `13d3:3503` over usbip
  (`results/bt17-emulation-2026-11-13/`). The window was found in source and reproduced by
  widening it.
- **Mechanism.** `BTUSB_SUSPENDING` is tested under `txlock`, then the lock is dropped before the
  URB is anchored on the deferred list. A resume that completes in between leaves the URB parked
  on an awake device. The waker finds nothing to resume, and the HCI command in that URB times
  out.
- **Fix.** Anchor inside the same `txlock` section. The lock order is unchanged.
- **Package.** `contributions/CO-43-…/send-20261113/E/`: one patch, with send commands and a
  dry run of 11-14 (six RCPT TO lines checked). The dry run is to be repeated after the operator
  adds his Signed-off-by. It goes before every other CO-43 patch.
- **Tests.** No upstream test reaches btusb, because vhci cannot carry it. In QEMU, with a debug
  delay and a forced resume, unpatched parked 3/3 and E answered. A stress run of 20 × 2,000
  cycles (about 81,000 packets) showed no kernel report.
- **Laptop.** Not run.
- **Review.** All five outside reviewers said send (11-14). The stable Cc is split: R1 and R7
  for, R2 and R3 against, because the race was not seen naturally.
- **Bot CI.** Local, base and patched. Only the Signed-off-by checks differ. VerifyFixes passes
  once a Signed-off-by follows `Fixes:`.
- **External.** Prior art (11-13): nobody else is on this race, and Sean Rhodes's pending rewrite
  keeps the window. Jens Willmer's 14973994 conflicts with B2, not with E (11-15).
- **Next.** The operator's word, and an apply check on today's tip.

### CO-44 — "Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT" (BT-21) · readiness 89

- **What and where.** `net/bluetooth/mgmt.c`, `mgmt_errno_status()`. A BlueZ test ships with
  it: "Set Device Class - Timeout 1" in `tools/mgmt-tester.c`. `Fixes: 161510ccf91c` (v5.17-rc1).
- **Origin.** The laptop's 2026-11-12 incident: bluetoothd logged "Failed to remove UUID:
  Authentication Failed (0x05)" three times while the controller did not answer.
- **Mechanism.** When the controller does not answer, the sync-command path returns
  `-ETIMEDOUT`. `mgmt_errno_status()` maps that to `MGMT_STATUS_AUTH_FAILED`. So Set Powered,
  Add/Remove UUID and Set Device Class report an authentication failure where no authentication
  happened. `MGMT_STATUS_TIMEOUT` (0x08) exists, and the HCI-status table already uses it.
- **Fix.** One line: `-ETIMEDOUT` → `MGMT_STATUS_TIMEOUT`. Also mapping `-EACCES` was rejected,
  because 0x05 and 0x18 both map to it.
- **Package.** `contributions/CO-44-…/send-20261113/`: one kernel and one BlueZ patch, with
  `send-commands.txt` STEP 2a/2b and dry runs of four forms (11-14, all OK). The BlueZ mail fills
  the kernel mail's lore link (`@KERNEL_PATCH_LINK@`) after the kernel mail is out.
- **Tests and VM.** The new case fails on base (0x05) and passes patched (0x08). mgmt-tester is
  526 of 527 on base and 527 of 527 patched. l2cap-tester 144/144 and smp-tester 8/8 are
  unchanged. A negative control shows the case times out if its hook is not reached.
- **Laptop.** The fix was not run there. The trigger, a controller that stops answering, cannot
  be produced on demand.
- **Review.** Four reviewers plus a fifth on 11-13. On 11-14 all five said send; the two wording
  points are fixed. Open: `Cc: stable` (the notes give the reviewers' count two ways, F-39),
  `Link:`, and the subject.
- **External.** Prior art (11-13): no competing patch since 2021. `mgmt.c` has moved since
  (F-42).
- **Next.** The operator's decisions, his Signed-off-by, a fresh dry run, and the send order.
  Outside reviewer 6 advised leading with CO-44 and CO-38.

### CO-38 — "Bluetooth: MGMT: Fix Read Advertising Features hiding instances" · readiness 83

- **What and where.** `mgmt.c`, `read_adv_features()`: one line. A BlueZ test goes with it:
  `contributions/CO-38-…/bluez-split-20261114/series-a/`, the helpers plus "Add Ext Advertising -
  Instance 2 listed alone". `Fixes: b338d91703fa` (2022); present from 6.1.y on.
- **Origin.** Found 2026-11-01 by CO-12's tests, then confirmed in mainline source.
- **Mechanism.** Each instance number is compared with `adv_instance_cnt` (how many exist)
  instead of `le_num_of_adv_sets` (how many may exist). Once instance 1 is gone, instance 2
  disappears from the listing, with no Advertising Removed event.
- **Fix.** Compare with `le_num_of_adv_sets`.
- **Tests and VM.** The BlueZ case fails on base and passes patched (`-p Add`: 113/114 → 114/114,
  3 runs). On the kernel side, 119 → 120 of 128 changes only that case. 128/128 needs CO-12's clamp
  too, which the index overstates (F-38).
- **Laptop.** Not run.
- **Review.** All five said send the kernel patch (11-14). Four of five asked for the BlueZ
  split, which is done. D12 recommends `Cc: stable`, which the package does not carry (F-38).
- **Bot CI.** Base and patched, identical tester results. A BlueZ TestFunctional failure was shown
  to be a flake (patched 2 of 8, base 1 of 7).
- **External.** No equivalent fix (11-14). Zhao Li's accepted "MGMT: Retain the selected legacy
  advertising schedule ID" (11-19) is in the same file (F-42).
- **Next.** Send commands and a dry run (none yet), the stable decision, and an apply check.

### CO-22 — stable request for two ASUS QCA ROME entries, and an owners' call · readiness 80

- **What.** "Please backport d54601f21faf and cfa67a1dbfd9 (btusb: ASUS QCA Rome IDs) to stable",
  for 7.3.y to 5.10.y. These are other authors' device-table entries (`0b05:1868`, `0b05:1825`), in
  mainline via the 7.4 merge window and in no stable branch. The companion is an owners' call
  ("QCA ROME controllers without a quirks entry - owners wanted").
- **Why.** It is the same failure class as BT-1. Without an entry the controller is bound
  generically and stays on ROM firmware, so `btusb_setup_qca()` never runs. Both commit
  messages report LE scanning failures with "unexpected event for opcode 0x2005". The
  research of 11-01 found about nine more likely ROME IDs without an entry.
- **Verification.** Both cherry-pick cleanly onto 7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192,
  5.15.225 and 5.10.274. `btusb.o` builds with an identical warning set. 6.6.162's W=1 failure is
  in `btmtk.h` on the plain tag too, and a separate draft report exists for it.
- **Laptop.** n/a: these are not our devices.
- **Review.** 11-02 and 11-14. All said send after a queue refresh. That was done on 11-14, and
  again **today**: neither commit is queued on any line or present on 6.18.y (F-29).
- **Gaps.** The package has no `CO-nn` folder (F-02), STATUS does not mention it at all (F-32), and
  there are no send commands or dry run. The owners' call waits on D7 (its venue).

### CO-43 BT-24/BT-25 — "[PATCH 0/2] Bluetooth: btusb: Deferred URBs that a failed resume or a close discards" · readiness 80

- **What and where.** `btusb_main.c`: the failure path of `btusb_resume()`, `btusb_close()` and
  `play_deferred()`. `Fixes: 7bee549e197c`, and on 2/2 also `19cfe912c37b`.
- **Mechanism.**
  - BT-24: the failed-resume path scuttles the deferred anchor outside `txlock`, then clears the
    flag, so a sender can anchor a URB after the scuttle.
  - BT-25: four discard sites free neither the skb nor, in some cases, the setup packet. That is
    a leak.
- **Fix.** The scuttle and the flag clear go in one `txlock` section, and the skb and setup are
  freed on discard. `btusb_close()` needs no lock of its own, because the core clears
  `HCI_RUNNING` first; the message argues this.
- **VM.** kmemleak, E alone against E + the pair: 3/3/1, 2/1/2, 5/3/4 and 2/2/2 leaked objects,
  against 0 everywhere. The anchor is left non-empty 3/3 against 3/3 empty. 103 run logs are clean.
- **Review.** Four of five reviewers asked for exactly this extraction (11-14). The extracted pair
  itself has not been re-reviewed.
- **Next.** Send commands, a dry run, the stable form, and after E.

### CO-35 — the L2CAP ECRED deferred-accept hang on 6.18.y, 6.12.y and 6.6.y (BT-10) · readiness 79

- **What.** Pauli Virtanen's two mainline commits: `608e0b7a675b` "L2CAP: add
  l2cap_chan_close_unlocked() and locking helpers" and `32d86e048d8e` "L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer". They are in v7.4-rc1 and carry no `Cc: stable`. Our part is
  hand backports as three `[PATCH 6.N.y 0/2]` series, plus a reduced-prerequisite alternative.
- **Mechanism.** In l2cap-tester "L2CAP Ext-Flowctl Server - Accept 2 Close 1", the task holds
  its socket's lock in `l2cap_sock_recvmsg()`. It then waits for the same lock in
  `l2cap_sock_teardown_cb()`, which is reached from `__l2cap_ecred_conn_rsp_defer()`. The lock is
  taken nested, so lockdep is silent. This is a self-deadlock, present since `9aa9d9473f15` (v6.3,
  backported to 6.1, 5.15 and 5.10, where it hangs only with `enable_ecred=1`).
- **Found.** 2026-10-23, in the full tester runs for CO-02 and CO-10. A confound-free bisect of
  bluetooth-next ends at the fix.
- **VM (11-14).** On v7.3.4, v6.18.63, v6.12.117 and v6.6.162 the case hangs unpatched, with 7
  hung-task reports each, and passes with the pair in about 1 s. The whole l2cap-tester gives the
  same 111 verdicts with the full and the reduced prerequisite. PROVE_LOCKING, LOCKDEP and KASAN
  are on in the built configs.
- **Laptop.** n/a: ECRED is a 5.2 feature and the controller is 4.2.
- **Review.**
  - 10-28: six reviews of the request; five approved the backports and the sixth was
    unavailable (F-30).
  - 11-02: follow-ups.
  - 11-14: five reviewers. R3 asked for the 100-line rule, which is why the reduced
    prerequisite was built. The reduced patch is new code and has not been reviewed.
- **Bot CI.** `ci-local.sh --kernel` last ran on 11-02 (F-30).
- **External, today.** The pair is **queued for 7.3** by the stable team and not queued for 6.18,
  6.12 or 6.6 (F-21, F-28). So the 7.3.y request mail is not to be sent, and the covers, which cite
  it, need rewording.
- **Next.**
  - The operator chooses full or reduced.
  - Reword the covers.
  - Re-run the local CI and the queue check on the send day.
  - Make the send commands and dry run.

### CO-43 A — "Bluetooth: btusb: Report a failed runtime resume for deferred data" (BT-20) · readiness 77

- **Mechanism.** `btusb_waker()` returns on a failed resume without a message, so only the HCI
  timeout about 2 s later shows anything.
- **Fix.** `bt_dev_err_ratelimited()` unless the error is `-EACCES`.
- **VM.** Base logs 0 lines; patched logs 2 per run (`-16`). In the emulator `tx timeout` comes at
  10.09 s and the line at 15.24 s.
- **Review.** All five said send after the message fix: R7's order of events, and R6's rate limit.
  Both were applied in `A-review-fixes-20261114/`.
- **Gaps.** The bot was not re-run after a note was rewrapped. The 11-14 dry run was on the
  replaced file (F-06, F-26). After E.

### CO-20 patch 1 — "Bluetooth: btusb: Report SCO receive failures by cause" · readiness 76

- **Mechanism.** At every call hang-up the controller still delivers SCO data for the link just
  closed. `btusb_validate_sco_handle()` rejects it, and btusb logs "corrupted SCO packet" and counts
  it in `err_rx`, through the same path as a real length error or an allocation failure. In the
  captures, 155 of 181 closed links had data after the Disconnection Complete, up to 33.6 ms
  later. A normal hang-up looks like corruption, and the counter mixes three causes.
- **Fix.** `btusb_recv_isoc()` returns `-ENOMEM`, `-EILSEQ` or `-ENOENT`. "corrupted SCO packet"
  stays for length errors only, and two new rate-limited messages name the other two causes. All
  three still count in `err_rx`. Patch 2 (stale data from the last valid handle demoted to debug)
  is held: reviewer 7's counter-case shows its test is a guess.
- **VM.** In the emulator over usbip, base logs "corrupted" 21, 21 and 24 times and patch 1 none.
- **Laptop.** Capture analysis only.
- **Review.** 11-14, five of five: "patch 1 alone".
- **External.** Last checked 11-01. No competing patch since 2024. The newline fix of the
  ratelimited message is another author's, `f51ee3bb5fbe` (F-27).
- **Next.** The operator decides whether it is worth sending. Then commands and a dry run.

### CO-25 R — the reply to Qualcomm, draft v4 · readiness 74

- **Context.** The report of 10-29 described BT-1's hang on the ROM firmware and asked two
  questions: a known erratum or affected ROM range, and a list of ROME USB IDs. Zijun Hu
  (Qualcomm) answered the same day that "QCA9377 is not ROME(QCA6174A), btusb driver does not
  support it". The project's evidence says otherwise:
  - the device reports Rome 3.2 (`0x302`);
  - `qca_devices_table` lists it;
  - linux-firmware ships its files and they load;
  - three QCA9377 modules upstream are `BTUSB_QCA_ROME`.
- **Draft.** `contributions/CO-25-…/drafts/reply-1-zijun-hu-v4.eml` (11-02) quotes the kernel's own
  boot line.
- **Review.** Five outside reviewers on v3 (11-02); v4 follows their points.
- **Gaps.**
  - No send script or dry run (F-32).
  - STATUS asks that the sent report's "the same three headset models" be checked against the
    exhibits before any reply.
- **Next.** That check, then the operator's word.

### CO-21 — "[PATCH 0/2] Bluetooth: btusb: Pick the SCO alternate setting from the links that are up" · readiness 72

- **What and where.**
  - 1/2: "Bluetooth: Keep the air mode of SCO links that came up". It touches `hci.h`,
    `hci_core.h` (`conn->air_mode`, `hci_conn_sco_up_num()`) and `hci_event.c`.
  - 2/2: "Bluetooth: btusb: Pick the SCO alt setting from links that are up", in `btusb_notify()`
    and `btusb_work()`. `Fixes: baac6276c0a9`.
- **Mechanism.** `btusb_notify()` takes the air mode from whichever event changed the SCO count.
  `btusb_work()` falls back to alt setting 0 for anything not CVSD or transparent. When one of
  two SCO links goes down, the other is moved to alt 0. A single link whose setup overlaps
  another connection's add or remove is also mis-set. Two such races are in the laptop's journal
  (2026-09-02). This is the defect Sashiko's High on Hitalo Souza's 6/6 points at.
- **Fix.** Store the Synchronous Connection Complete's air mode before `BT_CONNECTED`. Count CVSD
  and transparent links in one pass under `hdev->lock`, and pick the alternate setting from that
  count. The mixed CVSD+mSBC policy is asked about in the cover, not coded.
- **VM.** Real btusb in QEMU over usbip:
  - five scenarios: unpatched 0/10, patched 10/10;
  - reviewer 7's interleaving with a debug delay: the two-count version picks alt 0 in 3 of 3
    runs, the one-pass version in none.
- **Laptop.** Not run. It needs `bluetooth.ko` and `btusb.ko` built and installed together,
  since 20 of 94 CRCs change.
- **Review.** 11-01 "not ready". On 11-14, R2 and R7 said revise (one snapshot), and that change
  is made.
- **Bot CI.** Base and patched. VerifyFixes fails on partial history, and a CheckSparse warning
  is the same on base (F-24).
- **External.** Last read 11-11 (Hitalo Souza 14875454, one overlapping scenario).
- **Gaps.** STATUS and the dossier call it "the posted patch", but nothing was posted (F-24).

### CO-43 Q — the linux-usb question for BT-18 · readiness 57

- **Problem.** After a successful *runtime* reset-resume the USB core does not rebind a driver
  that has no `reset_resume` callback, so btusb stays suspended with a healthy device. This was
  reproduced in emulation 5 of 5.
- **What.** Reviewers 3 and 7 asked that the USB maintainers be asked first. The question is
  drafted (`contributions/CO-43-…/drafts/bt18-linux-usb-question-20261113/`) and **not sent**.
  HISTORY reads as if it was (F-18). The draft's own review is not recorded.

### CO-12 — "Bluetooth: hci_sync: Fix extended advertising duration overflow" (M-2) · readiness 52

- **Mechanism.** In `hci_enable_ext_advertising_sync()`, `adv->timeout` in seconds is multiplied
  by 1000 into a `u16`. 66 s becomes 460 ms, 655 s becomes 6517 units, and 8192 s becomes 0,
  which means "no limit", so the instance is never removed. The HCI field itself tops out at
  655.35 s. `Fixes: 10bbffa3e88e`.
- **Fix.** Compute in `u32` and clamp to `U16_MAX`. Below `---` the three options are stated:
  clamp, reject, or a per-instance host deadline (`DESIGN.md`).
- **VM.** Reproduced in QEMU on 11-01. On 11-14, the AdvDur research cases go from 9–10/22 to
  20/22, and Add from 119 to 127 (128 with CO-38).
- **Laptop.** n/a: extended advertising is Bluetooth 5.0 and the controller is 4.2.
- **Review.** 11-02 only, split: R6 and R1 said send the clamp now, R2, R4 and R3 said settle the
  semantics or post as an RFC (D5). It was not in the 11-14 round.
- **Gaps.**
  - The list bot was never run (F-36).
  - Its tests sit in CO-38's held BlueZ series B.
  - **Today**, Cen Zhang's v2 changes the same code (F-19).
- **Next.** D5 first, then a rebase on whatever lands.

### CO-02 v2 — SCO connection reuse, the second posting · readiness 47

- **What and where.** `net/bluetooth/hci_conn.c`, `hci_connect_sco()` and `hci_abort_conn()`.
  The BlueZ `tools/sco-tester.c` tests go with it.
  - 1/2 "hold a reused SCO connection for its caller", `Fixes: 8a5b0135d4a5`, `Cc: stable` 6.6.x.
  - 2/2 "don't reuse an aborting SCO connection", `Fixes: e6720779ae61`, for v6.13+.
  - A separate mismatch patch, "don't change the parameters of a SCO link in use", goes later.
- **Origin.** U7: a headset codec switch on the laptop (2026-09-29) left the new SCO link silent.
- **Mechanism.** `hci_abort_conn()` sets `abort_reason` and queues the Disconnect, but the state
  stays `BT_CONNECTED` until the Disconnection Complete. A connect in that window is handed the
  old connection with no setup. `sco_connect()` reports it connected, and then it closes with
  ECONNABORTED. Since `e6720779ae61` the closed socket is detached at once, so nothing rejects the
  newcomer. A second defect: a second connect to a live link returns EBUSY, but it consumes the
  first socket's hold, and the link drops.
- **Fix.**
  - 1/2 takes a caller hold on a reused link.
  - 2/2 refuses with `-ECONNABORTED` when `abort_reason` is set at lookup, or when the disconnect
    work is already running.
  - 2/2 does not wait. The waiting variant of 11-14 deadlocked against `cmd_sync_work_lock` with
    debug delays (3 of 3) and is withdrawn.
- **Tests.** The v1 sco-tester tests fail on every unpatched kernel. The v2 ports exist only in
  superseded directories, and the candidate's cover says they are "posted separately", which is
  not true yet (F-22).
- **VM (candidate, 11-15).**
  - sco-tester: 35 pass, 2 fail (the mismatch patch's cases), 7 not run.
  - mgmt-tester 526/526, iso-tester 213/213.
  - l2cap-tester not run.
- **Laptop.** v1 ran 2026-10-23→25 with three headsets (EX-067–077); the candidate has not.
- **Review.** About 17 rounds on v1 before its send. Five reviewers on 11-14 (split on
  splitting patch 3). Five on 11-15: the lock cycle was confirmed there, which replaced 2/2. The
  new 2/2 has not been reviewed.
- **Bot CI.** Not run on the candidate. 2/2's message has a line of about 95 columns.
- **External, today.** v1 is still `new` with no human reply. The CI bot asked for a resend
  (11-12), so v2 is also the resend. Wentao Liang's 14942649 conflicts textually. Jeremy Dean
  Clifton's two accepted `hci_conn.c` patches (11-17) are in the same file (F-42).
- **Next.**
  - Move the BlueZ tests into the candidate.
  - checkpatch, the bot, l2cap-tester.
  - Rebase on the tip.
  - The operator's D1/D2 and the trailer form.

### CO-43 D v2 and B2 — held · readiness 44 and 42

- **D v2** ("Recover after a runtime reset-resume", BT-18) registers a `reset_resume` callback
  that queues a USB reset only inside a runtime resume. Its runtime matrix is 18/18. Three
  reviewers independently found the blocker: registering `reset_resume` removes `needs_binding` on
  a **system** reset-resume, so a system resume would no longer rebind.
- **B2** ("Don't wait for a resume in the HCI command timeout", BT-19) removes the 5.3 s block of
  the ordered HCI workqueue (5.380 s → 0.002 s) and keeps the reset that a wedged controller
  needs. It needs D, conflicts with Jens Willmer's 14973994, and has three open review points:
  late submission, not per command, and a manual reset through sysfs.
- **Both** wait for the linux-usb question (CO-43 Q).

### CO-01 — Tested-by on Hitalo Souza's "Fix SCO setup failures after an abandoned setup" (v3) · readiness 40

- **The series.** Since `a13f316e90fd`, closing a SCO socket during its setup deletes the
  `hci_conn`. A late completion then breaks the next connection or leaves a link up. 68 QEMU runs
  (11-01) show the series fixes its own test (30/31 → 31/31) and coexists with CO-02.
- **Upstream.** The maintainer pointed to Sashiko's findings on 10-09. There is no v4, and the
  series no longer applies. Nothing the series fixes was seen in 350 laptop captures.
- **Next.** Wait. Nothing is drafted.

### CO-30 — "[RFC PATCH] Bluetooth: SCO: defer a connect until the link being aborted is gone" · readiness 37

- **Problem.** With CO-02, PipeWire's immediate retries of a refused connect are refused again,
  and audio returns only after WirePlumber's 5 s idle suspend (U17).
- **RFC.** It queues the connect behind the abort on cmd_sync and returns `-EINPROGRESS` (`sco.c`,
  113 lines).
- **Tests.** Its tests ran only on CO-02's **withdrawn** sleeping 2/2, from a base directory that
  no longer exists (F-05, F-23).
- **Next.** Waits on CO-02 v2.

### CO-43 C — RFC, local · readiness 24

Sets `BTUSB_WAKEUP_BROKEN` for `13d3:3503` on a Ryzen direct-root-hub child, so the device is not
runtime-suspended. This is BT-17's hypothesis H3, from one occurrence. The reviewers said keep it
local until a recurrence is captured with USB core debug.

### CO-04, CO-05 + CO-26, CO-14, CO-06 — the mesh items, capped at 10 today

All four are about `net/bluetooth/mgmt.c`'s mesh transmit path (`Fixes: b338d91703fa`, from 2022).
**Today's finding** is that the maintainer's own fix `1d7a52778858`, accepted 11-18, addresses
their ground by its message (F-41). Until our harnesses run on the new tip, each stays at 10. What
each was:

- **CO-04** ("MGMT: Fix use-after-free in mesh_send_sync()", syzbot `f20755f37da70df33a16`).
  - **Mechanism.** `HCI_MESH_SENDING` was cleared without `hdev->lock` before `mesh_next()`
    queued the head. A concurrent Mesh Send could then queue a second start for the same request.
    If the first start failed, the second read freed memory.
  - **Our fix.** It kept the flag set until the decision, made under the lock.
  - **Tests.** QEMU 4-CPU lockdep, UnregSweep 2/35 → 0, KCSAN clean; not reproduced here.
  - **Package faults.** It carries `Closes:` and `Cc: stable`, both against the records' advice
    (F-34).
  - **Now.** Run its UnregSweep and cancel cases on `cf357cfc025e`.
- **CO-05 + CO-26.**
  - **CO-05.** `mesh_send_sync()` changed the advertising list without `hdev->lock`, so the
    capacity check and insert raced with Add Advertising (lock-assert warnings 3 → 0).
  - **CO-26.** A failed add was ignored and the missing instance scheduled, so the real error was
    lost (fault-injected: −2 → −12).
  - **Now.** CO-05 1/2 duplicates the accepted fix's locking and Cen Zhang's v2. CO-26 may still
    stand alone, which needs a check (F-35, F-41).
- **CO-14** (M-4): every mesh send pending at controller removal leaked with its socket reference
  (kmemleak 86 objects in 10 boots → 0 with a 9-line fix in `mgmt_index_removed()`). The accepted
  fix "flushes the transmissions left … when the index is removed". Run the kmemleak harness on
  the tip.
- **CO-06**: a review reply on Jiale Yao's power-off patch (14864878). The accepted fix flushes
  transmissions at power-off, so a reply is probably moot.

**M-5** (a lockdep cycle at unregister) was "removed by CO-04". Now it should be re-read against
`1d7a52778858` and against Zheng Shuhao's 15008482 ("hci_sync: invoke destroy callbacks outside
lock", 11-21, `new`) (F-43).

### BT-13 and CO-13 · readiness 9

- **BT-13.** `hci_connect_sco()`'s `-ENOLINK` path drops a hold the new connection never got
  (`refcnt` 0 → −1). This is a cold path, found by code reading. Wentao Liang's 14942649 (11-04,
  `Cc: stable`) fixes this branch, and no record says so (F-25). The project's possible role is a
  test, or nothing.
- **CO-13.** A semantics question about the mesh Count parameter. Count does not set the airtime,
  and values ≥ 52 wrap the duration. The measurements behind it are not in the repository (F-40).

### CO-35 7.3 — the two 7.3.y requests · readiness 0 (superseded)

"Please backport 608e0b7a675b and 32d86e048d8e to 7.3.y" and "Please backport 5874f8d03268
(Bluetooth: SCI response fix) to 7.3.y". All three commits are in `queue-7.3` today (F-28). The
stable team did what the mails asked, so they are not to be sent.

## 7. Registered kernel defects with no contribution of ours

| issue | what | state | contribution |
|---|---|---|---|
| BT-11 | KASAN use-after-free in iso-tester on Ubuntu `-38` | resolved for Ubuntu by `-42`; the controller has no ISO | none needed |
| BT-14 | 6.12.114: every L2CAP `getsockopt()` fails | another author's fix; released in 6.12.115 per CO-35's log (STATUS still says "watch", F-31) | none |
| BT-15 | 7.3: l2cap-tester SCI stall | `5874f8d03268` queued for 7.3 today (F-28) | was CO-35's SCI request; now not needed |
| BT-16 | three boots with no Bluetooth (patch reported already loaded, LE commands fail, controller list empty), one on stock `-43` | cause not established | watch each boot |
| BT-17 | the 11-12 resume failure | the source of CO-43 and CO-44 | CO-43, CO-44 |
| BT-22 | xHCI ep0 maxpacket on an Enabled slot | another author's fix, queued 11-09 | CO-45, watch only |

## 8. Inconsistencies in the foundation documents (summary)

The work log has 43 findings. Grouped:
- **Stale rows in the front documents.** README (F-08, F-09), BRIEF (F-10, F-12), STATUS's CO-02,
  mesh and BT-14 rows (F-14, F-15, F-31), HISTORY's "sent to linux-usb" (F-18), and the index's
  CO-09, CO-14, CO-02 and CO-38 rows (F-01, F-03, F-04, F-22, F-38).
- **Records that are missing.** CO-22 is in no STATUS text (F-32). CO-20, CO-21 and CO-43 have no
  submission row. CO-13, CO-22 and CO-45 have no dossier (F-02). Several dossiers have no `log.md`
  or `refs.md` (CO-14, CO-21, CO-30, CO-38, CO-44). Dossier READMEs stop at 11-01 or 11-12 while
  their packages moved on 11-14 (CO-12, CO-20, CO-38).
- **Counts that differ between files.** CO-35's reviewer count (F-30), CO-12's test-case counts
  (F-36), CO-44's stable vote (F-39), and CO-14's boot count (F-37).
- **Packages that contradict their own records.** CO-04's `Closes:` and `Cc: stable` (F-34). CO-38's
  missing stable tag against D12 (F-38). CO-02's cover claims tests "posted separately" (F-22).
- **Upstream facts no record has** (all after 11-16): F-19, F-21, F-28, F-29, F-41, F-42, F-43.
- **CI.** The access-audit workflow has failed on every push to `main` since at least 11-16
  (F-11), and no front document says so.

## 9. Limits of this report

- The readiness levels are this report's rubric (§2), applied once, by one reader. The gates and
  points are explicit so that they can be disputed per cell.
- The dossiers were read for the fields of the rubric. Logs of more than a few hundred lines were
  read from their newest entries. Some files were not opened; each finding says where.
- **Not run here:** any build, test or apply check. "Applies to the tip" is unknown for every
  package (F-42).
- **The accepted mesh fix was not tested here.** It was read from its message and the list of
  functions it changes (F-41). Whether a gap is left for CO-04, CO-05+26, CO-14 or CO-06 needs a
  run on `cf357cfc025e`.
- Stable state was read from the queue for each line. For CO-22, only 6.18.y's branch was read.
- Nothing was sent, posted or changed upstream.
