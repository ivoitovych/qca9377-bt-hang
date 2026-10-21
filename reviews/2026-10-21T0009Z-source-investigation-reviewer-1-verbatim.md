# Source investigation — the first outside reviewer's answer, verbatim

*Received 2026-10-21 in answer to `2026-10-20T2332Z-source-investigation-task.md`, and kept
as received. What we checked and what holds: `2026-10-21T0009Z-source-investigation-reviewer-1.md`.*

---

**Source investigation findings (kernel bluetooth-next, PipeWire 1.0.5, related trees as of this session).** I checked out the trees and read the relevant paths. Findings that contradict the brief are included. Confidence levels and falsifiers are noted. Nothing here is a patch; each needs a capture or emulator test first.

### 1. `U7`: no new SCO setup after HFP codec switch under an active link

**Participating code**
- Kernel (bluetooth-next): `net/bluetooth/sco.c:sco_connect()` (~238) → `net/bluetooth/hci_conn.c:hci_connect_sco()` (~1566). The critical path is the lookup:
  ```c
  sco = hci_conn_hash_lookup_ba(hdev, type, dst);
  if (!sco) { sco = hci_conn_add(...); }
  ...
  if (acl->state == BT_CONNECTED && (sco->state == BT_OPEN || sco->state == BT_CLOSED))
      hci_sco_setup(acl, 0x00);
  ```
  When an existing `hci_conn` for the peer is in `BT_DISCONN` (Disconnect sent, Disconnection Complete not yet received), the lookup reuses it, the hold is taken, but `hci_sco_setup()` is **not** called. No Setup Synchronous Connection (`0x0428`) is ever queued.
