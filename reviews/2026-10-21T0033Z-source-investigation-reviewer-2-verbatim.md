# Source investigation — the second outside reviewer's answer

*Received 2026-10-21 in answer to `2026-10-20T2332Z-source-investigation-task.md`. The text
is kept as received, with two changes, made by `scripts/review-text-clean.py`:
- the reviewer's tooling marks are removed: tracking parameters in links, favicon lines
  with their site labels, and HTML space entities;
- one link that carries a mail address is replaced by a note.

No finding was added or changed. What we checked and what holds:
`2026-10-21T0033Z-source-investigation-reviewers-2-4.md`.*

---

# Source investigation review — QCA9377 open Bluetooth defects

Review date: 21 October 2026 · Target: Linux Bluetooth, BlueZ, PipeWire, WirePlumber, GNOME Settings · Hardware: QCA9377 USB 13d3:3503

## Executive findings

The strongest finding is in U7: a new SCO connection can attach to an HCI connection that is already being disconnected, without initiating a new HCI setup. I verified the relevant path in Linux source. This is a concrete kernel-side mechanism that explains the distinctive absence of `0x0428` in EX-060.

It is important to distinguish three kinds of result throughout this review:

- Source-confirmed: control flow or state handling directly demonstrated by code.
- Evidence-supported: a mechanism that fits the project's captures, but whose execution has not yet been demonstrated by instrumentation.
- Hypothesis: a plausible explanation that still needs a discriminating experiment.

I read the repository's `BRIEF.md`, including §5's retractions. In particular, I do not equate `0x0428` with CVSD, assume that isochronous data stopped during BT-1, or attribute the solved firmware problem to an established ROM-firmware mechanism.

The main contribution opportunities are not necessarily all patches. Some warrant a kernel fix with a regression test; others are better suited to userspace error recovery, a distribution backport, a hardware quirk, or a narrowly specified configuration option.

## 1. U7 — HFP codec switch during SCO teardown

Kernel mechanism identified

### 1.1 The decisive source path

The Linux source contains this sequence:

`net/bluetooth/hci_conn.c`, `hci_connect_sco()`, master lines 1864–1910

```
sco = hci_conn_hash_lookup_ba(hdev, type, dst);
if (!sco) {
    sco = hci_conn_add_unset(...);
}
```

Later:

```
if (acl->state == BT_CONNECTED &&
    (sco->state == BT_OPEN ||
     sco->state == BT_CLOSED)) {
    ...
    hci_sco_setup(acl, 0x00);
}
```

There are two independent conditions with important consequences.

First, the lookup is by peer address and link type, not by the readiness of the connection for a new setup. A pre-existing connection in `BT_DISCONN` can therefore be returned.

Second, `BT_DISCONN` does not satisfy the condition that initiates `hci_sco_setup()`.

Thus, if an old SCO connection remains registered while its disconnection is pending, the next connect can reuse it without sending any new HCI setup command.

This is a significantly stronger explanation than a generic timing race. It identifies exactly which state prevents the command from being generated.

### 1.2 What happens to the socket?

`net/bluetooth/sco.c`, `sco_connect()`, lines 336–430; `sco_chan_add()`, lines 321–334

`socket.connect()` reaches `hci_connect_sco()`, then obtains a `sco_conn` and calls `sco_chan_add()`.

There are two distinct cases:

1. The existing `sco_conn` still owns its previous socket. `sco_chan_add()` detects `conn->sk` and returns `-EBUSY`. The attempted new connection fails synchronously.
2. The old socket has been detached, but the HCI connection remains. The new socket can attach to the old connection. Because its HCI state is `BT_DISCONN`, the new socket enters `BT_CONNECT` without a new setup command.

These cases must not be conflated.

`net/bluetooth/hci_event.c`, `hci_disconn_complete_evt()`, lines 3422–3512

On a successful Disconnection Complete, the kernel sets the HCI connection to `BT_CLOSED`, invokes the protocol disconnection callback, and deletes the connection.

Consequently, an incoming disconnection completion can terminate the newly attached socket rather than complete the connection it was expecting.

Confidence: high that this code path exists and can prevent a setup command; medium-high that it is the specific execution in EX-060. The missing evidence is the identity and state of the reused `hci_conn` at the moment of the second connect.

This is a separate trigger from closing a socket while its initial SCO setup remains pending, although both concern stale or overlapping SCO connection lifetimes.

