# Source investigation — the third outside reviewer's answer

*Received 2026-10-21 as a report file in answer to
`2026-10-20T2332Z-source-investigation-task.md`. The text is kept as received, except that
the reviewer's tooling citation marks (59) are removed by `scripts/review-text-clean.py`. No
finding was added or changed. What we checked and what holds:
`2026-10-21T0033Z-source-investigation-reviewers-2-4.md`.*

---

# Source investigation of the open Bluetooth defects on the QCA9377 laptop

## Scope, baselines, and overall verdict

I treated the repository's current `BRIEF.md`, `docs/STATUS.md`, `docs/issues.md`, EX-060, and the October 20 contribution-opportunities document as evidence, not as conclusions to be repeated. In particular, I have **not** revived the retracted BT-1 claims: the project's present record says BT-1 was the missing `13d3:3503` btusb match/flags problem, fixed for this machine by `dc16388d45ec`, and the remaining work starts after that fix.

For source baselines, I read current Linux mainline at GitHub snapshot `4cbdd58dfa7aaad679bf62f81cdbc96a6cb7c6ae`, the Bluetooth code affected by the pending series, PipeWire tag `1.0.5` and current master `e0ca5ed944df3ec73cd616787b0db3121116429a`, BlueZ tag `5.72`, the parent and diff of BlueZ `a14d59725ef35d91b8504770046c701d0a2efe07`, and current WirePlumber at `9ac17bbcc7da60f10322ccaa07e5a6329dc33abc`. BlueZ master was `7bc9684dc9e45358661301da4a0ede433fdf0a30` in the source snapshot inspected.

One methodological limitation matters: the execution environment would not permit an actual network `git clone`, so I could not materialize local worktrees and run `git range-diff` or build/tests. I instead read exact repository blobs and commit diffs through repository access. The conclusions below distinguish things directly established by those blobs from things that still need your QEMU/hardware run. For the pending mesh patches, Patchwork itself was not retrievable, so the patch-specific review uses the exact diff descriptions already preserved in your repository plus the kernel code those diffs modify. That is sufficient to identify one serious lock-order issue, but not sufficient for a Reviewed-by.

The headline conclusions are:

| Item | Source-level verdict | Confidence | Best contribution |
|---|---|---:|---|
| **U7 codec-switch silence** | The brief's proposed kernel mechanism is correct: `hci_connect_sco()` reuses a same-peer SCO/eSCO `hci_conn` even when it is `BT_DISCONN`; it sends no setup for that state. The replacement socket is then torn down by the old link's Disconnection Complete, normally with `ECONNABORTED`. PipeWire has no retry for that **asynchronous** error, including current master. | **High** | Kernel regression test + kernel lifecycle fix; PipeWire retry is valuable defense-in-depth. |
| **Unknown-handle / corrupted SCO** | Two different receive-side conditions. Unknown-handle is core receiving SCO after its `hci_conn` has disappeared. `corrupted SCO packet` is btusb H4/isoc reassembly rejecting an invalid fragment/header/handle, explicitly including loss/desynchronization cases. | **High** | Instrument teardown; likely separate btusb/core report. |
| **Abandoned-setup v3 / patch 6** | Hitalo's series is **not the U7 fix**. Patch 6 fixes a failed/pending setup's spurious driver notification. It exposes a second btusb design defect when one real SCO of several disappears. | **High** | Hardware test of patch 6; separate btusb aggregate-air-mode patch. |
| **Mesh I12** | `adv_instances` really is being mutated from command-sync paths without its documented `hdev->lock`. Fix call sites narrowly; do not hold `hdev->lock` across HCI command waits. Igor's new lock in `mesh_next()` is unsafe until the `cmd_sync_work_lock → hdev->lock` teardown edge is resolved. | **High on I12; medium-high on pending-patch interaction** | Split locking patches + QEMU lockdep/KCSAN. |
| **M-2 duration overflow** | Real bug. A 66-second timeout becomes approximately **460 ms** before it even reaches the HCI 10-ms duration field. Merely widening the temporary only fixes part of the API range. | **High** | Kernel patch using host-side timeout for values beyond controller-duration range. |
| **U12** | `a14d59725` is logically backportable to 5.72 in `transport.c`; its `cancel_resume` machinery is introduced by that commit, not an external prerequisite. Some textual adaptation is needed. | **High** | Ubuntu/BlueZ backport with an Acquire→Release race test. |
| **U11/U3** | Current WirePlumber deliberately lets remembered user choices outrank ordinary newly available nodes. A small opt-in belongs in WirePlumber, not PipeWire's Pulse compatibility module. | **High on mechanism; medium on proposed API** | WirePlumber setting + policy test. |
| **U10** | The SBC-XQ capability decision cannot detect a speaker that advertises compatible Dual Channel/bitpool and then renders silence. A product quirk is appropriate only after a marked A/B test isolates mode versus bitrate. | **Medium-high** | PipeWire quirk after controlled codec matrix. |

The most important cross-item result is that **items 1–3 are not one bug**. They are three lifecycle problems that can meet at the same SCO teardown boundary: U7 is reuse of an established-but-disconnecting connection; Hitalo's series is abandonment while setup is still pending; unknown-handle/corruption is the receive path continuing or losing framing after connection-state changes. Treating them as a single root cause would obscure three separately testable fixes.

