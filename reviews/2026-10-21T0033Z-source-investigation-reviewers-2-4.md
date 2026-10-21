# Source investigation — reviewers 2, 3 and 4, checked against the source

**The task:** `2026-10-20T2332Z-source-investigation-task.md`.

**The answers, as received** (tooling marks and mail-address links removed by
`scripts/review-text-clean.py`; nothing else changed):
- `2026-10-21T0033Z-source-investigation-reviewer-2-verbatim.md`;
- `…-reviewer-3-verbatim.md`;
- `…-reviewer-4-verbatim.md`.

The first reviewer's answer and its check are in `2026-10-21T0009Z-source-investigation-reviewer-1.md`.

**Checked against:**
- bluetooth-next `27731ba09195`;
- Ubuntu `7.0.0-38` source (`cache/ubuntu-7.0.0-38`);
- PipeWire 1.0.5 (`cache/pipewire-upstream`);
- BlueZ 5.72 (`cache/bluez-upstream`, scratch worktree `tmp/research-20261021/bluez-5.72`);
- GNOME Settings 46.7 (`cache/gnome-control-center-upstream`);
- the patchwork diff of 14888791.

## Verdict

- **All four reviewers reach the same main result independently.** On U7, a new SCO connect
  reuses the old connection while its Disconnect is pending, so no setup is sent. The
  abandoned-setup series does not touch that path. PipeWire does not recover from the error
  that follows.
- **One detail is wrong in all four:** the old connection's state. It is not `BT_DISCONN` but
  `BT_CONNECTED` (RV1, below). The correction changes what the new socket sees: it is
  connected at once, rather than waiting.
- **Reviewer 4 is the strongest.** They pinned every tree, ran patch-application checks, and
  added three source findings that hold: the U12 backport recipe (RV6), the mesh error path
  (RV5) and the U4 caching guard (RV9).
- **Reviewers 3 and 4 found a separate btusb defect,** which the source confirms: one of two
  SCO links going down switches btusb to alternate setting 0 (RV3).

## RV1 — U7: the reused connection is `BT_CONNECTED`, and the socket is connected at once

**What all four say:** the old connection is `BT_DISCONN`, so `hci_connect_sco()` sends no
setup. Reviewers 2, 3 and 4 add that the new socket then waits in `BT_CONNECT`.

**What the source says:**
- `git grep BT_DISCONN` over `net/bluetooth` and `include/net/bluetooth` (bluetooth-next)
  finds the state set only on L2CAP channels, RFCOMM, ISO and SCO *sockets*, never on an
  `hci_conn`. The same holds for Ubuntu `-38`'s `hci_conn.c`, `hci_event.c`, `hci_sync.c` and
  `hci_core.c`.
- `hci_abort_conn_sync()` (`hci_sync.c:6058`) sends the Disconnect for a `BT_CONNECTED`
  connection through `hci_disconnect_sync()` (`hci_sync.c:5905`). That function waits for
  `HCI_EV_DISCONN_COMPLETE` and does not change the state.

So for the whole teardown window the old connection reads `BT_CONNECTED`. Then:
1. `hci_connect_sco()` returns it without a setup: the setup condition is `BT_OPEN` or
   `BT_CLOSED`, as all four say.
2. `sco_connect()` (`sco.c:417`) finds `hcon->state == BT_CONNECTED`, and marks the new socket
   **`BT_CONNECTED` immediately**.
3. At the Disconnection Complete, `sco_disconn_cfm()` → `sco_conn_del()` closes the socket
   with `bt_to_errno(reason)`. For 0x16 (Connection Terminated by Local Host) that is
   `ECONNABORTED` (`lib.c:128`).

Reviewer 3 predicted `ECONNABORTED`, and that prediction stands; only the path to it differs.

**PipeWire 1.0.5**, read here:
- `sco_do_connect()` retries only an *immediate* `ECONNABORTED` from `connect()`, twice
  (`backend-native.c:1440–1451`).
- `sco_ready()` reads `SO_ERROR` only when the connect returned `EINPROGRESS` (`1489–1498`).
- `sco_event()` on HUP or ERR sets the transport IDLE and closes the socket, with no new
  connect (`1653–1669`).