Source: [hci_conn.c](https://github.com/torvalds/linux/blob/master/net/bluetooth/hci_conn.c) · [sco.c](https://github.com/torvalds/linux/blob/master/net/bluetooth/sco.c) · [hci_event.c](https://github.com/torvalds/linux/blob/master/net/bluetooth/hci_event.c).

### 1.3 PipeWire 1.0.5 confirms the missing recovery path

The PipeWire tag `1.0.5` contains a particularly relevant sequence:

| Location                     | Source-confirmed behavior                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------------------------- |
| `backend-native.c:898–938`   | `AT+BCS` accepts the new codec, frees the existing transport, creates a replacement and sends `OK` |
| `backend-native.c:1420–1474` | `sco_do_connect()` opens a nonblocking SCO socket and calls `connect()`                            |
| `backend-native.c:1440–1451` | The immediate retry is restricted to `ECONNABORTED`, twice                                         |
| `backend-native.c:1479–1569` | `sco_ready()` obtains the pending socket error using `SO_ERROR`                                    |
| `backend-native.c:1653–1676` | `sco_event()` handles hang-up/error, changes transport state and closes the socket                 |
| `bluez5-dbus.c:2882–2912`    | Transport acquisition has an error counter, but this is not an autonomous reconnect timer          |

The important distinction is that the `ECONNABORTED` retries happen inside the initial `connect()` call. They do not recover an asynchronous failure discovered later through `SO_ERROR`.

The existing three-error limit similarly does not guarantee that PipeWire will initiate another acquire after the old SCO link disappears.

A difference between the AG accepting a codec switch and successfully establishing the replacement audio bearer is therefore possible.

Where the fixes belong: I would investigate both the kernel's state handling and PipeWire's recovery. A clean kernel rejection would improve correctness, but without an appropriate retry, a failed call could still remain silent.

Decisive experiment: Extend BlueZ `sco-tester` with a controller-emulator sequence in which the old SCO connection is marked disconnecting, a second socket connects to the same peer, and the old Disconnection Complete arrives afterward. Record the second socket's `connect()` result, `SO_ERROR`, state-change notification and all outgoing setup commands. Run this against the unpatched kernel and a candidate correction.

Source: [PipeWire 1.0.5 backend-native.c](https://github.com/PipeWire/pipewire/blob/1.0.5/spa/plugins/bluez5/backend-native.c) · [PipeWire transport acquisition](https://github.com/PipeWire/pipewire/blob/1.0.5/spa/plugins/bluez5/bluez5-dbus.c).

## 2. Unknown SCO handle and corrupted SCO packets

Related receive-path symptoms, not proof of one defect

I verified both error paths against Linux v7.0, the mainline base relevant to the laptop.

### 2.1 “SCO packet for unknown connection handle”

`net/bluetooth/hci_core.c`, `hci_scodata_packet()`, around line 3891 in v7.0

The diagnostic follows a call to `sco_recv_scodata()`, and specifically means that the receive path returned `-ENOENT` for the packet's connection handle.

It does not, by itself, imply a failed HCI command, a firmware hang, or an audio-codec error.

A packet can be received while its associated link is being removed. But the four-to-six-second observations are not adequately explained by claiming that ordinary USB isochronous URBs remain in flight for several seconds.

That would require additional evidence, such as actual late USB submissions, controller buffering, delayed log delivery or incorrect correlation between handles and link lifetimes.

There is another important complication: btusb already validates SCO handles before submitting reassembled frames upward. Therefore, a packet with an already-deleted handle will normally be rejected earlier, at the btusb reassembly layer.

An unknown-handle message from the upper layer warrants checking whether the handle was valid at the first lookup and became invalid before the second lookup, or whether some different path or state transition was involved.

Confidence: high about the meaning of the diagnostic; low about its precise hardware cause.

Fix location: not established. I would not propose a suppression patch before reproducing the condition.

Decisive experiment: In QEMU, hold an SCO receive frame between btusb's validation and `sco_recv_scodata()`, complete link deletion, then release the frame. Compare this with a frame presented only after deletion. Instrument both lookups, including handle, connection identity, and timestamps. If only the first sequence prints the upper-layer diagnostic, it explains the narrow race but not automatically the delayed real-world occurrences.

### 2.2 “corrupted SCO packet”

This diagnostic has a more direct explanation.

`drivers/bluetooth/btusb.c`, Linux v7.0

| Function / lines                          | Behavior                                                                                 |
| ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| `btusb_validate_sco_handle()`, 1341–1367  | Checks whether a reconstructed SCO header identifies an existing SCO/eSCO connection     |
| `btusb_recv_isoc()`, 1369–1425            | Reassembles an HCI SCO frame from isochronous fragments                                  |
| `btusb_recv_isoc()`, 1399–1412            | Rejects an invalid handle or oversized payload with `-EILSEQ`                            |
| `btusb_isoc_complete()`, 1641–1689        | Emits `corrupted SCO packet` when reassembly fails                                       |
| `btusb_switch_alt_setting()`, 2298 onward | Kills old URBs and clears an unfinished reassembly buffer on an alternate-setting change |

The comments in the source explicitly acknowledge that USB isochronous transfers can lose fragments, leaving the subsequent bytes misaligned with an HCI packet header.

For this controller, alt 1 offers nine bytes per USB service interval. If an HCI SCO frame is split across several USB packets, missing one fragment can corrupt the reassembly boundary.

However, the message does not prove a physical USB packet was corrupted. It also arises when the reconstructed header fails validation.

Confidence: high for the mechanism; medium that lost isochronous fragments explain the earbuds' observations; low that they explain the total silence.

Fix location: potentially btusb if a deterministic reassembly defect exists; potentially controller/USB behavior if transport loss is demonstrated. There is no basis yet for an audio-codec patch.

Decisive experiment: Feed `btusb_recv_isoc()` a known sequence of HCI SCO frames split into nine-byte fragments, then remove or truncate one middle fragment. Check whether the parser drops the damaged frame and resynchronizes correctly at the next valid header. This can initially be a targeted kernel test without real Bluetooth hardware.

### 2.3 Notification and USB teardown ordering

The v7.0 `btusb_notify()` path, lines 2242–2253, updates `data->sco_num` and schedules work when the counted number of SCO links changes.

`btusb_work()`, lines 2357–2417, selects an isochronous alternate setting when links are present, and otherwise kills anchored isochronous URBs and returns to alt 0.

This is asynchronous with respect to the HCI disconnection event. A short interval can therefore exist between connection deletion and completion of the USB teardown.

The code supports a bounded teardown race; it does not demonstrate several seconds of continued URB delivery.

Initial verdict: treat unknown-handle packets and corrupted reassembly as separate diagnostics until their capture timestamps and corresponding kernel state transitions show a shared cause.

Source: [btusb.c, v7.0](https://github.com/torvalds/linux/blob/v7.0/drivers/bluetooth/btusb.c) · [hci_core.c, v7.0](https://github.com/torvalds/linux/blob/v7.0/net/bluetooth/hci_core.c).

## 3. Hitalo Souza's six-patch SCO series

The v3 series of 8 October 2026 is explicitly about a SCO setup that has been abandoned while still pending. It addresses several ways that a subsequently completed old setup can be mistaken for a new one, remain orphaned in the controller, or disrupt another connection. The cover letter documents emulator tests using the legacy Setup Synchronous Connection command as well as other setup variants.

That is highly relevant to this laptop, which uses legacy `0x0428` after ROME setup.

But the specific U7 sequence is different:

U7 — new connect during teardown of an established link

Souza series — old setup is still pending

The series does not, on its face, correct `hci_connect_sco()` returning an already-disconnecting established connection. Its patch 6 is a distinct improvement: it limits notification of SCO air mode to a successfully established connection. Patch 6 diff [link removed: it carries a mail address].

### Hardware validation for patch 6

A meaningful hardware `Tested-by` should show more than successful compilation or an ordinary headset call. It should include an aborted or rejected setup, the driver notification sequence, the `sco_num` transitions, the selected USB alternate settings, and assurance that another already-running SCO connection is not inadvertently interrupted.

The series also acknowledges a remaining driver issue: with two active SCO connections, disconnecting one can still change the USB audio path for the other. That deserves a separate regression case. It should not be folded into the abandoned-setup fix without first establishing the intended `sco_num` and air-mode behavior.

For the laptop's real hardware tests, dynamic-debug output from `btusb` and the existing HCI capture are appropriate. Module changes must use the project's cold-boot deployment route, never live unloading or rebinding.

Verdict for items 1–3: there are at least three independently testable mechanisms: reuse of a disconnecting HCI connection (U7), stale/abandoned pending setup (the Souza series), and SCO receive/teardown handling. They may interact, but neither shared symptoms nor overlapping function names establish a single bug.

## 4. I12 — mesh advertising-list locking and pending patches

This is the strongest kernel contribution area after U7, but it is also the area where an apparently straightforward locking fix can introduce a new failure.

### 4.1 The locking violation is real

In the Linux source, the advertising-instance helpers explicitly require the caller to hold `hdev->lock`.

`net/bluetooth/hci_core.c`, master: `hci_find_adv_instance()` 1564; `hci_remove_adv_instance()` 1607; `hci_add_adv_instance()` 1674

Within `hci_add_adv_instance()`, the protected state includes the list structure, `adv_instance_cnt`, advertising data, timeout, duration, and mesh association.

Yet `mesh_send_sync()` in `net/bluetooth/mgmt.c`, lines 2325 onward, calls `hci_add_adv_instance()` from the command-sync worker without first acquiring that lock.

This is not merely an undocumented convention: the caller contradicts an explicit API precondition. The project's lockdep and KCSAN experiments provide independent evidence that concurrent access can occur.

Confidence: high for the missing locking; the KCSAN observations demonstrate races, not that memory corruption has already happened.

### 4.2 Recommended patch shape for `mesh_send_sync()`

I would not wrap all of `mesh_send_sync()` in `hci_dev_lock()`.

The function participates in a command-sync sequence, and parts of its work submit or await HCI operations. Holding the device mutex across those operations could invert lock ordering or cause deadlock.

The correct structure is narrower:

1. Enter with the existing command-sync context and its request serialization.
2. Acquire `hdev->lock` before examining advertising-list invariants, selecting/reusing an instance, calling `hci_add_adv_instance()`, and obtaining any list-derived state needed for the next operation.
3. Copy out scalar values, or otherwise establish safe lifetime ownership, before dropping the lock.
4. Release `hdev->lock` before executing HCI commands or any operation that expects to acquire it elsewhere.
5. On command failure, perform compensating list cleanup in a separately locked section, checking that the instance still belongs to the transaction being cleaned up.

That final ownership check is important. Merely locking `list_del()` cannot prevent a delayed failed transaction from deleting a newer transaction's advertising instance.

The existing lock ordering permits `req_lock → hdev->lock`; it does not make `hdev->lock → req_lock` safe.

The other three reproduced entry points — periodic/ISO advertising, Set LE off, and advertising timeout — should be reviewed as separate call-site corrections sharing one locking contract, rather than one enormous mesh patch.

For example, `hci_clear_adv_instance_sync()` in `hci_sync.c:489–543` traverses and removes advertising instances. It is called from the advertising-timeout command-sync worker at lines 545–555. That path needs a consistent locked list lifetime, while ensuring that subsequent HCI calls happen outside the mutex.

### 4.3 The hazard in Igor Putko's patch

The October 14 patch addresses a real additional race: `mesh_send()` can enqueue an object after seeing `HCI_MESH_SENDING` clear, while `mesh_next()` independently selects and enqueues that same object. Once one queued invocation frees it, the second invocation can dereference freed memory. The associated syzbot report contains an actual KASAN use-after-free, unlike the project's I12 list-race observations.




However, the proposed use of `hci_dev_lock()` inside `mesh_next()` needs a lock-order audit.

`mesh_next()` is also supplied as a destroy callback to `hci_cmd_sync_queue()`. A command-sync destroy callback can run under `cmd_sync_work_lock`, particularly during `hci_cmd_sync_clear()`.

The existing ordering includes:

`hdev->lock → unregister_lock → cmd_sync_work_lock`

The proposed reverse acquisition can create:

`cmd_sync_work_lock → hdev->lock`

Even when a particular teardown sequence makes a true deadlock unreachable, an inverted dependency remains a review problem. The same issue applies to `mesh_send_start_complete()` if it acquires the device lock when invoked as a canceled command's completion/destroy callback.

I would not approve Igor's patch unchanged without resolving this distinction.

A safer direction is to split completion handling into:

- a normal worker-context path that may acquire `hdev->lock`;
- a cancellation/destruction path that does not acquire the device mutex or submit replacement command-sync work under `cmd_sync_work_lock`;
- a separately scheduled recovery step if cancellation must cause another mesh transaction to start.

The transaction's queued/not-queued state also needs to be explicit. `HCI_MESH_SENDING` alone is not a complete ownership model.

### 4.4 Ordering the four pending patches

| Order | Patch                | Review decision                                                                                             |
| ----- | -------------------- | ----------------------------------------------------------------------------------------------------------- |
| 1     | Hui Peng, 14831271   | Establish the queue-failure leak/UAF control case first; verify exact patch and lifetime assertions         |
| 2     | Cen Zhang, 14880941  | Test socket-destruction cleanup separately; it addresses a different ownership boundary                     |
| 3     | Jiale Yao, 14864878  | Test power-off and failed scheduling on top of the validated lifetime baseline                              |
| 4     | Igor Putko, 14888791 | Integrate the genuine duplicate-queue fix only after revising or proving the destroy-callback lock ordering |

This is a testing and integration sequence, not a claim that the individual patches can simply be applied one after another.

Hui's queue-failure fix overlaps part of Igor's patch, so applying both unchanged would duplicate a correction. Jiale's synchronous failure handling could also interact with the completion and cancellation paths.

The important test matrix is the cross-product of queue failure, cancellation, socket closure, power-off, and an already queued next transaction.

### 4.5 Decisive I12 experiment

Use the existing four-CPU QEMU guest and the project's advertising-list assertions, but run an instrumented build with a narrowly locked `mesh_send_sync()` mutation section.

Require all of the following in the same controlled run:

- No lockdep violation on the newly protected list operations.
- No KCSAN race on `adv_instances`.
- No duplicate mesh transaction entering the command-sync worker.
- No stale advertising instance or mesh handle following failure.
- No ABBA report on device removal or power-off.

A KCSAN-negative run alone would not establish correctness. The cancellation and teardown transitions are essential.

Source: [mgmt.c](https://github.com/torvalds/linux/blob/master/net/bluetooth/mgmt.c) · [hci_core.c](https://github.com/torvalds/linux/blob/master/net/bluetooth/hci_core.c) · [hci_sync.c](https://github.com/torvalds/linux/blob/master/net/bluetooth/hci_sync.c).

## 5. M-2 — extended-advertising duration overflow

`net/bluetooth/hci_sync.c`, `hci_enable_ext_advertising_sync()`; mainline v7.0 lines 1550–1592, master around 1641–1680; relevant fix commit `8a8d51eeedeb`

I retrieved the actual diff of Pauli Virtanen's `8a8d51eeedeb`.

It changes the duration expression to:

```
u16 duration = adv->mesh ? adv->timeout :
                            adv->timeout * MSEC_PER_SEC;
```

That corrects the distinction between mesh milliseconds and ordinary advertising seconds, but it retains the 16-bit intermediate.

The HCI LE Set Extended Advertising Enable duration field uses units of 10 milliseconds, with a 16-bit range. The conversion is currently performed after the multiplication has already been truncated.

For example:

| Requested ordinary timeout | Correct HCI duration | Existing computed duration                                                                    |
| -------------------------- | -------------------- | --------------------------------------------------------------------------------------------- |
| 60 s                       | 6,000 units          | 5,899 units = 58.99 s                                                                         |
| 65 s                       | 6,500 units          | 6,500 units only if arithmetic does not wrap? No — 65,000/10 = 6,500, so this case is correct |
| 66 s                       | 6,600 units          | 46 units = 0.46 s                                                                             |
| 100 s                      | 10,000 units         | 3,446 units = 34.46 s                                                                         |

The first row illustrates why the arithmetic must be checked independently of the nominal 65-second threshold: 60 seconds fits the intermediate and should yield 6,000 units. The correct existing value is 6,000, not 5,899. Thus, the defect begins when the millisecond product exceeds 65,535, rather than at an earlier value.

The root bug is proven by arithmetic and source. This is not controller-specific.

The correct conversion for an ordinary instance begins with a wide type:

```
u32 duration_10ms = (u32)adv->timeout * 100;
```

But that is only the arithmetic fix. For an ordinary advertising timeout above the HCI field's representable duration, a design decision remains necessary.

The largest finite duration the controller can represent is 655.35 seconds. A zero duration has special meaning and must not be produced accidentally by overflow. A robust design should define whether longer MGMT lifetimes are managed through host-side expiration, segmented controller intervals or an indefinitely enabled controller instance plus a host timeout.

Recommended patch separation: one patch fixing the conversion and explicitly defining the over-range behavior, with a regression test for ordinary and mesh advertising. Do not silently clamp everything to 65 seconds.

Confidence: very high for overflow; MGMT reachability of the long timeout still warrants an explicit integration test rather than relying only on the `adv_info` type.

Decisive experiment: With an emulated extended-advertising controller, submit MGMT Add Advertising timeouts of 65, 66, 100, 655 and 656 seconds. Compare the requested MGMT lifetime, emitted HCI `duration`, and eventual host-side expiration. Include a 1,000-ms mesh advertisement as a regression control.

Source: [Exact upstream fix and diff](https://github.com/torvalds/linux/commit/8a8d51eeedebfa5aaaae7720f2fb2aa1a67b8587).

## 6. U12 — A2DP Acquire/Release race and the Ubuntu BlueZ 5.72 backport

`profiles/audio/transport.c`, BlueZ 5.72, especially `a2dp_resume_complete()` 371, `transport_a2dp_resume()` 416, `transport_a2dp_suspend()` 470 and `release()` 731

I retrieved the exact diff of commit [a14d59725](https://github.com/bluez/bluez/commit/a14d59725ef35d91b8504770046c701d0a2efe07) and compared it with tag 5.72.

The underlying failure is direct: when `Release()` arrives with `Acquire()` still pending, the older code removes the media owner and ultimately calls the A2DP cancellation machinery. Canceling the pending AVDTP START operation can lead to AVDTP ABORT, return the stream to IDLE and disconnect the A2DP profile.

The upstream fix changes the operation's meaning. It cancels the pending D-Bus acquisition response without aborting the already-started protocol transition, waits for the START operation to finish, then schedules SUSPEND.

### Can the fix be applied to 5.72 alone?

Semantically, its core mechanism is largely self-contained. Syntactically, the upstream commit is not a clean standalone backport.

The 5.72 source does not contain `a2dp->resume_id`, `cancel_resume` or `cancel_id`; the commit introduces these members. That alone is not a dependency problem.

But the commit also operates against a newer version of `transport.c` that has `transport_a2dp_get_stream()`, changes to the `TRANSPORT_OPS` macro and differences in the A2DP operations table. Those structures are not identical in 5.72.

Therefore, directly applying the commit or cherry-picking it without adjustment is not justified. It needs a 5.72-specific adaptation.

The minimal backport should preserve the core state transitions, add the new operation identifiers and cancellation callback, and use the existing 5.72 accessor and operation-table layout. There is no evidence from this comparison that all the intervening BlueZ feature commits must be backported.

I also would not assert that no other fixes are needed on this path: the intermediate commit history and test results have not been exhaustively audited.

Fix location: Ubuntu's BlueZ source package, with upstream-origin attribution and a narrowly adapted patch. BlueZ upstream already has the correction.

Confidence: high for the 5.72 mechanism and need for adaptation; medium on completeness of a single backport.

Decisive experiment: Run a BlueZ AVDTP emulator test that delays START completion, calls `Acquire()`, then `Release()`, and finally allows START to finish. The expected result is a canceled Acquire reply followed by SUSPEND, without AVDTP ABORT or an A2DP profile disconnect. Repeat with a subsequent SetConfiguration and Acquire to ensure reconfiguration still succeeds.

WirePlumber's automatic Bluetooth profile switching is the trigger in the reported scenario, not the owner of the faulty AVDTP cancel transition. Moving to WirePlumber 0.5 should not be considered a substitute for correcting this BlueZ behavior.

## 7. U11 / U3 — newly connected headset is not automatically the default

The requested behavior is a policy choice, not an unexplained failure.

WirePlumber 0.4.17, `modules/module-default-nodes.c`, lines 262–320; master, `src/scripts/default-nodes/state-default-nodes.lua`, lines 19–63

In 0.4.17, a node gets its ordinary session priority, but a match against the explicitly configured default receives a large additional preference. Earlier configured defaults also receive bonuses in stack order.

Specifically, `find_best_media_class_node()` adds:

```
prio += (N_PREV_CONFIGS - i) * 20000;
```

for a previous matching selection.

Master's `state-default-nodes.lua` continues that idea, assigning stored preferences a score derived from `20001 - i` and explicitly declining to let `priority.session` override the user's history.

### Smallest acceptable opt-in policy

I would implement a configurable newly connected physical-device preference, with these restrictions:

- Apply only to genuine hot-plug/hot-connect events, not devices discovered during initial session reconstruction.
- Restrict it to eligible physical sinks/sources, optionally Bluetooth only.
- Never override a new explicit selection the user makes afterward.
- Treat input and output separately, so connecting headphones need not unexpectedly replace a desired microphone.
- Suppress promotion during active streams/calls when an unexpected switch could disrupt communication.

The implementation belongs in WirePlumber's default-node selection policy, rather than in BlueZ or GNOME Settings.

PipeWire already offers `module-switch-on-connect`, which changes defaults when nodes appear. But it is a PulseAudio-compatibility mechanism, not precisely this policy: it also affects sources, ignores virtual devices by default, excludes HDMI by default, and its `only_from_unavailable` behavior is documented as not implemented.

I would not make it the default solution to U11/U3.

Confidence: high for the existing selection rule; medium for the proposed API until it has been reviewed against the policy architecture.

Decisive experiment: Create two emulated audio devices and one previously selected default, connect a third after session startup, then explicitly choose the original device. Verify promotion on connection, respect for the subsequent manual choice, separate source/sink behavior and no promotion after a session-restore event.

Source: [WirePlumber 0.4.17 default-node selection](https://github.com/PipeWire/wireplumber/blob/0.4.17/modules/module-default-nodes.c) · [Current selection policy](https://github.com/PipeWire/wireplumber/blob/master/src/scripts/default-nodes/state-default-nodes.lua).

## 8. U10 — Tronsmart T8 silent on SBC-XQ

PipeWire 1.0.5, `spa/plugins/bluez5/a2dp-codec-sbc.c`, lines 67–100, 127–176, 203–209 and 643–663; `bluez5-dbus.c`, lines 2398 onward

The source explains why the codec is offered.

SBC-XQ is not identified by a new A2DP codec ID: it is another configuration of ordinary SBC. PipeWire advertises it as `sbc_xq`, and the selection routine explicitly prefers Dual Channel among compatible SBC-XQ channel modes.

For 48 kHz Dual Channel, `default_bitpool()` returns 39 for SBC-XQ. The remote's advertised maximum bitpool of 53 therefore does not rule the configuration out.

At `codec_select_config()`, PipeWire intersects the remote's frequency and channel-mode capabilities, chooses the XQ preference, then limits the maximum bitpool to the selected target. It does not and cannot infer from these advertised capabilities that a particular speaker's decoder will actually play the configuration correctly.

This explains the offering; it does not establish that Tronsmart's decoder is defective, because the reported silence has not yet been established by a marked controlled test.

PipeWire's `bluez-hardware.conf` already contains `no-features = [ sbc-xq ]` device exceptions, including Motorola DC800, Motorola S305 and SoundCore 2. Several entries include their originating issue references. A narrowly identified device quirk would therefore follow an existing upstream practice.

Confidence: high for why SBC-XQ is offered; low-to-medium for the cause of silence.

Fix location: PipeWire's hardware-quirk configuration if reproducibly device-specific. A generic codec fix is justified only if the encoder or configuration is demonstrably invalid.

Decisive experiment: Compare four marked captures at the same output volume: ordinary SBC Joint Stereo, ordinary SBC Dual Channel, SBC-XQ Dual Channel at a reduced bitpool, and SBC-XQ Dual Channel at 39. Capture the selected AVDTP configuration and confirm whether RTP media packets actually leave the sender. This separates a channel-mode incompatibility from a bitrate-dependent problem and from an absent audio stream.

A device quirk should not be submitted solely on a remembered episode of silence.

Source: [SBC codec selection](https://github.com/PipeWire/pipewire/blob/1.0.5/spa/plugins/bluez5/a2dp-codec-sbc.c) · [Existing hardware exceptions](https://github.com/PipeWire/pipewire/blob/1.0.5/spa/plugins/bluez5/bluez-hardware.conf).

## 9. Lower-priority investigations

### U4 — GNOME Settings' Configuration row disappears

GNOME Control Center 46.7, `panels/sound/cc-sound-panel.c:171–209`; `cc-profile-combo-box.c`; current `main`, `cc-sound-panel.c:123–159`

The proposed mechanism is supported by source.

In 46.7, `output_device_update_cb()` and `input_device_update_cb()` update the profile combo box, count profiles, and show the corresponding row only when that count exceeds one.

Current `main` retains essentially the same condition, although the widget implementation has changed from a combo box to a combo row.

Thus a profile-set change that does not trigger the device-update callback can leave the visibility state stale.

Confidence: medium-high. The missing verification is whether another signal in the device-selection widget happens to invoke the callback for the specific changes observed.

Fix: GNOME Settings should refresh the profile list and row visibility when the active device's available profiles change, not only when device selection changes.

Decisive experiment: With a mocked mixer device, change its profile list from two entries to one and back without changing the selected device ID. Assert that row visibility follows the profile count. This belongs in GNOME's UI test infrastructure.

Source: [GNOME 46.7](https://github.com/GNOME/gnome-control-center/blob/46.7/panels/sound/cc-sound-panel.c) · [GNOME main](https://github.com/GNOME/gnome-control-center/blob/main/panels/sound/cc-sound-panel.c).

### U2 — headset microphone volume changes without user action

PipeWire 1.0.5, `backend-native.c`, `rfcomm_emit_volume_changed()` around line 394, `+VGM` parsing around 1216, and `rfcomm_ag_sync_volume()`

PipeWire handles HFP microphone gain using the RFCOMM volume synchronization path. It also synchronizes volume when a SCO connection becomes ready.

A separate WirePlumber route-restore operation could set the initial software volume as a device or profile appears.

These two mechanisms could explain a sequence such as `0.00 → 0.27 → 0.08`, but the observed numbers cannot be assigned to either mechanism from source alone. In particular, the value changes may involve translation between headset hardware gain and a software volume scale.

Confidence: medium for the participating mechanisms, low for the exact event sequence.

Fix: none indicated until the source of each volume update is known.

Decisive experiment: Record one microphone activation with time-aligned RFCOMM `AT+VGM`/`+VGM`, PipeWire transport-volume debug events, WirePlumber route changes and PipeWire node-volume properties. The first event preceding each change identifies which layer initiated it.

### U9 — no automatic reconnect after Bluetooth is switched off and on

BlueZ 5.72, `plugins/policy.c`, `disconnect_cb()` lines 743–785, `conn_fail_cb()` lines 802–828

The code explicitly restricts automatic reconnect to designated disconnection reasons: timeout and local-host suspend. A deliberate adapter power-off is not one of them.

`conn_fail_cb()` additionally abandons an active reconnect attempt when it receives `MGMT_STATUS_NOT_POWERED`.

So the missing reconnect after off/on is consistent with an intentional policy, not evidence that BlueZ forgot to resume an existing reconnect timer.

Confidence: high.

Fix: optional BlueZ policy, if upstream accepts the behavior. A narrow option might reconnect devices previously connected immediately before a user-initiated adapter-off transition, but only if they remain trusted and the user has enabled this policy. It should not automatically reconnect every paired device on every adapter activation.

Decisive experiment: An emulator test with two trusted devices, only one initially connected; turn adapter power off and on. Assert that an opt-in policy reconnects only the previously connected device, makes bounded attempts, and does not interfere with an explicitly requested disconnect.

Source: [BlueZ 5.72 policy.c](https://github.com/bluez/bluez/blob/5.72/plugins/policy.c).

### Other QCA9377 / ROME USB IDs

I verified the exact upstream fix `dc16388d45ec`, which adds `13d3:3503` alongside another IMC Networks ROME entry, `13d3:3501`, with both QCA ROME and wideband-speech flags.

There are several neighboring numeric IDs, but an adjacent USB ID is not sufficient evidence that the device is the same controller, and a QCA9377 Wi-Fi identifier is not sufficient to identify the Bluetooth USB part.

I cannot currently establish a new, unpatched QCA9377 Bluetooth USB ID with sufficiently corroborated hardware identity to recommend another table entry.

A suitable next investigation would cross-reference hardware-probe records and distribution bug reports against the exact btusb quirk table, requiring an HCI manufacturer/version report, relevant QCA firmware identity, and the actual USB ID for each candidate.

## 10. Additional source findings

Two observations merit recording beyond the project's stated hypotheses.

First: SBC-XQ negotiation lacks a clearly visible check for an inverted bitpool range. In PipeWire 1.0.5, `codec_select_config()` uses the greater of the remote minimum and the SBC minimum, then the lesser of the remote maximum and its preferred bitpool. It does not check at that point whether the resulting minimum exceeds the resulting maximum.

This is not evidence of the Tronsmart failure. It is a separate candidate for a small unit test: advertise a Dual Channel SBC sink whose minimum bitpool exceeds PipeWire's chosen SBC-XQ maximum and check whether configuration is rejected instead of constructing an inconsistent range.

Second: mesh correctness needs a transaction-lifetime model, not just stronger list locking. The current implementation represents several distinct conditions through list membership and the `HCI_MESH_SENDING` flag. These do not independently tell a destroy callback whether its queued work owns the transaction, whether that transaction has completed, or whether a successor is already queued. The reported duplicate enqueue and UAF are evidence that those distinctions matter.

A future structural correction could explicitly represent `QUEUED`, `RUNNING`, `COMPLETING`, and `CANCELED` states, with ownership transitions defined for each. That is a design direction, not a recommendation to replace the pending targeted fixes with a large rewrite.

## 11. Recommended contribution sequence

| Priority   | Contribution                           | First deliverable                                                            |
| ---------- | -------------------------------------- | ---------------------------------------------------------------------------- |
| P0         | U7 stale SCO connection reuse          | Kernel emulator reproducer and a trace confirming `BT_DISCONN` reuse         |
| P0         | Mesh transaction UAF and lock ordering | Review findings against Igor's patch, with destroy-callback lockdep evidence |
| P1         | I12 advertising-list races             | Narrow locking patch for `mesh_send_sync()` plus KCSAN/lockdep regression    |
| P1         | M-2 overflow                           | Exact HCI-duration test and conversion/lifetime proposal                     |
| P1         | U12 Ubuntu backport                    | 5.72-adapted BlueZ patch and Acquire/Release emulator test                   |
| P2         | U7 PipeWire recovery                   | Nonblocking SCO failure/retry test after establishing the kernel behavior    |
| P2         | SCO packet diagnostics                 | Two-level handle-lookup trace and isochronous reassembly test                |
| P2         | GNOME U4                               | Mocked profile-count change test                                             |
| P3         | U10 SBC-XQ                             | Marked Tronsmart test, then a quirk only if confirmed                        |
| Policy     | U11/U3 and U9                          | Small opt-in design proposals and behavior tests                             |
| Diagnostic | U2                                     | Correlated hardware/software microphone-volume trace                         |

For the four pending mesh patches, I would prioritize reviewing and testing Hui's cleanup, then Cen's socket-lifetime correction, then Jiale's power-off handling, before testing a revised Igor patch against their combined semantics. Apply only non-overlapping versions of the fixes.

### What would falsify the main conclusions?

The most consequential falsifiers are:

- U7: a trace shows the replacement socket receives a newly allocated `hci_conn` in a setup-eligible state, while no HCI setup is sent for an unrelated reason.
- SCO receive: an upper-layer unknown-handle error occurs with no intervening handle deletion or lookup/state discrepancy; that would demand a different receive-path explanation.
- I12: a purported list-race site is shown to have effective mutual exclusion from another invariant, including all concurrent readers and writers.
- Mesh locking: the proposed ABBA path is proven unreachable by a stable global invariant, rather than merely not appearing in ordinary runs.
- U12: the adapted BlueZ 5.72 patch still issues AVDTP ABORT during Release-after-Acquire despite the new pending-resume state tracking.
- M-2: the MGMT path rejects values beyond the safe range before they reach `adv->timeout`. That would narrow user reachability, although not remove the arithmetic defect.

## Review boundaries and corrections

One arithmetic correction to section 5: 60 seconds yields exactly 6,000 HCI units in the existing expression, because 60,000 fits in `u16`; the contradictory computed value in that table row is a transcription error. The 66-second and 100-second overflow examples remain correct.

I was able to retrieve and read the actual versioned source files through GitHub, including mainline v7.0, upstream master, PipeWire 1.0.5, BlueZ 5.72, WirePlumber 0.4.17, GNOME Settings 46.7, the relevant upstream commit diffs, and the project's repository documentation. I did not perform local Git checkouts, compilation or test execution. I also have not completed a line-by-line audit of the Ubuntu `linux-hwe-7.0` delta, the exact current `bluetooth-next` tip, or every intermediate BlueZ commit between 5.72 and 5.80. Therefore, this should be treated as a source-level external investigation, not a finished patch validation or a `Tested-by` result.

No repository files, branches, hooks or settings were changed, and nothing was submitted upstream.

Overall assessment: U7 has a strong source-identified failure mechanism, I12 and the mesh transaction races offer substantive kernel fixes but require careful lock ordering, M-2 is a demonstrable arithmetic defect, and U12 has a credible focused Ubuntu backport path. The receive-path messages should remain a separate investigation until correlated traces demonstrate otherwise.