## SCO teardown, receive tails, and the abandoned-setup series

**U7 — connect during the old link's `BT_DISCONN` state.** EX-060 is unusually strong evidence because it separates the successful and failed orderings. For the Lenovo earbuds, `AT+BCS=1`/`OK` occur only 16–30 ms after Disconnect, the old Disconnection Complete does not arrive until +177/+205 ms, and there is no new Setup Synchronous Connection. With the MOMENTUM 4, Disconnection Complete occurs at +39/+46 ms, before `AT+BCS`/`OK`, and Setup Synchronous Connection follows at +91/+101 ms. That makes the race window a source-level question rather than a vague timing correlation.

In current Linux, `net/bluetooth/hci_conn.c:hci_connect_sco()` (mainline snapshot above, approximately lines 1716–1760) first looks up an existing SCO/eSCO `hci_conn` by peer address. If one exists it is reused. Setup is initiated only when the SCO object's state is `BT_OPEN` or `BT_CLOSED` and the ACL is connected. There is no branch saying “existing connection is `BT_DISCONN`, wait for it” or “return busy”; therefore an existing `BT_DISCONN` object is returned without sending either legacy Setup Synchronous Connection or Enhanced Setup. This part does **not** depend on the QCA legacy-command quirk: using `0x0428` determines which setup helper is eventually used, but U7 fails before any setup helper is reached.

`net/bluetooth/sco.c:sco_connect()` then attaches the new SCO socket to the returned connection, puts the socket in connecting state because the `hci_conn` is not `BT_CONNECTED`, and waits. There is therefore no necessary synchronous `connect(2)` error telling PipeWire to retry.

The decisive final step is `net/bluetooth/hci_event.c:hci_disconn_complete_evt()` (roughly lines 3208–3291): the old HCI Disconnection Complete changes that same connection to closed, runs the protocol disconnect callback and then `hci_conn_del()`. SCO's disconnect callback reaches `sco_conn_del()`/`sco_chan_del()`, closes the socket now attached to that dying object, and records the translated HCI reason as `sk_err`. For EX-060's `0x16` Local Host Terminated reason, Linux maps the reason to `ECONNABORTED`. Thus the concrete prediction is stronger than the brief's question: **the replacement PipeWire socket should become asynchronously failed with `SO_ERROR == ECONNABORTED` at the old link's Disconnection Complete.**

That prediction is a useful falsifier. Capture PipeWire's `getsockopt(SOL_SOCKET, SO_ERROR)` result on one failed switch. If it is not `ECONNABORTED`, or if Linux allocates a second `hci_conn` rather than returning the `BT_DISCONN` one, this reading is wrong. Given the code and EX-060 ordering, my confidence is **high**.

PipeWire completes the other half of the explanation. In `1.0.5`, `spa/plugins/bluez5/backend-native.c:rfcomm_hfp_ag()` handles `AT+BCS`: after validating the selected codec it tears down/replaces the transport and replies `OK`. The new transport's acquire reaches `sco_acquire_cb()` → `sco_do_connect()`. `sco_do_connect()` opens a nonblocking SCO socket and has a two-retry loop, but only for **an immediate `connect()` returning `ECONNABORTED`**; `EAGAIN`/`EINPROGRESS` are accepted as a pending connection. Later, `sco_ready()` reads `SO_ERROR`; any asynchronous error marks the transport failed. `sco_event()` handles HUP/ERR and closes the fd. There is no retry from that path.

That distinction explains why PipeWire's existing `ECONNABORTED` retry did not save the earbuds: the kernel accepts the nonblocking connect against the dying `hci_conn`, then produces `ECONNABORTED` only when Disconnection Complete arrives up to roughly 200 ms later. The retry loop has already returned.

Current PipeWire master has materially refactored this area but **has not removed this failure mode**. At `e0ca5ed944df3ec73cd616787b0db3121116429a`, `sco_do_connect()` still retries immediate `ECONNABORTED` only; `sco_ready()` still converts nonzero `SO_ERROR` into acquisition failure, and `sco_event()` closes a HUP/error socket rather than scheduling another connect. USB adapters still use incoming readiness while establishing the SCO socket.

**Where U7 should be fixed.** I would fix the kernel first. It is a bad socket abstraction for a fresh `connect()` to become attached to a connection object that is already committed to destruction. A minimal kernel patch can detect a same-address SCO/eSCO object in `BT_DISCONN` and refuse the new attempt with a documented retryable failure. A more complete kernel design would arrange a successor connect after teardown, but that is significantly more invasive.

I would **not** make the kernel return immediate `ECONNABORTED` and call the problem solved: PipeWire's current two immediate retries can all run before a 177–205 ms teardown finishes. The userspace side should therefore also treat an asynchronous `ECONNABORTED`/appropriate busy result during HFP codec replacement as transient and retry after a bounded delay or after observing teardown. The kernel fix makes the API sane; the PipeWire retry makes codec switching resilient.

The one experiment is a `hci_vhci`/emulator regression test: establish SCO A; issue Disconnect but deliberately withhold Disconnection Complete; close the old SCO userspace endpoint; call `connect()` on SCO B to the same address; assert baseline sends **no** new setup; then inject Disconnection Complete and assert B receives `ECONNABORTED`. A fixed kernel must instead either reject B immediately with the chosen retryable errno without attaching it to A, or hold B safely and emit exactly one new setup after A's completion. This needs no btusb hardware.

