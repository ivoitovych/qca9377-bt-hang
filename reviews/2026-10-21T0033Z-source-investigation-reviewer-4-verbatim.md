# Source investigation — the fourth outside reviewer's answer

*Received 2026-10-21 as a report file in answer to
`2026-10-20T2332Z-source-investigation-task.md`. The text is kept as received, except that six
links that carry mail addresses (patchwork and patch URLs) are replaced by a note, by
`scripts/review-text-clean.py`. No finding was added or changed. What we checked and what
holds: `2026-10-21T0033Z-source-investigation-reviewers-2-4.md`.*

---

# Bluetooth source investigation — 2026-10-21

Review of the 2026-10-20 brief for QCA9377 USB `13d3:3503`.

## Results and limits

**U7 has a credible kernel mechanism, present in the exact Ubuntu source: a new SCO connect can attach to the old disconnecting connection without issuing a setup.** The abandoned-setup series does not change that lookup. PipeWire has immediate-error retries, but the asynchronous failure path does not schedule a retry. The missing piece is a trace of the new socket's actual connect and error, not another HCI-only timing comparison.

**Do not endorse the pending mesh locking patch unchanged.** It introduces `cmd_sync_work_lock → hdev->lock` acquisition from cancelled destroy callbacks, opposite to normal MGMT submission. Its advertising-list access also remains incompletely locked. Hui Peng's queue-failure cleanup is contained in it and must not be applied twice.

**M-2 is a definite arithmetic defect, including an unlimited-duration corner case.** BlueZ U12 is a definite backport opportunity, but the upstream patch does not apply unchanged to 5.72. The default-device issue is policy; GNOME's profile-list caching remains a plausible UI defect even in current main.

This is a source investigation, with patch-application checks and arithmetic checks. **No new QEMU, KCSAN, KASAN, hardware, audio or compiled-daemon test was run.** Existing project experiments are attributed as existing evidence. The raw laptop capture archives were not available here; EX-060 and the published issue records were read. Nothing was sent upstream, installed, committed or pushed.

### Source provenance

All repositories below were checked out locally. Project `BRIEF.md`, including §5 retractions, was read before technical conclusions, followed by STATUS, tooling index, issue records, EX-060 and the mesh state-machine document. BT-1, BT-7, BT-8 and BT-9 were not reopened.

| Key | Tree | Exact revision |
|---|---|---|
| PROJECT | ivoitovych/qca9377-bt-hang, main | `bd2f3cf46f1c3467f230bdfc428a41fdf1e3535b` |
| NEXT | git.kernel.org Bluetooth bluetooth-next | `27731ba091954eccddb2657053b590d2113e8d98` |
| BT | git.kernel.org Bluetooth bluetooth | `9b3b269829faa3a6264588cff6ef28da0ca5cee5` |
| MAIN | torvalds/linux | `4cbdd58dfa7aaad679bf62f81cdbc96a6cb7c6ae` |
| V7 | Linux v7.0 | `028ef9c96e96197026887c0f092424679298aae8` |
| U38 | V7 + Ubuntu `linux-hwe-7.0_7.0.0-38.38~24.04.4.diff.gz` | Bluetooth paths reconstructed from the distribution diff |
| B72 | BlueZ 5.72 | `770ad5614e7e8074133e6f563495ce4822f63fe4` |
| BM | BlueZ master | `7bc9684dc9e45358661301da4a0ede433fdf0a30` |
| P105 | PipeWire 1.0.5 | `a2287be601710eea0d073261223ec34b92384c8a` |
| PM | PipeWire master | `e0ca5ed944df3ec73cd616787b0db3121116429a` |
| W417 | WirePlumber 0.4.17 | `d3eb77b292655cef333a8f4cab4e861415bc37c2` |
| WM | WirePlumber master | `9ac17bbcc7da60f10322ccaa07e5a6329dc33abc` |
| G467 | GNOME Settings 46.7 | `9417bd3f9bb22473373f4631b2f21eb07c257273` |
| GM | GNOME Settings main | `a7e126b2b82c10cabbf347561def01bbec033145` |

Ubuntu diff SHA-256: `cd0996991ef58d83f4a7c64984b93d881eb10d450032348b482c9fbf4e7130ff`. This matched its downloaded `.dsc`; the OpenPGP signature was not checked. Applying its Bluetooth portions to V7 succeeded. E3's additional device-table entry does not change the SCO functions analysed here. Ubuntu userspace package deltas were **not** reconstructed; userspace conclusions below cite upstream tags and must be checked against the proposed distribution source package before a backport is released.

Line numbers below refer to these pinned trees, not moving branches. In NEXT, btusb has been split: the relevant file is **`drivers/bluetooth/btusb_main.c`**, not `btusb.c`. Mainline and U38 still have `btusb.c`.

## 1. U7 — connect during old SCO teardown

### Source and mechanism

