---
title: Review Follow-ups
subtitle: What the outside reviews of the Bluetooth Submissions Review ask for, checked and collected — nothing acted on yet
---

# How this list works

- **Reviews folded in so far:** Reviewer 2, Reviewer 6, Reviewer 4, Reviewer 3, Reviewer 1 (all
  2026-11-02; R1 covers ten of the sixteen items and adds no new defect). Reviewer 5 was read
  and nothing was folded in: a generic checklist that names no item of the document. Reviewer 7
  folded in too (2026-11-02). More reviews are
  coming; this list grows with each, and nothing on it is acted on until all are in.
- **Each review is an opinion, not the truth.** Where a claim could be checked against source,
  logs, tags or our records, the "Checked" column says what was found. "Not checked" means the
  claim is recorded as the reviewer's.
- **Kinds of follow-up:**
  **do** — work I can do without your word (local, nothing sent);
  **decide** — needs your decision;
  **you** — yours to do (laptop, sends, texts you write yourself);
  **doc** — a fix to the review document itself.
- Every send, filing and laptop test still waits for your explicit word.

# Decisions for you

| # | Decision | Reviewer views | My recommendation |
|---|---|---|---|
| D1 | **CO-02: when to post the next version, and its label.** | R6: post now (a high-severity bot finding on a `Cc: stable` patch should be answered promptly), as **v2**. R2: do not resend just because a bot prefers another layout; patience. | Label: **v2**, checked (see F-16). Timing: post v2 when the mismatch patch's error-code question (D2) is settled, so the fold, the BlueZ test port and the mismatch patch go out together. |
| D2 | **CO-02 mismatch patch: error code, and whether to send it yet.** | R2 and R6 agree: keep -EBUSY for a link still in use; -ECONNABORTED only for a closing link. R6: tell them apart by `refcnt == 0`. R7 (and R4): hold the guard until the in-flight overwrite (F-80) is tested; report the mismatch on the existing v7 thread meanwhile. | Rewrite and retest with the -EBUSY split (F-19) and the in-flight test (F-80) first; then the guard goes out with v2. If v2 must go earlier, a short factual note about the mismatch on the thread. |
| D3 | **CO-23/37: mailing list or private GitHub advisory.** | R2 and R6 both lean to BlueZ's advisory route; R6 strongly. R4: settle the reporting route together with consolidating the package. R3: security triage before any public posting; the advisory first. | Yours. I add no assessment. |
| D4 | **CO-04: `Closes:` or `Link:`, and syzbot testing.** | R2: reproduce deterministically, or ask syzbot to test; until then `Link:`. R6: ask syzbot to test (`#syz test`), then `Closes:`. | Both suggestions fall under your 29 October decision; I am not proposing them. Within it: `Link:` instead of `Closes:` is the safe wording if no syzbot test is run. Yours. |
| D5 | **CO-12: send the clamp now, or design first.** | R6: send patch A now with `Cc: stable`; don't wait for 14927631. R2: acceptable only as a clearly described mitigation, after maintainer agreement on the semantics. R4: a defensible mitigation; decide explicitly between a mitigation patch and an RFC. R3: post as `[RFC PATCH]`; prefers rejecting unrepresentable timeouts; no stable until the policy is settled upstream. R1: the clamp is acceptable for stable as a mitigation; the design question is the only open item. | Reviewers split 2 (R6, R1) : 3 (R2, R4, R3 want the semantics settled first). Revised: post as `[RFC PATCH]` with the clamp as the working code and the three options stated; no `Cc: stable` until the maintainers pick a policy. |
| D6 | **CO-03 + CO-11a: one Ubuntu upload or two; and the CO-37 5.72 backports.** | R6: one upload (`5.72-0ubuntu5.9`, two LP bugs), and ship the CO-37 5.72 patches with CO-03. R2, R3: one shared baseline in any case. R3: do not combine CO-03 with the CO-23/37 lifetime material; different risk stories deserve separate SRUs unless the sponsor asks. | CO-03 + CO-11a in one upload. The CO-37 5.72 backports as a separate SRU, after the upstream route (D3) is settled. |
| D7 | **CO-22 mail B (owners' call): venue and shape.** | R6: wrong venue; comment on the two Launchpad bugs with owners (2080638, 1815467) instead; at most a short list post. R2: ask only for device information first; no module-building recipe. | Short Launchpad comments first, in your words; a short list post only if you want the archive record. |
| D8 | **CO-21: the question to Hitalo Souza.** | R6: do not mail him; cite his 6/6 in our cover letter. (Earlier reviewers: ask before posting.) | Cite it in the cover; no separate mail. |
| D9 | **BlueZ subjects: 50 columns or the practice.** | R2: HACKING asks 50/72 (checked). R6: 55-65 is what BlueZ merges (checked: many recent master subjects exceed 50). | Shorten where it costs nothing; do not mangle a subject to reach 50. |
| D10 | **CO-25: reminder after silence.** | R6: no reminder; vendor silence is expected. Plan so far: one reminder after three weeks. | Drop the reminder. |
| D11 | **CO-36: issue or merge request, V2 or V3.** | R6: one small MR with V3 plus the V2 guard, let Pauli pick. R2: slightly prefers V2 as the minimal first proposal. | Yours to write (PipeWire's rules). Evidence supports either. |
| D12 | **CO-38 and CO-12: `Cc: stable`.** | R6: add to both. R2, R3, R1: stable for CO-38. R3: not for CO-12 until its policy is settled. | CO-38: yes. CO-12: no for now (see D5). |
| D13 | **CO-23/37: one six-mail series or two series.** | R6, R7: one final stack (R7 applied all six in order to the named BlueZ revision). R3: two independent series; rebase the tests so each stands alone (a textual conflict is not a semantic dependency). | Two series: CO-37's fixes already apply and pass without CO-23 (measured 11-02); only its test needs rebasing onto master's test file. |
| D14 | **CO-04: keep or split the queue-drain change.** | R6: keep, one sentence in the message. R2, R3: split it out unless it is needed for the new invariant. | Check first whether the invariant needs it (F-04); if not, restore the old head-only behaviour and send the drain separately. |

# Follow-ups by item

Columns: **From** (who asked), **Checked** (what I verified), **Kind**, **State** (all *open* unless
marked).

## CO-25 — reply to Qualcomm

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-01 | Name the 0x111 field without inventing a term: quote the kernel's own line once, verbatim (`QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111`). (R1 accepts "patch version 0x111"; the other three prefer the kernel's wording.) | R2, R6, R3 | btusb's struct field is `patch_version` (`btusb.c:3451`), printed as "build" (`btusb.c:3672`). | do |
| F-02 | Check the sent report's "the same three headset models" for the 74 links against the exhibits; if wrong, one correcting clause in this reply, not a separate mail. | R6; R2 (only if wrong) | Not yet checked. | do |
| F-03 | No reminder after silence. | R6 | — | decide (D10) |

## CO-04 — `mesh_send_sync()` use-after-free

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-04 | Say in the commit message that `mesh_next()` now completes every pending request whose start cannot be queued (user-visible: one Mesh Packet Complete per request), or split it out. First establish whether the new invariant needs the loop. | R6 (one sentence), R2, R3 (justify or split) | The behaviour change is real (diff). | do, then decide (D14) |
| F-83 | Audit everything now done under `hdev->lock`, in particular `mesh_send_complete()`, for re-entry into the same lock. (Sleeping is allowed: `hdev->lock` is a mutex.) Read-only. | R3 | — | do |
| F-05 | Trim the notes below `---` (testing paragraph to about three lines; keep the conflict notes). Shorten the `mesh_next()` comment to the invariant. (R1: the notes are useful and not excessive.) | R6, R2 | — | do |
| F-06 | Source check: can the unlocked `-ECANCELED` completion (from `hci_cmd_sync_clear()`) run concurrently with anything that walks `mesh_pending`? R6 thinks it is acceptable (runs at unregister). R4 also names the failed-start race and ownership questions as open. Read-only. | R2, R4 | Not yet checked. | do |
| F-07 | Name the two environments behind "mesh-tester 8/10" (local) and "10/10" (the bot's run). | R2 | — | doc |
| F-08 | Add Brian Gix (named by get_maintainer as the mesh author) to the recipients. | R6 | — | decide (trivial) |
| F-09 | `Closes:` vs `Link:`; syzbot test. | R2, R6, R3 | — | decide (D4) |
| F-90 | Cancel on-air request A while B is queued; A's delayed completion (`mesh_send_done_sync()`) completes the current head, which is then B, never sent. R7 proposes a test that tracks starts and completions by handle on both kernels. | R7 | **Pre-existing**, not new with the patch: the old code completes the head the same way; the document already lists it under "Not known" as unchanged. A test of this ordering is a mesh-send ownership test on the unmodified kernel, the kind your 29 October decision governs. | decide (with D4) |

## CO-38 — Read Advertising Features

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-10 | Regenerate the kernel patch on public bluetooth-next (the stored base-commit is our local CO-12 stack), and run the listing case with this fix alone, without the CO-12 clamp. | R2, R6, R7 | True (the document says so). | do |
| F-11 | Add `Cc: stable`. | R6, R2 | — | decide (D12) |
| F-12 | BlueZ test: regenerate the whole timeout-test series on a clean branch, subject prefix `[PATCH BlueZ ...]`, no "research only" cases in the context; say in the cover that the case fails until the kernel fix lands. | R6 | The stored test patch reads `[PATCH 4/4]` and has research-only context lines (document). | do |
| F-13 | Drop the "missing Advertising Removed event" question: instance 2 was never removed. | R2 (R6: separate, later) | Agree. | doc |

## CO-12 — advertising duration overflow

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-14 | Send patch A now with `Cc: stable`, or first agree the semantics. | R6 / R2 | The 655.35 s limit is already stated above `---`. | decide (D5) |
| F-15 | Reconcile the "15 new cases" count with the final test series. | R2, R6 | — | do |

## CO-05 + CO-26 — mesh locking follow-up

Both reviewers: wait for Cen Zhang's 14927631; then at most one small patch. R6: `Fixes:` on
the error path, no stable tag; R2: CO-26 alone is probably not worth a patch. **No action now.**

## CO-02 — SCO connection reuse

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-16 | **The next posting is v2, not v8.** The sent mails are unversioned (`[PATCH 0/3]`…`[PATCH 3/3]`, `[PATCH BlueZ]`); v1 to v6 were internal drafts, never posted. Add a change log under `---`. | R6 | **Verified**: subjects of the sent mails; the dossier's v1 to v6 are local packages. | do |
| F-17 | Timing of v2. | R6 / R2 | — | decide (D1) |
| F-18 | Cover letter to about 60 lines (hardware testing to five lines; the codec-switch delay to one sentence plus "a deferral prototype exists"; stable notes to two lines; the Ubuntu prerequisite note out). | R6 | Current cover is about 170 lines. | do |
| F-19 | Mismatch patch: refuse with -ECONNABORTED only when the found link has no remaining holder (`refcnt == 0`, a closed socket's link); keep -EBUSY for a live one. Retest. | R6, R2 | — | do (after D2) |
| F-20 | Compare the fields that decide the link (`setting`, `codec.id`, `codec.data_path`) instead of `memcmp` of the whole struct; say which. | R6 | — | do |
| F-21 | Put the check as an `else if` next to the `abort_reason` check. | R6 | — | do |
| F-22 | For a link the remote device set up, compare the negotiated Air_Mode instead of refusing once. Needs a stored air mode (CO-21's patch 1 adds exactly that field). | R2 | — | decide later |
| F-23 | The pending-setup parameter overwrite (`setting`/`codec` written on a reused connection): audit, separate patch with our measurements. | R2, R6, R4 | Measured earlier (document). | do later |
| F-80 | The mismatch check only covers `BT_CONNECTED`. When the first setup command is already in flight, a second connect still overwrites the stored parameters; the controller completes with the original ones while the connection records the new ones. Test: hold back the Synchronous Connection Complete *after* the setup command is seen, connect a second socket with other parameters, compare the stored setting with the completed air mode. Fix shape to follow from the result (likely: no overwrite once a setup is issued). The hold fix (patch 1) is unaffected. | R4 | Consistent with the code (the assignment after the lookup is unconditional) and with our earlier overwrite measurements; the in-flight case itself not yet measured. | do |
| F-24 | BlueZ test port as `[PATCH BlueZ v2]`, sent the same day as kernel v2. | R6 | Master's `sco-tester.c` no longer uses GLib (the sent patch is dead). | do with F-16 |
| F-84 | `READ_ONCE()`/`WRITE_ONCE()` on `abort_reason` while other readers stay plain: say which lock or invariant protects the field, or annotate every concurrent access (Sashiko's low note, now also R3). Separate small patch, or one sentence in v2. | R3, Sashiko | Plain readers exist (document). | do |
| F-25 | `Signed-off-by` on the mismatch patch. R6 calls its absence a blocker. | R6 | By design: drafts carry none; you add your own at send (pending proposal). | decide (existing) |

## CO-21 — btusb alternate setting

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-26 | Count CVSD and transparent links in one pass (two calls can see two moments). R3 calls the unlocked reads of `state`, `codec.data_path` and `air_mode` a blocker: `hci_core.h:1666-1668` says runtime data needs the object locked. | R2, R4, R3 | One pass: valid. Locking: a fair point, but existing core helpers read `c->state` under RCU alone (`hci_core.h:1514-1517`). Proportionate fix: one pass, `READ_ONCE()` on the fields, and the write order (air mode before `BT_CONNECTED`) stated; taking `hdev->lock` in `btusb_work()` needs a deadlock check first. | do |
| F-27 | A SCO link whose setting is neither CVSD nor transparent gets no `HCI_NOTIFY_DISABLE_SCO`, and the new `btusb_notify()` no longer schedules on other events: notify for every SCO/eSCO link in the core, or keep scheduling on `CONN_ADD/CONN_DEL`. | R6 | **Verified**: `hci_conn_cleanup()` notifies only for CVSD and transparent (bluetooth-next `hci_conn.c`). | do |
| F-28 | Make the stable tags consistent (patch 2 has `Fixes:`, patch 1 has none; a backport of 2 alone would not build). | R6 | True (patch texts). | do |
| F-29 | One line in the message: "transparent wins" is a choice; the old behaviour was "last event wins". R4 also questions the mixed-codec bandwidth assumption. | R6, R4 | — | do |
| F-30 | Laptop run: one headset at minimum (alt setting in sysfs, up and down), two headsets for the case the patch is about. Needs `bluetooth.ko` and `btusb.ko` together, a cold boot. | R6, R2 | — | you |
| F-31 | Kernel-level validation of the notification/state transitions. | R2 | btusb cannot run in QEMU; only a core-side test is possible. | do (partial) |
| F-32 | Mail to Hitalo Souza. | R6 | — | decide (D8) |

## CO-30 — deferred connect

All reviewers: hold; RFC only if the maintainers ask. R3 adds what an RFC must answer: that
using the cmd_sync queue as a waiting mechanism cannot deadlock or stall unrelated work; that the
wait bound includes queueing delay and the socket timeout; and that other SCO users (PulseAudio,
oFono) are part of the risk. R7 adds a concrete gap: `abort_reason` becomes visible *before* the
abort is queued on the cmd_sync queue, so a retry can be queued ahead of the abort and still find
the old connection. (Consistent with the code as described: `hci_abort_conn()` sets the reason,
then queues; not yet checked line by line.) **No action now; these go into the RFC if it is ever
posted.**

## CO-35 — L2CAP ECRED stable backports

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-33 | Drop 7.2.y; request 7.3.y only. | R2, R6 | **Verified**: kernel.org lists 7.2.15 as the last 7.2.y. Recorded (commit `f4d80fb`). | do |
| F-34 | Check that both commits are in v7.4-rc1, then send in one batch, newest line first. (R6 wrote "rc1 is days away"; it is tagged.) | R6, R2 | **Verified**: v7.4-rc1 tagged (`bc71431221f5`); commit presence not yet checked. | do |
| F-35 | `dc1ddc65f06d`: one source-level sentence on why it is not needed here (R2), or leave it out and let Pauli say (R6). | R2 / R6 | — | do (one sentence) |
| F-36 | The `Fixes:` origin: explain that the deadlock is older (R2), or do not editorialise (R6). | R2 / R6 | The hang is on lines without `ab4eedb790ca` (document). | decide |
| F-37 | Replace the non-pass breakdown in the covers with one sentence ("all other non-passes are pre-existing on the plain tag"). | R6 | — | do |
| F-38 | Shorten mail 1's subject (95 columns). | R6 | — | do |
| F-39 | Recheck the stable queues and newest tags on the send day. | all | — | do |
| F-91 | **Correct the patch-identity claim.** The document said the backports have the same `git patch-id` as upstream. Only 6.18.y's patch 2 does; patch 1 on all three lines and patch 2 on 6.12.y and 6.6.y differ, as their adaptations require. Keep the adaptation notes, drop the identity claim (also from the mails if it appears there). | R7 | **Verified** with `git patch-id --stable` against `608e0b7a675b2` and `32d86e048d8ef`. Review document corrected 11-02. | do (mails) |
| F-85 | Rerun checkpatch and the local CI on the regenerated 2026-11-01 files (pending since then). Write the size-exception sentence as "the upstream prerequisite as-is is the conservative choice over a smaller stable-only locking patch". | R3, R2 | Pending per the CO-35 log. | do |

## CO-22 — QCA ROME USB IDs

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-40 | Check both ASUS commits are in v7.4-rc1 (same check as F-34). | R2, R6 | rc1 tagged. | do |
| F-41 | Verify or drop "dc16388d45ec was queued after a request like this one". | R6 | The document marks it unverified. | do |
| F-89 | The condition to send is "in mainline", not the rc1 tag; write the request accordingly. | R3 | — | do |
| F-92 | Stable trees have `drivers/bluetooth/btusb.c`; `btusb_main.c` is the mainline name after the rename. Name the file per tree where the request mentions one. R7: after mapping the name, both ASUS hunks apply in order on all seven named stable tags. | R7 | Our CO-22 drafts do not use `btusb_main.c` (grep); the survey scripts handle both names. | do (check the mail text) |
| F-42 | Reword "in this order" (it attaches to the tree list). | R6 | — | do |
| F-43 | The 6.6.y `btmtk.h` `-Werror` break: its own short report to stable (bisect `b748250d778e`, 6.6.142; mainline fix `23e88450bb04`). | R2, R6 | — | do (draft) |
| F-44 | Mail B: venue and length. | R6, R2 | — | decide (D7) |
| F-45 | In any owners' text: soften "do not rmmod/modprobe btusb" to "if the controller stops responding after a re-probe, power-cycle"; no module-building walkthrough. | R6, R2 | — | do |

## CO-23 + CO-37 — bluetoothd lifetime fixes

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-46 | Route. | R2, R6 | — | decide (D3) |
| F-47 | One six-mail series, regenerated with `--base` on the public base (no `prerequisite-patch-id:` lines). | R6, R2 | Mail 6 needs mail 2's file; CO-37's fixes apply alone (measured 11-02). | do |
| F-48 | Subjects: 50 columns or practice. | R2 / R6 | HACKING:135 says 50; many merged subjects exceed it. | decide (D9) |
| F-49 | Message fixes: fix 2's ASan trace skips frame #6; the 5.72 patch 1 cites fix 1's old title; the RST "Killing" re-wrap. | both, ours | Known. | do |
| F-50 | Mail 4's code comment to two lines. | R6 | — | do |
| F-51 | Test code: use the plugin's `job` object instead of a `/proc` scan plus `waitpid`; kill the system bus daemon precisely (not the first `dbus-daemon`). Keep fixture-owned process handles throughout, with bounded waits in the teardown tests. | R6, R4, R7 | — | do |
| F-81 | Make the CO-37 dossier and the review section state one final package: six mails, no superseded test text, no contradictory applicability lines. | R4 | Partly done 11-02 (the six mails in the review document); the dossier README still describes earlier states. | do |
| F-52 | Audit the `released` flag through re-entrant `release_endpoint()`/`media_endpoint_remove()` calls (ownership trace). | R2 | — | do (read-only) |
| F-53 | One line in the cover: U25, U26 and the 5.72-only `clear_endpoint` crash are not addressed here. | R6, R2 | — | do |
| F-54 | Register the new 5.72-only `clear_endpoint` use-after-free as an issue. | ours | Found 11-02. | do |
| F-55 | Do not present the 5.72 backport as a complete endpoint-lifetime fix; it now carries the Release flag (`5.72-3`); whether it travels with CO-03 is D6. | R2, R6, R3 | — | do |
| F-86 | Shorten CO-23's mail 1 cause paragraph (the six-function chain) to the causal mechanism, per BlueZ's commit-message guidance. (R6 would keep it.) | R3 | — | do |

## CO-03 — Ubuntu 24.04 BlueZ 5.72 backport

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-56 | Put the bug text in SRU form ([Impact], [Test Plan], [Where problems could occur], [Other Info]); remove the editorial notes ("corrected 2026-11-01 …", "Still to write …"). | R6 | True (draft text). | do |
| F-57 | Changelog `UNRELEASED` to `noble`; LP number once the bug exists. | R6 | True. | do |
| F-58 | Attach a short python3-dbus [Test Plan] script (Acquire, then Release in the same main-loop turn; expect no AVDTP Abort). | R6 | — | do |
| F-59 | R2 says the exact three-patch candidate is untested. | R2 | **Disagree**: the three-patch candidate's own ASan build ran 70/70, and its installed packages 3/3 (document). | — |
| F-60 | Laptop test with the MOMENTUM 4 (the gate). | both | — | you |

## CO-11a — btmon abort

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-61 | [Test Plan]: attach the two captures; put the live results and three lines of outcome in the bug (no pointer to "the review document"). | R6, R2 | Placeholders present (draft). | do |
| F-62 | Retitle: "btmon aborts with 'buffer overflow detected' in print_packet()". | R6 | — | do |
| F-63 | Prepare debdiffs of `dca0f10fd560` for 27.04, 26.10 and 26.04, attached to the same bug. | R6 | — | do |
| F-64 | One upload with CO-03. | R6, R2 | — | decide (D6) |
| F-82 | **A further overflow in `print_packet()` with both fixes.** After the clamp, the text may fill `line[]` to its last byte; the colour reset (`COLOR_OFF`, when colour is on) and the `" %s"` extra text are then written with unbounded `sprintf()`. Reachable only when the text fills the buffer, i.e. a width of 2048 columns or more (`LINE_MAX`). R4 reproduced it under AddressSanitizer in an extracted copy of the 5.72 function (not the package). Next: reproduce with the both-fixes 24.04 btmon at `--columns=5000` with colour forced on a pty and a long record; if it aborts, a small upstream BlueZ patch reserving room for the suffixes, and a decision whether the SRU waits for it or names it. | R4 | **Verified by reading** master `monitor/packet.c:885-919` (the clamp leaves no room for the suffixes). Our replay at 3000/5000 columns did not hit it (no colour when not a terminal; texts shorter than the buffer). | do |

## CO-19 — PipeWire Hands-free codec line

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-65 | Guard in `emit_nodes()`: `if (!this->props.codec)` misses `SPA_ID_INVALID` from `get_hfp_codec_id(0)`; test `get_hfp_codec(this->props.codec) == 0` instead. Rebuild, rerun the unit tests. | R6 | Valid from the code shown (`SPA_ID_INVALID` is non-zero). | do |
| F-66 | Changelog: blank line before the ` -- ` trailer. | R6 | — | do |
| F-67 | [Impact] says the codec cannot be selected (functional); saved-profile restoration (step 8a) is an explicit gate; expect "won't fix in noble". | R6, R2 | — | do |
| F-68 | Laptop test. | all | — | you |
| F-87 | Add an HSP-only check (a synthetic HSP headset in PipeWire's VM tests) for the branch patch 1 protects. | R3 | — | do |

## CO-36 — PipeWire volume resend

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-69 | Leave the "3 of 91" scan out; quote the verified cases. | R2, R6 | — | you |
| F-70 | Issue or MR; V2 or V3. | R2 / R6 | — | decide (D11) |

## CO-32 — WirePlumber input meter

| ID | Follow-up | From | Checked | Kind |
|---|---|---|---|---|
| F-71 | Test first of the Ubuntu items (10 minutes); add to the watch list: repeated link creation, streams that persist after the switch. | R6, R2 | — | you |
| F-72 | Read the other uses of `was_handled` and the skipped path's `checkFollowDefault()` against the new state. Read-only. | R2 | — | do |
| F-73 | File against `wireplumber` (noble) linking LP 2122640, subscribing the patch's author. | R6 | — | you |
| F-88 | Generate the fix as a patch against the source package (`debian/patches`, a debdiff), not against the installed `/usr/share/...` script. | R3 | True (the shown diff is diagnostic form). | do |

# The review document itself

| ID | Follow-up | From | State |
|---|---|---|---|
| F-74 | Five versus six CO-37 mails (R3 also saw `1/2`, `2/2`, `1/3`… numbering). | R2, R6, R3 | **Done 11-02**: the six final mails, regenerated from the stored files, numbered 1/6 to 6/6. |
| F-75 | A decisions list on page one. | R6 | open |
| F-76 | Show near-identical texts once plus a diff (CO-35's three series; v8 patch 1 repeated). | R6 | open |
| F-77 | The reading conventions are restated four times; keep one. | R6 | open |
| F-78 | The draft to Hitalo Souza has a broken re-wrap (one line over 100 columns). | R6 | open |
| F-79 | 7.2.y and v7.4-rc1 facts. | R2, R6 | **Done 11-02**. |

# Rules to carry into every send

From both reviews; I agree with all of them.

1. The diff that is sent is the diff the decisive test ran on. Regenerate every patch from a
   clean public branch on the send day (`git format-patch --base`); no local base-commits, no
   `prerequisite-patch-id:` lines.
2. Cover letters about 60 lines at most; notes below `---` about 10 lines. Details stay in our
   records and go out on request.
3. Stable tags consistent across a series: no `Fixes:` on a patch that needs an untagged
   predecessor.
4. Unrelated discoveries get their own short report, not a paragraph in another request.
5. Answer bots' findings promptly; wait for humans patiently.

# Where the reviewers are wrong, or out of date

| Claim | Reviewer | Finding |
|---|---|---|
| CO-03's exact three-patch candidate was not tested end to end. | R2 | Its own ASan build: 70/70; its installed packages: 3/3. Only the laptop test is missing. |
| The 500 KB document is too much for maintainers. | R2 | It was never a submission; the mails go out one by one. |
| CO-12's 655.35 s limit should be stated above `---`. | R2 | It is already there. |
| 7.4-rc1 is days away. | R6 | Tagged (`bc71431221f5`, checked 11-02). |
| The missing `Signed-off-by` on the mismatch patch is a blocker. | R6 | Deliberate: you add your own at send (pending proposal). |
| BlueZ subjects of 55-65 columns are fine. | R6 | Partly: HACKING asks 50, but much merged practice is longer. Recorded as D9. |
| CO-04: after cancelling an on-air request, the delayed completion can *now* complete the next request. | R7 | The behaviour is real but pre-existing (old code identical on that path); see F-90. |
| CO-21's unlocked field reads are a blocker. | R3 | Overstated: existing core helpers read `c->state` under RCU alone (`hci_core.h:1514-1517`). The point still leads to F-26's single pass with `READ_ONCE()`. |
| CO-23/37's six mails are not serialised consistently. | R3 | Fixed 11-02, after the version R3 read. |
| CO-21: an incoming link can go down without btusb being told, because cleanup decides from the outgoing-only `conn->setting`. | R4 | **Not so for the common case.** `conn->setting` is indeed written only for outgoing connects (`hci_conn.c:1885`), but an incoming link's setting is then 0, and `SCO_AIRMODE_CVSD` is `0x0000` (`hci_core.h:2537`): cleanup takes the CVSD branch and sends `HCI_NOTIFY_DISABLE_SCO`. The gap that remains is R6's: a setting whose air-mode bits are 1 or 2 (F-27). |

# Not reopened

- **Reproducers and syzbot tests for CO-04** (R2, R6): under your 29 October decision; see D4.