**Hitalo Souza's v3 series is a different state machine.** The October 8 cover letter describes a socket that is closed while its SCO setup is **pending**: the HCI command cannot simply be canceled, its late completion can be inherited by a replacement socket, and duplicate setup or orphaned connections follow. Patch 2's “don't set up a SCO link that is already up” addresses the replacement socket taking over a late successful setup. It does not change the `hci_connect_sco()` same-address lookup for an already-established connection in `BT_DISCONN`.

So U7 is **not covered by that series**. A clean falsifier would be to apply all six patches to the U7 vhci test above: if a connect made while the old established `hci_conn` is `BT_DISCONN` starts working, then some indirect interaction has been overlooked. From the diffs I read, I do not expect that result.

**The unknown-handle line has a straightforward emitter.** In `net/bluetooth/hci_core.c:hci_scodata_packet()` (approximately lines 3622–3651), Linux parses the SCO header and passes it to the SCO receive code. If lookup of the HCI handle finds no live connection, the receive helper returns `-ENOENT`, and core emits the ratelimited `SCO packet for unknown connection handle %d`. It therefore means what it says quite literally: **at host processing time**, there is SCO payload with a handle that is no longer in the HCI connection hash.

The teardown ordering makes short tails entirely plausible. `hci_conn` cleanup notifies `HCI_NOTIFY_DISABLE_SCO`; `drivers/bluetooth/btusb.c:btusb_notify()` (around lines 2218–2228) only updates `data->sco_num`/`air_mode` and schedules work. Actual isochronous shutdown happens later in `btusb_work()` (around 2327–2384), which kills anchored isoc URBs and switches the USB interface back toward alt 0. There is consequently a window after the core no longer recognizes the handle but before btusb's async worker has shut down the endpoint.

That explains unknown-handle messages **at hang-up** very well. It does **not** satisfactorily explain the messages four to six seconds later as “buffers that were already queued at teardown.” `btusb_submit_isoc_urb()` uses ten isochronous frames per URB and keeps a small URB pipeline; on a full-speed device that represents a millisecond-scale/tens-of-milliseconds-scale pipeline, not seconds. A 4–6 s delay needs something else: `btusb_work()` itself being delayed for seconds, the controller continuing or resuming delivery for a stale handle, or a distinct late lifecycle defect. Your ledger's two multi-second cases are therefore particularly valuable evidence rather than harmless duplicates.

The deciding hardware experiment is short and non-invasive: enable dynamic debug around `btusb_notify()`/`btusb_work()`/alt changes and collect usbmon plus btmon for one hang-up. Timestamp three points: HCI Disconnection Complete, btusb's switch to alt 0/URB kill, and each unknown-handle packet. If alt 0 occurs promptly but a new SCO USB-IN transfer carrying that handle appears seconds later, this is not an old host URB tail. If `btusb_work()` itself does not execute for several seconds, the host-side ordering is the lead.

**`corrupted SCO packet` is lower in btusb and is not synonymous with unknown-handle.** `btusb_isoc_complete()` iterates successful isochronous frames and calls `btusb_recv_isoc()`; a negative return causes the `corrupted SCO packet` message. `btusb_recv_isoc()` performs H4 SCO reassembly across USB isochronous fragments. Its own comment explicitly anticipates lost USB isoc fragments: after loss, a continuation fragment may be misread as the beginning of an HCI SCO packet, so the code validates the apparent SCO handle to detect desynchronization and returns `-EILSEQ` when the reconstruction is impossible. It also rejects impossible SCO payload lengths.

The code even clears `data->sco_skb` while changing alternate settings to avoid carrying a partially assembled HCI packet across endpoint geometry changes. That strongly supports “reassembly problem after a short/lost fragment” as a valid explanation for the message on alt 1; it does **not** prove that every instance is caused that way.

For your 9-byte-alt-1 / 27-byte-HCI-buffer case, losing one USB fragment can therefore desynchronize the assembly of a 27-byte transparent SCO packet. But note the direction: this is **USB isochronous receive, controller → host**. It can directly damage the headset microphone direction. It cannot directly explain host→headset playback silence merely because the log line exists. A playback failure would require a second effect—for example PipeWire abandoning the transport because the receive side becomes unusable. A marked simultaneous `arecord`/playback capture is the falsifier.

The appearance of the same kernel messages on non-QCA adapters also argues against a QCA-ROME-only defect. BlueZ #2562's abandoned-setup report is on Intel hardware and demonstrates that the same core/btusb diagnostics can arise from generic SCO lifecycle failures. That does **not** mean its root cause is U7.

**Patch 6 and btusb.** Patch 6 changes synchronous-connection completion so the HCI core notifies the driver of an SCO enable only after a successful setup; a failed setup therefore no longer generates an enable notification followed immediately by deletion/disable. The cover letter explicitly says this was not tested with vhci because vhci has no driver's `notify` callback.

That matters because btusb's notification state is lossy. `btusb_notify()` stores an aggregate `sco_num` plus the last `air_mode` event, and schedules `btusb_work()`. `btusb_work()` uses those values to select the USB alternate setting. A DISABLE event can leave `sco_num > 0` yet `air_mode == HCI_NOTIFY_DISABLE_SCO`; that combination drives the alt-selection logic toward no active SCO alternate setting. Patch 6 prevents a **failed never-established** SCO connection from creating that destructive pair, but a legitimate established connection going down while another remains can still create it.