| Tree | File and location | Role |
|---|---|---|
| U38 | `net/bluetooth/hci_conn.c:1758`, `hci_connect_sco()` | Looks up SCO/eSCO by type and peer address without excluding `BT_DISCONN` |
| U38 | `net/bluetooth/sco.c:310`, `sco_connect()` | Associates the socket; connected hcon means connected socket, otherwise socket becomes `BT_CONNECT` |
| U38 | `net/bluetooth/sco.c:231,254,1521`, `sco_chan_del`, `sco_conn_del`, `sco_disconn_cfm` | Sets socket error/state and wakes waiters on disconnect |
| U38 | `net/bluetooth/hci_event.c:3387–3473`, `hci_disconn_complete_evt()` | Delivers disconnect confirmation and deletes hcon |
| U38 | `net/bluetooth/lib.c:131–132`, `bt_to_errno()` | Reason `0x16` maps to `ECONNABORTED` |
| NEXT/BT | `net/bluetooth/hci_conn.c:1892–1939`, `hci_connect_sco()` | Retains the same relevant lookup/state condition |
| MAIN | `net/bluetooth/hci_conn.c:1864–1910` | Same relevant condition |
| P105 | `spa/plugins/bluez5/backend-native.c:898–940` | `AT+BCS` replaces the transport and answers OK |
| P105 | same file `1422–1474,1479–1570,1573–1606,1652–1698` | `sco_do_connect`, `sco_ready`, `sco_acquire_cb`, `sco_event`, `sco_start_source` |
| P105 | `media-sink.c:1262–1295`, `media-source.c:706`; `bluez5-dbus.c:2882–2911` | Media-node start dispatches to native SCO acquisition; `bluez5-device.c:458` is the additional offload path |

The kernel lookup returns an existing matching hcon even if it is disconnecting. `hci_conn_link()` returns its existing ACL link when one exists. Setup is issued only when ACL is connected **and SCO state is `BT_OPEN` or `BT_CLOSED`**. `BT_DISCONN` does not qualify. The function nevertheless returns the connection.

If the old socket has detached, `sco_chan_add()` can attach the new socket; `sco_connect()` puts it into `BT_CONNECT`. The old link's eventual Disconnection Complete then reaches that association. With the recorded local-host termination reason `0x16`, the expected asynchronous error is **`ECONNABORTED`**, with socket state changed to `BT_CLOSED`. If the old socket still occupies the association, the earlier alternative is **`-EBUSY`** from `sco_chan_add()`. These alternatives require socket-level observation; EX-060 alone cannot choose between them.

This is not a claim of a raw dangling socket pointer: disconnect confirmation performs socket teardown before hcon deletion. The defect hypothesis is reuse of the wrong lifecycle object and failure of the new attempt, not a demonstrated UAF.

PipeWire's exact distinction matters:

* `sco_do_connect()` retries **up to two additional immediate `connect()` failures with `ECONNABORTED`**. There is no delay in that loop.
* Nonblocking `EAGAIN`/`EINPROGRESS` is accepted. For USB, 1.0.5 waits for input rather than ordinary writable readiness.
* `sco_ready()` reads `SO_ERROR`; a nonzero result sets transport ERROR.
* `sco_event()` handles HUP/ERR by calling `sco_ready()`, removing the event source, setting IDLE and closing the socket. It does not queue a new connect.
* `spa_bt_transport_acquire()` has refcount and error-count handling; those are not a teardown-completion retry scheduler. A later caller may reacquire, but recovery at old-link completion is not guaranteed. Media sink/source state callbacks (`media-sink.c:1952–1990`, `media-source.c:1510–1533`) stop transport and emit node errors; they do not themselves schedule a retry.

PM keeps the immediate `ECONNABORTED` loop (`backend-native.c:2662–2720`) and non-retrying HUP/error branch (`2901–2936`). Its readiness handling distinguishes USB from other buses and its error logging was improved. Those changes do not close the U7 lifecycle gap.

### Relation to Hitalo Souza's series

All six posted diffs, patchwork **14875449–14875454**, were read through the Patchwork API. All were still `new` in that response. Patches 1–2 prevent a stale/duplicate setup from destroying or setting up an already established link; 3–5 dispose of links completing after abandonment/abort; 6 guards the driver enable notification with `!status`.

**None changes `hci_connect_sco()`'s reuse of an existing `BT_DISCONN` connection.** Thus this series should not be presented as the U7 fix. Its mechanism concerns late setup completions and duplicate setup errors; U7's proposed mechanism concerns an already established link being disconnected and a new attempt issuing no setup at all.

### Fix, certainty and deciding test

**High confidence in the code path; medium confidence it is the path taken by these two incidents.** EX-060 has the necessary ordering, but does not record the socket syscall, returned error, or hcon state at lookup. Correct the older statement in `docs/issues.md` that absence of an HCI command rules out a kernel defect: the kernel can suppress the command before it reaches HCI.

Kernel fix choices: reject reuse of a disconnecting/aborting connection with a defined retryable outcome, or defer the new attempt until teardown finishes. Do not simply allocate a second indistinguishable same-peer object: address-based completion matching must remain unambiguous. Balance the ACL/SCO references on every new error branch.

PipeWire should recover from a transient asynchronous teardown-overlap failure while acquisition is still requested, with a bounded, cancellable retry. Avoid an arbitrary 200 ms sleep or retrying all errors indefinitely. Closing an fd is not proof that controller teardown completed.

**First experiment:** a BlueZ `sco-tester`/vhci case that establishes eSCO, closes A, acknowledges Disconnect immediately but withholds Disconnection Complete, then connects B to the same peer. Record B's return, readiness and `SO_ERROR`; release the delayed event and check for setup/recovery. Run B before and after the event, with legacy setup forced, on base and base plus the six-patch series. Prediction: B before the event fails without a new setup, and the series does not repair it. A fresh hcon/new setup during the window, or no actual PipeWire connect attempt in the incident, falsifies this reading.

## 2. Unknown handle and corrupted SCO receive messages

### They are different checks

