# Detail behind the upstream check of 2026-11-22

The main page is [`2026-11-22T1519Z-contributions-upstream-check.md`](2026-11-22T1519Z-contributions-upstream-check.md). Each part is one reader's findings as written; where the main page differs, the main page is the later reading (several facts were repeated there and are marked "checked").

---

# Part: kernel-sco

## kernel-sco findings, checked 2026-11-22
Trees: bluetooth-next.git master cf357cfc02 (2026-11-20); mainline.git (v7.4-rc3); bluez.git 1adfe662e (2026-11-16); kernel.org: mainline 7.4-rc3, stable 7.3.5, longterm 6.18.64 / 6.12.118 / 6.6.162 / 6.1.192 (releases.json).
Patchwork: all 1287 bluetooth-project patches since 2026-10-15 enumerated (/patches/?project=bluetooth&order=-date&per_page=100&since=2026-10-15T00:00:00&page=1..13) and filtered by title for sco, esco, btusb, hci_conn, hci_abort, handle, isoc, alt, sync conn, hfp, msbc, disconnect, hold, drop, race, use-after-free; plus q= searches ("SCO", "abandoned", "eSCO", "hci_connect_sco", "synchronous connection", "unknown connection handle", "btusb SCO", "btusb isoc", "corrupted SCO", "air mode", "hci_sco", "ECONNABORTED", "sco_connect", "mSBC", "HFP", "alt setting", "alternate setting") since 2026-10-01.
Code drift: from da3cc02587c6 (2026-11-12, the base of the CO-02 v2 / CO-21 candidates) to tip cf357cfc02: hci_connect_sco() and hci_abort_conn() byte-identical (diff of hci_conn.c: only hci_conn_add_unset/hci_conn_add changes, see CO-02); sco.c, btusb_main.c unchanged; hci_event.c and hci_core.h changed in unrelated places (ext adv enable length check, link-key delete helper, link_keys_lock, mgmt_mesh_flush).
Apply checks (git apply --check on files extracted from tip cf357cfc02, read-only, scratch dir): CO-02 v1 patches 1,2,3 apply in sequence; CO-02 alt-2of2 v2-0001 then v2-0002 apply in sequence (0002 alone does not, as designed); CO-02 standalone-3 mismatch patch applies alone; CO-20 patch1-standalone applies; CO-21 review-fixes-20261114 0001 then 0002 apply in sequence. Not built, not run.

### CO-01 — Tested-by on Hitalo Souza's "Fix SCO setup failures after an abandoned setup"
- ours: another author's series (a13f316e90fd made closing a pending SCO socket delete the hci_conn; late completion breaks the next link or leaves a link up); we only test/Tested-by. Register: stalled, wait.
- upstream now: series 1181908 "[v3 0/6]" 2026-10-08T22:26, patches 14875449..14875454 all state `new`, not archived (GET /series/1181908/, /patches/<id>/). BlueZ tester patches 14875435 (sco-tester) and 14875436 (l2cap-tester) `new`. v1 (14872569-71, 10-07) and v2 (14874941-46, 10-08) `superseded`. No v4: GET /patches/?project=bluetooth&submitter=225882&order=-date&since=2026-10-01 returns only v3 and the tester patches; the title enumeration since 10-15 has no later Hitalo SCO posting. bluetooth-next: git log --since=2026-10-01 -E --grep='abandoned|Disconnect links that complete|\bSCO\b' finds none of the six. Only patchwork comments: CI bot on 1/6 (27268049, 2026-10-09: CheckPatch FAIL (commit-id style), GitLint FAIL (title >80 on 3/6 and 5/6), CheckSparse WARNING) and bot comments on 14875435 (27268154, 27306443). The maintainer's 2026-10-09 reply "pointing to Sashiko" is not in patchwork comments; not verifiable here (lore 403). The one Hitalo patch that did land: "Bluetooth: Add missing newline to bt_dev_{err,warn}_ratelimited()" (patchwork 14870776 accepted; mainline f51ee3bb5fbe, 2026-10-06, in v7.4-rc1) - see CO-20/BT-6.
- reports and links: BlueZ issue #2562 (named in dossier) not reachable (api.github.com 403). Linked to CO-02 (same hci_conn/SCO reuse area), CO-21 (its 6/6 "Notify the driver only of SCO links that came up", 14875454, touches the same hdev->notify path as CO-21), BT-6/CO-20 (same author).
- objection: none; cannot tell Sashiko findings (netdev-ai bots site not fetched).
- delivered where: nowhere (not applied anywhere).
- backport: not applicable.
- verdict: CONFIRMED stalled; STILL NOT FIXED UPSTREAM, nothing of ours to send (only an optional Tested-by). Does it still apply: not checked this time (dossier says no); patch 6/6 and CO-21 overlap by design.
- proposed register text: "No v4 as of 2026-11-22; v3 (series 1181908) all six patches `new`, tip cf357cfc02 carries none; wait, rerun the QEMU matrix only if a v4 appears."
- not checked: lore.kernel.org (403), Sashiko site.