That remaining 2→1 case is worth its own patch. I would avoid the tempting fix “ignore DISABLE whenever `sco_num > 0`”: it works only if all surviving SCO links happen to require the same transport mode. The structural fix is for btusb to derive the required mode from the **surviving SCO/eSCO connections**, or for the core's notification contract to provide enough aggregate information to do that. A single remembered “last air-mode notification” cannot faithfully represent multiple simultaneous SCO links.

For a meaningful `Tested-by` on patch 6, keep SCO A streaming, provoke SCO B's setup to fail, and record: B's failed Setup/Enhanced Setup completion in btmon; A remaining connected; dynamic-debug output showing the selected btusb alt setting; and uninterrupted audio/USB isoc traffic for A. Then separately start two live links if the controller permits it and tear one down; that second sequence should reproduce the **unfixed** 2→1 condition. This is a better validation than merely showing “my normal one-headset call still works.”

My classification of items 1–3 is therefore:

> **Three mechanisms, one neighborhood.**  
> U7 = reuse of an **established connection already in teardown**.  
> Hitalo v3 = abandonment of a **connection whose setup is still pending**.  
> Unknown-handle/corrupt = **receive-side traffic/reassembly after or around connection-state changes**.  
> Patch 6 fixes one btusb side effect of the second mechanism; it is not the U7 patch and does not itself account for multi-second post-hang-up packets.

## Mesh locking and pending patches

The core I12 observation is consistent with the source's locking model. Ordinary MGMT advertising operations call `hci_add_adv_instance()` and remove/find/list-walk advertising instances while holding `hci_dev_lock(hdev)`. For example, the current `add_ext_adv_params()` path takes the device lock before creating an advertising instance and holds it through the corresponding in-memory manipulations. Your repository records that adding `lockdep_assert_held(&hdev->lock)` to the advertising-instance helpers trips exactly four command-sync call paths and that KCSAN reports list races in five of fifteen 4-vCPU boots.

**The `mesh_send_sync()` fix should be a narrow data-structure lock, not a function-wide lock.** Current `mgmt.c` computes the mesh advertisement's duration and calls `hci_add_adv_instance()` without the MGMT front-end's normal `hdev->lock`. The correct shape is:

```text
mesh_send_sync()
        ...
        hci_dev_lock(hdev)
        adv = hci_add_adv_instance(...)
        if success:
                initialize the adv_info fields owned/protected by hdev->lock
                including the mesh marker
        hci_dev_unlock(hdev)

        perform the HCI command-sync work without carrying hdev->lock
        ...
```

The exact critical section should include every access to `hdev->adv_instances`, `adv_instance_cnt`, and the returned `adv_info` fields that are part of that protected state, but it should end before helpers that themselves conditionally acquire `hdev->lock` or wait synchronously for an HCI command. Current `hci_sync.c` already contains advertising helpers that acquire/release `hdev->lock` internally around instance lookup/data access; holding the mutex across the whole command chain would invite recursive locking and unnecessarily couple a list mutex to controller latency.

I would add the `lockdep_assert_held(&hdev->lock)` contract to the low-level add/remove helpers **after** fixing all known unlocked callers, not as the first upstream patch. That turns the assertion into a regression guard instead of knowingly breaking four paths.

The ISO broadcast path is independently visible in `hci_start_per_adv_sync()`: if the advertising instance cannot be found, it calls `hci_add_per_instance()` from command-sync context without first taking `hdev->lock`. It should get its own patch. The Set-LE-off path and advertising-timeout `hci_clear_adv_instance_sync()` should likewise get separate patches. That division matches your existing contribution plan and is good upstream practice: one locking contract, four independently reviewable call-site bugs.

I do **not** see a reason to wrap HCI command submission in `hdev->lock` merely because the list operation is locked. The relevant correctness property is: capture/update advertising state atomically under `hdev->lock`; release it; let command-sync serialization govern controller commands. The lockdep experiment should nevertheless be retained because command-sync callback contexts have another lock-order problem.

That second problem is the strongest objection to Igor Putko's 14888791 as described. The patch takes `hdev->lock` in `mesh_send_done_sync()`, `mesh_send_start_complete()`, and `mesh_next()`. But `mesh_next()` is also registered as a destroy callback for queued command-sync work. Your device-removal reproducer invokes that callback from `hci_cmd_sync_clear()` while `cmd_sync_work_lock` is held. This establishes:

```text
cmd_sync_work_lock
        → destroy callback
        → mesh_next()
        → hdev->lock
```

Your project already captured a lockdep inversion only when a scratch delay kept that teardown entry queued. That is not something I would dismiss as a test artifact: the delay changes reachability/timing, but once a real callback is callable under `cmd_sync_work_lock`, adding another blocking lock inside it creates a real lock-order edge.

The right resolution is **not** “hope teardown is fast.” Either `hci_cmd_sync_clear()` should detach canceled work while holding `cmd_sync_work_lock` and invoke destroy callbacks **after dropping it**, or `mesh_next()`'s destroy-callback form must not acquire `hdev->lock` directly and must defer the protected cleanup to a context outside that lock. Which is preferable is a maintainers' design question because changing `hci_cmd_sync_clear()` affects every destroy callback, not just mesh.