U38 `net/bluetooth/hci_core.c:3867–3899`, `hci_scodata_packet()`, emits unknown-handle when `sco_recv_scodata()` (`sco.c:1531`) returns `-ENOENT`. A syntactically framed packet cannot be associated with a current connection. MAIN has the corresponding path at `hci_core.c:3875–3906`.

U38 `drivers/bluetooth/btusb.c:1344–1429`, `btusb_validate_sco_handle()` / `btusb_recv_isoc()`, reassembles SCO headers and payloads across USB fragments. `btusb_isoc_complete()` around `1645–1692` prints **corrupted SCO packet** for any negative reassembly result. The negative results include allocation failure and `-EILSEQ` for an impossible payload length or a header whose handle is not currently SCO/eSCO. It is **not an mSBC decoder error**. NEXT retains this path in `btusb_main.c:1518–1608,1819–1868`.

The source explicitly anticipates fragment loss: a continuation can be mistaken for a header; handle validation discards it. A short USB packet alone is not necessarily corruption—the parser accepts fragmented data. Failed isochronous frame descriptors are skipped, which can create a missing-fragment condition. Actual lengths, statuses and bytes are needed to identify that condition.

The QCA isochronous path here uses its own reassembler, **not `h4_recv_buf()`**. Do not transfer conclusions from a UART/H:4 parser to this receive path.

### Teardown ordering

U38 `hci_disconn_complete_evt()` delivers the SCO disconnect callback, then `hci_conn_del()` removes the hcon from its hash (`hci_conn.c:1187`). Cleanup invokes `HCI_NOTIFY_DISABLE_SCO` (`hci_conn.c:140–173`). `btusb_notify()` (`btusb.c:2245`) records the count/event and schedules work; `btusb_work()` (`2360`) later kills anchored isochronous URBs and selects alt 0.

This permits late receive completions and already queued HCI frames around deletion. In particular, a packet may pass btusb's handle check while the connection exists, enter the HCI receive queue, then be processed after the Disconnect event removes the connection. A packet reaching btusb's check only after removal can instead produce the **corrupted** message. Thus even these two different messages can share a teardown boundary without sharing U7's cause.

Do not treat the outgoing `len 27 mtu 9` debug line as the age or layout of a received URB: TX buffering and RX completion are different evidence. Nor does USB isochronous buffering, by itself, explain **four to six seconds** of delay. A scheduling backlog, a later burst, a framing mistake, timestamp attribution, or an orphan controller link needs to be distinguished. The code has no identified ordinary multi-second receive delay here.

**Confidence:** high for emit conditions and possible short teardown race; low for the observed seconds-late instances. A complete, timestamped usbmon→btusb→HCI receive sequence would falsify simple queued-tail explanations if it shows genuinely new controller traffic long after the link ended.

**First experiment:** use an existing incident window with usbmon and HCI/journal timestamps for one of the seconds-late handles. Correlate the last successful RX URB, its frame statuses, alt switch, `hci_conn_del`, and HCI packet delivery. If it is not in existing captures, add only these bounded tracepoints for one short hang-up. vhci can prove host queue/event ordering but cannot reproduce the QCA USB reassembly or firmware.

**Fix ownership:** kernel receive/teardown if ordering or framing is wrong; controller-specific quirk only after device evidence. Avoid blanket log suppression. These paths exist beyond QCA and alt 1. BlueZ #2562's current issue body describes an Intel AC 3168 and orphaned SCO following a rejected duplicate setup; the AX211 attribution in the brief may refer to a comment. Its orphan-link mechanism must not be imported into cleanly completed QCA hang-ups without evidence.

### U8 playback caveat

RX corruption does not automatically explain missing **TX playback**. There is an indirect dependency: P105 `sco_start_source()` waits for first incoming data, and `sco-io.c:150–159` writes nothing until `read_size` is known; `sco_io_on_ready():85–106` obtains that size from received data. This can stall initial output if RX never becomes usable. However, the project's thousands of recorded outgoing buffers mean “no first RX, therefore no TX at all” cannot explain those entire U8 links. Test RX microphone content and TX mSBC framing independently.

## 3. Series patch 6 and btusb's remaining multi-link defect

NEXT `btusb_main.c:2470–2481` updates both `sco_num` and `air_mode` only on a count change. `btusb_work():2584–2655` starts with `new_alts = 0`; only ENABLE_CVSD and ENABLE_TRANSP select a nonzero alternate.

With one real link active, a spurious notification for a failed second setup can change the remembered count to two. Deleting the failed hcon changes it back to one with **DISABLE_SCO** as `air_mode`. Work then sees a positive count but neither enable mode and can choose alt 0. Patch 6 prevents the failed setup's enable notification, avoiding this count excursion when btusb's remembered count remains that of the real link.

The remaining established-two-to-one case has the same bad positive-count/DISABLE combination and is **a separate driver defect worth a patch**. The fix must derive the required mode/bandwidth from surviving established SCO connections, or maintain equivalent per-link state. Blindly retaining the last mode can be wrong when the departing and surviving links use different modes. Failed/pending connections should not inflate the active transport requirements.

The legacy `0x0428` command still completes through `hci_sync_conn_complete_evt()`, so patch 6 is relevant to ROME. The series' enhanced-command-specific code is not exercised on this device, but its common event/status and notification paths are. Ordinary successful single-link mSBC calls should not change; a failed setup without another active link is weak evidence for the specific bug the patch claims to fix.

