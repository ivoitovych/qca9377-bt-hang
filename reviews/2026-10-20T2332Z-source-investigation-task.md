# Source investigation task — the open Bluetooth defects on a QCA9377 (`13d3:3503`) laptop, 2026-10-20

*The brief for outside reviewers, written 2026-10-20T23:32Z. It follows
`SOURCE-REVIEW-TASK.md` (2026-09-26), whose answers
(`2026-09-26-source-review-report.md`, `2026-09-26-source-review-followup.md`) pointed the
work that solved `BT-1`. The list of items comes from
`2026-10-20T2309Z-contribution-opportunities.md`.*

## What is asked

A **source-code investigation** of the code involved in the defects this project still has
open: the Linux Bluetooth subsystem and btusb, BlueZ, PipeWire's Bluetooth backend,
WirePlumber, and GNOME Settings' Sound panel. The observations are recorded and
re-runnable. For most items, the missing piece is the **mechanism**: which function, which
state, which ordering produces what we see. We want to turn each one into an upstream
contribution: a patch, a test, a precise report, or a request to a distribution.

Please **check out the code and read it**; do not rely on this brief alone. For each item,
tell us:
- which code participates in the observation (tree, commit, file, function, line);
- what in that code explains the observation, and what does not;
- how sure you are, and what would falsify your reading;
- what a fix would look like, and where it belongs (kernel, BlueZ, PipeWire, WirePlumber,
  GNOME, or Ubuntu);
- the one experiment that would decide it. Prefer QEMU with `hci_vhci` or BlueZ's emulator
  testers; next best is a capture we may already hold.

**Findings that contradict this brief are as welcome as ones that support it.** "I read X
and it cannot be the cause" is a result. If the code shows a defect we have not listed, tell
us. The 2026-09-26 review found the setup-command correlation that way.

## The machine and the evidence

- **Laptop:** AMD Renoir, xHCI; the Bluetooth controller is on USB bus 3, port 3, at full
  speed (12 Mb/s).
- **Controller:** Qualcomm QCA9377 "ROME", USB `13d3:3503` (IMC Networks). The isochronous
  interface has alternate settings 1 to 5 and no 6.