### CO-02 — A new SCO connect reuses the closing link (v1 sent 2026-10-27; v2 candidate)
- ours: hci_connect_sco() hands a new SCO socket the hci_conn that hci_abort_conn() is disconnecting (abort_reason set, state still BT_CONNECTED), so connect() "succeeds" with no setup and later closes with ECONNABORTED; plus a refused second connect consuming the first socket's hold. Fixes: 8a5b0135d4a5 (1/3), e6720779ae61 (2/3). v1 = 3 kernel patches + BlueZ sco-tester test; candidate v2 = 1/2 hold + non-sleeping 2/2 refusal (patches/alt-2of2/), mismatch patch later (patches/standalone-3/).
- upstream now, our four patches (patchwork API, 2026-11-22): 14919266 [1/3] new, check success; 14919267 [2/3] new, check FAIL = sashiko-nipa "Sashiko found issues (max severity: high)" (/patches/14919267/checks/); 14919268 [3/3] new, success; 14919269 [BlueZ] sco-tester new, check warning (smatch). All archived=False. Series 1194813 (kernel) and 1194814 (BlueZ). Comments: only bot mail. 14919266 /comments/: 27314240 (2026-10-27T21:24, CI result PASS x24 incl. TestRunner_sco-tester, l2cap, mgmt, iso). 14919267, 14919268: no comments. 14919269 /comments/: 27314119 (2026-10-27T20:16, CI: all PASS except CheckSmatch WARNING flexible-array in bluetooth.h) and 27363059 (2026-11-12T00:36, "pull request https://github.com/bluez/bluez/pull/2724 closed ... If the change should still be considered, it must be resent"). No human reply on any of the four. No reply visible in patchwork to the cover letter (series cover 14163716 per API; its comments not fetched separately).
- Did hci_connect_sco / hci_abort_conn change on bluetooth-next: NO. In hci_conn.c since da3cc02587c6 only hci_conn_add_unset() (+HCI_UP check, +lockdep_assert, Jeremy Dean Clifton 56abe5c17b 2026-11-17, patchwork 14991327 accepted) and hci_conn_add() (+ida_free of the unset handle on failure, 1f150a0bb8, 14991326 accepted) changed. hci_connect_sco() at tip (hci_conn.c ~1904-1950) still does hci_conn_hash_lookup_ba, then hci_conn_link(); the -ENOLINK branch still reads `hci_conn_drop(acl); hci_conn_drop(sco); return ERR_PTR(-ENOLINK);`; only setup when sco->state is BT_OPEN/BT_CLOSED; hci_abort_conn() still returns early on `conn->abort_reason` and sets abort_reason before queueing. So the defect is present at the tip and v1 and v2 candidate still apply in spirit and mechanically (apply checks above). The new HCI_UP refusal makes hci_conn_add_unset() able to return -ENETDOWN, which hci_connect_sco already handles (drops acl, returns the error); no interaction with our patches seen (inference from reading).
- Also changed nearby: Zijun Hu 3efdadae3a "Fix SCO/eSCO Transport_Unit_Size for HCI data path" (committed bluetooth-next 2026-11-02, in mainline v7.4-rc3-line; patchwork 14938724 still shows `new`), touches hci_conn.c SCO setup parameters only (adjacent, not our code). No upstream commit or patch with abort_reason / "reuse" / ECONNABORTED for SCO found (queries above, zero hits).
- reports and links: BlueZ tester series e37f17751 landed (10-21), our sco-tester tests (v1) are not in bluez.git (git grep 'Connect Twice|Reconnect During' tools/sco-tester.c at 1adfe662e: nothing). Linked to BT-13, CO-30, CO-01, CO-21 (same hci_conn).
- objection: n/a (nobody competing). Sashiko's patch-2 `fail` (high) is the only review; the candidate v2 folds as answer.
- delivered where: nowhere.
- backport: our stable trailers (1/2: 6.6.y, 6.12.y; 2/2 v6.13+: 6.18.y, 7.3.y) stay; stable lines in repo's package, not re-verified here.
- verdict: STILL OURS TO SEND (OVERLAP only at the edges: Wentao 14942649 touches the -ENOLINK branch that our 1/2 rewrites, see BT-13; Clifton's accepted patches are same file, no textual conflict with 1/2+2/2 at tip).
- proposed register text: "v1 (14919266-69) all `new`, bot CI green, Sashiko fail on 2/3, no human reply on 2026-11-22; hci_connect_sco/hci_abort_conn unchanged at bluetooth-next cf357cfc02, v1 and the alt-2of2 v2 apply cleanly there; next: rebase v2 on the tip (rebase is trivial), checkpatch, bot CI, send as the resend."
- not checked: lore replies (403).

### BT-13 — -ENOLINK path in hci_connect_sco drops a hold never taken
- ours: new conn starts at refcnt 0, failed hci_conn_link() then hci_conn_drop(sco) takes it to -1; no disc_work, stays in hash. Found by reading; no patch of ours (CO-02 1/2 keeps the lines for a created conn).
- upstream now: Wentao Liang "Bluetooth: delete the new SCO link if linking it fails", patchwork 14942649, 2026-11-04T02:28, state `new`, not archived, series 1201153, Fixes: 06149746e720, Cc: stable, "Assisted-by: DeepSeek ... and OpenAI Codex". Uses hci_conn_del() for a conn created here, keeps the drop for one found in the hash - same defect, same fix direction. Comments: 27335020 (2026-11-04T07:12, Krzysztof Kozlowski: objects to the sender - multiple identities, no checkpatch, nothing reproduced/tested, sent as unorganized independent patches) and 27335387 (CI: CheckPatch FAIL (Assisted-by signature, unrecognized), l2cap-tester FAIL, rest PASS). Not applied: tip still has the buggy branch (hci_conn.c:1927-1930). No maintainer comment on technical merit.
- reports and links: none public. Conflicts textually with CO-02 1/2 (both edit that branch).
- objection: none technical; cannot tell whether it will be taken.
- delivered where: nowhere.
- backport: n/a until applied; then it carries Cc: stable itself.
- verdict: OVERLAP (Wentao's pending patch fixes the same thing; cold path, not reproduced).
- proposed register text: "Same defect pending as Wentao Liang 14942649 (new, 2026-11-04, Kozlowski objected to process, CI l2cap-tester FAIL); not applied at tip. Ours: nothing separate; if CO-02 v2 goes first, say in the cover that 1/2 keeps the branch for a created conn and refer to 14942649."

### CO-20 — btusb: Report SCO receive failures by cause (patch 1 alone; patch 2 held)
- ours: btusb_recv_isoc() logs "corrupted SCO packet" and counts err_rx for data left over after Disconnection Complete as well as real corruption/allocation failure. Package patch1-standalone-20261114/. Register: ready, not sent.
- upstream now: no patch or commit found. Patchwork title/keyword searches (list above, "btusb SCO", "btusb isoc", "corrupted SCO", "unknown connection handle") zero SCO-btusb hits since 2026-10-01; git -C bluetooth-next.git log --since=2026-09-01 -E --grep='corrupted|isoc|unknown connection handle': only unrelated hits (btmtk isointf init, 3efdadae3a). btusb_main.c at tip: "corrupted SCO packet" at line 1844, btusb_recv_isoc line 1548 unchanged since da3cc02587c6. Adjacent upstream: f51ee3bb5fbe (above, Hitalo Souza, Fixes 36278a5d4d35 and 657cc646475b, in v7.4-rc1; its message cites MT7921 eSCO close giving "SCO packet for unknown connection handle"). Not in stable 7.3.y/6.18.y/6.12.y by title/Fixes grep (git log <branch> --since=2026-10-06 -E --grep='newline to bt_dev|bt_dev_\{err'); stable-queue and 6.6/6.1 branches missing in the local clones.
- reports and links: bugzilla 219992 "SCO packet for unknown connection handle 3" (NEW, 2025-04-08, JBL GO 2), 220593 (Sony XM5, SCO packet err), 221598 (RTL8821C mSBC stutter, bursty SCO RX), via rest/bug?quicksearch=; none fixed. Linked to BT-6, CO-21 (same btusb), CO-18.
- objection: n/a.
- delivered where: newline fix: mainline v7.4-rc1 onward; not stable (see above).
- backport: newline fix f51ee3bb5fbe is a backport candidate (has Fixes tags, real bug); needs checking it applies to 6.12/6.6 (bt_dev_*_ratelimited macro in include/net/bluetooth/bluetooth.h; virtio_bt hunk) and the stable queue (not reachable here).
- verdict: STILL OURS TO SEND (patch 1).
- proposed register text: "No competing patch at tip cf357cfc02 (btusb_recv_isoc unchanged); patch 1 applies to the tip; newline fix f51ee3bb5fbe is in v7.4-rc1 but not yet in 7.3.5/6.18.64/6.12.118 by grep."
- not checked: stable-queue.git, linux-6.6.y/6.1.y (not cloned), lore.

### CO-21 — btusb with two SCO links: one going down switches the other to alt 0
- ours: btusb_notify()/btusb_work() pick the alt setting from a count that ignores the other link; fix = keep air mode of links that came up (hci_event.c, hci.h/hci_core.h) + pick the alt from links up (btusb_main.c). review-fixes-20261114/ 2 patches + cover.
- upstream now: nothing found. btusb_main.c lines: isoc_altsetting 1075, btusb_notify 2472, btusb_switch_alt_setting 2528, btusb_work 2586 - unchanged from da3cc02587c6 (diff of btusb_main.c da3cc..tip empty). Only related posting: Hitalo's 6/6 (14875454, `new`) changes when the driver is told about SCO links, a different change in hci_event.c in the same flow (see CO-01). Patchwork queries "alt setting", "alternate setting", "btusb SCO": zero.
- reports and links: bugzilla quicksearch "btusb SCO alt setting": zero results. Related: 221722 (MT7925 enhanced setup quirk; reporter now cannot reproduce).
- objection/delivered/backport: n/a.
- verdict: STILL OURS TO SEND (overlap risk with CO-01 6/6 if it ever returns).
- proposed register text: "Nothing competing at cf357cfc02; both patches apply to the tip in sequence (apply check 2026-11-22); only possible conflict is Hitalo's stalled 14875454."

### CO-30 — defer a SCO connect (RFC)
- ours: sco.c RFC queuing the connect behind the abort, -EINPROGRESS.
- upstream now: nothing. sco.c: only c4154fc347 (Peng Fan, assign_bit, 2026-09-20) since 10-01 window; no patchwork hit for "defer", "sco_connect", "ECONNABORTED". Needs CO-02 2/2 first; not re-tested on the non-sleeping 2/2 (repo's own record).
- reports: BlueZ/PipeWire side is U7/U17 (not checked here).
- verdict: STILL OURS TO SEND (RFC, blocked by CO-02).
- proposed register text: "Nothing competing; sco.c untouched at tip; waits on CO-02 v2 and a re-test on the non-sleeping 2/2."

### CO-18 — U8, earbuds silent in mSBC
- ours: dropped as kernel item; the kernel line is CO-20's teardown effect. Upstream: no kernel patch for it; related public kernel bugs 221722 (MT7925 mSBC silent mic; reporter 2026-10-19 can no longer reproduce) and 221598 (RTL8821C bursty SCO RX) are other chips.
- verdict: CANNOT TELL for the earbuds' side; kernel side nothing to send.
- not checked: PipeWire/WirePlumber trackers (outside my part).

### BT-6 — "ACL/SCO packet for unknown connection handle"
- ours: benign race, data after Disconnection Complete (hci_core.c:4107 ACL, 4141 SCO, 4170 ISO at tip). Present at tip.
- upstream now: no patch changes the message or the handling. Related: f51ee3bb5fbe fixes the missing newline (the message's visible lateness), whose message describes the same SCO-after-disconnect on MT7921 (Hitalo Souza, patchwork 14870776 accepted, v7.4-rc1). Yu Junzhe's [6.6] stable backport "hci_core: lookup hci_conn on RX path" (14996835, 2026-11-18, new; backport of 79a2d4678ba9, CVE-2025-68304, 6.6.162 only; touches hci_core.c/sco.c/iso.c/l2cap_core.c RX lookups) is adjacent: it changes how the RX handler finds the connection, not the "unknown handle" message. bluetooth-next hci_core.c at tip already has l2cap_conn_hold_unless_zero use. bugzilla 219992 is the public report for the SCO line (2025-04-08, NEW).
- objection: none. verdict: FIXED UPSTREAM BY OTHERS for the diagnostic part (newline, v7.4-rc1, not in 7.3.5/6.18.64/6.12.118 by grep); the message itself still exists and CO-20 is our only related change.
- proposed register text: "Benign; the 'late' timing was the newline bug, fixed in v7.4-rc1 as f51ee3bb5fbe (not yet in stable by grep); message unchanged at tip; public report bugzilla 219992."

## Cross-links
- CO-02, BT-13, CO-30, CO-01 all in hci_connect_sco()/hci_conn; Wentao 14942649 and CO-02 1/2 edit the same -ENOLINK branch.
- CO-01 6/6 (14875454) and CO-21 both change when/how btusb learns of SCO links; CO-20/CO-21 share btusb_main.c SCO paths.
- BT-6, CO-20, CO-18 share the teardown tail (data after Disconnection Complete); Hitalo's f51ee3bb5fbe commit message describes it.

## Corrections to the readiness report or the register
- Register CO-20 row says the newline fix is bluetooth-next f3d041ec63f7; that id is not in the local clone; mainline id f51ee3bb5fbe (2026-10-06, v7.4-rc1) confirmed. Patchwork 14870776 accepted.
- Readiness report: Wentao's 14942649 "fixes this branch" confirmed; add that it is `new`, was criticized by Kozlowski on process (27335020) and failed CI CheckPatch/l2cap-tester; not applied.
- Register CO-02/STATUS cites bluetooth-next `47d4d9f67e92`/`c9644a9257d1` as base; current tip is cf357cfc02 (2026-11-20); hci_connect_sco unchanged there.
- Zijun Hu 3efdadae3a (SCO/eSCO Transport_Unit_Size) is in hci_conn.c and applied while patchwork shows 14938724 `new`; not mentioned in the register.

---

# Part: kernel-mgmt-mesh

## Kernel MGMT / mesh / advertising contributions: upstream check, 2026-11-22

Sources used (all read 2026-11-22): bluetooth-next.git master (tip cf357cfc02, 2026-11-20), mainline.git master
(4843f6873f, 2026-11-21, v7.4-rc3-921), stable.git linux-7.3.y / 6.18.y / 6.12.y (the 6.6.y and 6.1.y fetches were
still running; not read), Patchwork API (bluetooth project), kernel.org releases.json (mainline 7.4-rc3, stable
7.3.5, longterm 6.18.64 / 6.12.118 / 6.6.162 / 6.1.192), WebSearch + WebFetch of the syzkaller-bugs Google group.

## The commit 1d7a52778858 and the two claims, verified

- Commit: "Bluetooth: mgmt: Fix mesh transmission locking and lifetime", Luiz Augusto von Dentz, authored 2026-11-09
  (`git -C bluetooth-next.git show 1d7a52778858`), in bluetooth-next master (`merge-base --is-ancestor` yes).
  Patchwork 14998382 = "[v5,11/17]" of series 1215366 "Bluetooth: Fixes for issues reported by sashiko.dev"
  (v5, 2026-11-18, 17 patches), state `accepted`, commit_ref 1d7a527788584e4a88ccc532ed73bfdacd0b1e74. v1 to v4
  (14994498, 14994726, 14997223, 14997689) `superseded`. Confirmed: the report's id, state and hash are right.
- Tags: `Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")`, three `Link: https://sashiko.dev/#/bug/...`,
  `Reported-by: Sashiko`, `Assisted-by`. NO `Cc: stable@vger.kernel.org`. NO syzbot Reported-by/Closes. 
- Not in mainline: `git -C mainline.git merge-base --is-ancestor 1d7a527788 master` -> "Not a valid object name" (object
  absent from mainline as of 2026-11-21). So it is in no stable line and, being outside mainline, cannot be in
  stable-queue (stable-queue.git itself was not cloned; this is inference from the stable rules, not a lookup).
- Mainline mesh state for comparison: `71af682ba4` (Lee Jones, "Dequeue pending mesh_send_sync entries on cancel") and
  `8a8d51eeed` (Pauli Virtanen, mesh adv timeout units) are in mainline; 71af is also in stable linux-7.3.y
  (71af682ba4), 6.18.y (2189a21939), 6.12.y (084be90948).

### What 1d7a52778858 changes (diff read in full), mapped to our cases

| Our case | Our hunk | In 1d7a52778858? |
|---|---|---|
| CO-04 double queue of one mgmt_mesh_tx -> UAF in mesh_send_sync | keep HCI_MESH_SENDING set until mesh_next() decides under hdev->lock; mesh_next() takes hdev->lock; no lock under cmd_sync_work_lock; send_cancel hands over | YES, by another design: entries carry the handle (MESH_TX_DATA) and mesh_send_sync/start_complete re-find it with mgmt_mesh_find() under hdev->lock, so no raw pointer survives; `__mesh_next()` under hdev->lock sets HCI_MESH_SENDING only after a successful queue; `-ECANCELED` callbacks return before taking hdev->lock (same rule as ours); flag cleared only together with removal of the tx (same intent as ours). The syzbot freed-then-read case cannot occur (lookup by handle returns NULL). |
| CO-04 "Not changed here": cancel of the on-air tx makes mesh_send_done_sync complete the oldest pending (unsent) request | not fixed by us | YES (inference from the diff): mesh_cancel_tx() dequeues mesh_send_sync, dequeues mesh_send_done_sync if the cancelled tx is in progress, cancels the done timer, clears the flag; done_sync completes by handle. Not run by us. |
| CO-04 / M-5 lockdep cycle (mesh_next as destroy callback of mesh_send_done_sync under cmd_sync_work_lock, then hci_cmd_sync_submit -> unregister_lock) | we removed the destroy callback | YES (inference): the callback stays (`hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next)`) but `mesh_next()` now returns first on `err == -ECANCELED`, which is what hci_cmd_sync_clear() passes, so it no longer calls hci_cmd_sync_queue(). Not run against our UnregSweep. |
| CO-05 1/2 hdev->lock in mesh_send_sync (capacity check, hci_add_adv_instance, list walk; unlock before hci_schedule_adv_instance_sync) | 14 lines | YES, same structure: hci_dev_lock after the handle lookup, unlock before `hci_schedule_adv_instance_sync()`. Plus separately: c592dfe963 (Luiz, 2026-11-09, series 1215366 patch 04/17) takes hdev->lock inside hci_schedule_adv_instance_sync(); and d7e77168da (Cen Zhang, applied 2026-11-19) the rest (see CO-05 note). |
| CO-26 / CO-05 2/2: failed hci_add_adv_instance() must return the error, not schedule the missing instance | `if (IS_ERR(adv)) { unlock; return PTR_ERR(adv); }` | NO. bluetooth-next master `mesh_send_sync()` (hci_sync-independent, mgmt.c:2441-2515) still has `if (!IS_ERR(adv)) mesh_tx->instance = instance; else err = PTR_ERR(adv);` and carries on to `hci_schedule_adv_instance_sync(instance)` / `return err`. Neither 1d7a nor d7e77168da touch these lines. |
| CO-14 / M-4 pending mesh sends leaked (with their socket ref) at controller removal; our fix in mgmt_index_removed() | free silently there | YES: `mgmt_index_removed()` now calls `mesh_flush(hdev, true)` (clears the flag, cancel_delayed_work_sync(mesh_send_done), dequeues both cmd_sync entry kinds, mesh_send_complete(silent) every pending tx, which does the sock_put); also `mgmt_mesh_flush()` from hci_dev_close_sync() (power off, auto-off too) and Mesh Send refused with NOT_POWERED while the controller is down. Called with hdev->lock held (hci_unregister_dev takes it around mgmt_index_removed). Not run against our 10-boot kmemleak harness. |
| CO-06 Jiale Yao 14864878 (mesh_next failure on completion; mesh and power-off) | review reply | Substance is covered: `__mesh_next()` completes a tx whose queueing failed; `mesh_flush` at power off; NOT_POWERED reject; hdev->lock throughout. His patch is stale (`new`). |
| Tested-by target: Hui Peng 14831271 (mesh_tx leak when hci_cmd_sync_queue fails) | n/a | YES, behaviour covered: `__mesh_next(hdev, new)` completes a tx that failed to queue (silently for the handle userspace was not told), `mesh_send()` returns Failed and the tx is gone; the powered-off reproducer in our Tested-by now gets NOT_POWERED. |

Residual issue visible in the diff (inference, not run): `mesh_send_complete()` now documents "requires hdev->lock", but
`mgmt_cleanup()` (socket destructor, mgmt.c:11317-) still walks mesh_pending and calls mesh_send_complete(silent) without
hdev->lock. That is exactly what Cen Zhang's 14880941 ("Remove mesh cleanup from the socket destructor", 2026-10-12,
`new`, KASAN slab-use-after-free in mgmt_mesh_next) removes; it is not applied.

Cen Zhang series 1215537 "Bluetooth: Fix advertising instance accesses without hdev->lock" v2 (2026-11-19): 14999296
[v2,1/2] "Fix remaining advertising instance UAFs" and 14999297 [v2,2/2] "Use controller handles for periodic
advertising". Patchwork still says `new` (CI bot: CheckPatch/BuildKernel PASS), BUT both are already in bluetooth-next:
d7e77168da and a7d2c94ba2, 2026-11-19 (`git log --grep`; Luiz signed off). The report's "posted v2" is right; its
"new" is out of date (see Corrections). Patchwork 14927631 (v1 1/2, v9 id in the msgid) is `superseded`.

---

### CO-04 — syzbot's mesh_send_sync use-after-free, our independent fix
- ours: two start entries for one mgmt_mesh_tx (HCI_MESH_SENDING cleared before mesh_next hands over) -> second
  mesh_send_sync reads the freed tx; "Bluetooth: MGMT: Fix use-after-free in mesh_send_sync()", package
  CO-04-mesh-test-14888791/review-fixes-20261114/patch/, register: send package ready, nothing sent.
- upstream now: fixed in bluetooth-next by 1d7a52778858 (see table; patchwork 14998382 accepted, 2026-11-18; not in
  mainline, no stable). Competing earlier: Igor Putko 14888791 (2026-10-14, `new`, hdev->lock in mesh_next and
  start_complete; syzbot answered Hillf Danton's `#syz test` with Tested-by on 2026-10-15) and Baul Lee
  14736726-28 v2 (2026-08-07, `new`), Wentao Liang 14942650 (2026-11-04, `new`; Krzysztof Kozlowski's bot comment only):
  all stale next to 1d7a.
- reports and links: syzbot "KASAN: slab-use-after-free Read in mesh_send_sync", ext f20755f37da70df33a16, reported
  2026-10-07 on 3b7cab693ba2, reproducer found 2026-11-15 on 23c62304dde2 (WebFetch of
  groups.google.com/g/syzkaller-bugs/c/Gk3XAyPZf4M/m/dJia_2IrAQAJ; content truncated, no `#syz fix/dup` visible).
  Linked to CO-05, CO-06, CO-14 (same path) and to M-5.
- objection to the upstream fix: none found by reading. It covers the double-queue by construction. Caveat: 1d7a has no
  syzbot Reported-by/Closes, so syzbot will not auto-close the bug; someone must send `#syz fix: Bluetooth: mgmt: Fix
  mesh transmission locking and lifetime` once it is in mainline (we can do that, it is a reply to the syzbot thread).
  Not tested by us on 1d7a.
- delivered where: bluetooth-next only (11-19). Mainline: no (as of 2026-11-21, v7.4-rc3 +921). Stable: no.
  Ubuntu noble: no (not queried; it cannot be there).
- backport: when it reaches mainline: candidate for every line that has b338d91703fa (the dossiers say 6.1.y upward:
  6.1, 6.6, 6.12, 6.18, 7.3). The patch has Fixes: but no Cc: stable, so a request after mainline is the right step
  (AUTOSEL may also pick it). It is large and relies on 71af682ba4 (in 7.3.y/6.18.y/6.12.y; 6.6.y/6.1.y not read) and
  `kzalloc_obj` (mgmt_util.c context), so 6.6/6.1 need a hand backport. Homework: apply check per line, build, mesh-tester
  + our CO-04 cancel/backlog/removal runs on a 1d7a kernel in QEMU.
- verdict: FIXED UPSTREAM BY OTHERS (ours not needed). Possible remaining value: a Tested-by/Reviewed-by-style
  test report on 1d7a (our harness: 12-35 boots per scenario, KASAN, lockdep; compare M-5 2/35 on the old tip).
- proposed register text: "Superseded 2026-11-22: the maintainer's `1d7a52778858` (patchwork 14998382, accepted; bluetooth-next, not yet mainline) fixes the same double-queue by handle lookup under hdev->lock; our patch is not sent. Next: rerun our cancel/backlog/UnregSweep tests on bluetooth-next tip as a test report, and `#syz fix:` the syzbot bug once it is in mainline."
- not checked: syzkaller.appspot.com (HTTP 429), lore.kernel.org (403). The Google-groups page was readable but truncated.

### CO-05 + CO-26 — hdev->lock in mesh_send_sync (1/2); a failed add (2/2)
- ours: mesh_send_sync() adds the instance and reads the counters without hdev->lock; on failed add it schedules the
  missing instance. Two patches + cover, CO-05-mesh-adv-list-lock-i12/review-fixes-20261114/ (variant A with Fixes:,
  B without). Register: send package ready, mesh held.
- upstream now: 1/2 (the lock) FIXED UPSTREAM BY OTHERS: 1d7a52778858 (see table) and, for the rest of the advertising
  paths, Cen Zhang's d7e77168da "Fix remaining advertising instance UAFs" (applied 2026-11-19; lists mesh_send_sync in
  its message; its mgmt.c hunks touch adv_expire_sync and set_advertising_complete, not mesh_send_sync, which 1d7a had
  already locked). 2/2 (CO-26): NOT fixed, no patch found: bluetooth-next master mgmt.c:2441-2515 still
  `else err = PTR_ERR(adv)` then carries on; patchwork queries (project=bluetooth) `q=mesh_send_sync` returned only
  14888791, 14818191, 14802558, 14781678, 14781433; `q=mesh&since=2026-08-01` (list above in this file's data) shows no
  patch that touches the add result.
- reports and links: none public. Linked to CO-04 (same function) and CO-12 (d7e77168da also clamps the duration).
- objection to the upstream fix: none for the lock. CO-26's difference is real but minor: the user-visible completion
  is identical (our own commit message says "cleanup of the error path"), only the error code reaching
  mesh_send_start_complete() differs (-ENOENT vs -ENOMEM).
- delivered where: bluetooth-next only; not mainline, not stable.
- backport: 1/2: not applicable (superseded; its Fixes target is the same b338d91703fa as 1d7a). 2/2: not a stable
  candidate (no user-visible effect); mainline only.
- verdict: CO-05 1/2 = FIXED UPSTREAM BY OTHERS. CO-26 = STILL OURS TO SEND (nothing competing found), low value.
- proposed register text: "CO-05 1/2 superseded 2026-11-22 by `1d7a52778858` (hdev->lock in mesh_send_sync) and `d7e77168da`; drop. CO-26 (return the add error) is not upstream: rebase the one hunk on bluetooth-next `cf357cfc02`, optional, mainline only, no Fixes/stable."
- not checked: lore.

### CO-06 — review reply on Jiale Yao's mesh power-off patch (14864878)
- ours: nothing drafted; a reply would report a lock gap (his fallback runs the done work unlocked) and that a backlog of 3
  and controller removal still fail.
- upstream now: 14864878 "Bluetooth: mgmt: handle mesh send completion queue failure" (2026-10-03) is `new`, comments:
  only the CI bot (patchwork /patches/14864878/comments/ queried 2026-11-22). Its subject matter is handled by
  1d7a52778858 (`__mesh_next()` completes a tx that failed to queue; mesh_flush at power off and removal; NOT_POWERED).
- reports and links: our patch applies on neither; the research dossier measured 8/26 -> 21/26 and 20/26.
- objection: moot; cannot tell whether his patch's gaps remain only as 1d7a's design (not run).
- delivered: see CO-04.
- backport: not applicable.
- verdict: FIXED UPSTREAM BY OTHERS (reply moot; the author's patch will be dropped as stale).
- proposed register text: "Moot 2026-11-22: `1d7a52778858` covers the queue-failure completion and power-off/removal flush; 14864878 still `new` with only the CI bot. No reply to send; close."
- not checked: lore.

### CO-13 — mesh "Count" question
- ours: Count does not set air time (~1 s), Count 0 accepted, >=52 wraps the u16 duration; question to the list.
- upstream now: nothing found. Code unchanged: bluetooth-next master mesh_send_sync still `u16 duration = send->cnt *
  INTERVAL_TO_MS(hdev->le_adv_max_interval)` and `msecs_to_jiffies((send->cnt) * 25)` (mgmt.c, 1d7a context lines).
  Patchwork queries: `q=mesh+Count` -> 14736728 (Baul Lee, refcount tx), 14736335, 11456217 (BlueZ mesh relay count, 2020);
  none about Mesh Send Count semantics. Pauli Virtanen 8a8d51eeed fixed only the timeout units.
- reports and links: none public.
- objection / delivered / backport: not applicable.
- verdict: STILL OURS TO SEND (a question, nothing competing).
- proposed register text: "Unchanged 2026-11-22: Count semantics and the u16 duration wrap (Count >= 52) are untouched on bluetooth-next after `1d7a52778858`; a question to the list is still open, low priority; ask only once CO-04/05 are closed (they now are, by others)."
- not checked: lore, BlueZ mesh issue tracker on GitHub.

### CO-14 / M-4 / M-5 — pending mesh sends leaked at controller removal; lockdep cycle
- ours: mgmt_index_removed() only cancels the done work; each pending tx leaks with its socket reference (86 objects in
  10 boots); fix in mgmt_index_removed(); M-5 is the unregister_lock cycle. Dossier fix-20261114/. Register: fix written,
  nothing sent.
- upstream now: FIXED UPSTREAM BY OTHERS in bluetooth-next by 1d7a52778858: new `mesh_flush(hdev, true)` in
  mgmt_index_removed() (replaces the lone cancel_delayed_work_sync), also from hci_dev_close_sync(), plus
  not-powered rejection. M-5: the destroy callback mesh_next() exits on -ECANCELED (inference above). No other patch found.
- reports and links: our reproducer in retest/ and the dossier; no public report.
- objection: none from the diff. One check worth doing: the flush uses cancel_delayed_work_sync(mesh_send_done) and
  hci_cmd_sync_dequeue() with hdev->lock held (hci_unregister_dev holds it); the lockdep run on 1d7a is the proof, not done.
- delivered: bluetooth-next only. Not mainline, not stable.
- backport: with CO-04 (same commit).
- verdict: FIXED UPSTREAM BY OTHERS (ours not needed; maybe a test report remains).
- proposed register text: "Superseded 2026-11-22: `1d7a52778858` flushes pending mesh sends in mgmt_index_removed() and at power off, and stops mesh_next() taking locks on -ECANCELED (M-4 and M-5). Rerun our 10-boot kmemleak and 35-boot UnregSweep on bluetooth-next tip to confirm 0 / 0; nothing to send."
- not checked: lore.

### CO-12 / M-2 — u16 duration overflow in hci_enable_ext_advertising_sync()
- ours: `u16 duration = adv->timeout * MSEC_PER_SEC` wraps above 65 s (66 s ends after 463 ms; 8192 s = Duration 0 =
  never ends); clamp patch "Bluetooth: hci_sync: Fix extended advertising duration overflow", send-20261114/.
- upstream now: FIXED UPSTREAM BY OTHERS in bluetooth-next: d7e77168da (Cen Zhang, 2026-11-19, patchwork 14999296 [v2,1/2],
  series 1215537, patchwork still `new` but applied). Message: "Use a u32 for the timeout-to-milliseconds conversion before
  converting to the controller's 10 ms units, and clamp the result to U16_MAX. The old u16 intermediate wrapped timeouts
  longer than 65 seconds." Code now: `u32 duration = 0; ... set->duration = cpu_to_le16(min_t(u32, duration / 10, U16_MAX));`
  with the mesh branch (`adv->mesh ? adv->timeout : adv->timeout * MSEC_PER_SEC`) kept. Identical result to our clamp
  (including the >655.35 s limit; our "RFC for a different semantics" question was not raised there). Not in mainline
  (mainline hci_sync.c still has `u16 duration`, checked with `git show master:net/bluetooth/hci_sync.c`).
  Earlier: v1 14927631 (2026-10-30) `superseded`.
- reports and links: no public report. The fix's Fixes: tags (cba6b758711c, eca0ae4aea66, c249ea9b4309, b338d91703fa)
  do not include our origin 10bbffa3e88e; no Cc: stable.
- objection: none for the code. Note the commit buries the wrap fix in a large UAF patch, so it will not be taken to stable
  as is.
- delivered: bluetooth-next only. Not mainline, not stable (7.3.y/6.18.y/6.12.y unaffected by the commit).
- backport: candidate AFTER mainline, as a small separate clamp-only patch for stable lines that have the u16 code
  (the wrap is user visible via btmgmt add-adv -t; our own package is already that small patch). Needs: confirm which
  lines carry the u16 line (6.1 onward per the dossier; 6.6.y/6.1.y not read), apply check, build, our AdvDur 22 cases.
  Stable rule fit: fixes a real bug, in mainline first.
- verdict: FIXED UPSTREAM BY OTHERS (ours not needed for mainline); STABLE BACKPORT CANDIDATE once mainline has it.
- proposed register text: "Fixed 2026-11-22 in bluetooth-next by Cen Zhang's `d7e77168da` (same u32 + U16_MAX clamp; not yet mainline). Do not send ours; after it reaches mainline consider a clamp-only stable backport, and send the AdvDur tests (BlueZ series B) as the remaining contribution."
- not checked: lore, syzbot.

### CO-38 — Read Advertising Features hides instances numbered above the instance count
- ours: read_adv_features() compares instance with `adv_instance_cnt` instead of `le_num_of_adv_sets`; send-20261114/patch/
  "Bluetooth: MGMT: Fix Read Advertising Features hiding ...". Register: send package ready.
- upstream now: nothing found, defect still present: bluetooth-next master read_adv_features():
  `if (adv_instance->instance <= hdev->adv_instance_cnt)` after the comment "Only instances 1-le_num_of_adv_sets are
  externally visible" (mgmt.c). Patchwork queries (project=bluetooth): `q=Read+Advertising+Features` (only 2021 Marcel
  Holtmann opcode fix 12137381, 12161223), `q=read_adv_features` (0), `q=adv_instance_cnt` (only 2022 Niels Dossche
  12744449), `q=num_of_adv_sets` (2024 Luiz 13663681), `q=Advertising+Features&since=2026-01-01` (0). Adjacent but
  different: Piyus Kedia 14976301 [v3] "drop advertising instances the controller cannot carry" (2026-11-12, `new`,
  hci_powered_update_adv_sync); Luiz's 2026-10-05 advertising-instance series (applied) and BlueZ mgmt-tester
  "Add single advertising set tests" (Weihong Guan, bluez 923d95d0c, 2026-11-12) and "emulator: Set the number of
  advertising sets" (58e111cc9) touch the same test area: a conflict/overlap with our BlueZ test cases is possible.
- reports and links: none public. Related to CO-12 (found by its tests; the clamp now upstream via d7e77168da, so 128/128
  of "Add" no longer needs our CO-12 patch, only CO-38).
- objection: n/a.
- delivered: nowhere; present in 6.1.y to bluetooth-next per the dossier (origin b338d91703fa per register).
- backport: after mainline; our patch has no Cc: stable (the report notes D12 says yes).
- verdict: STILL OURS TO SEND (nothing competing found). Homework: apply check on cf357cfc02 (mgmt.c moved: 1d7a, d7e77168da, 5052141b19), rerun the new case; check our BlueZ test against Weihong Guan's new advertising-set tests.
- proposed register text: "Defect still present on bluetooth-next `cf357cfc02` (2026-11-22), no competing patch; rebase and re-test on the tip, check the BlueZ cases against bluez `923d95d0c`/`58e111cc9`, then send."
- not checked: lore.

### CO-44 / BT-21 — a command timeout reported as Authentication Failed
- ours: mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED; "Bluetooth: MGMT: Report a timed out command as
  MGMT_STATUS_TIMEOUT" + BlueZ mgmt-tester case, send-20261113/.
- upstream now: nothing found, defect still present: bluetooth-next master mgmt_errno_status() has
  `case -ETIMEDOUT: return MGMT_STATUS_AUTH_FAILED;`. Patchwork (project=bluetooth) `q=MGMT_STATUS_TIMEOUT` 0,
  `q=ETIMEDOUT&since=2026-06-01` 0, `q=mgmt_errno_status` 0, `q=timeout+Authentication+Failed` 0,
  `q=Set+Device+Class+timeout&since=2026-10-01` 0, `q=mgmt-tester+timeout&since=2026-10-01` 0. bluez.git log of
  tools/mgmt-tester.c since 2026-10-01: no timeout/Device Class test. Kernel bugzilla quicksearch for the subject words
  returned unrelated old bugs only.
- reports and links: none public.
- objection: n/a.
- delivered: nowhere. Present in every line with 161510ccf91c (the dossier's Fixes:).
- backport: ours says not for stable (user-visible status change).
- verdict: STILL OURS TO SEND (nothing competing found).
- proposed register text: "Still unfixed on bluetooth-next `cf357cfc02` (2026-11-22), no competing patch or report; apply-check both patches on the tip (mgmt.c moved), then send per the operator's decisions."
- not checked: lore.

### Hui Peng 14831271 — Tested-by (not a CO row)
- ours: Tested-by posted 2026-10-06 20:18 on his patch (visible in patchwork /patches/14831271/comments/, author Iaroslav
  Voitovych, full test text, with the retest link). Confirmed delivered.
- upstream now: 14831271 still `new`, no reply except ours and the bot. A v3 of his other patch 14831256 was withdrawn by him
  ("Please drop this patch", 2026-09-19). Behaviour covered by 1d7a52778858 (see table). Wentao Liang 14942650 (2026-11-04) is the
  same fix again, `new`.
- verdict: ALREADY DELIVERED (Tested-by); the patch itself is overtaken by 1d7a52778858; nothing further owed.
- proposed register text: "Tested-by sent 2026-10-06 (patchwork comment). Patch overtaken 2026-11-22 by `1d7a52778858`; closed."

### Other authors' mesh patches named in STATUS.md — state now (patchwork API, 2026-11-22)
| id | author, subject | date | state | note |
|---|---|---|---|---|
| 14831271 | Hui Peng, MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure | 2026-09-19 | new | overtaken by 1d7a52778858; our Tested-by is on it |
| 14864878 | Jiale Yao, mgmt: handle mesh send completion queue failure | 2026-10-03 | new | only the CI bot replied; overtaken |
| 14880941 | Cen Zhang, mgmt: Remove mesh cleanup from the socket destructor | 2026-10-12 | new | NOT covered by 1d7a (mgmt_cleanup() still walks mesh_pending unlocked on bluetooth-next); still live |
| 14927631 | Cen Zhang, [1/2] hci_sync: Fix remaining advertising instance UAFs (v1, series 1197214) | 2026-10-30 | superseded | replaced by v2 14999296, applied as d7e77168da |
| 14888791 | Igor Putko, mgmt: Fix UAF in mesh_send_sync caused by race in mesh queue | 2026-10-14 | new | syzbot Tested-by on #syz test 2026-10-15; overtaken by 1d7a |
| 14998382 | Luiz von Dentz, mgmt: Fix mesh transmission locking and lifetime (v5 11/17) | 2026-11-18 | accepted, 1d7a52778858 | |
| 14999296 / 14999297 | Cen Zhang v2 1/2, 2/2 | 2026-11-19 | new in patchwork, applied as d7e77168da / a7d2c94ba2 | |
| 14942650 | Wentao Liang, free the mesh tx if queueing the send fails | 2026-11-04 | new | overtaken |

### syzbot bug "slab-use-after-free Read in mesh_send_sync" (f20755f37da70df33a16)
- Closed? CANNOT TELL. syzkaller.appspot.com returns HTTP 429. The Google-groups thread (WebFetch, truncated) shows the
  report of 2026-10-07 and a reproducer message of 2026-11-15, and no visible `#syz fix`, `#syz dup` or `#syz invalid`.
  A web-search snapshot of the bluetooth subsystem page lists it open with a "PATCH" discussion (undated, stale).
  1d7a52778858 has no syzbot tags, so syzbot will not close it automatically, and it is not in mainline anyway
  (syzbot closes on a mainline commit).

### Stable and distribution answers for 1d7a52778858
- Fixes: b338d91703fa (Bluetooth: Implement support for Mesh). No `Cc: stable`. Not in mainline (absent from
  mainline.git master 4843f6873f of 2026-11-21), not in linux-7.3.y/6.18.y/6.12.y (`git log --grep`: only 71af682ba4 hits).
  Not in stable-queue (stable-queue.git was not cloned: inference: nothing outside mainline is queued).
- Lines that would need it once in mainline: all stable lines containing the mesh code (6.1.y, 6.6.y, 6.12.y, 6.18.y,
  7.3.y by the dossiers; 6.6.y/6.1.y sources not read here), plus Ubuntu kernels built on them (noble 6.8 GA and
  linux-hwe-7.0; Launchpad not queried because nothing is delivered). Expect the landing at the 7.5 merge window through
  net-next unless Luiz also pushes it to the `bluetooth` fixes tree (not checked; only bluetooth-next was cloned).

## Cross-links
- CO-04, CO-05 1/2, CO-06, CO-14, M-4, M-5, Hui Peng's Tested-by and 14888791/14864878/14942650 are all one mesh
  transmit path, now settled by 1d7a52778858. CO-26 and CO-13 are the only mesh items left over.
- CO-12 and CO-38: the clamp is now Cen Zhang's d7e77168da; CO-38's "Add 128/128" needed CO-12's clamp, so after the clamp
  is in the tree CO-38's test series stands alone. The BlueZ test overlap with Weihong Guan's single-advertising-set tests
  (bluez 923d95d0c, 58e111cc9) concerns CO-38 and CO-12.
- The same sashiko.dev series 1215366 contains other patches next to ours: 09/17 "Reject zero multi advertising rotation
  duration" (adjacent to CO-12's duration, different field) and 04/17 hdev->lock in hci_schedule_adv_instance_sync.
- 14880941 (mgmt_cleanup walking mesh_pending unlocked) is the one mesh-adjacent defect not yet fixed by anyone; it is
  where 1d7a's "requires hdev->lock" comment and the code disagree.

## Corrections to the readiness report or the register
- Report/STATUS say Cen Zhang's series 1215537 v2 is `new`: patchwork says `new`, but both patches are already applied in
  bluetooth-next (d7e77168da, a7d2c94ba2, 2026-11-19). Its 1/2 does NOT add the mesh_send_sync lock (1d7a already had); the
  duration clamp in it makes CO-12 redundant, not merely "conflicting".
- Report: "1d7a covers CO-04, CO-05 1/2, CO-14 and CO-06": confirmed per the table, with the exceptions: CO-26 (2/2) is NOT
  covered; the M-5 half of CO-14 is covered only by inference (-ECANCELED early return); CO-13 untouched; mgmt_cleanup()
  still unlocked (14880941 not applied). Add: 1d7a has Fixes: but no Cc: stable, and no syzbot tag.
- Register row CO-04/CO-05 "to make" send packages and CO-12 "send the clamp": all three are void; CO-06, CO-14 closed as above.
- STATUS l.61 says the Tested-by row is "submitted"; confirmed against patchwork (comment 2026-10-06T20:18).
- STATUS says 14927631 `new`: now `superseded` (replaced by 14999296).
- Not checked anywhere: lore.kernel.org (403), syzkaller.appspot.com (429), stable-queue.git (not cloned), linux-6.6.y and
  linux-6.1.y in stable.git (fetch unfinished), Launchpad, bluetooth tree (fixes branch).

---

# Part: kernel-btusb-stable

## Upstream check, 2026-11-22: CO-43 and the btusb/stable items

Abbreviations. PW = patchwork.kernel.org API 1.3 (`/patches/?project=<p>&q=<subject words>&order=-date&since=...`, `/patches/<id>/`, `/patches/<id>/comments/`).
BN = local bluetooth-next.git, tip `cf357cfc02` (2026-11-20). ML = local mainline.git, tip `4843f6873f` (2026-11-21, = v7.4-rc3-921).
SG = local stable.git, branches linux-7.3.y / 6.18.y / 6.12.y / 6.6.y / 6.1.y. SQ = local stable-queue.git, HEAD `9d73296208` (2026-11-22 09:08 -0500).
Stable-tree history in SG starts 2026-09-15 and PW has no "stable" project, so the stable@ list itself was not readable (lore.kernel.org answers 403, www.mail-archive.com search has no recent linux-bluetooth/stable mail).

## Current stable versions (https://www.kernel.org/releases.json, read 2026-11-22)

| line | version | released |
|---|---|---|
| mainline | 7.4-rc3 | 2026-11-15 |
| stable | 7.3.5 | 2026-11-17 |
| stable (EOL) | 7.2.15 | 2026-11-01 |
| longterm | 6.18.64 | 2026-11-17 |
| longterm | 6.12.118 | 2026-11-17 |
| longterm | 6.6.162, 6.1.192, 5.15.225, 5.10.274 | 2026-11-06 (unchanged since the 11-14 refresh) |

The 11-14 refreshes used 7.3.4, 6.18.63, 6.12.117. All three have moved (11-17). Any "tips of 11-14" statement in the send packages is stale for those three lines; 6.6/6.1/5.15/5.10 are the same.

---

### CO-43 E — Anchor a deferred URB under txlock (BT-23)
- ours: `submit_or_queue_tx_urb()` in `btusb_main.c` tests `BTUSB_SUSPENDING` under `txlock`, drops the lock, then `usb_anchor_urb(urb, &data->deferred)`; a resume completing in between parks the URB on an awake device. Fix: anchor inside the same txlock section. `send-20261113/E/`, register: ready, not sent, goes first.
- upstream now: nothing found. BN `drivers/bluetooth/btusb_main.c` at `cf357cfc02` still has the unlocked anchor (`git -C bluetooth-next.git show master:drivers/bluetooth/btusb_main.c`, function at line 2388: lock, `suspending = test_bit(...)`, unlock, then `usb_anchor_urb(urb, &data->deferred); schedule_work(&data->waker);`). `git log` of btusb_main.c/btusb.c/btusb.h in BN and ML since 2026-10-14 shows no change in the tx or resume code (only 868c886f45 "fix use-after-free in force_poll_sync", 2026-11-05, YuanZhe Liu, which touches debugfs poll_sync). PW bluetooth queries since 2026-10-15, each 0 hits except as listed in the cross-search below: `txlock`, `anchor`, `autopm`, `waker`, `btusb_reset`, `btusb_close`, `tx timeout`, `URB`, `urb`, `autosuspend`, `wakeup`, `remote wakeup`, `command timeout`.
- reports and links: BT-17 (origin). Sean Rhodes' "btusb: clear remote wake on idle Intel ACPI paths" (PW 14729774, 2026-08-04, state new; earlier 14482511 and 14572021) and "restore powered-off Intel adapters" (PW 14826990, 2026-09-17, new): not updated since 10-15; per the repo's prior-art note they keep the window. Not re-read in full here.
- objection to the upstream fix: n/a (no upstream fix).
- delivered where: nowhere. Defect is in BN, ML and every stable line (the register says `Fixes: 7bee549e197c`; that commit is not in the local clones, not verified here).
- backport: stable form will differ by file name: SQ `queue-7.3/bluetooth-btusb-build-the-driver-from-multiple-sourc.patch` (Zijun Hu, `be58267a34`, "Build the driver from multiple source files") is queued for 7.3.y, so 7.3.y will have `btusb_main.c`; 6.18.y and older still have `btusb.c`. A `Cc: stable` series will need a `btusb.c` form for 6.18 and older.
- apply check, done now: E applies to BN `cf357cfc02` `btusb_main.c` with `patch -p1` without offset; A (after E) offset 5; BT-24/25 pair (after E, A) offsets 5. (Run in a scratch copy: `up/extra-kernel-btusb/t`.)
- verdict: STILL OURS TO SEND
- proposed register text: "Ready, not sent. Rechecked 2026-11-22: bluetooth-next `cf357cfc02` still anchors outside txlock; nobody else posted a fix; applies cleanly to the current tip. 7.3.y will carry btusb_main.c (queued file split), so the stable form needs btusb.c for 6.18 and older."
- not checked: lore.kernel.org (403).

### CO-43 A — Report a failed runtime resume for deferred data (BT-20)
- ours: `btusb_waker()` calls `usb_autopm_get_interface()` and on error returns silently; fix logs the failure. `send-20261113/A-review-fixes-20261114/`.
- upstream now: nothing found. BN `btusb_waker()` unchanged (`err = usb_autopm_get_interface(); if (err < 0) return;`). Same PW queries as E: no hit.
- reports and links: BT-17/BT-19/BT-23/BT-24/BT-25 same series.
- objection: n/a.
- delivered where: nowhere.
- backport: none planned (log-only change, not a stable candidate on its own).
- verdict: STILL OURS TO SEND
- proposed register text: "Ready, after E. Rechecked 2026-11-22: unchanged in bluetooth-next `cf357cfc02`, no competing patch; applies to the tip after E with an offset of 5 lines."

### CO-43 BT-24/BT-25 pair — deferred URBs after a failed resume or a close
- ours: failed-resume path scuttles `deferred` outside txlock (BT-24); four discard sites (`btusb_close()`, `play_deferred()`, failed resume) free neither skb nor setup packet (BT-25). `send-bt24-bt25-20261114/` (cover + two patches on E).
- upstream now: nothing found. BN history for `usb_scuttle_anchored_urbs` in btusb files since 2026-08-01: no btusb commit (only an unrelated merge). PW queries as for E: no hit.
- reports and links: none public.
- objection: n/a.
- delivered where: nowhere.
- backport: as E (file name).
- verdict: STILL OURS TO SEND
- proposed register text: "Ready, after E. Rechecked 2026-11-22: nobody else touches the deferred anchor; both patches apply on E + A at the current bluetooth-next tip (offset 5)."

### CO-43 B2 (BT-19) and D v2 (BT-18), held; and Jens Willmer's PW 14973994
- ours: B2 = "Don't wait for a resume in the HCI command timeout" (btusb_reset moved to a work item, skip when a command is still deferred); D v2 = btusb `reset_resume` that queues a USB reset only in a runtime resume. Both held (`send-series-20261114/HELD.md`).
- Jens Willmer's patch, read in full: PW 14973994, "Bluetooth: btusb: Wait for setup to finish before system sleep", 2026-11-11 22:18, state new, series 1208822, `Fixes: 04b8c8143d46`, `Cc: stable`. What it does: registers a per-device PM notifier (`pm_notifier` member at the end of `struct btusb_data`; `btusb_pm_notifier()` before `btusb_probe()`; `register_pm_notifier()` before `hci_register_dev()`; `unregister_pm_notifier()` before `hci_unregister_dev()` in `btusb_disconnect()`) and calls `flush_work(&hdev->power_on)` on PM_SUSPEND_PREPARE / HIBERNATION_PREPARE / RESTORE_PREPARE, so a Realtek firmware download in `hci_power_on()` finishes before the next system suspend (RTL8852CU 0bda:0852; the suspend kills the download, then every command times out and the device is "reset and probed in a loop"). The patch text discloses AI assistance. It touches `btusb_probe`, `btusb_disconnect`, the struct and a new function only; it does not touch `btusb_reset()`, `btusb_waker()`, `btusb_close()`, `play_deferred()`, `submit_or_queue_tx_urb()`, `btusb_resume()`.
  - Review state: CI bot 2026-11-12: all PASS except GitLint (trailing whitespace in the notes). Luiz von Dentz 2026-11-12 relayed Sashiko findings (possible dev->mutex cycle through `btusb_mtk_claim_iso_intf()`; a pre-existing UAF in `btusb_bcm_set_diag()`). Jens answered 11-12 22:35: calls the first a false positive, offers a v2 that drops the btusb notifier and does `flush_work(&hdev->power_on)` in `hci_suspend_notifier()` in hci_core instead; asked which Luiz prefers. No answer visible in PW comments as of 11-22 (2 comments + the bot). No v2 on PW (`q=Wait for setup`, bluetooth, since 11-11: only this patch).
  - What it does to our series, tested with `patch --dry-run` and `git apply --check` on BN `cf357cfc02` `btusb_main.c`:
    - E, A and the BT-24/BT-25 pair: no textual or semantic overlap. Jens' diff applies on the tip, on tip + E + A and on tip + E + A + pair (offsets 10 to 30 lines only).
    - B2: conflicts textually. `git apply --check` of B2 (send-series patch 0002) on tip + E + A + Jens fails: "patch failed: btusb_main.c:1092" (the tail of `struct btusb_data`, where both add a member, and the `btusb_disconnect` hunk: both insert next to `hci_unregister_dev()`). `patch -p1` accepts it with fuzz 1 in two hunks, so it is context only, a trivial rebase. The reverse (Jens on tip + E + A + B2) also fails with `git apply` (line 1090) and applies with fuzz 1.
    - Semantics: different defect (system suspend vs Realtek setup in flight) from BT-19 (HCI command timeout while a runtime resume is failing). Nothing in it fixes or removes B2's need. Its description does say a Realtek reset-resume reprobe is the intended design, which agrees with the prior-art finding that btusb relies on `needs_binding`/absence of `reset_resume` (relevant to D v2's blocker). If Jens moves the flush to hci_core (his v2 offer), the conflict with B2 disappears.
- other upstream, any author, btusb suspend/resume/reset/anchor/txlock/waker/usb_autopm, since 2026-10-15 (BN git log of `drivers/bluetooth/btusb*`, `btmtk*`, `btqca*`; PW bluetooth and linux-usb queries): 
  - PW 14998567 (Leon Romanovsky, v3 02/31 of a 31-patch driver-core series, 2026-11-18, new): "Bluetooth: btusb: Fix MediaTek ISO claim locking": adds `usb_autopm_get_interface()` around `btusb_mtk_claim_iso_intf()`/`btusb_mtk_setup()`; MediaTek-only; applies to tip + E + A + pair at offset 32; no overlap.
  - PW 14989055 (Selvarasu Ganesan, 2026-11-16, new, `Cc: stable`) "usb: core: don't skip system resume for an already suspended device" (`usb_resume_both()`, offload case); USB core, adjacent to BT-18's question but about USB audio offload.
  - PW 14956832 (Cunhao Lu, 2026-11-06, new) "usb: core: hcd: Skip PHY rollback on failed autoresume": hcd_bus_resume failure path; not btusb.
  - PW 15006420 / 15001035 (Piotr Kubik, 2026-11-19/20): "USB: cdc-acm: restore the line coding after a reset-resume": another driver adding reset-resume handling; no relation to btusb.
  - PW 14966463 (Pengfei Lv, v4, 2026-11-10, new) "usb: core: hub: Re-guess ep0 maxpacket size after reset" (v1 14944086 11-04): USB core reset path for full-speed devices; adjacent to the BT-17 log (full-speed device failing after reset); see CO-45.
  - PW 14972223 / 14960686 (Andre Eikmeyer, hci_bcm4377 "probe again after a resume through firmware") and PW 14896689 (Daniel Golle, btintel_pcie `device_schedule_reprobe()`): other drivers solving "re-probe after resume" by driver-side reprobe; different drivers.
  - PW 14912288 (Cen Zhang, accepted 10-24): vhci "Flush suspend work after removing debugfs" (affects the vhci emulation, not btusb).
  - BN btusb commits since 10-14: only 868c886f45 (force_poll_sync UAF). The rest of the list from `git log --since=2026-10-14` is the 7.4 merge-window material dated 10-14 or earlier.
  - PW linux-usb queries since 2026-10-15/09-15: `btusb` (0 USB-core hits), `reset-resume` (only cdc-acm), `needs_binding` (0), `rebind` (only raw-gadget), `resume`. Nothing on runtime reset-resume rebind (BT-18).
- reports and links: kernel bugzilla Drivers/Bluetooth changed since 10-15 (REST `component=Bluetooth&product=Drivers&last_change_time=2026-10-15`, 15 bugs): none about btusb runtime resume of a QCA device. 210141 (RTL8821CE lost after S3, 2026-11-08 comment: root cause BIOS BT_EN pad, not btusb); Launchpad `linux` task search "btusb resume" finds #2171816 (same HP 15s RTL8821CE case). Not our defect.
- objection: n/a.
- delivered where: nowhere.
- verdict: B2: OVERLAP (Jens' 14973994 conflicts at context level; trivially rebasable; different bug). D v2: STILL OURS (held for its own blocker; no one else is on BT-18).
- proposed register text (B2/D v2): "Held (D v2 breaks needs_binding; B2 needs D). 2026-11-22: Jens Willmer's 14973994 (PM notifier, Realtek setup flush at system sleep) is a different bug but its struct/disconnect hunks collide with B2 (git apply fails, patch -p1 fuzz 1); rebase B2 over it if it merges, or after his v2 if he moves the flush to hci_core. Linux-usb question still unsent; no related thread on linux-usb since 09-15."
- not checked: lore.kernel.org (403), syzkaller (429).

### BT-17 — Ryzen remote-wakeup condition (`dcaf83ead130`) and CO-43 C
- ours: BT-17 H3: the condition behind `dcaf83ead130` is not MediaTek-specific; CO-43 C (RFC, local) sets `BTUSB_WAKEUP_BROKEN` for 13d3:3503 on a Ryzen direct-root-hub child.
- upstream now: confirmed. `dcaf83ead1` Rong Zhang, 2026-09-08, "Bluetooth: Properly disable remote wakeup for MT7922/MT7925 on Ryzen platform", Tested-by Rafael Passos, Fixes `e31d761628ad`; `git describe --contains` in ML: v7.3-rc3~35^2~33^2~10, so v7.3-rc3. Its message limits the quirk to MT7922/MT7925 as direct children of a Ryzen platform root hub, and says other NICs may need it ("While there is still a chance that the quirk may exist on other platforms..."). Diffstat: `btmtk.c` and `btusb.c`. It is in SG linux-7.3.y (`BTUSB_WAKEUP_BROKEN` found in btusb.c); not found in 6.18.y by grep; not in any queue (`git grep -il 'remote wakeup for MT7922\|dcaf83ead130'` in SQ: none).
- reports and links: no new thread about extending it to other IDs (PW q=`remote wakeup`, `wakeup` since 10-15: 0).
- objection: n/a.
- verdict: STILL OURS TO SEND for C only as a local RFC (unchanged: one occurrence); nothing competing. 
- proposed register text: "Condition confirmed in mainline `dcaf83ead130` (v7.3-rc3, MT7922/MT7925 only, also in 7.3.y); no later patch extends it. C stays local until a recurrence with USB core debug."

### CO-45 / BT-22 — xHCI "Fix ep0 maxpacket update on enabled slots"
- ours: not ours; the laptop's BT-17 log shows `invalid context state for evaluate context command` followed by Address Device Parameter Error.
- upstream now: PW linux-usb 14964105, Michal Pecio, "usb: xhci: Fix ep0 maxpacket update on enabled slots", 2026-11-09 10:28 UTC, state `new` (linux-usb states are not maintained); Mathias Nyman replied 2026-11-09 14:57 "Added to queue" (PW comment 27352888). Diff: 5 lines in `xhci_check_ep0_maxpacket()` (`drivers/usb/host/xhci.c`): return 0 if `GET_SLOT_STATE(...dev_state) == SLOT_STATE_ENABLED`. `Fixes: e34900f46cd6` and `af8e119f52e9`, no `Cc: stable` tag in the patch text read from PW. Sashiko: "no issues".
  - Not in mainline at ML tip `4843f6873f` (2026-11-21): `git log` of `drivers/usb/host/xhci.c`, `xhci-ring.c`, `drivers/usb/core/` since 2026-11-05 shows nothing after 3149e8b323 / d1ec1859f3 / 2f2fe32010 (all 11-05); `git log --grep='ep0'` since 11-09: none.
  - Not in Greg's trees as of 2026-11-20: fetched `usb-linus` (`b0baaf6cbb`), `usb-next` and `usb-testing` (`8e31dedb9a`) from git.kernel.org gregkh/usb.git: `git log -S'SLOT_STATE_ENABLED' -- drivers/usb/host/xhci.c` empty on all three. So "queued" means Mathias' own queue, not yet sent to Greg.
  - Not in any stable queue: SQ `git grep -il 'ep0 maxpacket'` only finds `usb-gadget-dummy_hcd-fix-superspeed-ep0-maxpacket.patch` (a different fix, in all queues); no xhci ep0 file.
  - Adjacent: PW 14966463 (Pengfei Lv, v4, 2026-11-10, new): "usb: core: hub: Re-guess ep0 maxpacket size after reset" (USB core, full-speed devices after reset); different layer, same symptom family.
- reports and links: patch text cites a Sashiko-found bug and an ASMedia hang; no bugzilla entry found for this exact warning (bugzilla REST Bluetooth component list above; USB component not searched).
- objection to the upstream fix: none from the diff. It covers the sequence in the laptop log (slot left Enabled after an Address Device error, then a corrupted input context). Per the register it did not cause the loss; it made the retries fail messier.
- delivered where: nowhere. Not in mainline (7.4-rc3-921), not in 7.3.5/6.18.64/6.12.118/6.6.162/6.1.192, not in any queue. Ubuntu: absent from the changelogs of `linux-hwe-7.0` 7.0.0-42, -43 and -44 (grep `maxpacket`/`ep0`: only "usb: core: clear both ep_in and ep_out for non-ep0 control endpoints"); the two regression commits are not named in those changelogs either (grep for "Reconfigure endpoint 0" / "Panther point": 0). Not checked: whether Ubuntu's 7.0 tree has `e34900f46cd6` (the register says v7.0 has the code).
- backport: not applicable until it is in mainline. Then: it carries Fixes tags and may be auto-selected; a request is the maintainers' choice. Homework: none.
- verdict: FIXED UPSTREAM BY OTHERS (queued by the xHCI maintainer, not yet in mainline or stable; ours not needed)
- proposed register text: "Queued by Mathias Nyman 2026-11-09 (PW 14964105); not yet in mainline (7.4-rc3-921), Greg's usb-linus/usb-next (11-20), any stable queue, or Ubuntu linux-hwe-7.0 7.0.0-44. Watch for the mainline commit id; then check the stable queues."
- not checked: git.kernel.org xhci queue tree of Mathias Nyman (not named; only Greg's trees checked).

### CO-35 / BT-10 — L2CAP ECRED deferred-accept hang: 32d86e048d8e + 608e0b7a675b
- ours: `l2cap_sock_recvmsg()` holds the socket lock, then `l2cap_sock_teardown_cb()` via `__l2cap_ecred_conn_rsp_defer()` waits for it; Pauli Virtanen's `608e0b7a675b` ("L2CAP: add l2cap_chan_close_unlocked() and locking helpers") + `32d86e048d8e` ("hold conn->lock for __l2cap_ecred_conn_rsp_defer"). Ours: hand backports for 6.18.y/6.12.y/6.6.y, full or reduced prerequisite; package `review-fixes-20261114/`.
- upstream now (SQ HEAD 2026-11-22):
  - queue-7.3 has, in this series order: `l2cap-avoid-maybe-return-locked`, `add-locking-annotations`, `take-chan-lock-for-l2cap_chan_add-re` (385c0829e0), `add-l2cap_chan_close_unlocked-and-lo` (608e0b7a67), `fix-race-condition-in-l2cap_sock_shu` (79ff49a72c), `6lowpan-use-l2cap_chan_close_unlocked`, `6lowpan-avoid-concurrent-peer_del`, `hold-conn-lock-for-__l2cap_ecred_con` (32d86e048d). The `32d86e048d` file header: "From: Sasha Levin", "[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]" (selected by the stable team, not Cc: stable). `git log -S'hold-conn-lock-for' -- queue-7.3/series`: added `80c4c0bba3` 2026-11-17 08:39 -0500 ("Fixes for all trees"), removed `bc3c70fb4c` 2026-11-19 ("drop 77 patches based on RC review feedback"), re-added `3dd4b2d3c1` 2026-11-20. It is in the queue now; it was out of it for one day.
  - queue-6.18, queue-6.12, queue-6.6 contain only two of the L2CAP patches: `take chan->lock for l2cap_chan_add/ready/del` (385c0829e0) and `hold chan in l2cap_ecred_conn_rsp()` (b508a2a2d8), both added 11-17. They do not contain 608e0b7a67 or 32d86e048d (queue-6.18 series: lines 1519-1521 only). queue-6.1 has only `hold-chan-in-l2cap_ecred_conn_rsp`. (`git ls-tree HEAD queue-6.x/ | grep l2cap`; `git grep -l 32d86e048d8e HEAD -- 'queue-*'` finds only queue-7.3.)
  - Not in any released stable tree: `git log <branch> --grep='32d86e048d8e\|608e0b7a675b'` empty on 7.3.y (7.3.5), 6.18.y (6.18.64), 6.12.y (6.12.118), 6.6.y and 6.1.y.
  - BT-15's `5874f8d03268` ("Fix the LE Read Connection Interval response layout", Luiz von Dentz, mainline v7.4-rc1~136^2~116^2~1) is in queue-7.3 (added 11-17 08:39 -0500, after 7.3.5's 11:14 +0100 release tag, so not in 7.3.5: SG 7.3.y `include/net/bluetooth/hci.h` still has the old `struct hci_rp_le_read_conn_interval` without the minimum-interval octet).
- who has posted backports for 6.18.y/6.12.y/6.6.y/6.1.y: no one found. PW bluetooth queries since 2026-09-01: `ecred_conn_rsp_defer`, `hold conn->lock`, `l2cap_chan_close_unlocked`, `locking helpers`, `6.18.y`, `Ext-Flowctl`: 0 hits; `6.12.y` finds only Ghidoli's getsockopt_iter (14907537) and our BT-9 backport (14878736); `6.6.y` only Dinaburg's eir/hci_core patches (14893328-14893334); no `[6.x.y]` L2CAP posting. Not checked: the stable@vger list itself (lore 403).
- reports and links: Pauli's accepted series PW 14782633 ([1/4] "take lock for l2cap_chan_del in l2cap_ecred_rsp_defer", 2026-09-01, accepted, BN `dc1ddc65f0`; patches 2-4 of series 1155667: annotate locking, `refuse __l2cap_chan_add if chan already has conn`) is the same series family as 385c0829e0/608e0b7a67. Adjacent, not competing: Kyle Pepper's PW 14982368 ([v12,2/2] "Keep credits from completing security upgrades", 2026-11-14, new; its text includes "Send an ECRED response before releasing accepted children's data ... close every deleted child") and tester patch PW 14974654 ("[RFC] l2cap-tester: Check deferred ECRED batch rejection", 2026-11-12, edits the same `ext_flowctl_accept_2_close_1` listen callback our reproducer uses); Luiz's PW 15006062/15006063 ([v3 1/2, 2/2] security of deferred BR/EDR channels, 2026-11-20, touch `l2cap_sock_defer_cb`) and PW 14998992 (Alquraini). None fixes our hang. Kernel bugzilla: nothing for this case.
- objection to the upstream fix: none (it is the fix; hang gone with the pair on 7.3.4, 6.18.63, 6.12.117, 6.6.162 per register).
- delivered where: mainline v7.4-rc1 (BN `32d86e048d`, `608e0b7a67` dated 2026-10-14). Stable: queue-7.3 only, not yet released; 6.18/6.12/6.6/6.1 none.
- backport: candidate for 6.18.y, 6.12.y, 6.6.y (6.1.y and older: only with ECRED enabled; not covered). New since the readiness report's "queued for 7.3": the stable team queued two of the prerequisite patches for 6.18/6.12/6.6 (385c0829e0, b508a2a2d8) on 11-17. Our backports (and the "reduced prerequisite", which was built against trees without 385c0829e0) must be re-applied on 6.18.64, 6.12.118, 6.6.162 plus those two queued patches (`quilt` order in SQ) before any send; the series context in `l2cap_core.c` changes. The 7.3.y request mails are superseded (queue-7.3 has the chain). Also check: the queue could take the pair for older lines on its own, as it did for 7.3 (inference).
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE (7.3.y: queued by the stable team; 6.18/6.12/6.6: ours, re-base needed; nobody else posted)
- proposed register text: "7.3.y: all of the chain, 32d86e048d + 608e0b7a67 + 5874f8d03268, queued by Sasha Levin (11-17, briefly dropped 11-19, back 11-20), not released as of 7.3.5. 6.18/6.12/6.6 queues hold only 385c0829e0 and b508a2a2d8 since 11-17; no one posted a backport of the pair. Next: rebase the three backports onto 6.18.64/6.12.118/6.6.162 + the queued prerequisites, rerun l2cap-tester, then the operator's send."

### BT-14 — 6.12.y `getsockopt_iter` (5bd0dec150f56)
- ours: not ours (Emanuele Ghidoli's backport, PW 14907537, 2026-10-22, "Queued for 6.12" by Sasha Levin 10-23 per register).
- upstream now: released. SG `4b26b1d3a9` "net: call getsockopt_iter if available" (Breno Leitao, 2026-10-30, "commit 5bd0dec150f56b6307d599132dcb7c01007bbecc upstream"); `git describe --contains` = v6.12.115~114; `v6.12.115` tagged 2026-10-30, `v6.12.114` 2026-10-21. So released in 6.12.115, current 6.12.118 has it. 6.6.y/6.18.y: not applicable (no `getsockopt_iter` dispatch, unchanged from the register).
- reports and links: kernel bugzilla 222177 (2026-10-21, NEW, Drivers/Bluetooth): "Bluetooth AX201 device does not work on Debian 13 on Kernel 6.12.114, works on 6.12.113"; a 2026-10-30 comment says rebuilding with `5bd0dec150f5` fixes it (Thinkpad E15 Gen2). The bug is still NEW; it is the public report of BT-14.
- verdict: ALREADY RELEASED AND DELIVERED (6.12.115)
- proposed register text: "Released in 6.12.115 (2026-10-30; stable commit 4b26b1d3a9); STATUS 'watch' can close. Public report: bugzilla 222177 (reporter says the patch fixes it)."

### BT-15 — 5874f8d03268 in 7.3.y?
- upstream now: not released. In SQ queue-7.3 (added 2026-11-17 08:39 -0500, still there at 11-22); 7.3.5 (released 2026-11-17 11:14 +0100) does not have it (SG linux-7.3.y `hci.h` struct without the extra octet; `git log linux-7.3.y --grep='5874f8d03268'` empty). Mainline: v7.4-rc1.
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE only in the sense "queued, due with the next 7.3.y release (7.3.6, inference)"; nothing for us to send.
- proposed register text: "Queued for 7.3.y on 11-17 (after 7.3.5); expect it in 7.3.6. Nothing to send."

### BT-11 — ISO use-after-free (Ubuntu -38) and the 6.12.y iso-tester stall
- ours: KASAN `iso_conn_hold_unless_zero` UAF on Ubuntu 7.0.0-38; resolved by `-42` per register; 6.12.114 iso-tester showed four timeouts, a lockdep "possible recursive locking" and a stall, not analysed.
- upstream now: BN `net/bluetooth/iso.c` log since 2026-09-01 shows ISO fixes up to 11-11 (`b4a00dedc5` "Hold the listener during disconnect notification" 10-14, `e32d80293a` "Serialize concurrent connect calls" 10-05, `555ff78fa7` "Reject concurrent BIS listener setup" 10-05, `0fcd4dad55`, `296e7f3c50`, `ca18ee413a`) and HDT feature patches. PW bluetooth queries `iso_conn`, `ISO: `, `use-after-free` since 10-20: no patch for a use-after-free of `iso_conn` at socket release / aborted CIS other than the 6.1.y backport PW 14932529 (Andrey Misiurov, 2026-11-02, new, "drop unbalanced sock_put() in iso_conn_ready()"; SQ queue-6.1 has `bluetooth-iso-drop-unbalanced-sock_put-in-iso_conn_r.patch`). queue-6.12/queue-6.6/queue-6.1/queue-7.3 each have `bluetooth-iso-hold-the-listener-during-disconnect-no.patch`; queue-6.6 also `iso-release-unused-cis-holds-after-channel`.
  - The three Ubuntu commit ids in docs/issues.md (`0786469ee2429`, `aa9f7cb2bd3a2`, `fdfde532ab1ca`) are not mainline ids (not found in ML); in SG the only hit is a message mention in 6.12.y `42c8bd6ac8` (v6.12.113~485, "ISO: Fix data-race on iso_pi(sk) in socket and HCI event paths"). I could not map them to titles.
- reports and links: none public found (Launchpad `linux` task search "QCA9377 bluetooth": two unrelated bugs).
- delivered where: Ubuntu `linux-hwe-7.0` 7.0.0-42 per register (not re-verified here).
- verdict: CANNOT TELL for the 6.12.y stall (no analysis, nothing upstream matching); the Ubuntu UAF: ALREADY RELEASED AND DELIVERED per register.
- proposed register text: "No upstream report or patch found for the 6.12.y iso-tester stall (2026-11-22); not analysed; reopen only if it reproduces on 6.12.118. Ubuntu UAF resolved by -42."

### CO-22 — two ASUS QCA ROME IDs for stable (0b05:1868 `d54601f21faf`, 0b05:1825 `cfa67a1dbfd9`)
- ours: stable backport request v3 (`research-2026-11-01/qca-ids/refresh-20261114/`), plus the owners' call v2.
- upstream now: mainline: `d54601f21f` Quentin Strydom "btusb: add ASUS 0b05:1868 to QCA Rome quirks" and `cfa67a1dbf` Konstantin Nazarov "... 0b05:1825 ...", both author-dated 2026-09-28 / 10-01, in v7.4-rc1 (`git describe --contains`: v7.4-rc1~136^2~116^2~47 and ~37); neither carries a `Cc: stable` or `Fixes:` line (`git show | grep`). SG `git grep '0x0b05, 0x1868\|0x0b05, 0x1825'` on btusb.c: nothing on 7.3.y (7.3.5), 6.18.y (6.18.64), 6.12.y (6.12.118), 6.6.y (6.6.162), 6.1.y (6.1.192). SQ: `git grep -il 'qca rome\|0b05:18\|d54601f21faf\|cfa67a1dbfd9'` in all queue-* and staging-*: none (includes queue-5.15, queue-5.10). 5.15.225 and 5.10.274 releases were not inspected in a tree (SG has no 5.x branch); queues are clean. Nobody else has requested a backport: PW bluetooth `ASUS`/`Rome` queries find no `[x.y.y]` posting.
  - 0cf3:e303 (Daan Bouwman, Surface Laptop 3 AMD): PW 14976888, 2026-11-12, state new; CI 11-12 CheckPatch FAIL, GitLint FAIL; no maintainer reply in PW. Still unmerged: BN btusb_main.c/btusb.c log has no such commit.
  - No other QCA ROME ID was added to btusb since: BN `git log --since=2026-10-14 -- drivers/bluetooth/btusb*` lists only the ASUS pair, Realtek/MediaTek/Intel IDs. Related pending QCA btusb patch: PW 14908088 (Paolo Abeni, 2026-10-22, new) "btusb: disable by default Qualcomm multi-subsystem" (QCC2072, not ROME).
  - Queue note: SQ queue-7.3 carries the btusb split (`be58267a34`), so on 7.3.y the table sits in `btusb.c` today (SG 7.3.5 has `btusb.c` with `0x13d3, 0x3503`) but will move to `btusb_main.c`; a cherry-pick of the ASUS commits (which are against `btusb_main.c`/`btusb.c` at 7.4-rc1) must be re-checked for the file name on 7.3.y after the next 7.3.y release.
- reports and links: none public beyond the commit messages (they report LE scan failures "unexpected event for opcode 0x2005").
- objection: n/a.
- delivered where: mainline 7.4-rc1 only.
- backport: candidate for 7.3.y to 5.10.y; unchanged. Homework: the v3 request says "tips of 11-14"; re-run the queue and tip check on the send day (7.3.5, 6.18.64, 6.12.118 are new). 6.6.y W=1 btmtk.h failure is known.
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE
- proposed register text: "Both ASUS entries still in mainline (v7.4-rc1) only; rechecked 2026-11-22 on 7.3.5, 6.18.64, 6.12.118, 6.6.162, 6.1.192 and all queues incl. 5.15/5.10: absent, no one else requested them. Refresh the mail's dates (new tips) before sending; 0cf3:e303 (PW 14976888) is still unmerged with CI failures."

### CO-25 / BT-1 — report to Qualcomm on the QCA9377 ROM firmware (sent 2026-10-29)
- ours: [REPORT] mail 2026-10-29 to linux-bluetooth + maintainers + Zijun Hu et al; Zijun Hu replied 10-29 "not ROME, btusb does not support it"; our clarifying reply v4 drafted, not sent.
- upstream now: nothing new found, with the limit that no list archive was readable. PW bluetooth searches since 2026-10-20 (patches only; a [REPORT] mail is not a patch): `QCA9377`, `qca_devices_table`: 0 hits; `QCA Rome` / `ROME`: only PW 14976888 (Surface 0cf3:e303); `WCN`, `QCA`: only hci_qca/btqca UART-SoC patches (WCN3950/WCN3990/QCA2066/WCN3988) by Michael McAllister, Shuai Zhang, Hex Lindqvist, Stanislavs Nilovs, Joas Antonio; Zijun Hu's PW 14992927 ([GIT PULL v2] Update QCC2072 and WCN685x 2.0 firmware, 2026-11-17, new). BN git log of `btusb*`, `btqca*` since 10-14: no change to `qca_devices_table` or `btusb_setup_qca()` for QCA9377; `dc16388d45ec` ("Add IMC Networks QCA9377 to quirks table", Tibor Harcsa) is in stable as shown for CO-09. Kernel bugzilla REST (Drivers/Bluetooth, changed since 10-15): no QCA9377 / ROM firmware entry. Launchpad `linux` searchTasks "QCA9377 bluetooth", "13d3:3503": no related bug. Web search of the subject: nothing indexed.
- reports and links: none.
- objection: n/a.
- verdict: CANNOT TELL whether anyone has replied on the list since Zijun Hu's 10-29 mail (thread not readable); nothing new in patchwork, bugzilla, bluetooth-next or Launchpad.
- proposed register text: "No reply other than Zijun Hu's of 10-29 could be found (patchwork, bugzilla, bluetooth-next, Launchpad checked 11-22; list archive not readable). No new QCA9377/qca_devices_table/ROME btusb patch has appeared. Reply v4 still unsent."
- not checked: lore.kernel.org thread (403), mail-archive (no recent coverage).

### CO-09 — dc16388d45ec in Ubuntu noble's HWE kernel
- ours: QCA9377 entry (Tibor Harcsa) in Ubuntu `linux-hwe-7.0`.
- upstream now: Launchpad API `getPublishedSources&source_name=linux-hwe-7.0&distro_series=.../noble&exact_match=true` (2026-11-22): `7.0.0-43.43~24.04.1` Published in Updates (2026-11-11 21:12 UTC) and in Security (2026-11-12 02:04 UTC); `7.0.0-44.44~24.04.1` Published in Proposed (2026-11-20 05:27 UTC); `-42.42~24.04.1` Superseded (Updates 2026-10-28, Security 2026-11-02). Changelogs (`changelogs.ubuntu.com/changelogs/pool/main/l/linux-hwe-7.0/linux-hwe-7.0_<ver>/changelog`): `-43` has "Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table" inside the "Upstream stable to v6.18.56, v7.2.10" patchset (changelog line 415); `-44` has it (line 809); `-42` has no QCA9377 line (grep: 0). So the first published version with it is 7.0.0-43.43~24.04.1; -42 and earlier lack it.
- verdict: ALREADY RELEASED AND DELIVERED
- proposed register text: "Delivered: linux-hwe-7.0 7.0.0-43.43~24.04.1 (noble-updates 2026-11-11, noble-security 2026-11-12; changelog confirms the commit; -42 lacks it); 7.0.0-44 (proposed 11-20) keeps it."

### CO-10 and CO-28 — Tested-by on stable reviews
- CO-10: stable.git: `v6.6.160` tagged 2026-10-21 (register: sent 10-21, released the same day). CO-28: `v6.1.191` tagged 2026-10-30; register: 5.15.224 and 5.10.273 released 10-30 (not re-inspected in a tree; releases.json now lists 5.15.225 and 5.10.274 from 11-06).
- verdict: ALREADY RELEASED AND DELIVERED (closed, nothing to send).
- proposed register text: unchanged ("closed, nothing sent").

### BT-9 backports (`96d006ae6445`)
- SG `git log <branch> --grep=96d006ae6445`: 6.12.y `9a328ae014` (2026-10-15; `git describe --contains` v6.12.113~153), 6.6.y `80861f424f` (2026-10-21; v6.6.160~1184), 6.1.y `dafb564a49` (2026-10-30; v6.1.191~1454). Each carries "Signed-off-by: Iaroslav Voitovych" after the author and Luiz von Dentz, before Sasha Levin. Tags: v6.12.113 2026-10-15, v6.6.160 2026-10-21, v6.1.191 2026-10-30. Confirmed. 7.3.y and 6.18.y have the fix in their code (`!test_bit(HCI_INQUIRY, ...)` in `le_set_scan_enable_complete()`, checked in both branches) without a matching message in the clone window.
- verdict: ALREADY RELEASED AND DELIVERED (6.12.113, 6.6.160, 6.1.191). 5.15/5.10 not part of BT-9.

---

## Cross-links
- E, A and BT-24/25 are three edits of the same btusb deferred-URB path (txlock anchor, waker, scuttle/discard) and share one origin (BT-17); B2/D v2 depend on E and A and on the linux-usb question.
- BT-17's log connects to CO-45/BT-22 (xHCI ep0 maxpacket, PW 14964105) and to Pengfei Lv's USB-core ep0 re-guess patch (PW 14966463): both address a full-speed device failing to re-enumerate after a reset.
- Jens Willmer's 14973994 touches `btusb_disconnect`/`struct btusb_data` like B2; it shares with D v2 the premise that btusb reprobes (`reset_resume`) after system sleep.
- CO-35/BT-10, BT-14 and BT-15 are all in the 6.12.y/7.3.y L2CAP stable pipeline: BT-14's missing dispatch (fixed in 6.12.115) made 6.12 l2cap-tester numbers meaningless until then; BT-15's stall in 7.3.y ends with `5874f8d03268` (queued), which CO-35's 7.3 runs also need. The same queue batch (11-17) put 385c0829e0 and b508a2a2d8 into 6.18/6.12/6.6 queues, changing the base of CO-35's backports.
- CO-22 / CO-25: CO-25's question about ROM-only IDs and CO-22's ID survey are the same line; 0cf3:e303 (PW 14976888) sits between them.
- CO-09 closes BT-1's Ubuntu side; the stable entry is the same `dc16388d45ec` as BT-1/CO-10/CO-28.
- BT-14 public report: bugzilla 222177.

## Corrections to the readiness report or the register
1. Readiness: "Jens Willmer's 14973994 conflicts with B2, not with E (11-15)". Confirmed, with detail: conflict is context-only (struct tail and `btusb_disconnect`), `git apply` fails, `patch` fuzz 1 passes; it is a different bug; E, A and the BT-24/25 pair are unaffected (clean). Jens offered a v2 moving the flush into hci_core (PW comment 27366922, 11-12), which would remove the conflict.
2. Readiness / register (CO-35): "queued for 7.3, not queued for 6.18/6.12/6.6" is incomplete: the queues for 6.18/6.12/6.6 got `385c0829e0` and `b508a2a2d8` on 11-17 (prerequisites of the pair), and the pair was dropped from queue-7.3 on 11-19 and put back on 11-20 (SQ `bc3c70fb4c`, `3dd4b2d3c1`). The register's CO-35 row ("still in no stable queue", 2026-11-14) is out of date; and the "tips of 11-14" for 7.3, 6.18, 6.12 changed on 11-17 (7.3.5, 6.18.64, 6.12.118).
3. STATUS BT-14 "watch": released in 6.12.115 (2026-10-30, `4b26b1d3a9`); also now has a public bugzilla entry (222177). (The readiness report already says this; STATUS still says "watch".)
4. Register CO-45: "queued upstream 2026-11-09" is true only for Mathias Nyman's own queue; as of 11-20 it is in none of usb-linus/usb-next/usb-testing and not in mainline `4843f6873f` (11-21).
5. Register CO-22: "in no stable branch" confirmed on today's tips; the request text's "checked 2026-11-14" must be redone (7.3.5, 6.18.64, 6.12.118 are newer). The 7.3.y btusb file split (queued `be58267a34`) changes the file name the stable form targets.
6. docs/issues.md BT-11 lists `0786469ee2429`, `aa9f7cb2bd3a2`, `fdfde532ab1ca` as "Pauli Virtanen's ISO fixes"; none of the three ids exist in the local mainline clone (history since 2026-08), so they are probably Ubuntu-tree ids or older mainline ids: the table needs titles to be checkable.
7. CO-43 packages: the E/A/pair patches still apply to the tip (`cf357cfc02`, 11-20) with small offsets; the register can say "applies on bluetooth-next 2026-11-20".

---

# Part: bluez

## BlueZ contributions against upstream, 2026-11-22

Sources: bluez.git clone (master `1adfe662e`, 2026-11-16, 103 commits after 5.88); patchwork project bluetooth, every patch since 2026-10-10 (1410 fetched, 282 BlueZ non-superseded); GitHub issue pages through the web-fetch tool (api.github.com not used).

Newest tag: **5.88, 2026-11-05** (`git tag --sort=-creatordate`; 5.87 was 2026-07-03). Master has 103 commits since.

Release table (`git tag --contains <commit>`, first tag):
| commit | subject | first release |
|---|---|---|
| a6ac17f0e393 | a2dp: Fix connection error message (CO-40) | 5.78 |
| a14d59725 | transport: don't disconnect A2DP if canceling Acquire() with Release() (U12) | 5.80 |
| fdbfe0018 | monitor: Fix crash due to negative max_len (btmon) | 5.80 |
| dca0f10fd | monitor: clamp max_len in print_packet (Chad Spensky, 2026-08-14, patchwork 14750981) | 5.88 |
| 7e3212fa233e | adapter: clear discovery_found list before discovery_cleanup() (U24) | 5.88 |
| 3e5b0da969c2 | ioctl-tester: Fix name of the 3-DH packet type test (CO-34, applied 2026-10-28) | 5.88 |
| 4f3428e9d, cad7a98e7 | Kevin Dewald, Discovering staying true after a rejected / failed stop (patchwork 14919283 accepted, 14919284 shows "new" but the commit is in 5.88) | 5.88 |
| a994cab0e | adapter: Don't return Busy when a pending change sets the same value (Luiz, 2026-10-29) | 5.88 |
| aa3d6c761 | adapter: Don't power on while blocked by rfkill (Tobias Wilken) | 5.88 |
| efabf8db4 | a2dp: Fix refusing the AVDTP connection of a new link (Luiz, 10-30) | 5.88 |
Not in 5.88 (master only): 70197a083 shared/timeout UAF (10-30), 43de1efcb avdtp connection_lost UAF (11-16).
None of our own pending BlueZ patches (CO-23, 37, 39, 41, 38 tests, 44 test, CO-02 sco test) is in any release; none has been applied.

### CO-23 / U22 — a2dp_reconfig() use-after-free
- ours: `a2dp_reconfig()` (profiles/audio/a2dp.c) writes `setup->reconfigure = TRUE` after `avdtp_close()`/`avdtp_abort()` freed the setup; fix = hold a reference across close/abort, free only if still pending; package `contributions/CO-23-one-off-events/patch/send-20261114/`; register: ready, not sent.
- upstream now: defect still present on master `1adfe662e` (`git show 1adfe662e:profiles/audio/a2dp.c`, a2dp_reconfig at l.2110-2190, `setup->reconfigure = TRUE;` after the avdtp_abort path). Patchwork queries (since 2026-10-01, project bluetooth): `a2dp_reconfig`, `a2dp reconfig`, `use-after-free a2dp`, `reconfigure`, `UAF` -> nothing about it. Adjacent, different defects in the same file: ef54133c6 "a2dp: Fix UAF after rejected SetConfiguration" and 79aedd33f "a2dp: Fix crash on NULL session in auto_config" (Eduardo Alves, 2026-10-01, in 5.88; the latter changes finalize_all()); 43de1efcb "avdtp: Fix use-after-free in connection_lost" (Jinwang Li, 11-16, patchwork 14987376 v4 accepted; reverse discovery, not reconfig); efabf8db4 (Luiz, 10-30).
- reports and links: GitHub issue #60 (2020, closed) "bluetoothd crashes when change a2dp codec" matches the text "a2dp_reconfig" but is a 2020 report (only its title read). No report of ours.
- objection: not applicable (nobody else fixed it).
- delivered where: nowhere; not in 5.88.
- backport: n/a. Apply check against master: 79aedd33f changed finalize_all() near our code, our package is rebased on 20ffd285b58f (after it), so it should be fine; re-run `git am` on 1adfe662e.
- verdict: STILL OURS TO SEND
- proposed register text: "Still unfixed on master 1adfe662e (2026-11-16) and in 5.88; no competing patch; adjacent a2dp/avdtp UAF fixes by others (79aedd33f, 43de1efcb) do not touch a2dp_reconfig(). Next: re-apply on master tip, send."
- not checked: lore.kernel.org (403), syzbot.

### CO-37 / U23, U24, U25, U26, U27 — media endpoint use-after-frees
- ours: U23 `media_endpoint_remove()` / `clear_endpoint()` / `path_free()` (profiles/audio/media.c) use freed endpoint/app at exit; series of 3 patches (+ duplicate Release fix); U25/U26/U27 not in series; package `CO-37-bluez-media-endpoint-exit-uaf/send-20261114/`.
- upstream now: master `path_free()` still frees `adapter->apps` (queue_destroy(app_free)) before `release_endpoint()` on endpoints (`git show 1adfe662e:profiles/audio/media.c`, path_free at l.3813); media.c commits since 10-01 are only hfp-hf (89b91a480, 8df2ed315) and 79aedd33f. No commits touch a2dp_remove_sep / a2dp_sep_unlock. Patchwork queries: `media endpoint`, `path_free`, `media_endpoint_remove`, `clear_endpoint`, `use-after-free media`, `endpoint` -> only BAP/HFP-HF endpoint patches (Luiz, Frédéric Danis), nothing on this. Bastien Nocera's RFC 14568134 (2026-05-12) is outside the window; not re-checked. U24: fixed by Pauli Virtanen's 7e3212fa233e (2026-09-04), first in **5.88** (confirmed).
- reports and links: none found. Inference: the register's "master's own l2cap-tester abort in timeout_callback" is probably Luiz's 70197a083 (shared/timeout UAF, master only, 10-30), so the CO-37 base comparison may change on the tip; re-run.
- objection to U24 fix: none read (adapter: clears discovery_found before cleanup; our 5.72 backport reproduces 10/10 -> 0/10 per register).
- delivered where: U24 in 5.88 only; U23, U25-U27 nowhere.
- backport: U24 = candidate for the 5.72 line (Ubuntu side done by the bundle; not mine).
- verdict: U23 STILL OURS TO SEND; U24 FIXED UPSTREAM BY OTHERS, ALREADY RELEASED (5.88); U25/U26/U27 STILL OURS (unfixed, no patch yet).
- proposed register text: "U23 still unfixed on master 1adfe662e; no competing patch found (patchwork queries listed in bluez.md). U24 is in BlueZ 5.88 (2026-11-05). Re-run the exit tests on the tip: 70197a083 (shared/timeout UAF) may change the l2cap-tester baseline."
- not checked: lore, syzbot.

### CO-39 / U29 — non-discoverable advertisements keep a temporary device alive
- ours: `btd_adapter_device_found()` (src/adapter.c) calls `device_update_last_seen()` before dropping a non-discoverable report, which restarts the 30 s temporary timer; 2-patch series, `Fixes: def01de02`; `CO-39-.../send-20261114/`.
- upstream now: unchanged on master (adapter.c l.~7806 `device_update_last_seen(dev, bdaddr_type, !not_connectable);` before the skip). `git log -S device_update_last_seen --since=2026-06-01` only shows Kevin Dewald (Connectable/auto-connect), 5d836f1c6 (Simon Mikuda), nothing for this. Patchwork queries (since 2026-08-01): `temporary`, `last_seen`, `last seen`, `non-discoverable`, `TemporaryTimeout` -> nothing; `discoverable` -> only 15010040 "advertising: Refresh only advertisements that depend on discoverable" (Simon Mikuda, 11-22, new; src/advertising.c, different subject) and a client print patch. Adjacent in the same function: the 2026-07 public-address comment (Philipp Dunkel's change).
- reports and links: linked to CO-41 (same U29 incident) and CO-27 (same adapter.c flags code).
- objection: n/a.
- delivered where: nowhere.
- verdict: STILL OURS TO SEND
- proposed register text: "No competing patch as of 2026-11-22 (master 1adfe662e); 15010040 (Simon Mikuda, new) touches advertising.c only. Next: re-apply on the tip, send."

### CO-41 — emulator IO Capability Negative Reply ignores the reason
- ours: `cmd_io_cap_negative_reply()` (emulator/btdev.c) completes SSP with `BT_HCI_ERR_AUTH_FAILURE` always; one-line fix + check in mgmt-tester "Pairing Acceptor - SSP 4"; `CO-41-.../send-20261114/`.
- upstream now: unchanged on master (`git show 1adfe662e:emulator/btdev.c`, l.3523-3537 still `ssp_complete(..., BT_HCI_ERR_AUTH_FAILURE, false)`). Patchwork queries (since 2026-08-01): `negative reply`, `AuthenticationRejected` -> 0; `IO Capability` -> only 15006061; `btdev` -> no matching change. Adjacent, pending: Luiz's series "BlueZ,v2,2/5 emulator/btdev: Add btdev_set_link_key_type" (15006058, 11-20, new, same series 1217494) edits btdev.c near link_key_notify and struct btdev (neighbouring fields io_cap/auth_req): textual conflict possible; and 5/5 "l2cap-tester: Set IO capability in Client SSP - Success 2" (15006061).
- reports and links: none; U29.
- verdict: OVERLAP (mild: Luiz's pending btdev.c/l2cap-tester series 1217494 touches neighbouring lines; not the same defect). Otherwise STILL OURS.
- proposed register text: "Still unfixed on master; Luiz's pending series 1217494 (btdev_set_link_key_type, 11-20) edits nearby btdev.c lines: rebase after it lands or check `git am` on the tip, then send."

### CO-27 / U13 and U18 — LE-only headset (Flags 0x00) and Connect counting LE services
- ours: U13: Flags 0x00 not treated as BR/EDR-capable (`btd_adapter_device_found()` `eir_data.flags && !(flags & EIR_BREDR_UNSUP)`, adapter.c; `select_conn_bearer()`, device.c:2740); U18: `dev_connect()` (device.c:2907-2930) and connect-service check (l.2873) count any CONNECTED service, including LE GAP/Battery. No patch written (register: investigating).
- upstream now: both unchanged on master (device.c from `git show 1adfe662e:src/device.c`: dev_connect uses `find_service_with_state(dev->services, BTD_SERVICE_STATE_CONNECTED)`; adapter.c still has the flags test, now with a comment restricting BR/EDR inference to public addresses). Patchwork queries (since 2026-10-01): `select_conn_bearer`, `LE-only`, `GATT services`, `connected service`, `dev_connect`, `connect_profiles` -> 0; `BR/EDR`, `bredr`, `bearer`, `Flags`, `pair` -> nothing on this (Ye He 14878926 / f088feb4f "device: Fix BR/EDR bearer when merging duplicate device" is applied, merging, not flags). Bearer work by Kevin Dewald (Connect/Disconnect, ReadRSSI) is adjacent in device.c.
- reports and links: BlueZ GitHub #2700 (opened 2026-10-22, open, "stale" label added by the bot on 2026-11-22; one comment = the bot; no human reply). It describes a dual-mode, BR/EDR-connectable, non-discoverable audio peer paired only over LE with a CTKD key the peer never honours (br-connection-key-missing); workaround: open a classic link through SDP then pair natively. Same path as our U13/U18; issue has no linked patch. GitHub issue search "connected LE services Connect audio no sound": 7 closed, none this.
- verdict: STILL OURS TO SEND (nothing competing; a reproducer is still the open step). #2700 is at risk of auto-close by the stale bot: a comment would keep it open.
- proposed register text: "Still unfixed on master 1adfe662e; no patch posted by anyone; #2700 got the stale label on 11-22 and will be closed unless someone comments. Next: comment on #2700 with the evidence, then an emulator reproducer."
- not checked: lore, BlueZ mailing-list threads, Launchpad, GNOME tracker.

### U16 — StartDiscovery refused InProgress while a stop is queued
- ours: `start_discovery()` (adapter.c) returns `btd_error_busy` when `get_discovery_client()` finds the client still in the discovery list while its MGMT Stop Discovery waits; no patch.
- upstream now: start_discovery on master has the same structure (`git show 1adfe662e:src/adapter.c`). Kevin Dewald's 14919283 (rejected stop, 4f3428e9d) and 14919284 (failed stop, cad7a98e7) are both applied in master and released in **5.88** (patchwork shows 14919284 as "new", stale state); they change `stop_discovery_complete()` / `discovering_callback()` and not the start path, as the register says. Their GitHub links: #2547, #807 (closed), PW_SID mirror PRs #2723, #2725 (closed). Nothing else: `git log --since=2026-10-15 --grep=discovery -- src/adapter.c` = those two only; GitHub search "StartDiscovery InProgress": #1554 "Emptying scan list / stalling discovery" (open, 2025-09) is the nearest, not read in full.
- verdict: STILL OURS TO SEND (adjacent fixes delivered in 5.88; ours not needed to be rebased, they are already underneath it).
- proposed register text: "Kevin Dewald's pair is in 5.88 and does not cover this trigger; start path unchanged on master. Check #1554 for a duplicate before any patch."

### CO-16 / U9 — no reconnect after rfkill
- ours: wait; policy.c `disconnect_cb()` reconnects only for TIMEOUT / LOCAL_HOST_SUSPEND (l.920).
- upstream now: policy.c has no commit since 2026-08-01 (`git log --since=2026-08-01 -- plugins/policy.c` empty). Adjacent: aa3d6c761 (Tobias Wilken, 5.88) stops Set Powered while rfkill-blocked and relies on the unblock event; Dylan MacKenzie's 15009074/15009075 (11-21, new, `btd_device_get_disconnect_reason` + "input/device: Only auto-reconnect on link loss") narrows HID reconnect in the other direction (no reconnect after remote or local-host terminated), so it points against an opt-in policy for deliberate disconnects.
- reports and links: #294 (per register: closed by stale bot; not re-fetched).
- verdict: STILL OURS (idea only; keep waiting); watch 15009074/5.
- proposed register text: "Policy unchanged; new Dylan MacKenzie series 15009074/5 (11-21) records the disconnect reason per bearer and stops HID reconnect after deliberate disconnects: any opt-in should reuse that reason helper."

### U12 (CO-03) and CO-40 backports
- U12: a14d59725 (Pauli Virtanen, 2024-11-02) first in **5.80**. CO-40: a6ac17f0e393 (Frédéric Danis, 2024-08-21) first in **5.78**. Both confirmed by `git tag --contains`; ours are only 5.72 backports. verdict: FIXED UPSTREAM, BACKPORT CANDIDATE (Ubuntu side belongs to another reader). Objection: none (register's tests 70/70 -> 0/70 and 10/10 refused).

### BT-4 / U28 — btmon print_packet overflow
- fdbfe0018 (Luiz, 2025-02-18) first in 5.80; dca0f10fd (Chad Spensky, 2026-08-14, patchwork 14750981 accepted) first in 5.88. Both confirmed.
- U28 remaining overflow: still present on master, `monitor/packet.c` print_packet l.885-919: `max_len` clamped to `sizeof(line) - pos - 1`, then unguarded `sprintf(line + pos, "%s", COLOR_OFF)` and `sprintf(line + pos, " %s", extra)` (LINE_MAX columns >= 2048). No fix posted: patchwork queries `print_packet`, `clamp`, `max_len`, `COLOR_OFF`, `columns`, `btmon` (since 2026-08-01) -> only 14750981 and an unrelated test-runner path patch. Adjacent monitor patches by others: Roland Schober 15007661 "Fix overflow of the name buffer in print_eir" (11-20, new, different buffer); Zijun Hu 3e1ec42b8 (applied, in 5.88, packet_hci_scodata).
- verdict: STILL OURS TO SEND (U28; needs a real-binary reproducer first).

### CO-11b — Pauli Virtanen's "test: functional: retry pairable when Busy"
- 14879847 (10-10) is **superseded**; replaced by "[RESEND,BlueZ]" 14928110 (2026-10-30, state new). Its CI mirror PR was flagged on 2026-11-14 by the bot as never applied after 2 weeks. Root cause fixed in the daemon instead: a994cab0e (Luiz, 2026-10-29, in 5.88) no longer returns Busy when a pending change sets the same value, so "pairable on" right after agent registration no longer fails (inference: this makes the test retry unnecessary; master's test_bluetoothctl.py l.44 still sends plain "pairable on").
- verdict: OVERLAP/obsolete. A Tested-by on 14879847 is moot (superseded id); if wanted, test 14928110 against a tree without a994cab0e only.
- proposed register text: "(b) 14879847 is superseded by 14928110 (new, unapplied) and its cause is fixed in the daemon by a994cab0e (5.88); drop the Tested-by unless the maintainer asks."

### CO-34 — ioctl-tester duplicate name
- applied as 3e5b0da969c2 (2026-10-28, Iaroslav Voitovych; patchwork 14920644 accepted), first in **5.88** (confirmed). verdict: ALREADY RELEASED AND DELIVERED. Register statement correct.

### CO-44 and CO-38 BlueZ tests (mgmt-tester)
- Nothing equivalent upstream: patchwork `Read Advertising Features`, `Authentication Failed`, `Pairing Acceptor`, `advertising instance` (BlueZ) -> 0 BlueZ results. Adjacent: Weihong Guan "mgmt-tester: Add single advertising set tests" (14974679, applied 11-12, with emulator 58e111cc9 "Set the number of advertising sets") touches the same area as CO-38's test: re-apply and re-run on the tip. Kernel side of CO-38 adjacent: Piyus Kedia "mgmt: drop advertising instances the controller cannot carry" (v3, 11-12, new), Weihong Guan 14910392 (not my part, noted for the kernel reader).
- verdict: STILL OURS TO SEND (re-apply check needed for CO-38 test).

### CO-02 sco-tester tests
- Patchwork 14919269 "tools/sco-tester: Add SCO reconnect tests" (our posting, 10-27, new, unreviewed). Not in master (`git log -- tools/sco-tester.c` since 10-27: only e37f17751 mainloop port, 10-29, after our posting), so the register's "needs its port" stands.
- verdict: STILL OURS (pending in patchwork, needs rebase on e37f17751).

## Cross-links
- CO-39, CO-41 and U29: same incident (headset not in pairing mode); CO-39 and CO-27 share `btd_adapter_device_found()` and its flags/last-seen handling.
- CO-27/U13, U18 and BlueZ #2700 are one path.
- CO-23 and CO-37 are both a2dp.c/media.c lifetime defects (a2dp setup vs. endpoint); both lie near 79aedd33f (finalize_all) and ef54133c6.
- CO-11b/a994cab0e and U16 both live in adapter.c request-queue behaviour ("Busy"/"InProgress"); a994cab0e (Busy) and Kevin Dewald's pair (discovery stop) are the nearest upstream.
- CO-16 and Dylan MacKenzie 15009074/5 (disconnect reason) and aa3d6c761.
- 70197a083 (shared/timeout UAF) may explain the master l2cap-tester abort noted in CO-37 (inference).

## Corrections to the readiness report or the register
- CO-37 README/issues U24: correct as now written (7e3212fa233e is in 5.88). 
- CO-11b: register cites 14879847; that patch is superseded, the live one is 14928110, and a994cab0e (5.88) fixes the underlying Busy.
- CO-27 row: "#2700 no reply" is right, but it is now labelled stale (2026-11-22).
- U16 row (STATUS.md) says 14919283/14919284 are "pending": both are applied (4f3428e9d, cad7a98e7) and released in 5.88.
- CO-23 / U22 / U23 text "re-checked at 82667d713949 / 20ffd285b58f": still true at master 1adfe662e (2026-11-16).
- The registry's "newest tag" must be 5.88 (2026-11-05); 5.87 is 2026-07-03.

---

# Part: ubuntu

## Ubuntu 24.04 (noble): what ships on 2026-11-22 and what Launchpad already holds

Sources: Launchpad API `getPublishedSources` (all pockets, exact_match, noble and tenacious), `getPackageUploads status=Unapproved`
(noble, 0 for bluez, linux-hwe-7.0, pipewire, wireplumber, systemd, gnome-control-center), `searchTasks`, bug and bug_tasks reads;
changelogs from `https://changelogs.ubuntu.com/changelogs/pool/main/...` (reachable, HTTP 200); BlueZ release facts from the local
`bluez.git` (`git tag --contains`). Raw dumps: `co/lp/`.

## Series and package state today (Launchpad, 2026-11-22)

| package | noble Release | noble Updates (newest) | noble Security (newest) | noble Proposed | dev release (tenacious 27.04) |
|---|---|---|---|---|---|
| bluez | 5.72-0ubuntu5 | 5.72-0ubuntu5.8 (2026-10-21 06:52 UTC) | 5.72-0ubuntu5.8 (2026-10-13) | nothing published | 5.88-1 (Release, 2026-11-07 15:29 UTC) |
| linux-hwe-7.0 | (not in Release) | 7.0.0-43.43~24.04.1 (2026-11-11 21:12 UTC) | 7.0.0-43.43~24.04.1 (2026-11-12 02:04 UTC) | **7.0.0-44.44~24.04.1** (2026-11-20 05:27 UTC) | n/a |
| gnome-control-center | 1:46.0.1-1ubuntu7 | 1:46.7-0ubuntu0.24.04.6 (2026-09-02) | none newer | none | 1:51.0-1ubuntu1 |
| gnome-bluetooth3 (source of gnome-bluetooth 46) | 46.0-1build1 | 46.0-1ubuntu1 (2024-11-20) | - | none | not listed in tenacious query (empty output) |
| pipewire | 1.0.5-1 | 1.0.5-1ubuntu3.3 (2026-07-13) | 1.0.5-1ubuntu3.3 | none | 1.6.8-1ubuntu4 Release; 1.6.11-1ubuntu1 Proposed |
| wireplumber | 0.4.17-1ubuntu4 | 0.4.17-1ubuntu4.1 (2025-10-09) | - | none | 0.5.19-1ubuntu1 (2026-11-20) |
| gvfs | 1.54.0-1ubuntu2 | 1.54.4-0ubuntu1~24.04.5 (2026-11-03) | same | none | 1.62.0-3 |
| systemd | 255.4-1ubuntu8 | **255.4-1ubuntu8.19** (2026-11-19 18:51 UTC; was Proposed from 11-05) | 255.4-1ubuntu8.18 | none (8.19 only, now in Updates) | 262.1-1ubuntu1 (Proposed), 261.3-0ubuntu3 Release |

Other BlueZ series: resolute (26.04) 5.85-4ubuntu0.4 in updates+security, 5.85-4ubuntu0.5 in proposed (2026-11-10); stonking (26.10) 5.87-4 Release, 5.87-4ubuntu0.1 in proposed (2026-11-10).
Series list (`/1.0/ubuntu/series`): tenacious = Active Development 27.04; stonking = Current Stable 26.10; resolute = Supported 26.04.

## bluez in noble: versions and changelog

All noble bluez publications (the 5.72 line): 5.72-0ubuntu5 Release 2024-04-07; 5.72-0ubuntu5.1 Updates 2025-03-11; .2 never reached updates; .3 Updates 2025-06-24; .4 Updates 2025-08-21;
.5 Updates 2025-10-16; .6 Updates 2026-10-07 (published 2026-10-07 03:27); .7 Security 2026-10-08 / Updates 2026-10-09; **.8 Security 2026-10-13, Updates 2026-10-21 (newest everywhere)**.
**No `5.72-0ubuntu5.9` exists in any pocket, in any status (Published, Superseded, Deleted), and nothing is in the noble Unapproved queue.** The bundle's version is free.

Changelog of the newest, 5.72-0ubuntu5.8 (noble-security, Allen Huang, 2026-10-13): "SECURITY REGRESSION: loading of cached A2DP remote SEPs broken by the CVE-2026-19774 fix (LP: #2170509); `regression-a2dp-sep-cache.patch`, a2dp: Fix loading of remote SEP from cache in profiles/audio/a2dp.c".
Its predecessors in the last two months:
- 5.72-0ubuntu5.7 (security, 2026-10-07): CVE-2026-19774 (a2dp codec capability storage, `a2dp.c`), CVE-2026-75032 (avrcp GetFolderItems), CVE-2026-80185 (sdp-xml), CVE-2026-80186 (eir), CVE-2026-85218 (avrcp ListPlayerAttributes). **None is btmon.**
- 5.72-0ubuntu5.6 (noble, 2026-09-22): fix for extra bytes in MGMT_OP_ADD_EXT_ADV_DATA (LP: #2164626).
- 5.72-0ubuntu5.5 (2025-10-08): "Improve audio profiles compatibility" (LP: #2122382): `audio-upgrade-versions-to-latest-possible-to-qualify.patch`, `cleanup-endpoints-when-devices-been-removed.patch`, `profiles-avdtp-Fix-reply-for-bad-media-transport-for.patch`.
So noble's a2dp.c and avdtp.c have been touched by four Ubuntu patches since 5.72; the bundle's base (5.8) already includes them, and the bundle's builds were made on 5.8 (BUNDLE says so), so no new conflict, but a2dp.c-touching patches 3/7-10 should be re-applied if another security upload lands first.

### What the 2026-11-10 uploads are (the dossier's "version numbers taken by unrelated uploads")
- resolute `5.85-4ubuntu0.5` (Kai-Chuan Hsieh, 2026-11-04 changelog date, published to proposed 2026-11-10 11:41 UTC) and stonking `5.87-4ubuntu0.1` (same author, 2026-11-06 changelog, proposed 2026-11-10 10:35 UTC): both only "mpris-proxy segfault during OBEX file transfer (LP: #2172906)", patch `debian/patches/mpris-proxy-fix-possible-crash.patch`. Confirmed: nothing btmon-related.
- LP #2172906 "mpris-proxy segfault (NULL deref in find_player_by_obex)", created 2026-11-04, Fix Released (dev series; the SRU tasks are in progress/proposed). Tenacious `5.88-1` carries the same fix ("Cherry-pick proposed patch to fix mpris-proxy segfault during OBEX file transfer (LP: #2172906)").
- The dossier's numbering consequence is therefore right: resolute and stonking debdiffs need the next numbers (.6 and ubuntu0.2). Noble is not hit: no noble upload on that bug.
- CO-11a's dossier says tenacious `5.88-1` "has both btmon fixes": confirmed. `dca0f10fd` and `fdbfe0018`: fdbfe0018 first in 5.80, dca0f10fd first in 5.88 (`git tag --contains`), and 5.88-1's changelog is "New upstream release" with "CVE-2026-105460 (btmon out-of-bounds read)". Stonking 5.87-4 has fdbfe0018 but NOT dca0f10fd (5.87 predates it), so stonking still needs the debdiff; resolute 5.85 same.

## Where each BlueZ commit first appears (git, bluez.git, `git tag --contains`; the repository's own dossiers agree)

| commit | subject | first tag | in noble 5.72 | in tenacious 5.88-1 |
|---|---|---|---|---|
| a14d59725 | transport: don't disconnect A2DP if canceling Acquire() with Release() | 5.80 | no | yes (5.88 contains 5.80) |
| 664a5d3785a1 | a2dp: don't change setup sep when it is reconfiguring | 5.80 | no | yes |
| fdbfe0018 | monitor: Fix crash due to negative max_len | 5.80 | no | yes |
| dca0f10fd | monitor: clamp max_len in print_packet | 5.88 | no | yes |
| 7e3212fa233e | adapter: clear discovery_found list before discovery_cleanup() | 5.88 | no | yes |
| a6ac17f0e393 | a2dp: Fix connection error message | 5.78 | no | yes |
| a734b06059cb | adapter: Fix crash on short start discovery reply (ours) | 5.88 | no | yes |
| 0bed9886cff3 | a2dp: Fix crash on NULL stream in transport_cb (ours) | 5.88 | no | yes |
| ae23df052290 | shared/mgmt: Fix notify leak in mgmt_unregister() (ours) | 5.88 | no | yes |
| 6475b75e7e0e | monitor: validate Return Link Keys length before parsing (CVE-2026-105460) | 5.88 | no | yes |

5.88 was tagged 2026-11-05; `bluez.git` master is 103 commits past it. CO-37's U23 patches are not upstream (the dossier says so; not re-checked here), so they are not in 5.88-1 either.

### Per-contribution noble status (bluez)
- **CO-03 (U12, a14d59725 + 664a5d3785a1 + helper):** not in 5.72-0ubuntu5.8; fixed in dev release (5.88-1). No Launchpad bug (see bug searches below). SRU-ready on the "fixed in dev release first" rule: it already is.
- **CO-11a (btmon, fdbfe0018 + dca0f10fd):** not in 5.72-0ubuntu5.8; both in tenacious 5.88-1. No Launchpad bug. Debdiff numbers: resolute -> ubuntu0.6, stonking -> ubuntu0.2 (as the refresh says); noble's 5.9 is free.
- **CO-37 backports (U24 = 7e3212fa233e):** not in noble; in tenacious 5.88-1. U23 is not upstream, so Ubuntu would carry a patch that exists in no dev release; the SRU rule "fixed in the development release first" is not met for patches 4-6 (they would have to go to BlueZ upstream first, or be accepted as Ubuntu-only with a dev-release upload; the SRU team normally refuses Ubuntu-only delta that upstream has not accepted).
- **CO-40 (a6ac17f0e393):** not in noble; in tenacious 5.88-1.
- **BT-7 crash fixes (a734b06059cb, 0bed9886cff3) and shared/mgmt ae23df052290:** all first in 5.88, hence in tenacious 5.88-1, absent from noble 5.72-0ubuntu5.8. The bundle `5.9` carries none of them (its notes say the final CO-03 candidate left the BT-7 fixes out; the staged `~co03.1` has them).
- CVE-2026-105460 (btmon Return Link Keys, `6475b75e7e0e`): tenacious has it; the dossier says noble is `needs-triage`; not re-read from the Ubuntu CVE tracker here (not fetched).

### Launchpad bug search, bluez (ubuntu/+source/bluez `searchTasks`, all statuses; every query repeated by `search_text`)
Zero results, exact queries: `btmon crash`, `max_len`, `btmon abort`, `btmon Aborted`, `print_packet`, `SIGABRT btmon`, `A2DP lost microphone`, `A2DP drops when microphone`, `br-connection-unknown`, `br-connection`, `org.bluez.Error.Failed br-connection`, `use-after-free exit`, `media endpoint release`, `discovery_found`, `ECONNREFUSED`, `Release transport acquire`.
Near misses:
- `btmon` (9 hits, 2016-2025): all unrelated pairing/connect reports that mention btmon logs; none about btmon crashing.
- `Acquire Release` (2): #1273629, #1645631, unrelated (old).
- `transport_cb` (2): #1689448 "bluetoothd crashed with SIGSEGV in avdtp_stream_set_transport() from transport_cb" (Confirmed, High, 2017-05-09) and #1689460 (avdtp_unref from setup_free, Confirmed, 2017-05-09). Same function name as BT-7's `transport_cb` fix but a 2017 crash on 17.04's BlueZ 5.43, different trace (avdtp_stream_set_transport), not our NULL-stream case. Adjacent only.
- `a2dp transport release` (3): #2056196 "BT headset is disconnected when remotely changing from A2DP to HSP" (noble 5.72-0ubuntu1, New, 2024-03-05, log line `ext_io_disconnected() ... getpeername ... (107)`): the headset leaving A2DP for HSP, unrelated cause (remote profile change), adjacent symptom to U12 (A2DP lost on mic open), no analysis in the bug.
- A2DP regression on 5.72-0ubuntu5.5: #2159829 "Regression in BlueZ 5.72-0ubuntu5.5 prevents A2DP connection to Amazon Echo Dot 4" (Fix Released, created 2026-07-06). Adjacent to CO-40 (A2DP connect failure) but a different cause (SEP/profile compat patches of .5); fixed by a later upload (the changelog's .6/.7/.8 do not name it; the status is as the API says).
- bluetoothd SIGSEGV: #2137758 "bluetoothd crashed with SIGSEGV in btd_service_connecting_complete() from control_connect_cb()" (Confirmed, 2026-01-09, seen on 5.84-1, i.e. not 5.72). Different function from the BT-7 crashes.
- #2164630 "[SRU][Resolute] Fix use-after-free caused by reentrant client teardown in GATT" (Fix Released, 2026-08-20): a UAF at teardown in `btd_gatt_client_service_removed`, not the media-endpoint UAF of CO-37; shows Ubuntu accepts bluetoothd UAF SRUs for resolute with an [Impact] text.
- #2138384 "Bluetooth HSP mic fails silently" (Incomplete/Confirmed, Bose, pipewire 1.4.9 PPA): unrelated.
Recent bluez bugs since 2026-01-01 listed in full (38 bugs, `created_since=2026-01-01`): none matches the A2DP-lost-on-microphone, btmon or br-connection-unknown wording.
**Result: no Launchpad bug exists for CO-03, CO-11a, CO-37, CO-40 or the BT-7 backports.**

## Kernel: linux-hwe-7.0 in noble

`docs/STATUS.md` names `linux-hwe-7.0`. Published versions (Launchpad `getPublishedSources`):
- 7.0.0-34.34~24.04.1: Updates 2026-09-22, Security 2026-09-23 (superseded).
- 7.0.0-38.38~24.04.4: Proposed 2026-09-16, Updates 2026-10-01, Security 2026-10-08 (superseded).
- 7.0.0-39.39~24.04.1: Proposed 2026-10-01 (Deleted 2026-10-29, never reached updates).
- 7.0.0-42.42~24.04.1: Updates 2026-10-28, Security 2026-11-02 (superseded 2026-11-11/12).
- **7.0.0-43.43~24.04.1: Updates 2026-11-11 21:12 UTC, Security 2026-11-12 02:04 UTC (current in both).**
- **7.0.0-44.44~24.04.1: Proposed 2026-11-20 05:27 UTC (newest upload; not yet in updates).**
There is no linux-hwe-7.2 or -7.4 source for noble yet (queries returned no entries).

Changelog (`https://changelogs.ubuntu.com/changelogs/pool/main/l/linux-hwe-7.0/linux-hwe-7.0_<v>/changelog`, grep by exact upstream subject):
the changelogs name each stable patch by subject, so "carried" below means "the subject appears as a line in that version's changelog". That is an inference from the changelog, not from the diff; the stable-base line is the one stated.

Stable-base lines: -42 newest base "Upstream stable to v6.18.55, v7.2.9"; -43 newest "v6.18.57, v7.2.11" (its patchset of 2026-10-21); -44 newest "Upstream stable to v7.2.15, v7.3.1" (patchset 2026-11-04, plus 2026-11-03 "v6.18.60, v7.2.14", 11-02 "v6.18.59, v7.2.13", 11-01 "v6.18.58, v7.2.12"). Note that the kernel is based on Ubuntu's resolute 7.0 base and takes 6.18.y and 7.2.y stable patchsets; the names in the changelog are subjects of those stable patches.

| change | CO / BT | subject searched | -42 | -43 (updates today) | -44 (proposed) |
|---|---|---|---|---|---|
| dc16388d45ec (mainline v7.3-rc2 range) | CO-09 | "Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table" | **absent** | **present** (changelog line 415) | present (line 809) |
| 96d006ae6445 | BT-9 | "Bluetooth: hci_event: fix simultaneous discovery stuck in FINDING" | present (line 11328) | present | present |
| 86ef0f58bdec (mainline v7.3-rc7 range) | BT-8 | "Bluetooth: MGMT: Fix status of pending commands flushed on power off" | **absent** | **present** (line 137, patchset 2026-10-21) | present (line 531) |
| xHCI ep0 maxpacket fix "usb: xhci: Fix ep0 maxpacket update on enabled slots" | CO-45 / BT-22 | "ep0 maxpacket" | absent | absent | absent |
| 608e0b7a675b "L2CAP: add l2cap_chan_close_unlocked() and locking helpers" and 32d86e048d8e "L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer" (both in mainline v7.4-rc1) | CO-35 | "l2cap_chan_close_unlocked", "__l2cap_ecred_conn_rsp_defer", "conn->lock" | absent | absent | absent (the only L2CAP locking line is "L2CAP: cancel pending_rx_work before taking conn->lock", a different commit) |

Notes:
- 96d006ae6445 in -42/-43: the STATUS row says `-38` already carries it; I did not fetch -38's changelog. The bundled 7.0.0-42 changelog line is at 11328 within its older stable patchsets (v6.18.4x/v7.1.x range: consistent).
- xHCI ep0 fix: still queued, not merged. Patchwork id 14964105 ("usb: xhci: Fix ep0 maxpacket update on enabled slots", Michal Pecio, 2026-11-09, state `new`, `https://patchwork.kernel.org/api/1.3/patches/14964105/`); `git log` on the local mainline master (tip 2026-11-21, 4843f6873f) for xhci.c/xhci-ring.c since 2026-11-01 lists only three 2026-11-05 xhci commits, none this fix. So the fix is in no kernel (mainline, stable, or Ubuntu) as of today. Separate and not ours: "[v4] usb: core: hub: Re-guess ep0 maxpacket size after reset" (lvpengfei20, patchwork 14966463, 2026-11-10, new).
- L2CAP pair: present in mainline v7.4-rc1 (`git describe --contains`), absent from the local stable clone's `linux-7.3.y` (grep by subject, nothing). Only `linux-7.3.y` exists in the local stable.git; the 6.18/6.12 branches were absent when checked, and the stable-queue clone had no commits ("master has no commits yet"), so stable-queue was **not checked**.
- What could not be established: the actual contents of the .diff.gz (not read, per instruction); the carried-or-not decisions rest on the changelog subject lines. 7.0.0-42's absence of IMC and MGMT subjects matches the repository's own `-42` check (STATUS: `-42` lacks the entry).

Kernel verdicts for noble:
- CO-09 (QCA9377 entry): **delivered**: in noble-updates and noble-security since 7.0.0-43 (2026-11-11/12). Confirms the dossier ("done").
- BT-9: delivered (all three).
- BT-8 / `86ef0f58bdec`: delivered to noble in -43 (via upstream stable; the dossier should say so if it does not).
- CO-45 xHCI: not carried; not yet upstream; Ubuntu cannot take it before mainline/stable.
- CO-35 L2CAP pair: not carried; mainline v7.4-rc1; the kernel team picks up stable patchsets, so the route to noble is stable first.

### Launchpad kernel bugs
Not searched for each item in `linux-hwe-7.0` (the `ubuntu/+source/linux` and `linux-hwe-7.0` searchTasks for `13d3:3503`, `3503` were run on 2026-10-18 per STATUS with 0 results). The changelog of -43 cites tracker LP #2171675, and of -44 LP #2173377 (SRU tracking bugs, not ours). Not rechecked here: `searchTasks` on `linux` for QCA9377 (not run in this pass).

## Desktop packages

### CO-07 / U6 (gnome-control-center input-meter series, first in GNOME 47) and the Sound panel
- noble Updates `1:46.7-0ubuntu0.24.04.6` (2026-09-02, changelog 2026-08-14, Marco Trevisan: fingerprint popover, LP #2158603). The newer 5.x changelog lines mention only the "Disable-non-working-camera-microphones-panels" patch; nothing touches `panels/sound`. **The six commits (215289935, a74bc5a84, bf6f72278, afec106a8, 3aeb837cb, 0da10f03a) are not in noble.** Dev release tenacious ships `1:51.0-1ubuntu1` (GNOME 51), so they are in the dev release (GNOME 47+).
- Launchpad: `searchTasks` on gnome-control-center, queries `level meter` (0), `microphone meter` (0), `input level` (4, all unrelated old: #1245064, #979326, #987626 fixed 2012, #1923602 Triaged 2021 "Output level shows input level"). Adjacent, current: **#2167667** "Not able to select audio input device when Bluetooth Headphone with A2DP profile" (New, 2026-09-18, `gnome-control-center 1:51~rc.1-1ubuntu1`, Ubuntu 26.10, 6 comments): the Sound panel offers no input while headphones are on A2DP, the reverse side of U19; against stonking, not noble. Also #2172448 (narrow window volume level; unrelated).
- SRU needs: a Launchpad bug for noble with [Impact] [Test Plan] [Where problems could occur] and [Other Info]; dev release already has the fix, so the noble task is the SRU. But per the repository's own finding, on Ubuntu the GNOME 47 fix alone does not help while U19's WirePlumber patch destroys the re-targeted stream, so the bug must be filed against wireplumber first (CO-32).
- Verdict (Ubuntu side): FIXED UPSTREAM, BACKPORT CANDIDATE; no bug exists; not yet useful without CO-32.

### CO-42 gnome-bluetooth
- Noble source package is `gnome-bluetooth3` 46.0-1ubuntu1 (Updates 2024-11-20); there is no newer noble upload. Launchpad: only #1964600 ([MIR]); searches `pairing` (0), `error` (1, the MIR). No Ubuntu bug for the silent failure. The upstream state (issue #18, MR !137) was not re-read here (gitlab.gnome.org is not reachable by API from here).
- Verdict (Ubuntu side): nothing to deliver; upstream-only (comment on !137/#18).

### CO-19 / U1 (pipewire codec-less profile, upstream 805e5cf9c)
- noble Updates and Security: `1.0.5-1ubuntu3.3` (2026-07-13, security: CVE-2026-14324 RAOP, CVE-2026-14330 pulse alloca). Its changelog has no bluez5 profile/HFP change after the older volume patches (`bluez5-volumes-need-to-be-distributed-to-all-channels`, `bluez5-set-the-right-volumes-on-the-node`) and `c7b3ef0d` (CIND brace). **805e5cf9c (and f142c0a5b) are not in noble.** Dev release tenacious: pipewire 1.6.8-1ubuntu4 (Release), 1.6.11-1ubuntu1 (Proposed 2026-11-16): both contain them (the dossier says so).
- Launchpad pipewire bugs: `codec profile` (2: #1993668 Invalid mSBC; #2172504 crash), `HSP/HFP` and `Headset Head Unit` (#2162010 "Bluetooth headset microphone never available: HFP link dropped because AT+..." New 2026-07-28, against newer releases). **No Launchpad bug for the codec-less "Headset Head Unit (HSP/HFP)" line.**
- NEW and relevant to our own HFP work: **#2173777** "[SRU] Bluetooth headset mic stops after a headset profile switch with WirePlumber 0.5.17" (pipewire task; Fix Committed, High; created 2026-11-09, updated 2026-11-20): tasks for stonking and tenacious only, "Resolute is not affected (WirePlumber 0.5.13)"; upstream fix `b7246d0d` released in PipeWire 1.6.11 as `5412be368`. Noble is not mentioned (noble runs WirePlumber 0.4.17). It sits next to CO-36 (HFP volume resend after Release) and the headset-session work, but is a different defect (stale transport error). Cross-check against CO-36 is the maintainer's.
- SRU needs: the dossier has `lp-report.md` and the debdiff; the Launchpad bug is not yet filed; the dev release already has the fix, so the fixed-in-development-first rule is met.
- Verdict: FIXED UPSTREAM, BACKPORT CANDIDATE (already packaged; held for the laptop test).

### CO-29 (U14) and CO-32 (U19), wireplumber
- noble Updates `0.4.17-1ubuntu4.1` (2025-10-09), the only change since release: `lp-2122640-bluetooth-audio-glitch.patch` (LP: #2122640). **No newer noble wireplumber upload, nothing in proposed.**
- **LP #2122640** ("When switching between the audio profiles of a bluetooth device, a sound glitch can be heard on another device", Antoine Lassagne, created 2025-09-12): the wireplumber task is **Invalid** (the series/dev task), the **Ubuntu Noble task Fix Released, Medium**; 8 messages, last activity 2025-10-09: sponsored 2025-10-01, an SRU-team comment 2025-10-01 that this "is not a clean backport ... we should have a wider call for testing", accepted into proposed 2025-10-01, tester run 2025-10-02, "fixed in 0.4.17-1ubuntu4.1" and verification done 2025-10-09. **No comment mentions the Sound panel level meter or a regression.** It stays closed, so the follow-up would have to be a new bug.
- **Follow-up bug search for U19 / the regression of that patch** (wireplumber searchTasks): `handsfree` (3: #2034935 expired 2023, #2083798 Invalid 2024, #2122640), `autoswitch` (0). Recent wireplumber bugs since 2025-06 (40 listed): none mentions the 2-second Bluetooth link block or `preventing non-Bluetooth devices from linking`. Closest: #2169383 "Existing audio streams do not switch to Bluetooth sink after reconnect" (Confirmed, 2026-10-03, wireplumber 0.5.13, resolute/26.04): different generation (0.5) and cause; #2164672 "Audio controls can get stuck when using Bluetooth audio" (Expired). **No Launchpad bug exists for U19.**
- Closest ongoing work on the 0.5 line, not noble: #2169803 "Sometimes not record any sound through bluetooth headset device" (Fix Released for wireplumber and stonking; resolute In Progress; upstream commit `80842cbb...` "audio.source must not select sink node") and #2173777 above.
- CO-29 (U14, 0.4.17 forces Handsfree for any listed recording): no bug; upstream fixed it only by the 0.5 rewrite; noble stays 0.4.17; dev release has 0.5.19.
- SRU needs for U19 (CO-32): a new Launchpad bug against wireplumber noble naming `lp-2122640-bluetooth-audio-glitch.patch` as the cause, with [Impact] [Test Plan] [Where problems could occur] (where problems: the same `policy-node.lua` that LP #2122640 touched; the SRU team already doubted it was a clean backport, so a regression story is believable), the dev release is exempt (it has 0.5 and does not carry the patch; the repository says upstream master does not mark an unlinked stream handled), the debdiff on noble 0.4.17-1ubuntu4.1 with the one-line change, verification on a laptop. The "regression of a SRU" tag (`regression-update`) would apply, and the original bug's reporter and sponsor can be named.
- Verdict: STILL OURS TO SEND (U19, Ubuntu-only, no report, no competing patch); U14: no Ubuntu action possible beyond a local override unless an SRU request is wanted.

### X1 gvfs (Launchpad 1967258)
- LP #1967258 "Totem has short pause when playing CD" (created 2022-03-31, New, Undecided, 3 messages, last update 2022-03-31; apport info `totem 3.34.1-2ubuntu2`, kernel 5.14.0-1027-oem; the only task is **totem (Ubuntu)**, there is no gvfs task). It describes the same symptom (pauses when playing CD tracks in Totem, "can not reproduce by Rhythmbox"), a different, reporter-side description, no analysis.
- noble gvfs `1.54.4-0ubuntu1~24.04.5` (Updates + Security 2026-11-03, security: CVE-2026-84267 sftp, -84269 afp, -84270 mtp); the changelog has nothing for cdda. Dev release `1.62.0-3`. The dossier's upstream MRs (#893/!368, #894/!369) are not in any release; gitlab.gnome.org not checked (unreachable by API).
- Other gvfs searches: `cdda` (16 old crash bugs), `CD audio` (26 old): none about readahead/stall.
- SRU needs: nothing until upstream merges !368; then a gvfs noble bug can cite #1967258 (add a gvfs task; note the reporter's kernel and totem versions are older).
- Verdict (Ubuntu side): CANNOT TELL for delivery; the Launchpad report exists and is linkable.

### CO-46 systemd (journalctl file count slowdown)
- noble Updates **`255.4-1ubuntu8.19` since 2026-11-19 18:51 UTC** (it was in proposed from 2026-11-05; the dossier's text "8.18, or 8.19 in -proposed" is out of date); Security `8.18`. Nothing newer in proposed. The 8.19 changelog (Nick Rosbrook, 2026-10-15): resolved TCP reset busy loops (LP #2145709), IPv4 route MTU (LP #2167098), networkd tclass qdisc segfault (LP #2085314), "Fix user journal corruption on rotate when using btrfs (LP #2088163)". **None is the file-count slowdown; no sd-journal performance change.**
- Launchpad searches on systemd: `journalctl slow` (2, unrelated), `journal files` (83, old unrelated, none about journalctl scaling with file count), `journalctl` (170 old). **No Launchpad bug.** Dev release: tenacious `262.1-1ubuntu1` (Proposed) and `261.3-0ubuntu3` (Release): both contain commits A `99e6f682d3` and B `51b2bcf835` (first in v256), by the dossier's table.
- Upload-wise nothing for the slowdown. PR #44579 (the further rework, "cached winner and runner-up") is on GitHub and was not checked here.
- SRU needs: the request in `sru-noble/` (bug-description in the template with Impact, Test Plan, Other Info) is for a debdiff against 8.19; **noble moved to 8.19 in updates on 2026-11-19, so the debdiff's base is now the updates version, not proposed**; the next version is `255.4-1ubuntu8.20`. A bug must exist first (placeholders NNNNNNN). Dev release has the fix. The SRU team treats a performance change as lower risk but still asks for where-problems text; systemd uploads normally go through the systemd maintainers' packaging branch (`ubuntu-noble`) merge proposal, as the dossier says.
- Verdict: FIXED UPSTREAM, BACKPORT CANDIDATE (prepared; unfiled).

## What an SRU request still needs (Ubuntu's rules, applied)
For every candidate: (1) a Launchpad bug on the source package with noble task and [Impact], [Test Plan], [Where problems could occur] (and [Other Info]); (2) fixed in the development release first: **yes for all bluez commits (tenacious 5.88-1), pipewire, gnome-control-center, systemd**; **no for CO-37 patches 4-6 (not upstream)** and no for U19 (the dev release does not carry the faulty patch, so the dev task is Invalid, as it was for #2122640); (3) an upload (debdiff or merge proposal) to noble-proposed by a sponsor; (4) verification of the fix in -proposed by the reporter, with the `verification-needed-noble` tag cycle; (5) for bluez, a bundle of unrelated fixes will draw a request to split by bug (each bug needs its own [Impact] and Test Plan; the changelog must cite each `LP: #`). The bundle's `bugs/` directory has five descriptions with `LP-…` placeholders; **none is filed**.
Kernel: noble HWE kernels take stable patchsets in the Canonical kernel team's own cycle (the changelogs show "Resolute update: upstream stable patchset <date>" with an LP tracking bug); a request for a patch that is in mainline but in no stable release (L2CAP pair, xHCI) is premature until stable has it, and the Ubuntu route would be a `kernel-team@lists.ubuntu.com` SRU patch on a Launchpad bug.

## Dev release ships (bluez)
Tenacious (27.04, Active Development): bluez **5.88-1** (Release, 2026-11-07 15:29 UTC, Jeremy Bicha, Debian sync; "New upstream release", CVE-2026-105460, "gatttool is no longer provided", two cherry-picks that landed after 5.88, mpris-proxy fix LP #2172906). Yes, it already has 5.88 and with it fdbfe0018, dca0f10fd, a14d59725, 664a5d3785a1, 7e3212fa233e, a6ac17f0e393, a734b06059cb, 0bed9886cff3, ae23df052290. 5.88 was tagged 2026-11-05. Stonking: 5.87-4 (Release 2026-10-02) + `5.87-4ubuntu0.1` in proposed; resolute: 5.85-4ubuntu0.4 updates/security, `.5` in proposed.

## Per-contribution blocks

### CO-03 — U12: bluetoothd backport of a14d59725 and 664a5d3785a1 (plus BT-7 fixes in the staged ~co03.1 build)
- ours: A2DP is lost when an application opens the microphone while A2DP is starting (`profiles/audio/transport.c`, a2dp); the backport of two upstream BlueZ 5.80 commits. Package in `contributions/CO-03-bluez-u12-backport/backport/` and in the bundle patches 7-9. State: tested in QEMU, not filed.
- upstream now: both commits in BlueZ since 5.80 (`git -C bluez.git tag --contains a14d59725` -> 5.80, `664a5d3785a1` -> 5.80).
- reports and links: no Launchpad bug (queries listed above). Related: #2056196 (noble, New, A2DP->HSP disconnect), not the same.
- objection to the upstream fix: none (it is the upstream fix).
- delivered where: BlueZ 5.80; tenacious 5.88-1; absent from noble 5.72-0ubuntu5.8 (newest in updates and security; no 5.9 anywhere).
- backport: candidate for noble: needs the Launchpad bug (placeholder in `bugs/01-u12-...md`), a sponsor, and verification in proposed.
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE
- proposed register text: Upstream in BlueZ 5.80 and in the dev release's 5.88-1; absent from noble's 5.72-0ubuntu5.8 (checked 2026-11-22, no 5.9 in any pocket, no Launchpad bug). Next: the operator files the Launchpad bug with the bundle's text and finds a sponsor.
- not checked: noble CVE tracker (no fetch).

### CO-11a — btmon overflow fixes fdbfe0018 and dca0f10fd
- ours: btmon aborts on long lines (`monitor/packet.c`, `print_packet`); debdiffs in `CO-11-.../ubuntu/ready-20261114/` for resolute/stonking, patches 1-2 of the noble bundle.
- upstream now: fdbfe0018 (5.80), dca0f10fd (5.88); 5.88-1 in tenacious has both. Related: CVE-2026-105460 `6475b75e7e0e` (5.88).
- reports and links: no Launchpad bug (queries `btmon crash`, `btmon abort`, `max_len`, `print_packet`, `SIGABRT btmon` all 0).
- objection: none. The dossier's own finding (first fix alone aborts live at 60 columns, both fixes 0 in 264 runs) is consistent with taking both.
- delivered where: not in noble 5.72-0ubuntu5.8, not in resolute 5.85, not in stonking 5.87 (dca0f10fd is 5.88-only); in tenacious 5.88-1.
- Taken version numbers: resolute `5.85-4ubuntu0.5` and stonking `5.87-4ubuntu0.1` (proposed, 2026-11-10): both are only the mpris-proxy segfault fix, LP #2172906, `mpris-proxy-fix-possible-crash.patch`. Renumber to `.6` and `ubuntu0.2`. The tenacious debdiff is obsolete (5.88-1 has it).
- backport: candidate for noble, resolute, stonking; needs the bug (placeholder) and sponsor.
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE
- proposed register text: Both fixes are in BlueZ 5.88 and tenacious 5.88-1; noble 5.72-0ubuntu5.8, resolute and stonking still lack dca0f10fd. The "taken" numbers belong to the unrelated mpris-proxy uploads (LP #2172906); renumber and file.

### CO-37 — U23/U24 (media endpoint exit use-after-free)
- ours: `profiles/audio/media.c`; U24 is `7e3212fa233e` (upstream 5.88); U23 not upstream (patches 4-6 of the bundle).
- upstream now: U24 in 5.88; U23: not re-checked here (dossier: present on master, nothing upstream; `send-20261114/` ready).
- reports and links: none on Launchpad (queries `use-after-free exit`, `media endpoint release` 0). Related: #2164630 (resolute GATT UAF, a different bug).
- objection: none for U24.
- delivered where: U24 in tenacious 5.88-1, absent from noble; U23 nowhere.
- backport: U24 candidate for noble; U23 first needs upstream acceptance (SRU "fixed in dev release first").
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE (U24); STILL OURS TO SEND (U23, upstream series)
- proposed register text: U24 is in 5.88 and 5.88-1, not in noble's 5.72-0ubuntu5.8, no Launchpad bug; U23 stays a BlueZ upstream submission first, and noble gets it only after upstream accepts it.

### CO-40 — a6ac17f0e393 "a2dp: Fix connection error message"
- ours: `error_to_errno()` in `profiles/audio/a2dp.c`; patch 10 of the bundle; tested 10/10.
- upstream now: in BlueZ 5.78; in tenacious 5.88-1.
- reports and links: no Launchpad bug (`br-connection-unknown` 0, `ECONNREFUSED` 0). Adjacent: #2159829.
- delivered where: absent from noble 5.72-0ubuntu5.8 (5.72 predates 5.78).
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE
- proposed register text: In BlueZ 5.78 and tenacious 5.88-1; absent from noble's 5.72-0ubuntu5.8 with no Launchpad bug; ride with the bundle or a bug of its own.

### BT-7 crash fixes (a734b06059cb, 0bed9886cff3) and shared/mgmt fix (ae23df052290)
- All three are the operator's own commits, applied in BlueZ and in 5.88; in tenacious 5.88-1; none in noble 5.72-0ubuntu5.8; the Ubuntu bundle 5.9 omits the first two (the `~co03.1` staged build has them).
- Launchpad: no bug for `transport_cb` NULL stream or short start discovery reply (queries `transport_cb`, `start discovery crash`: only 2017 and 2009 old bugs).
- verdict: FIXED UPSTREAM, BACKPORT CANDIDATE (optional; the mgmt fix is a leak, low value for an SRU).

### Bundle `ubuntu-bluez-5.72-0ubuntu5.9-bundle/`
- Base `5.72-0ubuntu5.8`: still the newest in updates and security (confirmed 2026-11-22; the bundle's README says the same for 11-14). Version `5.72-0ubuntu5.9` is free in all pockets.
- Re-check before upload: any new noble-security upload (the CVE-2026-105460 btmon patch, still `needs-triage` per the dossier) would take `5.9`; then the bundle becomes `5.10`.

## Cross-links
- CO-03 and CO-11a and CO-37 and CO-40 ride one noble upload; the SRU team may ask to split by bug.
- CO-07 (gnome-control-center) depends on CO-32 (wireplumber U19), and #2167667 (gcc, 26.10) is the reverse symptom on the newer stack.
- CO-32's follow-up report would mention LP #2122640 (closed; sponsor and original reporter on that bug; the SRU team's "not a clean backport" comment).
- #2173777 (pipewire/WirePlumber 0.5.17, headset mic after profile switch) is adjacent to the headset-session work and to CO-36, a stonking/tenacious issue (WirePlumber 0.5), not noble.
- CO-09 (kernel entry), BT-8 (MGMT flush status) and BT-9 all reached noble in `7.0.0-43` (BT-9 earlier).
- CO-45 (xHCI ep0) and CO-35 (L2CAP pair) are in no kernel that noble carries.

## Corrections to the readiness report or the register
- CO-46 README says noble is "8.18, or 8.19 in -proposed": as of 2026-11-22 8.19 is **in noble-updates** (published 2026-11-19 18:51 UTC); the SRU debdiff base is correct (8.19), the next number is 8.20.
- docs/STATUS.md and the CO-09 dossier: consistent with Launchpad (7.0.0-43 in updates 2026-11-11, security 2026-11-12). Newer: **7.0.0-44.44~24.04.1 is in noble-proposed since 2026-11-20**; it still contains the entry and, by its changelog, not CO-35's L2CAP pair nor the xHCI fix.
- Register CO-03/CO-11a/CO-40 rows say "5.72-0ubuntu5.9 candidate": correct, no 5.9 exists. Verified again on 2026-11-22 including Unapproved queue (0).
- The CO-11 dossier says dca0f10fd is "master"; it is in the 5.88 tag (released 2026-11-05).
- CO-07 states "Launchpad: the only match is #1923602, unrelated": confirmed (no panel level-meter bug); but #2167667 (gnome-control-center, 26.10, New) is a newer adjacent report, A2DP input not selectable.
- CO-32/U19 "no report found" in the register: confirmed (no wireplumber bug mentions the 2-second rule; #2122640 is closed Fix Released for noble with no regression note).
- X1 register says "Launchpad 1967258": it is a **totem** bug (no gvfs task), still New, last touched 2022-03-31.

## Not checked
- gitlab.gnome.org (gcc, gnome-bluetooth, gvfs MRs and issues), github.com systemd PR #44579 (not reachable by API from here).
- Ubuntu CVE tracker for CVE-2026-105460 on noble.
- The kernel .diff.gz of any version (not read, by design); stable-queue.git (clone had no commits); stable branches other than `linux-7.3.y`.
- Launchpad `linux`/`linux-hwe-7.0` searchTasks for `QCA9377`, `13d3:3503` in this pass (STATUS records 0 results on 2026-10-18).

---

# Part: desktop

## Desktop-audio and off-topic contributions, upstream check of 2026-11-22

Sources used: freedesktop GitLab API v4 (pipewire%2Fpipewire, pipewire%2Fwireplumber; issues/MR search and commits work, notes endpoints need login: 401); local pipewire.git (HEAD 20128216d, 2026-11-22) and wireplumber.git (HEAD c6a331d2, 2026-11-21); raw master files saved in up/extra-desktop/ (bn.c = backend-native.c, hw.conf = bluez-hardware.conf); gitlab.gnome.org API with `Accept: application/json` (works; the direct MR 137 and issue notes endpoints do not: 406/401, list queries with iids[] work); Launchpad API; WebFetch for github.com pages; systemd.git blobless clone in up/extra-desktop/systemd.git.

Latest PipeWire releases: 1.6.11 (2026-10-29), 1.6.10 (2026-10-22). WirePlumber 0.5.19 (2026-10-30). Noble: pipewire 1.0.5-1ubuntu3.3 (updates 2026-07-13), wireplumber 0.4.17-1ubuntu4.1 (updates 2025-10-09), gnome-control-center 1:46.7-0ubuntu0.24.04.6 (2026-09-02), gnome-bluetooth3 46.0-1ubuntu1, gvfs 1.54.4-0ubuntu1~24.04.5 (2026-11-03), systemd 255.4-1ubuntu8.19 (updates 2026-11-19).

### CO-36 / U15 — HFP volume resend outlives the SCO link
- ours: `sco_ready()` in spa/plugins/bluez5/backend-native.c arms a 1.5 s timer (`volume_sync_start_timer`) that resends +VGS/+VGM; `sco_release_cb()` and the hang-up path in `sco_event()` do not stop it. Dossier CO-36, evidence only; the operator writes the report.
- upstream now: still unfixed on master 20128216d (2026-11-22). Fetched raw master backend-native.c: `volume_sync_timer_event()` checks only `rfcomm->transport`; `sco_release_cb()` (L2890) and `sco_event()` (L2915ff) do not call `volume_sync_stop_timer()`; the only stop is at L1241 (AT+BCS). `git log -S volume_sync_stop_timer` in backend-native.c: only d82b3d647 (Pauli Virtanen, 2022-06-16). Only commit to backend-native.c since 2026-10-15: 710136cc7 (Pauli Virtanen, 2026-11-07 author date, merged 2026-11-19, MR !3109) "reject AT+BCC while SCO setup is in progress" (adjacent, see U7; does not touch the timer).
- reports and links: PipeWire issue searches "volume resend", "VGM", "VGS": only old 678 (2021, mic hardware volume) and 2062 (2022). Adjacent: MR !3035/!3036 (icegood1980, 2026-10-05, both closed unmerged) "send initial gain to HF that never reports it", same function area (rfcomm_ag_sync_volume), different defect. No duplicate.
- objection to the upstream fix: not applicable.
- delivered where: nowhere. noble 1.0.5 has the same code (per dossier).
- backport: not applicable.
- verdict: STILL OURS TO SEND (as evidence for the operator's own report).
- proposed register text: Rechecked 2026-11-22: master 20128216d still arms the 1.5 s resend in sco_ready() and stops it nowhere on release or hang-up; no issue or MR found (queries: "volume resend", "VGM", "VGS", "hw-volume-mic"). Next: the operator's GitLab duplicate search by browser, then his report.
- not checked: issue comment threads (login needed).

### CO-31 / U17 — sco_do_connect retries ECONNABORTED at once
- ours: `sco_do_connect()` retries `connect()` twice immediately on ECONNABORTED (d439b7cdd, 2021); with the CO-02 kernel refusal the audio returns only after WirePlumber's 5 s suspend of the failed node.
- upstream now: master L2692-2700 unchanged: `for (int retry = 2;;)` ... `errno == ECONNABORTED && retry-- > 0` -> `continue`, no delay. Searches in PipeWire issues "ECONNABORTED": zero results; "SCO": nothing about retry timing (5506, 5476, 5543, 5571 are other defects). WirePlumber suspend-node 5 s: not re-read at head (script files were reorganised to streams in 0.6 development, commits 2026-10-28..11-03; 0.5.19 is the release).
- reports and links: adjacent only: pipewire #5506 (closed 2026-11-19 by wtaymans), #5476, #5467 (closed 2026-09-30, MR !3004), #5533 "pipewire stalls on BT profile switch" (open, 2026-10-17).
- objection: not applicable. delivered: not fixed anywhere.
- verdict: STILL OURS TO SEND (evidence for the operator).
- proposed register text: Rechecked 2026-11-22: master still retries ECONNABORTED twice at once; no issue (query "ECONNABORTED": 0). Next: the operator's report, citing CO-02 (kernel refusal) and #5533 as the nearest open item.
- not checked: comments of #5533.

### U7 — codec switch under a live SCO link (issue 5506)
- ours: U7 is the kernel side (CO-02, sent 2026-10-27) plus PipeWire connecting before the old link's Disconnection Complete.
- upstream now: #5506 "bluez5: HFP microphone dies after the first use when the headset sends AT+BCC during eSCO setup (patch)", opened 2026-10-03 by abrus861, CLOSED 2026-11-19 by wtaymans. Fixed by commit 710136cc7 (Pauli Virtanen, MR !3109 merged 2026-11-19): replies ERROR to AT+BCC when a codec switch/initial setup is running or the SCO fd is open/requesting (diff read). It is in master only: `git tag --contains 710136cc7` is empty (1.6.11 predates it). Competing MR !3083 (sun617, open since 2026-10-25, carries abrus861's patch "keep the transport when AT+BCS confirms the current codec", Fixes #5506) still open, now probably superseded. Issue text says it is the PipeWire side of bluez/bluez#2562.
- Difference from ours: 5506 is the headset sending AT+BCC during setup (transport freed and recreated mid-connect); ours is a codec switch while a link is up, the headset's AT+BCS arriving before the old link's Disconnection Complete. The 710136cc7 guard does not touch this (inference from the diff: the `AT+BCS=` handler is unchanged). Our dossiers' statement "no PipeWire commit through master fixes it" stays true for U7 proper, but "adjacent open reports: #5506" is out of date: it is closed.
- delivered where: not released. noble 1.0.5 lacks it.
- verdict: OVERLAP (adjacent: same AT+BCS/BCC path, different trigger); U7's kernel part stays with CO-02.
- proposed register text: #5506 closed 2026-11-19 by 710136cc7 (reject AT+BCC while SCO setup is in progress, master only, unreleased); it does not cover our switch-under-live-link race; !3083 open. U7 remains CO-02 (kernel) plus CO-31.

### CO-33 / U20 and U15's quirk — hw-volume-mic quirk for Shure AONIC 50 and Sennheiser MOMENTUM 4
- ours: add `{ name = "...", no-features = [ hw-volume-mic ] }` entries to spa/plugins/bluez5/bluez-hardware.conf.
- upstream now: master bluez-hardware.conf (raw, 117 lines): no Shure, Sennheiser, MOMENTUM, AONIC entry; the file's last commit is 755aa967 (2026-09-21, Mackie CR-X). The feature `hw-volume-mic` exists, precedent `{ name = "Air 1 Plus", no-features = [ hw-volume-mic ] }`. PipeWire issues "Shure", "MOMENTUM", "Sennheiser", "hw-volume-mic": nothing relevant (3225 closed 2023, 5172 unrelated). Nearby: #5563 (EPOS USB headset, unrelated), #5583 muted mic low volume (open).
- reports and links: none. verdict: STILL OURS TO SEND (as the operator's entry, after the local test).
- proposed register text: Rechecked 2026-11-22: no entry for either headset in master's bluez-hardware.conf (last change 2026-09-21); `hw-volume-mic` has a precedent (Air 1 Plus). Next: the operator's local test via bluez5.hardware-database, then his entry (the project asks for a device name/address and an issue number comment).
- not checked: nothing.

### CO-08 / U10 — SBC-XQ on a Tronsmart T8
- upstream now: no `Tronsmart` or T8 entry in bluez-hardware.conf; issues "Tronsmart": 0; "SBC-XQ" open ones: #5545 (AirPods Max one ear on SBC-XQ, 2026-10-25, open), #5416 (SBC-XQ regression with JBL, open) — adjacent symptoms (one-sided/silent SBC-XQ), not the same device. Existing sbc-xq quirks: Motorola DC800/S305 (#1590), SoundCore 2, PMK, Phonak.
- verdict: STILL OURS (evidence not decisive; the operator's A-B-A-B test pending). Register text: unchanged state; add that #5545 reports single-channel SBC-XQ on AirPods Max (2026-10-25), same symptom class as the T8's single-channel test sounds; query "SBC-XQ", "Tronsmart".

### U30 — HFP gains outside 0..15
- upstream now: no issue (queries "VGM", "VGS" in issues: nothing since 2022). Master: `SPA_BT_VOLUME_HS_MAX` 15, A2DP 127 (defs.h); backend-native.c L3133 `rfcomm_ag_set_volume()` sends `rfcomm->volumes[id].hw_volume` with no range check; `sco_set_volume_cb()` computes `linear_to_hw(volume, t_volume->hw_volume_max)`. Where 127/119/99 come from is not established here (inference: a hw_volume_max of 127 reaching an HFP transport; bluez5-dbus.c L5570-5572 sets A2DP_MAX only on A2DP transports).
- verdict: STILL OURS (needs a reproduction before a report). Text: not fixed on master 20128216d; no report; cause still inferred.

### CO-19 / U1 — codec line in Hands-free (805e5cf9c)
- upstream: 805e5cf9c and f142c0a5b (both Pauli Virtanen, 2024-01-28) are first in tag 1.1.81 (the 1.2 series); noble ships 1.0.5-1ubuntu3.3 (2026-07-13), so it lacks them. Nothing changed upstream; the Ubuntu hand-port remains ours (an SRU/PPA matter).
- verdict: ALREADY RELEASED upstream (1.2), NOT DELIVERED to noble: backport candidate = our hand-port; the gate remains the laptop test.

### WirePlumber CO-15 / U11 — a newly connected headset does not become default
- upstream: issue #352 closed 2022-11-24; #1036 closed 2026-10-09 by its author (question; find-best-profile and priority, not about connect); #914 open since 2026-02-16 (manual selection in a tray permanently overrides priorities; by design, last update 2026-09-25). No new MR on default-node/bluetooth policy; since 10-15 the WP commits are the 0.6 development (streams, WpContext), plus `autoswitch-bluetooth-profile` moved to streams 2026-10-28. No option for "new device becomes default" (grep switch-on-connect in WP HEAD: no hit). Related open WP issues: #1035 (autoswitch regression 0.5.17/18), #1058 (LC3-SWB WF-1000XM6).
- verdict: STILL OURS (as a configuration note: module-switch-on-connect in PipeWire); by design upstream. Text: nothing new since 2026-11-01; #352/#1036 closed, #914 open as design discussion.

### WirePlumber CO-29 / U14 (0.4.17 forces Handsfree) and CO-24 / U5
- upstream: 0.4 is not developed; the 0.5 rewrite is the fix (as register). 0.5 has its own related reports: #1048 (0.5.18 stays in HFP after connect, closed 2026-10-19 by julian), #1050 (autoswitch restores A2DP between two captures, closed 2026-10-28), #1042, #1030. Noble has 0.4.17-1ubuntu4.1 only.
- verdict CO-29: FIXED UPSTREAM BY OTHERS (0.5) / not delivered to noble; a local override or an Ubuntu report remains the operator's. CO-24: "drop" stands, nothing upstream.

### WirePlumber CO-32 / U19 (Ubuntu-only)
- upstream WirePlumber has no such patch; noble wireplumber 0.4.17-1ubuntu4.1 (2025-10-09) unchanged. Verdict: STILL OURS (Launchpad). No newer Ubuntu version found.

### CO-07 / U6 and U4 — gnome-control-center sound panel
- upstream: the six commits (2024-03, GNOME 47) are unchanged; I did not re-verify the hashes. New in main: MR !3506 "sound: Allow output peak meter to auto-suspend" (Maurizio Casciano, merged 2026-09-29; output meter only), !3502 "input volume above 100%" (merged 09-29). Open: MR !3536 (dirksu, 2026-11-13) "sound: Show inputs when the default source has no UI device" (Closes #3710), adjacent to U4's missing row but not the meter or the codec row. Issues #3710 (open, Handsfree selection, 6 notes), #3715 (open, gvc_mixer_stream_get_port SIGABRT on handsfree port switch), #3859 (open 2026-11-15). Nothing for the Configuration row.
- noble: 46.7-0ubuntu0.24.04.6, no newer. verdict: STILL OURS (Ubuntu bug); U4: OVERLAP-adjacent with !3536 and #3710/#3715 (already cited).
- not checked: gnome-control-center notes.

### CO-42 / U13 / U29 — gnome-bluetooth silent pairing failure
- upstream: issue #18 open (2009, last update 2024-02-09, 1 note). MR !137 (eduxstad, "settings-widget: show error toast when authentication fails") open, updated 2025-02-23, head a28b9112, 16 notes, not merged; !135 (its larger predecessor) closed 2022-06-20. gnome-bluetooth main since 2026-10-01: translations only (last 2026-10-26); latest tags 47.2 (2026-04-17). New issue #176 (2026-11-11, 0 notes): BLE keyboard passkey never shown, cites unmerged MR !100; related to U13's LE flow. Noble ships gnome-bluetooth3 46.0-1ubuntu1.
- verdict: STILL OURS (a comment on !137/#18 only). Text: !137 still open at a28b9112 (unchanged since 2025-02-23), no maintainer reply visible via API (notes not readable); #176 is a new neighbour (LE passkey, MR !100).
- not checked: !137 comments (notes need login).

### U31 — libgnome-volume-control
- upstream: gvc repo has commits after our event dates? Not after 10-22: latest 0a4eda0c 2026-05-15. Earlier relevant: 3984af01 and 47c47a42 and 20784b53 (Guido Günther, 2026-01-23: portless BT streams, device lookup, zombie default-source), d2442f45 (02-11). Open: issue #48 (2026-09-10, Sound panel "No Input Devices" with portless BT source), #47 (NULL deref, zero profiles), #50 (segv in set_card_profile cb), MR !39. No issue for `gvc_mixer_ui_device_get_id` assertion. Whether noble's gnome-settings-daemon 46 bundles a gvc older than these commits: not checked (inference: yes, being older).
- verdict: CANNOT TELL (needs the gsd gvc version); probably FIXED UPSTREAM BY OTHERS in part (inference). 

### gvfs X1–X4
- MR !368 "cdda: Limit paranoia read-ahead to avoid playback stalls" and !369 "cdda: Refuse to open invalid and non-audio tracks" (ivoitovych, both 2026-11-07, open, 0 notes, no update since; draft=false; heads 98dc71aa4a, 610794dcad). Issues #893, #894: open, 0 notes. No cdda commit since 2026-02-25 (7db83c8d); the gvfs master commits since 10-15 are translations and sftp (Ondrej Holy). No other cdda MR/issue (queries "cdda", "paranoia", "audio CD"). Latest tags: 1.62.0. Noble gvfs 1.54.4-0ubuntu1~24.04.5.
- verdict X1 and X2-X4: STILL OURS, awaiting maintainers (15 days without reply). Whether X2/X3 are in !369 or in a separate MR: only 368 and 369 exist, so X2-X4 are in 369 or unsubmitted (not checked against the dossiers). Next: wait or nudge (the operator's decision).

### CO-46 — systemd journalctl file-count slowdown
- upstream: 99e6f682d3 "sd-journal: cache last entry offset and journal file state" and 51b2bcf835 "...journal_file_read_tail_timestamp() notify..." (Yu Watanabe, 2024-01-03) are both in v256 (`git tag --contains`: v256-rc1 first). Noble ships 255.4 (1ubuntu8.19 in updates 2026-11-19; the SRU is not delivered by it). PR 44579 "sd-journal: don't compare all files for every entry" (Ar-maan05, opened 2026-11-01): OPEN, not merged, yuwata asked for rework, author pushed f26f663 on 2026-11-02; no merge. Issue 31486 open since 2024-02-25, labels optimization/scalability, no linked PR. No sd-journal changes by others since 2026-10-01 other than test refactors and c60341fa37 (validator helper).
- verdict: ALREADY RELEASED (v256) BUT NOT DELIVERED TO NOBLE: our SRU stays ours; PR 44579 is someone else's open work on the remaining growth.
- proposed register text: 99e6f682d3 and 51b2bcf835 are in v256, noble 255.4 lacks them; PR 44579 (other author) open, not merged as of 2026-11-22 (checked via github.com page). The SRU remains ours.

### BlueZ issue 1554 (our reply of 2026-10-09)
- fetched github.com page: open, our comment of 2026-10-09 (kernel fix 96d006ae6445), one reply by Regina-v 2026-10-14 (tested a 6.18.50 Raspberry Pi kernel, less frequent for 4 months); nothing later, not closed, no BlueZ commit linked except e9bac13. Verdict: no change; waiting for a retest.
- gnome/bluez GitHub issues beyond that: not checked (only the pages above were fetched).

## Cross-links
- U7 / CO-02 / CO-31 / CO-30 / #5506 / !3109 (710136cc7) / bluez#2562: one switch path; U17's 5 s gap is CO-02 meeting CO-31.
- CO-36 (volume resend) is the U15 volume story with CO-33's quirk (the +VGM: 0 that triggers "mute on" and the Shure's ineffective mic volume).
- U13/U29/CO-42 with gnome-bluetooth #176 (LE passkey, !100) and #18/!137.
- U4/U6/CO-07/CO-32 share the Sound panel; U31 and gnome-control-center #3715 and gvc #48/#47 are the same mixer-control area.
- CO-19 and CO-29 share the Ubuntu-old-package pattern (noble 1.0.5 / 0.4.17).

## Corrections to the readiness report or the register
- docs/STATUS.md U7 row: "adjacent open reports ... pipewire #5506" is out of date; #5506 is closed (2026-11-19, 710136cc7, !3109) and !3083 is the competing open MR.
- CO-36/CO-31 rows: "not fixed in master" remains true (20128216d); the "master 4cfc4711 / 73974598f" references are older.
- CO-42: !137 is unchanged since 2025-02-23 (a28b9112); add #176.
- CO-46: PR 44579 is open, not merged (still "open" matches the register); issue 31486 has no linked PR.
- Not corrected: CO-33 (no entries), CO-08, CO-15.