**Meaningful hardware test:** base versus exact series, firmware-loaded E3 both times; keep peer A's SCO carrying verified audio, provoke peer B's failed/abandoned setup, and record A's handle, uninterrupted data/content, failed B's completion status, notifications, remembered SCO count and chosen USB alt. Base should exhibit the extra notification/count excursion; patched should omit it and preserve A. Also test two successfully established links followed by one hang-up as the explicit remaining negative control. If the adapter cannot support two links, that limitation prevents claiming coverage of the multi-link behaviour.

A test driver with a recording `notify` callback can verify the event contract in QEMU. Unmodified vhci has no such callback, so its clean run cannot certify btusb audio survival. On hardware use dynamic debug plus an explicit chosen-alt trace if the existing sites do not print the decision. Module changes require `updates/` plus cold boot; no reload or rebind.

**Confidence:** high for the source-level failure mechanism; untested on this hardware. Falsifier: a controlled count transition with DISABLE that does not reach the positive-count alt-0 path, or an additional constraint excluding the second established link.

**Classification of items 1–3:** at least three mechanisms: (a) connect during teardown, (b) receive data crossing deletion or losing framing, and (c) abandoned setup/incorrect completion ownership, with its driver-notification consequence. An abandoned orphan can cause unknown-handle traffic, so the symptom classes overlap; that does not make all three one defect. U8's silent playback remains an additional unresolved observation.

## 4. I12 and the four mesh patches

### Reviewed shape of the advertising-list fix

NEXT `mgmt.c:2328–2386`, `mesh_send_sync()`, reads `adv_instance_cnt`, calls `hci_add_adv_instance()`, changes `mesh_tx->instance`, reads current/timeout state and walks to the next instance without `hdev->lock`. NEXT `hci_core.c:1708,1775,1842` explicitly requires that lock for remove/add/per-instance add. Command-worker serialization alone does not serialize MGMT syscalls and HCI event processing.

Use the existing **`req_lock → hdev->lock`** order. In the sync worker:

1. Take `hdev->lock` before the capacity check and related advertising-state reads.
2. Keep it through add/update and choosing the next instance. On error, unlock and return the error immediately.
3. Copy the chosen **instance ID**, not an unowned `adv_info *`, before unlocking.
4. Release `hdev->lock` **before** `hci_schedule_adv_instance_sync()` or any command that waits for an HCI completion. Event completion needs the same lock.
5. Audit downstream lookup/lifetime handling: a local lock around the add is not a proof that every later `adv_info *` remains valid across command waits.

This is a reviewed design shape, not an approved ready-to-merge diff. `mesh_tx` lifetime is a separate ownership problem; the advertising-list lock does not give a queued callback ownership of that object.

Split the non-mesh sites into focused patches in one coherent locking series: `hci_clear_adv_instance_sync()` (`hci_sync.c:489–540`) performs unlocked list walks/removals and must copy any next ID before unlock; periodic/ISO setup (`1880–1946`) both looks up/mutates instances and removes its added instance on failure. Check Set LE off's actual callback path separately. Do not wrap whole sync functions in the mutex. Nearby `hci_clear_adv_sync()` and `hci_remove_adv_sync()` (`2173–2225`) illustrate short locked software cleanup sections, with controller work outside.

Also audit `mesh_send_done_sync()`'s `list_empty(&hdev->adv_instances)` at `mgmt.c:1101`: Putko's patch leaves that check **outside** its newly added lock.

**Confidence:** high that the unlocked paths violate the stated contract; source review plus existing project's asserted-lock/KCSAN evidence, not a new reproduction. **First experiment:** rerun the existing four-CPU advertising/Mesh Send workload with add/remove lock assertions and KCSAN, base versus the focused I12 fix, then the other three paths. A changed helper contract or an independently demonstrated common exclusion mechanism would falsify the lock diagnosis; it is not provided by `req_lock` alone.

### Putko's lock inversion is not hypothetical hand-waving

NEXT `hci_sync.c:663–676`, `hci_cmd_sync_clear()`, holds `cmd_sync_work_lock` while `_hci_cmd_sync_cancel_entry()` invokes destroy callbacks (`650–658`). Normal `mesh_send()` holds `hdev->lock` while enqueueing; `hci_cmd_sync_submit()` (`716–744`) takes `unregister_lock`, then `cmd_sync_work_lock`.

Patch 14888791 takes `hdev->lock` at entry to `mesh_next()`, including its `-ECANCELED` destroy call. It also takes it in `mesh_send_start_complete()`'s error branch **before** the `err != -ECANCELED` test. Both can establish the reverse order. Suppressing only `mesh_next()` on cancellation is therefore insufficient.

The old `mesh_next()` already requeues on cancellation, creating the `cmd_sync_work_lock → unregister_lock` edge described by the project's forced-delay test. HCI_UNREGISTER may prevent progress past submit's flag check, so that specific observation must remain a lockdep inversion, not a claimed observed deadlock. Putko's additional device-lock edge needs its own cancellation test.

Safe remediation requires a cancellation ownership contract: separate no-requeue cancellation cleanup from normal completion, or detach queued entries under the work-list lock and invoke destroy callbacks outside it after a wider audit. A bare early return can leak entries/references; moving arbitrary callbacks outside locks without auditing callers can create a different race.

### Relationship and test order

Actual `git apply` checks against NEXT:

| Exact patches, in order | Result |
|---|---|
| Hui Peng 14831271 alone | applies |
| Putko 14888791 alone | applies |
| Jiale Yao 14864878 alone | applies |
| Cen Zhang 14880941 alone | applies |
| Hui Peng → Putko | second fails on duplicated queue-failure cleanup hunk |
| Putko → Hui Peng | second fails on that same hunk |
| Cen Zhang → Putko → Jiale Yao | all apply mechanically |

Mechanical application is not semantic compatibility. Suggested test order:

1. Baseline and Hui Peng's exact small cleanup, retaining the existing failure-injection regression test. It is the most isolated change.
2. Cen Zhang's exact destructor removal, alone and with that baseline cleanup. `mgmt_mesh_remove()` (`mgmt_util.c:433–438`) calls `sock_put()` before freeing the request; last-reference destruction can recurse into mesh cleanup. Check socket close with active and queued sends and eventual release of every socket reference.
3. Putko's exact patch alone to reproduce its intended race improvement **and the cancellation lock concern**. For a combined candidate, remove the already-applied Hui Peng hunk explicitly and record the adaptation. Do not call an adapted composite an exact-patch Tested-by.
4. Jiale Yao's queue-failure handling, last. It directly calls `mesh_send_done_sync()` and `mesh_next()` from delayed work on enqueue failure. That substitutes for the normal command-sync worker/`req_lock` context and can invoke synchronous advertising work without the usual serialization. Separate `-ENETDOWN` from `-ENOMEM`; a power-off case and a running-device allocation failure need different scrutiny.

Keep I12's advertising-list fixes independently testable, then test the combined result. Required combined gates: normal multiple sends, cancel one/all from two sockets, close a sender, power-off, queued cancellation during unregister, allocation failures at both enqueue sites, ordinary LE advertising and periodic/ISO advertising. Assert each accepted request starts/completes at most once; rejected requests never remain listed or later complete; no stuck scheduler flag, leaked socket reference, lockdep warning or KCSAN race.

**Do not infer that all mesh lifetime problems are solved by these four patches.** Putko does not comprehensively lock `send_cancel()` (`mgmt.c:2419–2451`), and advertising ownership is still separate.

## 5. M-2 — duration overflow and the right design

NEXT `hci_sync.c:1701–1706`, `hci_enable_ext_advertising_sync()`, assigns seconds×1000 into a `u16`, then divides by 10. The outgoing `hci_cp_ext_adv_set.duration` is in **10 ms units**; zero means no duration limit. NEXT `mgmt.c:9080–9148`, `add_advertising()`, accepts the userspace `u16` timeout without a 65-second cap and passes it into the instance. `hci_core.c:1826–1830` records timeout/remaining_time. Yes, ordinary MGMT Add Advertising can reach the bug when powered and otherwise valid.

Calculated directly from the expression:

| Requested seconds | Wrapped milliseconds | HCI duration units | Controller duration |
|---:|---:|---:|---:|
| 65 | 65000 | 6500 | 65 s |
| 66 | 464 | 46 | 0.46 s |
| 120 | 54464 | 5446 | 54.46 s |
| 655 | 65176 | 6517 | 65.17 s |
| 656 | 640 | 64 | 0.64 s |
| 8192 | 0 | 0 | unlimited by this field |
| 65535 | 64536 | 6453 | 64.53 s |

The resulting integer is normally a valid HCI parameter, so a controller parameter rejection is not the expected primary outcome. It is a shortened controller timeout, or accidentally unlimited duration. NEXT `hci_event.c:6113–6183`, `hci_le_ext_adv_term_evt()`, removes an advertising instance on a nonzero termination status and emits Advertising Removed. A premature timeout can therefore affect both controller operation and MGMT-visible lifetime.

Using `u32` milliseconds fixes the 65-second intermediate overflow but **not the final HCI limit: 65535 × 10 ms = 655.35 seconds**, while MGMT can request 65535 seconds. Clamping silently changes the request; wrapping is worse.

Preferred design for maintainers to choose: maintain an explicit host lifetime/deadline and program unlimited controller duration when the requested finite lifetime exceeds the controller field, with host expiry performing the same orderly disable/remove/event path. Alternatively, use bounded controller chunks and rearm without treating each chunk expiration as final MGMT removal. The latter must avoid observable Advertising Removed/Added cycles and unintended gaps. In either design define lifetime across temporary disable, reconfiguration, connection-induced termination and power-off; reuse or replace remaining_time consistently. Mesh milliseconds and ordinary seconds must be converted explicitly in a wide type. Do not round a nonzero sub-10-ms duration down to the unlimited sentinel.

**Confidence:** certain arithmetic defect, design still requires subsystem agreement. **First experiment:** a mgmt-tester extended-advertising case at 65/66/120/655/656/8192 seconds, inspect opcode LE Set Extended Advertising Enable immediately and inject termination events. The emulator already uses `duration * 10` for its timeout (`BlueZ emulator/btdev.c:5670–5672`), so a 66-second request can expose the old 460-ms expiry quickly; no long laptop session is needed. Separately prove cancellation and no premature Advertising Removed for the long-duration implementation. Falsifier: a distribution-specific earlier cap or different conversion; neither exists in the examined NEXT path.

## 6. U12 — BlueZ 5.72 backport

The exact commit is `a14d59725ef35d91b8504770046c701d0a2efe07`. It introduces `resume_id`, `cancel_resume` and `cancel_id` in `profiles/audio/transport.c`; those fields are **not a prerequisite that 5.72 already needs to contain**.