A test on exact 14888791 should therefore be considered failed for `Tested-by` purposes if your existing 4-vCPU device-removal lockdep case reproduces that inversion. The ordinary mesh-send UAF reproducer passing is not enough.

The four pending submissions should not simply be stacked in Patchwork-number order:

1. **Hui Peng 14831271 and Igor Putko 14888791 are alternatives, not cumulative patches.** Your repository records that Igor includes Hui's hunk verbatim; if Igor is tested, Hui is redundant.
2. **Cen Zhang 14880941 should be evaluated first conceptually**, because removing mesh cleanup from the socket destructor changes which teardown/lifetime path exists. That can change the context in which Igor's added locking is needed.
3. **Then test Igor's superset**, specifically with both the normal mesh reproducer and the delayed device-removal lockdep case. Do not give it a Tested-by if the latter warns.
4. **Jiale Yao 14864878 should remain a separate power-off review.** Your October 20 notes already say its fallback completion runs without `req_lock`/`hdev->lock`, and that a three-request backlog strands a request both with that patch and with your adapted minimal fix. That is evidence against treating it as the general I12 solution.

I12 itself can proceed independently of those queue-lifetime fixes as small call-site locking patches, provided they do not introduce `hdev->lock` inside a `cmd_sync_work_lock` destroy callback.

The one QEMU gate I would use for the mesh set is your existing 4-vCPU guest with three configurations: lockdep-only with the helper assertion; KCSAN repeated boots; and device removal with a queued mesh transmission. Success means zero helper assertions, zero KCSAN `adv_instances` races over a substantially larger run than 15 boots, and no `cmd_sync_work_lock`/`hdev->lock` inversion. KASAN is secondary here because your evidence is currently a race/ordering defect, not demonstrated corruption.

## Extended-advertising timeout overflow

**M-2 is real, and the important correction is that a type widening alone is not the complete fix.**

In the mainline snapshot I read, `net/bluetooth/hci_sync.c:hci_enable_ext_advertising_sync()` is around lines 1635–1680. For a nonzero `adv->timeout`, it does:

```c
u16 duration = adv->timeout * MSEC_PER_SEC;

/* Time = N * 10 ms */
set->duration = cpu_to_le16(duration / 10);
```

and sends that through `HCI_OP_LE_SET_EXT_ADV_ENABLE`. Bluetooth-next has subsequently incorporated the mesh-units distinction recorded in your repository, but the non-mesh multiplication into a 16-bit temporary remains the defect you identified.

For `adv->timeout == 66` seconds:

```text
66 × 1000 ms = 66000 ms
66000 stored in u16 = 464 ms
464 / 10 = 46
HCI duration = 46 × 10 ms ≈ 460 ms
```

So this does not normally produce a controller error. It produces a **perfectly valid but drastically shorter HCI duration**. Different timeout values wrap modulo 65,536 ms, so the resulting controller duration is a sawtooth, not a simple clamp.

The HCI field itself is also 16-bit in 10-ms units. Its largest nonzero representable duration is therefore 65,535 × 10 ms = **655.35 seconds**. The MGMT timeout, however, is a 16-bit value in **seconds**. `mgmt.c:add_ext_adv_params()` reads the `__le16` timeout and passes it directly to `hci_add_adv_instance()` without a ≤65 s or ≤655 s validation. Userspace can therefore request values far beyond both the current temporary's ~65-second safe multiplication range and the HCI duration field's ~655-second representable range.

That yields three regimes:

| Requested MGMT timeout | Current behavior | What merely changing `duration` to `u32` achieves |
|---|---|---|
| ≤65 s | Correct | No change |
| 66–655 s | Premature wrap today | Fixes this range |
| >655.35 s | Cannot fit HCI Duration even with a wide temporary | **Still needs a design** |

That is why “a timeout design, not a clamp” is the right review conclusion. Clamping 3600 s to 655.35 s violates the MGMT API by ending advertising too early. Wrapping violates it worse. Rejecting the request would newly restrict an API that currently accepts a `u16` seconds timeout.

The clean design is to make the **host** authoritative for MGMT lifetime once the requested timeout exceeds the controller field. For a timeout that fits HCI Duration, programming the controller's duration is a useful offload, preferably with host bookkeeping remaining coherent. For a larger timeout, program zero/no controller duration and arm a host delayed timeout that disables/removes the advertising instance at the requested MGMT time. That preserves all `u16`-seconds API values instead of inventing a 655-second maximum.

A QEMU/vhci regression does not need to wait 66 real seconds. Add Advertising with timeout 66 s and inspect the outgoing `LE Set Extended Advertising Enable` command immediately. The unfixed kernel will encode about 46 duration units; a fixed kernel should encode 6600 units. Add a second test above 655 s—say 700 s—and assert that the host chooses the long-timeout path rather than wrapping the HCI field. That second case is the one that prevents an incomplete “change `u16` to `u32`” patch from being accepted.

**Fix location: kernel, `hci_sync` plus the advertising-timeout machinery. Confidence: high.** A falsifier would be evidence that the MGMT layer rejects >655 s before `adv_info` is created; the current `add_ext_adv_params()` source does not do that.

## BlueZ backport and WirePlumber profile/default policy

**U12 — `a14d59725` is a backportable behavioral fix, but not a literal one-line cherry-pick.**