So PipeWire takes the "connected" socket as ready, and then loses it to the old link's
teardown, with no retry. This matches the earbuds' silence in `EX-060`.

**The `-EBUSY` alternative** (reviewers 2 and 4): `sco_chan_add()` refuses if the old socket
is still attached. PipeWire frees the old transport before it connects, and `sco_chan_del()`
clears `conn->sk`, so the attached case needs the close to lag. Either way the connect
fails. A socket-level trace tells which.

**For a kernel patch:** `hci_abort_conn()` sets `conn->abort_reason`. That field, not a
state, is the observable mark of a connection being torn down. A fix can refuse to hand such
a connection to a new connect, or defer the connect until the teardown completes. Reviewer 4
warns against a second, indistinguishable connection to the same address.

**Status:** CO-02. The reproducer must also record the second socket's `connect()` return and
`SO_ERROR`.

## RV2 — the two SCO messages (all agree; nothing new to verify)

- "corrupted SCO packet" also fires for data of a deleted connection.
- The 4 to 6 s cases are not explained by queued URBs.
- **Reviewer 3:** the corrupted packets are on the controller → host (microphone) side, so
  they cannot by themselves explain silent playback.
- **Reviewer 4** adds that PipeWire 1.0.5's `sco_start_source()` waits for the first received
  packet before sending, which ties output to input at start. That is not read here.

**Next (CO-20):** one hang-up with btusb dynamic debug, usbmon and btmon, to time the
Disconnection Complete, btusb's switch to alt 0 and each late packet.

## RV3 — btusb with two SCO links: one going down switches the other off (confirmed in source)

**Reviewers 3 and 4.** Ubuntu `-38`:
- **`btusb_notify()`** (`btusb.c:2245–2255`) stores `air_mode = evt` whenever the SCO count
  changes, including when it drops from 2 to 1 with `HCI_NOTIFY_DISABLE_SCO`.
- **`btusb_work()`** (`2360–2411`) chooses an alternate setting only for `ENABLE_SCO_CVSD` or
  `ENABLE_SCO_TRANSP`. With a count above 0 and `air_mode` DISABLE, `new_alts` stays 0, and
  it switches to alternate setting 0 while a link remains.

So the defect patch 6's cover letter names is real in source, and separate from the series.
Reviewer 3 adds a caution: "ignore DISABLE while count > 0" is wrong when the two links use
different air modes; the mode must come from the surviving connections.

**Status:** CO-21 moves from idea to source-confirmed; a test needs two SCO links at once.

## RV4 — Igor Putko's 14888791: the lock order (confirmed from the diff)

**Reviewers 2, 3 and 4.** The diff (patchwork API) takes `hdev->lock`:
- in `mesh_next()`, which also runs as the destroy callback of `hci_cmd_sync_clear()` under
  `cmd_sync_work_lock`;