B72 `transport.c:382–489` has the old resume/suspend/cancel implementation. The patch changes cancellation of a pending START to waiting for completion and then suspending, and wires owner removal to cancellation cleanup. The `release()` hunk replies `ECANCELED` to the pending Acquire. All of that belongs to the backport; copying only the boolean/branch is unsafe.

Observed application checks:

* Exact a14 diff against B72: exit 1, failure at the hunk around old line 394.
* Earlier `3d9900eb754d277ef6abf21bed827cdc9e79ddb4` applies to B72; it introduced `transport_a2dp_get_stream()` and moved stream lookup into that helper.
* With that earlier change, a14's functional hunks apply; its final A2DP_OPS hunk still fails because the macro later gained a delay setter parameter.
* In a disposable tree, applying the functional hunks and wiring `transport_a2dp_remove_owner` into the existing 5.72 macro succeeds; `git diff --check` passes. This is an application exercise, **not a compiled or tested backport**.

Therefore it can be a **single-file, tailored `transport.c` backport**. Retain 5.72's direct stream lookup, or carry the small helper adaptation. It is unnecessary to import all later Delay-property behaviour just to satisfy patch context. Preserve all cancellation callback/owner cleanup semantics.

Review nearby fixes separately:

| Commit | Relevance |
|---|---|
| `664a5d3785a1a57989d236b6fd649321a39451f5` | Direct companion: resume/suspend during reconfiguration must not overwrite `setup->sep`. Strong candidate for the same Acquire/Release/reconfigure regression scope. |
| `aa118e965b02a6b78039c1ed55b9947698c6de59` | Removes the 500-ms reconfiguration delay after CLOSE; relevant to peers disconnecting in that gap, not a hard prerequisite to U12. |
| `47da1efdc5843294cfaf9522624b3876e8ab2972` | Clears the transport owner before freeing it. Audit owner teardown and whether Ubuntu already carries it; do not assume a textual dependency. |
| `87ad4c66b934b1280bc8843589856313ef1bc912` | Fixes remote-endpoint free-after-transport-free. A separate lifetime fix worth auditing in the distribution base, not the cause of EX-063. |

W417 `src/scripts/policy-bluetooth.lua:315–382` triggers on communication/application-classified capture streams while a Bluetooth sink is default. WM `src/scripts/device/autoswitch-bluetooth-profile.lua:423–490` instead evaluates a running Bluetooth loopback source actually linked to a non-monitor stream, with per-device switching/restoration. Thus “any application records” is too broad, and 0.5/master is not identical policy. It still intentionally switches profiles when that headset microphone is used. It cannot substitute for fixing BlueZ's valid Release-during-Acquire operation.

**Confidence:** high in the backport mechanism and application findings. **First experiment:** emulate an AVDTP peer that delays START_RSP; issue Acquire then Release from the same D-Bus owner. Base should Abort; candidate should error Acquire, await START, send SUSPEND, and complete Release. Then retry Acquire. Include owner disappearance, failed START, and concurrent reconfiguration. A remaining ABORT or dangling callback falsifies the backport's sufficiency. Final Ubuntu request should use the exact 5.72-0ubuntu5.8 source with its security fixes, not replace it with bare upstream 5.72.

## 7. U11/U3 — new device preference

W417 `modules/module-default-nodes.c:262–320` confirms the configured-default/history bonuses. WM `src/scripts/default-nodes/state-default-nodes.lua:19–66` retains history with rank `20001 - i`, deliberately excluding session priority. Its metadata hook (`69–116`) stores explicit configured-default writes. A fallback is not necessarily a new explicit choice.

The smallest defensible **opt-in design** is a transient preference layer in WirePlumber's default-node selection, keyed by stable device identity and a real connection generation:

* Record a newly connected eligible Bluetooth device after initial enumeration; wait for a usable node.
* Prefer its output until a subsequent explicit configured-default selection, disconnect, or newer eligible connection supersedes it.
* Do not rewrite persistent history merely because of automatic switching. Do not treat node recreation during a codec/profile change as a fresh connection.
* Keep input takeover a separate opt-in, or explicitly pair input with the user's headset choice; do not silently replace an intentionally selected USB/internal microphone.
* Exclude startup enumeration, monitor/virtual nodes, unchanged reconnect churn where appropriate, and profile-transition node bursts. Preserve pinned stream targets.

That is more than adjusting one numeric priority: implementing the connection-generation and explicit-choice boundary is what avoids the unwanted-switch reports. The hook should run with defined precedence relative to configured/history selection, with an explicit choice invalidating the transient override.

P105 `src/modules/module-protocol-pulse/modules/module-switch-on-connect.c:71–142` already reacts to newly added eligible sink/source objects and writes **configured** default metadata. It filters internal devices, defaults to ignoring virtual devices and blocklists HDMI. `only_from_unavailable` is explicitly **not implemented** in this version. It can switch inputs as well as outputs, and node appearance is not equivalent to a newly connected physical device. Its automatic write can affect saved preference history. Thus it is a useful opt-in approximation, not the precise transient policy above.

**Confidence:** high in existing behaviour; proposed change is a design, not an implementation. **First experiment:** a policy test sequence: initial enumeration → A connects → explicit B selection → A profile recreation → C connects → C disappears. Assert only intended defaults change, persistent history stays unchanged by automatic events, and input remains separately controlled. A node-add-only policy fails the profile-recreation case.

## 8. U10 — SBC-XQ offering and a discriminating test