BlueZ commit `a14d59725ef35d91b8504770046c701d0a2efe07`, authored November 2, 2024, says exactly what your observation requires: calling `Release()` while `Acquire()`/A2DP START is in progress previously reached `a2dp_cancel()`, which sends AVDTP ABORT and drives the transport to IDLE/disconnect. The replacement logic lets START finish, then sends SUSPEND and completes Release, preserving the A2DP profile. The commit changes only `profiles/audio/transport.c`.

The significant dependency finding is that the `resume_id`, `cancel_resume`, and `cancel_id` machinery is **introduced by `a14d59725` itself**. It is not a helper that 5.72 lacks because an earlier prerequisite commit introduced it. The diff adds those fields, records the pending START id, turns cancellation of that specific id into `cancel_resume = TRUE`, waits for `a2dp_resume_complete()`, and then schedules the suspend.

BlueZ 5.72 already has the same fundamental owner/request/A2DP resume/suspend/cancel model: `a2dp_resume_complete()`, `transport_a2dp_resume()`, `a2dp_suspend_complete()`, `transport_a2dp_suspend()`, and a `transport_a2dp_cancel()` that unconditionally calls `a2dp_cancel(id)`. That is precisely the behavior the later commit replaces.

There is some **textual drift** between 5.72 and the 5.79 parent of `a14d59725`: for example, the parent has a `transport_a2dp_get_stream()` helper whereas 5.72 directly gets the SEP and calls `a2dp_sep_get_stream()`. But the state machine being modified is recognizably the same. Consequently my recommendation is a semantic backport of this one commit to 5.72's `profiles/audio/transport.c`, resolving those small context differences, rather than dragging 5.73–5.79 wholesale into Ubuntu.

I did not find evidence in the 5.72→5.80 history inspected that another A2DP Release-during-START commit is a semantic prerequisite to `a14d59725`. The range contains many transport/BAP and ownership changes, but `a14d59725` is itself the commit that defines this A2DP cancellation strategy. A distribution backport should therefore start with **that commit alone**, then add another commit only if an integration test demonstrates a dependent failure.

The decisive test is an emulator AVDTP peer that delays START response: issue `MediaTransport1.Acquire()`, issue `Release()` before the peer answers START, then answer START. On 5.72 baseline the peer should see ABORT/profile teardown; on the backport it should see START completion followed by SUSPEND, with the A2DP device remaining connected. Repeat immediately with SetConfiguration because the commit specifically says canceled Acquire previously broke subsequent reconfiguration.

**WirePlumber's “recording appeared, switch to headset profile” behavior was not removed in 0.5/master.** Current master still has an explicit `bluetooth.autoswitch-to-headset-profile` setting and profile-selection script logic conditional on it. So U12 should not be described as “WP 0.4.17 does a profile switch that 0.5 no longer does.” The policy still exists; what evolved is its implementation/configuration framework.

That distinction is useful for the Ubuntu request. U12's destructive A2DP disconnect is a **BlueZ transport race**, not something Ubuntu should “fix” by disabling WirePlumber's legitimate microphone/profile policy.

**U11/U3 — the remembered-default policy is equally explicit in current WirePlumber.** Current `src/scripts/default-nodes/state-default-nodes.lua` loads the stack of previously configured node names. When choosing among available nodes, entry position alone gives priorities `20001 - i`; `priority.session` is deliberately ignored so it cannot override the user's history. A metadata change to `default.configured.audio.sink` or `.source` pushes the selected name to the top of that persistent stack.

Master also has a separate `find-selected-default-node.lua` hook whose documented purpose is to give the **currently configured user preference** higher priority. This confirms the core design point behind the reports you cited: “newly appeared hardware” and “user selected this” are intentionally not equivalent events.

The smallest acceptable opt-in is therefore not “reverse the stored stack globally.” I would add a setting along the lines of `node.follow-new-device` with a **volatile connected-device candidate** in default-node selection:

```text
explicit default.configured.* chosen after this connection
        highest
newly connected eligible physical device, when opt-in enabled
        next
stored historical preferences
        next
ordinary priority.session / best-node policy
```

The temporary candidate should disappear as soon as the user explicitly chooses another node, the candidate disconnects, or the session policy determines it is no longer available. Crucially, it should **not be written into the historical configured-default stack merely because the policy selected it**. That is how to obtain “new headset wins until the user chooses something else” without turning every hotplug into a permanent user preference.

This shape addresses the unwanted auto-switch reports better than changing the existing persistent stack ordering. It can also be tested entirely with WirePlumber's script tester: create sink A and source A; mark them as historical configured defaults; add Bluetooth sink/source B; assert no change with the setting off; assert B becomes selected with it on; perform explicit metadata choice of A; then flap B and assert the explicit choice remains authoritative.

PipeWire's Pulse `module-switch-on-connect` is not the same policy primitive. PipeWire implements it as a PulseAudio compatibility module, and current `pipewire-pulse.conf` leaves it commented out rather than loading it by default. It performs the deliberately blunt “new sink/source appeared, make it the Pulse default” behavior that some Pulse-oriented desktops expect. PipeWire's own NEWS describes it as emulating PulseAudio's new-device behavior.