- Later, `hci_disconn_complete_evt()` → `hci_conn_del()` deletes that `hci_conn`. `sco_conn_del()` (sco.c) then calls `sco_chan_del()`, which sets `sk->sk_err` and `BT_CLOSED` on any socket that was attached.
- PipeWire 1.0.5 (`spa/plugins/bluez5/backend-native.c` AT+BCS handling ~898, and `sco_acquire_cb` ~1573): on successful BCS it frees/recreates the transport, emits `codec_switched(0)`, then the new transport’s acquire does `sco_do_connect()`. There is no retry on later `EPOLLHUP`/`SO_ERROR` after the old link’s teardown completes. Master has not materially changed this path since 1.0.5 (the nearby tracker items #5506/#5476 and BlueZ #2562 are the same race family).

**Reading**
The observation matches exactly: the new connect is issued ~25–30 ms after `OK`, which on the earbuds falls inside the old link’s teardown window. The kernel reuses the dying `hci_conn` by address and never sends a setup. The new socket later sees the deletion (error on the socket), but PipeWire does not retry. On the MOMENTUM 4 the teardown finished first, so a fresh `hci_conn` was created and setup was sent.

**Confidence**: high. Falsifier: a capture showing a Setup Synchronous Connection (or Enhanced) after the Disconnection Complete of the old link, or a kernel log of a new `hci_conn` being added while the old one is still in `BT_DISCONN`.

**Hitalo Souza series** (v3, patchwork 14875449–14875454, linux-bluetooth 2026-10-08): handles a socket closed *while its setup is still pending* (abandoned setup that can still complete and be matched by address to a new connection). It does **not** cover a connect that arrives while an already-established link is in `BT_DISCONN`. Related but separate case. Patch 6 (stop notifying the driver of a never-up SCO) is also orthogonal to this teardown-reuse path.

**Where the fix belongs**
Both places are valid; the cleanest long-term is the kernel (either wait for the old `hci_conn` to reach `BT_CLOSED` before allowing a new setup, or fail the new connect immediately with a distinct error so userspace can retry). PipeWire can also wait for the old transport’s link to disappear or retry on the error that arrives when the old `hci_conn` is deleted. A pure userspace retry is simpler to land and test.

**First experiment**
QEMU + `hci_vhci` (or BlueZ emulator tester): start an mSBC SCO, send Disconnect, then immediately issue a new SCO connect from a second socket before Disconnection Complete. Confirm no Setup command is sent and that the new socket later receives an error when the old conn is deleted. Then re-run after a short delay (after Disconn Complete) and confirm setup is sent.

### 2. “SCO packet for unknown connection handle” and “corrupted SCO packet”

**Participating code**
- “SCO packet for unknown connection handle”: `net/bluetooth/hci_core.c` (~3847, ratelimited) in the SCO receive path after the packet has been reassembled. The handle no longer maps to an `hci_conn`.
- “corrupted SCO packet”: `drivers/bluetooth/btusb.c` (~1296) when `btusb_recv_isoc()` fails (reassembly error on the isochronous data).
- Ordering at hang-up: `hci_conn_del()` can run while isochronous URBs that were already queued on the previous alternate setting are still in flight. Those URBs complete later and deliver 27-byte (or 9-byte on alt 1) buffers after the handle is gone. Seconds-later delivery is possible if the USB controller or host controller delays the completion. Alt-1 (9-byte packets into 27-byte SCO buffers) is particularly prone to short/lost-packet reassembly failures, which produce the “corrupted” message and can silence one direction.

**Reading**
Generic to USB Bluetooth isochronous SCO (also reported on Intel AX211 in BlueZ #2562). Not QCA-specific. The late unknown-handle messages are residual URBs; the corrupted messages on alt 1 are reassembly failures that can explain one-way silence.

**Confidence**: high for the mechanism; medium for “explains all silence” (needs a capture that shows short or incomplete isochronous packets coinciding with silence).

**Where the fix belongs**
Kernel (btusb and/or hci_core): more aggressive cancellation of in-flight isochronous URBs on `HCI_NOTIFY_DISABLE_SCO` / alt-setting switch, or simply drop SCO data for unknown handles without logging at error level after a grace period. Not a userspace issue.

**First experiment**
On the laptop (short): enable `btusb` dynamic debug, hang up an mSBC call, and correlate the unknown-handle lines with URB completion timestamps vs. the Disconnection Complete. In QEMU the same sequence with a delayed URB completion can reproduce the late messages.

### 3. Abandoned-setup series and btusb (its patch 6)

Patch 6 stops the driver notify for a SCO link that never came up. The cover letter correctly notes that btusb can still disturb another live SCO when one of two links goes down; that case is unchanged. On this QCA ROME device (legacy `0x0428` setup, `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`) the notify path (`btusb_notify` → `btusb_work` → `data->sco_num` / `air_mode`) is exercised, but the “never came up” notification is rare once the device-table entry is present. No behavioural change is visible on the laptop for the sequences we already have.

A meaningful Tested-by would need: two concurrent SCO links (or rapid setup/teardown), btusb dynamic debug showing the alt-setting choice, and a capture proving that one link’s teardown did not silence the other. The remaining “one of two SCO links going down” case is worth its own patch if it is still reproducible after the series lands.

**Relation of 1–3**: three distinct problems that share the “SCO state machine is racy around setup and teardown” root. U7 is the BT_DISCONN-reuse case; the unknown-handle messages are residual URB delivery; the series is the abandoned-pending-setup case. They are not one bug.

### 4. Mesh `hdev->adv_instances` without lock (`I12`) and pending patches

**Reading of the correct shape for the `mesh_send_sync()` path**
`hdev->lock` must be held around `hci_add_adv_instance()` and the list walks in `mesh_send_sync()`. The ordering against `req_lock` and the HCI commands the function sends needs care: take `hdev->lock`, do the list update, drop it, then queue the command-sync work (or hold it only for the list mutation). The other three paths (ISO broadcast `hci_add_per_instance()`, Set LE off, advertising timeout `hci_clear_adv_instance_sync()`) need their own small patches; they are independent.

**14888791’s new lock in `mesh_next()`**
`mesh_next()` runs as a destroy callback of `hci_cmd_sync_clear()` under `cmd_sync_work_lock`. Adding `hdev->lock` there can invert against any path that takes `hdev->lock` and then queues or clears command-sync work. That needs an explicit lock-order annotation or a different structure (work item that takes the lock outside the clear path).

**Order to test the four patches**
1. Igor Putko 14888791 (the UAF fix; contains Hui Peng 14831271).
2. Jiale Yao 14864878 (power-off).
3. Cen Zhang 14880941 (remove mesh cleanup from socket destructor).
They do not appear to conflict textually; the lock-order question in 14888791 should be resolved first.

**Confidence**: medium-high on the missing lock; the inversion risk needs a lockdep run.

### 5. `M-2`: extended-advertising duration overflow

In `hci_enable_ext_advertising_sync()`:
```c
u16 duration = adv->timeout * MSEC_PER_SEC;   // truncates for timeout > 65 s
set->duration = cpu_to_le16(duration / 10);   // HCI units are 10 ms
```
`adv->timeout` is `__u16` seconds. For a non-mesh instance > 65 s the product wraps; the controller sees a short (or zero) duration. Pauli Virtanen’s `8a8d51eeedeb` fixed only the mesh case (different units). Userspace can reach > 65 s via MGMT Add Advertising. The right design is a proper timeout type (or explicit clamp with a comment) rather than the current silent truncation; the 2026-10-05 review’s “timeout design, not a clamp” remark is correct.

**Fix belongs**: kernel. Experiment: MGMT Add Advertising with timeout 100 s and observe the HCI LE Set Extended Advertising Enable duration field.

### 6. `U12`: A2DP lost when microphone opens during A2DP start (backport to 5.72)

`a14d59725` (“transport: don't disconnect A2DP if canceling Acquire() with Release()”) touches the `cancel_resume` path in `profiles/audio/transport.c`. It does not apply cleanly to 5.72 alone; it depends on intermediate changes between 5.72 and 5.80. A distribution backport should also carry the related Release-during-Acquire fixes in that range. WirePlumber 0.4.17’s switch to the headset profile on record is more aggressive than 0.5.x; that contributes to the window.

**Fix belongs**: BlueZ (backport) + possibly a WirePlumber note. Experiment: apply only `a14d59725` to a 5.72 tree and see what else fails to compile or regresses.

### 7. `U11` / `U3`: newly connected headset does not become default

Confirmed by design in WirePlumber 0.4.17 `module-default-nodes.c` (earlier choices outrank a new device, commit `7a1b48b7`) and stricter in master’s `state-default-nodes.lua`. PipeWire’s `module-switch-on-connect` does the switch but has known side-effects on inputs (the history in #83, #221, #463, #629, #840). The smallest opt-in in master is a property that temporarily elevates a newly connected node until the user explicitly chooses something else, without changing the permanent ranking.

**Fix belongs**: WirePlumber (opt-in). Experiment: enable the property, connect a headset, confirm it becomes default, then manually select another sink and confirm the new headset does not steal it back.

### 8. `U10`: speaker silent on SBC-XQ

PipeWire offers SBC-XQ from the remote’s Dual Channel + high bitpool advertisement (`a2dp-codec-sbc.c` select path). The quirk list in `bluez-hardware.conf` (`no-features = [ sbc-xq ]`) has been extended case-by-case with device-specific evidence (issue numbers). A better test than “Dual Channel low bitpool vs joint-stereo high bitpool” is to force the exact SBC parameters the speaker accepted and compare against a known-good joint-stereo stream of similar bitrate; that separates channel mode from bitrate.

**Fix belongs**: PipeWire quirk (once confirmed). Experiment: marked test with the exact config the T8 accepted, plus a joint-stereo control.

### 9. Lower-priority items (cheap)

- **`U4`**: GNOME Settings 46.7 shows the Configuration row only when >1 profile and re-checks only on active-device change (`cc-sound-panel.c` / `cc-profile-combo-box.c`). Unchanged in `main` in the relevant logic; #3710 is related. Whole mechanism for the disappearance.
- **`U2`**: WirePlumber route-restore + PipeWire HFP `+VGM` sync can move the mic volume with no user action. Matches the observed 0.00 → 0.27 → 0.08.
- **`U9`**: BlueZ `plugins/policy.c` reconnects only after link loss or suspend; #294 closed “not planned”. A narrow opt-in (e.g. a property for “reconnect on adapter power cycle for previously connected devices”) is acceptable if it does not revive the old “reconnect everything” behaviour.
- **Other QCA9377 / ROME USB IDs**: the missing-table-entry class of bug (BT-1) is worth a sweep of hardware-probe databases and distribution trackers for `13d3:*` and other ROME IDs not in today’s `btusb` table. I did not complete that sweep in this session.

### Summary for items 1–3

U7, the unknown-handle messages, and the abandoned-setup series are **three** problems that share a racy SCO state machine. The series does not fix U7; the unknown-handle messages are residual URB delivery after deletion.

### Recommended next experiments (in order)

1. Emulator/`hci_vhci` reproduction of the BT_DISCONN-reuse case (U7).
2. Lockdep + KCSAN run of the mesh paths with the proposed `hdev->lock` placement.
3. Short btusb dynamic-debug capture of a hang-up to confirm residual URB timing.
4. Clean application test of `a14d59725` against a 5.72 tree.

I can go deeper on any single item (full function traces, exact line numbers against a particular commit, or a draft patch outline) if you want.