- **and** in `mesh_send_start_complete()`'s error branch, before the `err != -ECANCELED`
  test (reviewer 4's addition, confirmed).

It also leaves `list_empty(&hdev->adv_instances)` in `mesh_send_done_sync()` outside the new
lock (reviewer 4, confirmed).

**The verdict, shared:** no Tested-by if our device-removal lockdep case reports the
inversion.

**Test order:** the four reviewers disagree. Reviewer 4 ran actual `git apply` checks; their
result is not re-run here:
- Hui Peng and Putko conflict with each other in either order;
- Cen Zhang, then Putko, then Jiale Yao apply mechanically.

## RV5 — `mesh_send_sync()` swallows a failed add (new, confirmed)

**Reviewer 4.** In bluetooth-next `mgmt.c:2342–2379`, a failed `hci_add_adv_instance()`
stores `err` and goes on. If `instance` stays nonzero, the function returns
`hci_schedule_adv_instance_sync()`'s result instead. The error is lost, and an instance that
was never added gets scheduled. The source structure is confirmed; the visible effect is not.

**Status:** a new item, CO-26. It belongs with the I12 patch (CO-05): return the add error
immediately, under the new lock.

## RV6 — U12: the backport recipe (confirmed)

**Reviewer 4.**
- **On 5.72 alone:** `a14d59725` fails, as found earlier.
- **After `3d9900eb7`** ("transport: Delay existence based on delay reporting capability"),
  applied to the scratch 5.72 tree: its `transport.c` hunks apply at small offsets (its
  `avdtp.c`/`.h` hunks too). Then `a14d59725`'s hunks 1 to 5 apply, and only the last fails,
  on the `A2DP_OPS` macro (`transport.c:2280`), which later gained a delay parameter.

So the backport is one file, plus the `transport_a2dp_get_stream()` helper part of
`3d9900eb7` (not its delay-reporting feature), plus a hand-wired `A2DP_OPS` line.

**Reviewer 3:** `a14d59725` introduces its own `resume_id`/`cancel_resume`/`cancel_id`; it has
no semantic prerequisite.

**Companions to audit** (reviewer 4, not checked here): `664a5d3785a1`, `aa118e965b02`,
`47da1efdc584`, `87ad4c66b934`.

**Reviewer 3 corrects reviewer 1:** WirePlumber master still has
`bluetooth.autoswitch-to-headset-profile`. Not checked here.

**Status:** CO-03.

## RV7 — M-2: the arithmetic and the reach (confirmed)

- **Reviewer 4's table** (65 → 6500 units; 66 → 46; 120 → 5446; 655 → 6517; 656 → 64;
  8192 → 0, unlimited; 65535 → 6453): recomputed with `((s × 1000) mod 65536) / 10`, and all
  seven rows hold.
- **Reviewer 2's** 60 s row was wrong, and they corrected it themselves.
- **MGMT Add Advertising** (`mgmt.c:9108–9121`) reads the `u16` timeout and checks only
  "powered" and "busy". There is no cap, so any value reaches the instance.
- **The partial fix trap,** shared by reviewers 2, 3 and 4: widening to `u32` fixes 66 to
  655 s, but not values above the HCI field's 655.35 s. The patch needs a host-side lifetime
  and a test above 655 s.

**Status:** CO-12.

## RV8 — U10: the four-cell test, with equal-bitrate pairs (arithmetic confirmed)

**Reviewer 4's** frame sizes at 48 kHz, 16 blocks, 8 subbands:

| configuration | frame | bitrate |
|---|---|---|
| Dual Channel, bitpool 26 | 116 bytes | 348 kb/s |
| Stereo, bitpool 52 | 116 bytes | 348 kb/s |
| Joint Stereo, bitpool 51 | 115 bytes | 345 kb/s |
| Dual Channel, bitpool 39 | 168 bytes | 504 kb/s |

These hold by the SBC frame-length formula, and the last matches our own record of 168-byte
frames. The test that separates channel mode from bitrate is then:
- Dual 26 against Stereo 52, at equal bitrate;
- then Dual 26 against Dual 39.

**Reviewer 2** adds a separate candidate: no check for an inverted bitpool range in
`codec_select_config()`. Not checked here.

**Status:** CO-08.

## RV9 — U4: the profile list is cached per device object (confirmed for 46.7)

**Reviewer 4.** GNOME Settings 46.7, `cc_profile_combo_box_set_device()`
(`cc-profile-combo-box.c:96`): `if (device == self->device) return;`. A device whose profiles
change while it stays the same object keeps its old list and row visibility. Reviewer 4 says
`main` keeps the guard in `cc-profile-combo-row.c`; that is not checked here.

**Status:** CO-17.

## RV10 — a correction to our own record

Reviewer 4 is right: `docs/issues.md` U7 says "Not a controller or kernel defect: no HCI
command was issued for it to fail". RV1 shows the kernel itself is what issues no command.
Corrected there today, with a dated note.

## Not verified here

- Reviewer 4's patch-application table for the mesh patches.
- Their PipeWire master line numbers.
- Reviewer 3's WirePlumber master `find-selected-default-node.lua`.
- The four BlueZ companion commits.
- Reviewer 2's SBC bitpool inversion.
- GNOME `main`.

Each is noted in its dossier as a reviewer's claim.