That can approximate U11 for output, but it is not Bluetooth-device-aware and it also applies to sources. Enabling it to solve “my new headset should become output” therefore risks automatically making a newly appearing microphone the default input as well. It also creates two policy authorities—WirePlumber's default-node metadata and a Pulse compatibility module—which is precisely the sort of interaction an upstream WirePlumber opt-in can avoid.

**Fix location for U11/U3: WirePlumber. Confidence on mechanism: high; confidence on the exact setting/API name: design proposal, not an upstream-reviewed interface.**

## SBC-XQ and the lower-priority desktop issues

**U10 — the offering decision cannot discover this kind of broken implementation from A2DP capabilities alone.** PipeWire's BlueZ5 SBC codec code treats SBC-XQ as a constrained SBC configuration rather than a separate Bluetooth codec. The important remote-side prerequisites are compatible sample frequency/channel mode—particularly Dual Channel for XQ—and a sufficient advertised bitpool range. A peer that advertises Dual Channel with max bitpool 53 therefore gives PipeWire no capability-level reason not to offer the 48-kHz Dual Channel XQ configuration described in your evidence.

The project's October 20 source review also confirms that current `spa/plugins/bluez5/bluez-hardware.conf` carries product-specific `no-features = [ sbc-xq ]` entries, with `SoundCore 2` as an issue-linked example, and currently has no Tronsmart T8 entry. This is the correct layer for a device that advertises legal capabilities, accepts SetConfiguration/Start, but empirically cannot render a particular valid SBC mode.

I did **not** establish a single formal maintainer rule from the complete history of every `sbc-xq` blacklist entry, so I would not claim “PipeWire requires exactly X reproductions.” The evidentiary package that would make this quirk hard to dispute is nevertheless clear: remote SEP capabilities from btmon, the exact SBC configuration selected for each trial, successful AVDTP SetConfiguration/Start, marked audible/silent results, and a matrix that changes one codec dimension at a time.

Your proposed “Dual Channel at low bitpool versus Joint Stereo at high bitpool” is useful but confounds mode and bitrate in the opposite directions. A better four-cell test is:

| Trial | Channel mode | Bitpool/rate intent | Question |
|---|---|---|---|
| A | Dual Channel | XQ's normal value | Reproduce silence |
| B | Dual Channel | substantially lower | Does failure follow Dual Channel even at low bitrate? |
| C | Joint Stereo | chosen as close as practical to A's encoded bitrate | Does similar bitrate work in another channel mode? |
| D | Joint Stereo | normal known-good setting | Control |

If both Dual Channel trials are silent while both Joint Stereo trials play, channel mode is the strong discriminator. If failure follows bitrate rather than mode, an `sbc-xq` blacklist is still a practical workaround but the technical report should say so. Saving the emitted SBC frames and decoding them locally would additionally distinguish malformed host output from a speaker decoder bug.

**U4 — GNOME Settings codec row.** I was not able to give this item the same independent source verification as the kernel/PipeWire items, so I would keep the conclusion provisional. The mechanism in your current evidence is internally plausible: if `cc-profile-combo-box` hides itself when the active device has only one currently exposed profile, while `cc-sound-panel` rebinds/rechecks it primarily when the selected device changes, then profile-set mutation on the **same** Bluetooth device can leave visibility stale. Your project already classifies GNOME #3710 as related and asks for a UI capture rather than an immediate patch.

The deciding experiment is correspondingly small: keep the same device selected while forcing only its available PipeWire profiles to change, record `pw-dump`/GNOME panel state, and see whether selecting another device and back instantly restores the row. If that refresh alone repairs it, the missing signal/recompute path is demonstrated. I would not submit a GNOME patch from this review without checking `46.7` and `main` directly around those two classes.

**U2 — microphone volume movement has at least one concrete PipeWire mechanism.** In the native HFP path, after SCO acquisition succeeds, `sco_ready()` calls `rfcomm_ag_sync_volume()` immediately and again in a delayed form; the source comment explicitly says some headsets have an out-of-sync HFP volume after A2DP and may need repeated synchronization. Incoming HFP gain signaling is also converted into Bluetooth transport volume changes.

WirePlumber can separately restore stored route/volume state as a profile/route appears. Consequently a sequence such as `0.00 → 0.27 → 0.08` is **compatible** with “initial route state → HFP hardware-volume synchronization → stored policy/route value,” but the numbers alone do not identify which actor wrote each value. The falsifier is a single synchronized trace containing RFCOMM `+VGM`/`AT+VGM`, PipeWire transport/route property changes, and WirePlumber restore-policy logs. An unsolicited volume step with a matching `VGM` message is headset/HFP sync; one with no HFP gain traffic but a route restore event is policy.

**U9 — adapter off/on reconnect.** Your current source/status record says the BlueZ policy issue was closed “not planned” and treats this as at most a narrow opt-in. That is a reasonable boundary. I would not broaden normal link-loss reconnect policy so that every remembered device is connected whenever an adapter powers on; that creates exactly the unwanted-reconnection behavior BlueZ policy has historically tried to avoid.

A technically narrow feature would record only devices that were **connected at the moment the local adapter was intentionally powered off**, and, under a disabled-by-default policy option, attempt those devices once when the same adapter returns to powered state. Clear the set after the attempt and do not treat boot, daemon restart, or “paired but was not connected” as eligibility. Given the existing upstream decision, the first contribution here should be a design request, not a code patch; a desktop/session policy implementation may ultimately be more acceptable than BlueZ core policy.