P105 `a2dp-codec-sbc.c:67–96,113–210` chooses rate/mode from capability intersections, prefers Dual Channel for XQ, and clips its desired bitpool against the peer's maximum. At 48 kHz Dual Channel its XQ target is 39. It can also choose joint stereo or stereo; **Dual Channel and bitpool 53 are not universal prerequisites for offering the codec**. They explain this unit's selection. PM retains the same general selection structure (`a2dp-codec-sbc.c:115–213`).

`bluez5-dbus.c:2391–2462`, `spa_bt_device_supports_media_codec()`, checks enablement, the per-device XQ feature quirk, profile/direction and remote endpoint capabilities through `media_codec_check_caps()`. It does not verify that an accepting peer actually decodes the resulting stream audibly.

P105 `bluez-hardware.conf:40–48` contains model-specific XQ exclusions for Motorola DC800/S305, PMK True Wireless Earbuds and SoundCore 2. Commit `966fbd5a2176e31c8a34a751a5c831c19221a5ab` added the Motorola entries referencing issue #1590. This supports a narrowly matched model quirk if the failure is verified. The tracker pages were inaccessible in this session, so I cannot truthfully report exactly what maintainers demanded in their discussion. Do not invent a formal evidentiary policy from the presence of a quirk entry.

**Improve the experiment:** hold sample rate, blocks, subbands, allocation, source PCM and volume constant. First compare Dual Channel with stereo/joint stereo at nearly equal **encoded bitrate**, then sweep Dual Channel bitrate. With 48 kHz, 16 blocks and 8 subbands, Dual bitpool 26 yields 116-byte frames (348 kb/s); ordinary stereo bitpool 52 yields the same frame size/rate. Joint stereo bitpool 51 yields 115 bytes (345 kb/s), another close control. Then compare Dual 26 with Dual 39 (504 kb/s).

Do not demand joint-stereo 504 kb/s from a peer advertising maximum bitpool 53: reaching that rate would exceed its advertised bitpool capability. Bitpool numbers across modes are not equal-bit-rate controls. Distinguish accepted configuration, actual transmitted frame headers, actual PCM content, and audible output. Repeat marked Settings tones rather than Chrome's previously uninformative stream. A short microphone recording of the speaker, if the operator chooses, can make audibility objective.

**Confidence:** high in offering logic; low in the device diagnosis until the marked sound test. Low-rate Dual failing while matched-rate stereo works supports a channel-mode defect; low-rate Dual working and high-rate Dual failing supports a bitrate/packet-size limit. Both can also be affected by packetisation, so inspect RTP/frame grouping. A local PipeWire quirk disabling XQ is the likely upstream contribution only after that evidence. No kernel change is justified by the current record.

## 9. Lower-priority findings

### U4: GNOME profile row

G467 `panels/sound/cc-sound-panel.c:172–208` sets row visibility from profile count on device update. `cc-profile-combo-box.c:88–137` returns immediately if the device pointer is unchanged; otherwise it copies the current GVC profile list. GM still has that identity guard in `cc-profile-combo-row.c:177–220` and the count-based visibility check in `cc-sound-panel.c:124–166`.

This supports a stale-list mechanism **even if another device-update signal fires for the same object**. It does not prove that all eight PipeWire profiles were present in that particular GVC UI device: GVC performs its own representation/grouping. The profile/route index mismatch is not evidence of this bug.

**Confidence:** high for caching behaviour, medium/low for this incident. **First experiment:** keep a GVC device object stable while its profile list changes from one to several, log the GVC list and widget model/count, then emit the existing update signal. If GVC has several profiles but the widget stays at one, patch GNOME refresh/subscription and visibility handling. If GVC itself has one, trace GVC/Pulse compatibility mapping first. The current main source does not by itself demonstrate a U4 fix.

### U2: microphone volume

W417 `src/scripts/policy-device-routes.lua:133–195,295–336,427–450` restores saved route properties and writes Route parameters. P105 `backend-native.c:394–418,1047–1053,1850–1876,1971–2020` propagates HFP gain and synchronizes it immediately/later. For this laptop acting as AG, **incoming headset `AT+VGM`** and **outgoing AG `+VGM`** have different directions; an outgoing command may be the result of local restore rather than evidence that the headset originated the change.

Both mechanisms can move volume without a contemporaneous UI click, but the sparse 0.00→0.27→0.08 observations do not attribute the changes. Also, user-visible volume and linear route volume can use different scales; do not compare them as if identical.

**Confidence:** plausible, unproved. **First experiment:** correlate one route-restore write, RFCOMM gain commands/replies and resulting node volume with timestamps. A change with neither route write nor received gain falsifies these as a complete explanation. Fix the component producing the unintended write; do not disable hardware volume globally on this evidence.

### U9: reconnect after adapter power toggle

B72 `plugins/policy.c:743–785`, `disconnect_cb()`, permits reconnect for timeout/link loss and local-host suspend, not ordinary local power-off. A narrow opt-in belongs in session policy or BlueZ policy: retain only devices actually connected immediately before an intentional adapter off, retry those trusted audio devices after successful power-on with bounded attempts, and cancel on explicit device disconnect/unpair. Do not enumerate and connect all paired devices; do not retry while powered off. This needs an adapter power-state transition, not merely expanding the disconnect-reason filter.