- **Kernel:** Ubuntu `7.0.0-38-generic` (v7.0 plus the `linux-hwe-7.0`
  `7.0.0-38.38~24.04.4` delta). btusb is replaced by "E3": stock btusb plus exactly the
  upstream entry `dc16388d45ec`, so the device runs as `BTUSB_QCA_ROME |
  BTUSB_WIDEBAND_SPEECH`. The QCA rampatch and NVM load (`QCA: patch rome 0x302 build
  0x3e8`). The ROME setup sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`, so SCO links are
  set up with the legacy `Setup Synchronous Connection` (`0x0428`).
- **Userspace (Ubuntu 24.04):**
  - **BlueZ:** 5.72. The running daemon is a local build of `5.72-0ubuntu5.5`'s source plus
    two fixes since applied upstream (`a734b06059cb`, `0bed9886cff3`); the packaged
    `5.72-0ubuntu5.8` is installed but not running.
  - **PipeWire** `1.0.5-1ubuntu3.3`; **WirePlumber** `0.4.17-1ubuntu4.1`; **GNOME Settings**
    `1:46.7-0ubuntu0.24.04.6`.
- **Headsets:** Sennheiser MOMENTUM 4, Shure AONIC 50, Lenovo thinkplus GM2 Pro earbuds; a
  Tronsmart T8 speaker.
- **Repository:** <https://github.com/ivoitovych/qca9377-bt-hang>. Read `BRIEF.md` first: the
  current state and the **retracted claims (§5), which must not be re-asserted**. Then
  `docs/STATUS.md` (one row per issue and submission) and `docs/issues.md` (each issue's
  evidence). `evidence/exhibits/` holds the exhibits; each gives the command that produced
  its output.
- **Trees to read against:** for the kernel, `bluetooth-next` and `bluetooth` on
  git.kernel.org, mainline, and Ubuntu's `linux-hwe-7.0` source. Then BlueZ master and tag
  5.72; PipeWire master and 1.0.5; WirePlumber master and 0.4.17; GNOME Settings `main`
  and 46.7.

**Settled; no review needed:**
- `BT-1`, the controller dying on the first command after a wideband SCO stream starts: its
  cause was the missing device-table entry, fixed upstream by `dc16388d45ec`, with 0 command
  timeouts in every SCO link since that fix was loaded (BRIEF §0, `docs/STATUS.md`).
- `BT-7`, `BT-8` and `BT-9`: fixed upstream, partly by us.

## The items, in priority order

### 1. `U7`: after an HFP codec switch made during a call, no new SCO link is ever set up

**Observed** (`EX-060`, [`evidence/exhibits/060-hfp-codec-switch-reply-before-old-link-gone.md`](../evidence/exhibits/060-hfp-codec-switch-reply-before-old-link-gone.md)).
On the earbuds, both mSBC → CVSD switches made while the mSBC link was up ended in silence:

| switch | `Disconnect` Command Status | headset `AT+BCS=` | AG `OK` | old link's Disconnection Complete | `Setup Synchronous Connection` |
|---|---|---|---|---|---|
| earbuds, 1 | +2 ms | +16 ms | +17 ms | +177 ms | **none** |
| earbuds, 2 | +3 ms | +30 ms | +30 ms | +205 ms | **none** |
| MOMENTUM 4, 1 | +5 ms | +67 ms | +67 ms | +39 ms | +91 ms |
| MOMENTUM 4, 2 | +5 ms | +75 ms | +75 ms | +46 ms | +101 ms |

What separates failure from success is whether the old link is gone **before** the new
connect. PipeWire's new transport connects about 25 to 30 ms after `OK`. On the earbuds that
moment falls inside the old link's teardown, and **no HCI setup command is ever sent**.
Nothing retries after the teardown completes. The test stream and the panel's meter both
linked to the new node.

**Questions:**
- **The kernel.** In `sco_connect()` → `hci_connect_sco()` (`net/bluetooth/sco.c`,
  `hci_conn.c`): what happens when a SCO socket connects to a peer whose previous SCO/eSCO
  `hci_conn` is in `BT_DISCONN`? Is the closing connection found by address and reused, so
  no setup is sent? Then the Disconnection Complete
  (`hci_disconn_complete_evt()` → `hci_conn_del()`) deletes it under the new socket. What
  error, if any, does the new socket see, and when?
- **Hitalo Souza's series.** "[PATCH v3 0/6] Bluetooth: Fix SCO setup failures after an
  abandoned setup" (linux-bluetooth, 2026-10-08; patchwork 14875449 to 14875454) handles a
  socket **closed while its setup is pending**. Does it also cover a connect **during the
  previous link's teardown**, or is that a separate case?
- **PipeWire 1.0.5.** In `spa/plugins/bluez5/backend-native.c` (the AG codec switch,
  `AT+BCS` handling) and the SCO connect/acquire path (`bluez5-device.c`, `sco-io.c`, the
  transport acquire): which code issues the new connect, what does it do on an error or on
  an `EPOLLHUP`/`SO_ERROR`, and is there any retry? Has master changed this since 1.0.5?
  The tracker items nearby: PipeWire #5506 and #5476; BlueZ #2562.
- **Where the fix belongs:** the kernel (wait for the old link, or fail the connect
  cleanly), PipeWire (wait for the old transport's link to close before connecting, or
  retry), or both.

### 2. "SCO packet for unknown connection handle" at most hang-ups, and "corrupted SCO packet"

**Observed, current boot** (`journalctl -k -b 0 -p err --grep "unknown connection handle"`;
`scripts/sco-ledger.sh 0`): 9 mSBC calls on the MOMENTUM 4, all hung up cleanly, 0
timeouts. The message came at the hang-up of 6 of the 9 (14 lines in all). Twice it came 4
to 6 s **after** the link ended: handle 10 at 11:55:51 after an end at 11:55:45; handle 17
at 00:12:37 after 00:12:33. Separately, `corrupted SCO packet` appears during some mSBC
links (`U8`: the earbuds, once the AONIC 50). On the earbuds, mSBC playback was silent.

**Questions:**
- Which code emits each message (`hci_core.c` SCO receive path; btusb's isochronous receive
  and reassembly, `btusb_recv_isoc()` / `h4_recv_buf()`), and under what conditions?
- At disconnection, what is the order between `hci_conn_del()`, btusb's switch back to
  alternate setting 0 (`btusb_work()`, `HCI_NOTIFY_DISABLE_SCO`), and the isochronous URBs
  already in flight? Can 27-byte buffers already queued in URBs on alt 1 be delivered after
  the connection is gone? Can they arrive seconds later?
- Is "corrupted SCO packet" on alt 1 (9-byte packets, 27-byte SCO buffers) a reassembly
  problem when a packet is lost or short, and would it explain silence in one direction?
- The same two lines appear in BlueZ #2562 on an Intel AX211. Is this generic, or specific
  to the alt-1 path?

### 3. The abandoned-setup series and btusb: its patch 6

Patch 6 of the series stops notifying the driver of a SCO link that never came up. Its cover
letter: "with btusb, that notification and the one for the connection's deletion right after
could stop the audio of another SCO connection. btusb can still do that when a SCO link that
was up goes down while another one stays up; that is not changed here." It also says patch 6
was not tested, because `hci_vhci` has no notify callback.

**Questions:**
- Read patches 1 to 6 against btusb's notify path (`btusb_notify()`, `btusb_work()`,
  `data->sco_num`, `air_mode`) for a QCA ROME device on the legacy setup command. Is any
  behaviour change visible on this laptop?
- What would a real-hardware test have to show for a Tested-by to be meaningful: which
  sequences, which log lines (btusb's dynamic debug prints the alt choice), which capture
  records?
- Is the remaining case (one of two SCO links going down) a defect worth its own patch?

### 4. Mesh: `hdev->adv_instances` changed without `hdev->lock` (`I12`), and the pending mesh patches

**Observed in QEMU** (`docs/mesh-tester-ci/STATE-MACHINE.md`, update block):
- With `lockdep_assert_held(&hdev->lock)` added to the advertising-instance add and remove
  functions, four call paths fire on bluetooth-next:
  - `mesh_send_sync()`;
  - ISO broadcast (`hci_add_per_instance()`);
  - Set LE off;
  - the advertising timeout (`hci_clear_adv_instance_sync()`).
- On a 4-CPU guest, KCSAN reports races on the list in 5 of 15 boots.
- No KASAN report and no corruption were shown.
- At device removal, lockdep reports a lock-order inversion (`cmd_sync_work_lock` →
  `unregister_lock`, from `mesh_next(-ECANCELED)` under `hci_cmd_sync_clear()`), but only
  with a scratch delay that keeps the tear-down entry queued.

**Pending upstream (all `new` on patchwork):**
- Igor Putko, 14888791, "Bluetooth: mgmt: Fix UAF in mesh_send_sync caused by race in mesh
  queue": takes `hdev->lock` in `mesh_send_done_sync()`, `mesh_next()` and
  `mesh_send_start_complete()`.
- Hui Peng, 14831271, which 14888791 contains.
- Jiale Yao, 14864878, the power-off case.
- Cen Zhang, 14880941, "Remove mesh cleanup from the socket destructor".

**Questions:**
- **The `mesh_send_sync()` fix:** what is the correct shape for `I12` there? Is it
  `hdev->lock` around `hci_add_adv_instance()` and the list walks, and how does it order
  against `req_lock` and against the HCI commands the function sends? Should the other three
  paths get their own patches?
- **14888791's new lock in `mesh_next()`:** `mesh_next()` also runs as a destroy callback of
  `hci_cmd_sync_clear()`, under `cmd_sync_work_lock`. Can the new `hdev->lock` there invert
  against any path that takes `hdev->lock` and then queues or clears command-sync work?
- **The four patches together:** do they conflict? Which one should be reviewed or tested
  first?

### 5. `M-2`: the extended-advertising duration overflow

In bluetooth-next, `hci_enable_ext_advertising_sync()` has `u16 duration = adv->mesh ?
adv->timeout : adv->timeout * MSEC_PER_SEC;`. `adv->timeout` is `__u16` seconds
(`struct adv_info`, `hci_core.h`). For a non-mesh instance with a timeout above 65 s, the
product truncates. Pauli Virtanen's `8a8d51eeedeb` ("Bluetooth: hci_sync: fix mesh adv
timeout units") fixed only the mesh case.

**Questions:**
- What does `duration` feed (units, and the HCI parameter's range)? What does the truncation
  do: a shorter advertisement, none, or a controller error?
- Can userspace reach a timeout above 65 s through MGMT Add Advertising?
- The 2026-10-05 review said "a timeout design, not a clamp". What is the right design?

### 6. `U12`: A2DP lost when a microphone opens during A2DP start, and its backport to 5.72

Fixed upstream by `a14d59725` ("transport: don't disconnect A2DP if canceling Acquire() with
Release()", Pauli Virtanen, 2024-11-02, first in 5.80; `EX-063`, `EX-064`).

**Questions:**
- Does `a14d59725` apply to 5.72's `profiles/audio/transport.c` alone, or does it depend on
  earlier changes between 5.72 and 5.80 (for example, the `cancel_resume` handling it
  touches)?
- Are there other fixes in that range on the same Release-during-Acquire path that a
  distribution backport should carry with it?
- Is WirePlumber 0.4.17's switch to the headset profile at the moment an application records
  doing anything that 0.5.x no longer does?

### 7. `U11` / `U3`: a newly connected headset does not become the default output or input

This is WirePlumber by design. In 0.4.17's `module-default-nodes.c`, the stack of earlier
choices outranks a newly connected device (`7a1b48b7`). Master's `state-default-nodes.lua`
keeps the rule and makes it stricter. The tracker history: #352, #914 (open), #1005, #1036.

**Questions:**
- What is the smallest opt-in change, in master, that would let a newly connected device rank
  first until the user chooses something else, without the unwanted switches reported in
  #83, #221, #463, #629 and #840?
- Does PipeWire's `module-switch-on-connect` already do what is needed? What are its side
  effects for inputs?

### 8. `U10`: a speaker silent on SBC-XQ

The Tronsmart T8 advertises Dual Channel at bitpool 53. PipeWire builds SBC-XQ from that (48
kHz Dual Channel, bitpool 39, 504 kb/s), and the speaker accepts and starts the stream. The
operator reports silence on SBC-XQ (not yet confirmed by a marked test).

**Questions:**
- **The offering logic:** where does PipeWire decide to offer SBC-XQ (`a2dp-codec-sbc.c`, the
  media-codec selection), and what does it check of the remote's capabilities?
- **The quirk list:** how have entries been added to `bluez-hardware.conf`'s
  `no-features = [ sbc-xq ]` list, and what evidence did maintainers ask for?
- **Testing it:** is there a better test than ours (Dual Channel at a low bitpool against
  joint stereo at a high one) to separate the channel mode from the bitrate?

### 9. Lower priority, only if cheap

- **`U4`:** the Configuration (codec) row disappears in GNOME Settings 46.7. The row is shown
  only when a device has more than one profile, and that is re-checked only when the active
  device changes (`cc-sound-panel.c`, `cc-profile-combo-box.c`). Is that the whole
  mechanism? Is it changed in `main`? GNOME #3710 is related.
- **`U2`:** the headset microphone's volume moves with no user action (0.00 → 0.27 → 0.08).
  Do WirePlumber's route-restore and PipeWire's HFP volume sync (`+VGM`) explain it?
- **`U9`:** no reconnect after Bluetooth is switched off and on. BlueZ's
  `plugins/policy.c` reconnects only after link loss or suspend, and BlueZ #294 was closed
  "not planned". Is there a narrow, acceptable opt-in?
- **Other QCA ROME / QCA9377 USB IDs:** `BT-1`'s cause was a missing table entry. Which
  QCA9377 / ROME USB Bluetooth IDs are known in the field (hardware-probe databases,
  distribution bug trackers) but absent from btusb's table today?

## What we would like back

1. **Per item:**
   - the participating code (tree, commit, file, function, line);
   - your reading, how sure you are, and its falsifier;
   - where the fix belongs;
   - the experiment you would run first.
2. **For items 1 to 3:** whether our `U7`, our unknown-handle messages and the
   abandoned-setup series are one problem, two or three.
3. **For item 4:** a reviewed shape of the `I12` fix, and your view of the order in which
   the four pending mesh patches should be tested.
4. **Anything else** the code shows that we have not listed.

**Constraints:**
- The laptop is in daily use, so experiments on it are short.
- Do not propose unloading, reloading or rebinding `btusb` or `bluetooth.ko` on the running
  system: a reload kills even a healthy controller here (`EX-046`). Kernel module changes go
  in through `/lib/modules/<release>/updates/` and a cold boot.
- Prefer QEMU, `hci_vhci` and BlueZ's emulator testers wherever they can decide the
  question.
- Nothing is sent upstream on the strength of a review alone: each finding is checked
  against the source and our captures first.