**Other QCA9377/ROME USB IDs.** I did not complete a reliable field-database-versus-current-`btusb_table` comparison in this investigation, so I will not fill this section with plausible-looking Qualcomm/IMC IDs. The one ID supported by this project's evidence is the already-settled `13d3:3503`, now covered by `dc16388d45ec`; the existence of one omitted OEM ID is not evidence that similarly numbered IMC IDs use the same ROME transport/firmware path. A useful follow-up contribution requires, per candidate ID, an actual hardware-probe descriptor plus controller/firmware identification and then a comparison against the current table. That part remains open rather than yielding another safe upstream candidate from this review.

## Contribution map and decisive experiments

The strongest immediately actionable result is **U7**. The source predicts a very specific transition:

```text
old hci_conn: BT_CONNECTED
       |
Disconnect command
       v
old hci_conn: BT_DISCONN
       |
new SCO connect to same bdaddr
       |
hci_connect_sco() finds old hci_conn
       |
state is neither BT_OPEN nor BT_CLOSED
       |
NO Setup Synchronous Connection
       |
new socket attaches to dying SCO connection
       |
old Disconnection Complete, reason 0x16
       |
sco_conn_del() / hci_conn_del()
       |
replacement socket SO_ERROR = ECONNABORTED
       |
PipeWire sco_ready(): ERROR, no retry
```

Every box above is either directly visible in the kernel/PipeWire source or has an immediate observable falsifier. This is strong enough to write a kernel regression test now, before designing the final fix.

For the remaining work, I would prioritize experiments as follows—not by cosmetic user impact, but by how cheaply each one turns a source reading into upstream-quality evidence:

| Target | First decisive experiment | Success criterion | Likely owner |
|---|---|---|---|
| **U7** | vhci: connect while previous established SCO is held in `BT_DISCONN` | Baseline reproduces “no setup + later socket error”; patch creates clean successor semantics | **Kernel**, plus PipeWire retry |
| **Unknown handle** | One real hang-up with btusb dynamic debug + usbmon + btmon | Establish whether 4–6 s packet occurs before or after actual alt0/URB shutdown | **Kernel/btusb** |
| **Patch 6** | Keep SCO A live while SCO B setup fails | Patched kernel never disrupts A's btusb alt setting | **Kernel** |
| **btusb 2→1** | Two SCOs; disconnect one | Surviving link keeps correct isoc alt/air mode | **Kernel/btusb** |
| **Mesh I12** | Existing 4-vCPU lockdep/KCSAN suite after narrow call-site locks | Zero assertions/races without new lock inversions | **Kernel** |
| **14888791** | Exact patch + delayed device-removal reproducer | No `cmd_sync_work_lock → hdev->lock` inversion | **Kernel patch review** |
| **M-2** | vhci Add Advertising at 66 s and 700 s | 66 s encodes correctly; 700 s uses host lifetime rather than HCI wrap/clamp | **Kernel** |
| **U12** | BlueZ emulator: delayed AVDTP START, Release while Acquire pending | START→SUSPEND; no ABORT/profile disconnect | **BlueZ / Ubuntu backport** |
| **U11/U3** | WirePlumber script test with stored A, newly connected B, then explicit A | Opt-in chooses B only until user explicitly selects A | **WirePlumber** |
| **U10** | Marked four-cell SBC mode/bitpool test | Failure cleanly follows mode or bitrate | **PipeWire quirk** |

A few additional source-level observations are worth preserving in the project because they sharpen the existing issue descriptions.

First, **U7's new socket should not merely “disappear”; it should normally report `ECONNABORTED`**, and PipeWire's failure to retry that error is specifically because it arrives asynchronously. That gives EX-060 a new userspace assertion to capture.

Second, **the multi-second unknown-handle cases should no longer be described as plausibly just “27 bytes left in an URB.”** The btusb URB geometry makes a short post-disconnect tail credible, but not seconds of prequeued data. The experiment should focus on when `btusb_work()` actually stopped the endpoint versus when the controller/USB delivered the late handle.

Third, **patch 6 exposes an independent btusb state-representation problem**. `sco_num + last air_mode event` is not a sufficient model for multiple surviving SCO connections. Fixing only the failed-setup notification removes one trigger, not the underlying 2→1 ambiguity.

Fourth, **M-2 has a trap for the obvious patch**: `u16 duration` → `u32 duration` repairs 66–655 seconds but still cannot faithfully encode the full MGMT `u16 seconds` range into HCI's `u16 × 10 ms` duration. An upstream patch should include the >655-second test so the partial fix cannot regress later.

Finally, the mesh work should keep two questions separate. **I12 is an `adv_instances` locking bug with direct lockdep/KCSAN evidence and can be fixed call site by call site.** The queued-mesh teardown work is a command-sync lifetime/lock-order problem. Folding them into one “mesh locking” patch would make both harder to review. Your own October 20 plan already points in that direction, and the source supports it.

The items that remain genuinely incomplete from this source pass are the exact GNOME 46.7→`main` U4 change, a comprehensive historical review of PipeWire's SBC-XQ blacklist submissions, and a defensible hardware-probe inventory of additional QCA9377/ROME USB IDs absent from today's btusb table. None is needed to proceed with the much stronger U7, btusb teardown, mesh, M-2, or BlueZ-backport contributions above.