**Confidence:** high for B72's filter; acceptability of a proposal remains a maintainer decision. **First experiment:** virtual adapter off/on with one connected audio device and another paired-only device; assert only the former is attempted, and an explicit disconnect suppresses it. The tracker closure cited by the brief was not independently re-read here.

### Other QCA IDs

No new absent ID was established. NEXT `drivers/bluetooth/btusb_main.c:274–318` already includes the ROME entries `0cf3:535b/e007/e009/e010/e300/e301/e360/e500`, `0b05:1825/1868`, `0489:e092/e09f/e0a2`, `04ca:3011/3015/3016/301a/3021`, `13d3:3491/3496/3501/3503`. This is a table inventory, **not proof every entry is QCA9377**, and not an exhaustive hardware-probe survey. A Wi-Fi PCI QCA9377 ID is insufficient to establish its Bluetooth USB identity or firmware protocol. A future candidate needs actual USB descriptors and ROM/version/firmware evidence before assigning ROME flags. This low-priority survey remains incomplete.

## Additional source findings and next action

1. **I12 is broader than add/remove alone.** The unlocked `list_empty()` in mesh completion and raw pointers across synchronous advertising operations need review alongside mutations. A local add-lock fix must not be described as a full advertising-lifetime fix.
2. **Mesh allocation errors can be obscured.** In NEXT `mesh_send_sync()`, a failed `hci_add_adv_instance()` stores `err` but continues into scheduling logic; if `instance` stays nonzero, the scheduler's result replaces that error. Return the allocation/add error immediately under the proposed lock discipline. This is source-confirmed error-path structure, not a newly reproduced externally visible failure; fault-inject the add to determine its effect.
3. **USB first-RX dependency is relevant to audio diagnosis.** It supplies a specific test for U8, but the observed host TX prevents casually treating it as the whole explanation.
4. **Repository source paths have moved upstream.** Automation looking only for `drivers/bluetooth/btusb.c` must account for NEXT's `btusb_main.c`/`btusb_qcom.c` split before declaring a quirk absent.

The highest-value next work is the deterministic **connect-B-before-Disconnection-Complete** SCO test, followed by the mesh cancellation lockdep test. U12 can proceed independently as a narrowly adapted and emulator-tested distribution backport. None of these conclusions licenses an upstream Tested-by without the specified actual test.

## Reproduction and source links

Source reads are reproducible with `git show <full revision>:<path>` and line numbering. Recreate U38 by applying the verified Ubuntu diff with `git apply -p1` restricted to `drivers/bluetooth/*`, `include/net/bluetooth/*`, `net/bluetooth/*`; preserve V7 separately. The published project helper `scripts/prepare-ubuntu-ksrc.sh` documents the same construction and checksum gate.

Patch-application checks used the exact Patchwork `diff` fields against copied NEXT files; no fuzz-editing or conflict resolution was used for the table. The arithmetic table uses `((seconds * 1000) % 65536) // 10`, followed by multiplication by 10 ms. No runtime behaviour is inferred from application success alone.

Primary repositories and patches:

* [Project at reviewed revision](https://github.com/ivoitovych/qca9377-bt-hang/tree/bd2f3cf46f1c3467f230bdfc428a41fdf1e3535b)
* [bluetooth-next](https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git/tree/?id=27731ba091954eccddb2657053b590d2113e8d98), [bluetooth](https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth.git/tree/?id=9b3b269829faa3a6264588cff6ef28da0ca5cee5), [mainline](https://github.com/torvalds/linux/tree/4cbdd58dfa7aaad679bf62f81cdbc96a6cb7c6ae)
* [Ubuntu source directory](https://archive.ubuntu.com/ubuntu/pool/main/l/linux-hwe-7.0/)
* [BlueZ U12 commit](https://github.com/bluez/bluez/commit/a14d59725ef35d91b8504770046c701d0a2efe07), [BlueZ 5.72](https://github.com/bluez/bluez/tree/770ad5614e7e8074133e6f563495ce4822f63fe4)
* [PipeWire 1.0.5](https://github.com/PipeWire/pipewire/tree/a2287be601710eea0d073261223ec34b92384c8a), [PipeWire master snapshot](https://github.com/PipeWire/pipewire/tree/e0ca5ed944df3ec73cd616787b0db3121116429a)
* [WirePlumber 0.4.17](https://github.com/PipeWire/wireplumber/tree/d3eb77b292655cef333a8f4cab4e861415bc37c2), [WirePlumber master snapshot](https://github.com/PipeWire/wireplumber/tree/9ac17bbcc7da60f10322ccaa07e5a6329dc33abc)
* [GNOME 46.7](https://github.com/GNOME/gnome-control-center/tree/9417bd3f9bb22473373f4631b2f21eb07c257273), [GNOME main snapshot](https://github.com/GNOME/gnome-control-center/tree/a7e126b2b82c10cabbf347561def01bbec033145)
* SCO series first patch [link removed: it carries a mail address], patch 6 [link removed: it carries a mail address]
* Putko [link removed: it carries a mail address], Hui Peng [link removed: it carries a mail address], Jiale Yao [link removed: it carries a mail address], Cen Zhang [link removed: it carries a mail address]
* [BlueZ issue 2562](https://github.com/bluez/bluez/issues/2562)

Access gaps: PipeWire issues #5506, #5476 and #1590 were not retrievable; their equivalence or discussion details are not asserted. The WirePlumber issue history supplied in the brief was not independently exhaustively re-read. Those gaps do not affect the pinned-source findings, but they prevent claiming a complete tracker/history review.
