# The Mesh MGMT transmit path as two state machines

Working design document, not a submission. Author: Iaroslav Voitovych. Written 2026-10-05 on a
private branch; ported to `main` 2026-10-09.
Asked for by the research review of 2026-10-05 (`docs/mesh-tester-ci/research-review-2026-10-05.md`,
"An organising document, private"). Read-only analysis: nothing was built, run, sent or committed
for it.

> **Update 2026-10-05, after the research gates (`gates-2026-10-05.md`).** Two findings marked
> *inferred* below are now **shown in qemu**:
> - **I12 (advertising-list locking)** — with `lockdep_assert_held(&hdev->lock)` added to the
>   adv-instance add/remove functions, four call paths fire on bluetooth-next and on v3:
>   `mesh_send_sync`, ISO broadcast (`hci_add_per_instance`), Set LE off and the advertising
>   timeout (`hci_clear_adv_instance_sync`). On a 4-CPU guest KCSAN reports races on the list
>   between Add Advertising (locked) and `mesh_send_sync` (unlocked) in 5 of 15 boots on
>   bluetooth-next and 4 of 15 on v3; v3's tear-down also walks the list unlocked. No KASAN
>   report, no corruption shown. Unlocked since `b338d91703fa` (2022) for mesh, `eca0ae4aea66`
>   and `c249ea9b4309` (2022) for the others; the requirement dates from `d2609b345ebf` (2015).
> - **The unregister lock-order inversion** — lockdep reports "possible circular locking
>   dependency" (`cmd_sync_work_lock` then `unregister_lock`, from `mesh_next(-ECANCELED)` under
>   `hci_cmd_sync_clear`) on bluetooth-next in 16 of 16 boots once a scratch delay keeps the
>   tear-down entry queued at removal; the path is proven by kprobe stacks; no deadlock (submit
>   returns -ENODEV). Silent on v3, whose tear-down entry has no destroy callback. Reaching the
>   window without the delay is inferred, not shown.
> - **Correction to earlier evidence:** phase 5's KCSAN runs used the tester config's
>   single-CPU kernel and could not see most races; "KCSAN clean" from phase 5 means single
>   CPU only.
>
> Consequences for the redesign: the command worker does not own the advertising list; mesh's
> add, remove and list walks need `hdev->lock` (after `req_lock`, never across an HCI command);
> the three non-mesh callers are a question for the maintainers; unregister now has a real
> lockdep report to cite, the drain policy (I6) remains open.

The goal is a written-down model to map every historical and proposed patch onto. With it, a
future series can be explained as "these are the invariants; these transitions break them in
mainline; these patches repair exactly those".

## 0. How to read this

**Evidence marks.** Every statement carries one of these:

- **[Q]** quoted: a code line at a named revision, a list message (URL plus the quoted words), or
  a recorded run in `phase5-results.md`.
- **[I]** inferred from quoted material. Not reproduced unless the text says so.
- **[NF]** not found: looked for and not present.

**Revision keys.** Line numbers come from `git show <rev>:<path>` through
`tmp/mesh-tester-ci/sm-showlines.sh <repo> <rev> <path> <first> <last>`.

| key | what | where |
|---|---|---|
| R0 | `b338d91703fa` "Bluetooth: Implement support for Mesh" (Brian Gix, 2022-09-01) | `cache/linux` |
| R1 | R0 lineage + `f3cb5676e5c1` "Bluetooth: MGMT: mesh_send: check instances prior disabling advertising" (Christian Eggers, 2025-06-25) | commit diff, `cache/linux` |
| ML | `08e90633377f`, bluetooth/master and the v3 base. It contains `3c742feda8fc` (Linmao Li, 2026-08-06), `71af682ba469` (Lee Jones, 2026-09-15) and `b1f24c1ab523` "Bluetooth: hci_sync: don't drain cmd_sync backlog on unregister" (Nguyen Ngoc Thang, 2026-09-27) | `cache/linux` |
| HP | ML + Hui Peng, "[PATCH] Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure", 2026-09-19, https://lkml.iu.edu/2609.2/10074.html | posted diff |
| FEB | Maiquel Paiva, "[PATCH v4 2/2] Bluetooth: mgmt: Fix race conditions in mesh handling", 2026-02-08, https://www.spinics.net/lists/stable/msg911606.html (1/2: msg911605) | posted diff |
| AUG | Baul Lee, "[PATCH v2 1/3..3/3] Bluetooth: MGMT: …", 2026-08-07, https://lists.openwall.net/linux-kernel/2026/08/07/798 and /800 (v1: /426, /427, /430), as posted on its base | posted diff |
| V3 | this project's series as applied: `cache/mesh-guest` branch `mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03` = `71a4243699c8` (1/5 `266dda8daee0` … 5/5 `71a4243699c8`) on ML | `cache/mesh-guest` |

**ML is also mainline and bluetooth-next for this code [Q].**
- `git diff --stat e767a4ea70a3 08e90633377f -- net/bluetooth/{mgmt,mgmt_util,hci_sync,hci_core,hci_sock}.c …`
  gives `net/bluetooth/mgmt.c | 2 +-`. That one changed line is `cmd_complete_rsp()` at mgmt.c:1498,
  outside the mesh code. `e767a4ea70a3` is `stable/master`, the mainline mirror, merged 2026-10-02.
  `71af682ba469`, `3c742feda8fc` and `b1f24c1ab523` are all in `stable/master`, `bluetooth/master`
  and `bluetooth-next/master` (`git branch -r --contains`).
- bluetooth-next `036d4119079a` has the same mesh functions, 3 lines further down (`mesh_send_done_sync`
  at 1096 instead of 1093). One related change: `mgmt_errno_status()` gains `case -ECANCELED: return
  MGMT_STATUS_CANCELLED;`. That does not change any branch in `mesh_send_start_complete()`, because
  `mgmt_err` stays non-zero [Q, inferred for the branch].
- The bluetooth-next fetch is the one recorded on 2026-10-05 in the research review. This read-only
  task did not fetch it again.

**AUG's base.** The automated review the maintainer linked in his reply
(https://lists.openwall.net/linux-kernel/2026/08/07/1532: "… found a couple of problems") applied v2
to "bluetooth-next/HEAD (0ed4fd40f49c…)" and failed on bluetooth/HEAD [Q, its API JSON saved as
`tmp/state-machine/aug-review-patchset.json`]. That base contains `3c742feda8fc` (the v2 cover:
"send_cancel() no longer ends in mgmt_pending_free()") but **not** `71af682ba469`, which was authored
2026-09-15 [Q]. So AUG as posted has no dequeue on cancel.

**Fetched for this document.** Saved under `tmp/state-machine/`: `aug-430.html`, `aug-798.html`,
`aug-800.html`, `feb-911605.html`, `feb-911606.html`, `feb-911613.html`, `huipeng-10074.html`,
`aug-review-patchset.json`. The FEB cover letter was **[NF]**: spinics stable msg911604 is an
unrelated message.

**Helpers written for this document** (in `tmp/mesh-tester-ci/`): `sm-showlines.sh` (numbered lines of
`rev:path`), `sm-grep-context.py` (substring context in minified HTML), `sm-json-reviews.py` (prints
the long strings of a JSON document).

---

## 1. Objects and owners

### 1.1 `struct mgmt_mesh_tx`, one transmission request

Fields, ML `mgmt_util.h:20-28` [Q]:

```c
struct mgmt_mesh_tx {
	struct list_head list;
	int index;
	size_t param_len;
	struct sock *sk;
	u8 handle;
	u8 instance;
	u8 param[sizeof(struct mgmt_cp_mesh_send) + 31];
};
```

| aspect | ML | source |
|---|---|---|
| allocated by | `mgmt_mesh_add()` from `mesh_send()` under `hdev->lock` | [Q] `mgmt_util.c:mgmt_mesh_add:408-431`, `mgmt.c:mesh_send:2517,2531` |
| handle | `hdev->mesh_send_ref++`, skipping 0 | [Q] `mgmt_util.c:417-421` |
| socket reference | `mesh_tx->sk = sk; sock_hold(sk);` | [Q] `mgmt_util.c:425-426` |
| hdev reference | **none**: only `index = hdev->id` | [Q] `mgmt_util.c:422`; [NF] no `hci_dev_hold` in mgmt_util.c |
| linked | `list_add_tail(&mesh_tx->list, &hdev->mesh_pending)` (FIFO) | [Q] `mgmt_util.c:428` |
| freed by | `mgmt_mesh_remove()`: `list_del`, `sock_put`, `kfree` | [Q] `mgmt_util.c:433-438` |
| callers of the free | `mesh_send()` error path (2546), `mesh_send_complete()` (1090). The latter is called from `mesh_send_done_sync` (1103), `mesh_next` (1121), `mesh_send_start_complete` (2314), `send_cancel` (2429, 2438) and `mgmt_cleanup` (10925) | [Q] ML grep |
| `instance` | written once, in `mesh_send_sync()`, when `hci_add_adv_instance()` succeeds: `mesh_tx->instance = instance;` (`le_num_of_adv_sets + 1`). Never cleared | [Q] `mgmt.c:mesh_send_sync:2348-2349` |
| identity on the advertising object | `hci_add_adv_instance(..., mesh_tx->handle)` stores `adv->mesh = mesh_handle;`, and **nothing reads `adv->mesh`** | [Q] `hci_core.c:1720`; [Q] `git grep "adv->mesh"` → only that line |

AUG 3/3 adds `refcount_t ref`. The list holds one reference and every pointer handed to
`hci_cmd_sync_queue()` holds a second one. `mgmt_mesh_remove()` becomes `list_del_init` + put [Q, /800].

### 1.2 `hdev->mesh_pending`

- **What it is.** The single FIFO of accepted and not yet completed requests, across all sockets
  [Q, `hci_core.h:556`, initialised `hci_core.c:2501`].
- **Per-socket limit.** `MESH_HANDLES_MAX` per socket, counted by `send_count` over
  `mgmt_mesh_foreach(..., sk)` [Q, `mgmt.c:mesh_send:2519-2528`].
- **Freed at unregister or release?** Nothing frees it at either [Q: `hci_release_dev` at
  `hci_core.c:2722-2756` has no mesh_pending; recorded by phase 5 §D4.1].

### 1.3 `HCI_MESH_SENDING`

- **What it is.** A non-volatile hdev flag [Q, `hci.h:474`].
  `hci_dev_clear_volatile_flags` clears only `HCI_LE_SCAN`, `HCI_LE_ADV`, `HCI_LL_RPA_RESOLUTION`,
  `HCI_PERIODIC_INQ` and `HCI_QUALITY_REPORT` [Q, `hci_core.h:861-868`].
- **Set by:**
  - `mesh_send()` success path, under `hdev->lock` [Q, ML 2549].
  - `mesh_next()` after a successful queue: ML 1123, from the worker, without `hdev->lock` [Q].
- **Cleared by:**
  - `mesh_send_done_sync()` first thing (ML 1097) [Q].
  - `mesh_send_start_complete()` error path (ML 2312) [Q].
- **Read by:**
  - `mesh_send()` (2530).
  - `mesh_send_done()` (1131).
  - `send_cancel()` (2445) [Q].
- **In V3:** set in `mesh_send()` (2630), cleared only at the end of `mesh_next()` (1120). Both are
  under `hdev->lock` [Q].

### 1.4 Command-sync work entries

- **The entry.** `struct hci_cmd_sync_work_entry {func, data, destroy}` on `hdev->cmd_sync_work_list`
  [Q, `hci_sync.c:hci_cmd_sync_submit:726-737`].
- **The worker** takes the head under `cmd_sync_work_lock`, unlinks it, drops the lock, then runs
  `func` and `destroy` under `req_lock` [Q, `hci_sync.c:hci_cmd_sync_work:319-339`]. **A running entry
  is invisible to lookups and dequeue.**
- **Since `b1f24c1ab523`** the worker stops taking entries once `HCI_UNREGISTER` is set:
  "`/* Leave the backlog to hci_cmd_sync_clear() */`" [Q, `hci_sync.c:315-317`].
- **No reference.** The entry holds no reference on `data` [Q, `hci_sync.c:731-733`].

The mesh entries [Q, ML]:

| entry | func | data | destroy | queued by |
|---|---|---|---|---|
| start | `mesh_send_sync` | the `mesh_tx` | `mesh_send_start_complete` | `mesh_send()` 2536, `mesh_next()` 1117 |
| teardown | `mesh_send_done_sync` | `NULL` | `mesh_next` (ML); `NULL` (V3 1/5) | `mesh_send_done()` 1134 |
| cancel | `send_cancel` | the `mgmt_pending_cmd` | `send_cancel_destroy` (since `3c742feda8fc`; `NULL` before) | `mesh_send_cancel()` 2476-2477 |

**Destroy is called in three ways [Q]:**
1. After `func` returns, with `func`'s result, under `req_lock` (`hci_sync.c:337-338`).
2. From `hci_cmd_sync_dequeue()` with `-ECANCELED`, under `cmd_sync_work_lock` (886-892).
3. From `hci_cmd_sync_clear()` with `-ECANCELED`, under `cmd_sync_work_lock` (670-673). This one runs
   in the unregistering thread: no `req_lock`, no `hdev->lock`.

### 1.5 The delayed work `hdev->mesh_send_done`

- **Armed** by `mesh_send_start_complete()` on success:
  `queue_delayed_work(hdev->req_workqueue, &hdev->mesh_send_done, msecs_to_jiffies(cnt * 25))` [Q,
  ML 2320-2322]. `req_workqueue` is ordered [Q, `hci_core.c:2586` `alloc_ordered_workqueue`].
- **Cancelled** only in `mgmt_index_removed()`, `cancel_delayed_work_sync(&hdev->mesh_send_done)`
  [Q, ML 9795]. Not by cancel, not by power-off [NF elsewhere: grep `mesh_send_done` →
  1126-1147, 2321, 9795].
- **It carries no request identity.** It reaches the owner only through whatever the teardown entry
  then picks [Q, ML 1126-1135].

### 1.6 The internal advertising instance and the controller's set

- **The instance.** Number `le_num_of_adv_sets + 1`: one above what Add Advertising accepts, the one
  slot `hci_add_adv_instance()` allows above the range (`instance > hdev->le_num_of_adv_sets + 1`
  → `-EOVERFLOW`) [Q, `hci_core.c:1689-1691`; ML `mgmt.c:9025, 9217, 9581`: `if (cp->instance < 1
  || cp->instance > hdev->le_num_of_adv_sets)` for userspace].
- **Created or reused** by `mesh_send_sync()`. If it already exists it is **reused** and overwritten
  (`hci_find_adv_instance` then `memset`) [Q, `hci_core.c:1683-1687`]. It is added with `timeout =
  1000` and `duration = cnt * INTERVAL_TO_MS(le_adv_max_interval)` [Q, ML 2337-2346], and counts
  towards `adv_instance_cnt` (1709).
- **Locking gap.** `hci_add_adv_instance()` is documented "`/* This function requires the caller
  holds hdev->lock */`" [Q, `hci_core.c:1673`]. `mesh_send_sync()` calls it from the worker under
  `req_lock` only [Q, ML 2339; no `hci_dev_lock` in 2325-2377]. **[I]** That is an unprotected
  mutation of `hdev->adv_instances`, a separate lock defect that no patch below addresses.

**Who removes the host instance [Q]:**
- `hci_remove_adv_instance()`, under `hdev->lock` (1606-1633). It is reached through:
  - `hci_remove_adv_sync`: legacy (2179-2185); extended via the Remove Set Command Complete
    `hci_cc_le_remove_adv_set`, `hci_event.c:1495-1502`.
  - `hci_clear_adv_sync` / `hci_cc_le_clear_adv_sets` (power-off, `hci_event.c:1522-1533`).
  - `hci_le_ext_adv_term_evt` (controller-side Duration end, `hci_event.c:6008-6009`).
  - legacy `adv_timeout_expire` (after `remaining_time`).
- `hci_release_dev()` → `hci_adv_instances_clear()` (2739).
- **In V3 only**, also `mesh_send_done_sync()` → `hci_remove_advertising_sync(hdev, NULL,
  le_num_of_adv_sets + 1, true)` (V3 1137).

**The controller set.** It is enabled by `hci_schedule_adv_instance_sync()` (ML 2374). Extended
Duration is `timeout` in 10 ms units, truncated to u16 (1696 = 16.96 s for 1000 s), with Max Events 0
[Q, phase 5 §B1].

### 1.7 The MGMT pending command for Mesh Send Cancel

- **Created** by `mgmt_pending_new()`. It holds `sock_hold(sk)` and a raw `hdev` pointer, and is
  **not** put on `hdev->mgmt_pending` [Q, `mgmt_util.c:260-285`].
- **Freed** by `send_cancel_destroy()` → `mgmt_pending_free()` in both the run and the `-ECANCELED`
  case [Q, ML 2451-2454].
- **Before `3c742feda8fc`,** `send_cancel()` freed it itself, and a cancelled entry leaked it [Q,
  commit message: "A cancelled entry is leaked … The leak also pins the socket reference"].

---

## 2. Locks and contexts

| lock | kind | source |
|---|---|---|
| `hdev->lock` | mutex: `#define hci_dev_lock(d) mutex_lock(&d->lock)` | [Q] `hci_core.h:1752`, `hci_core.c:2494` |
| `hdev->req_lock` | mutex: `#define hci_req_sync_lock(hdev) mutex_lock(&hdev->req_lock)` | [Q] `hci_sync.h:15` |
| `hdev->cmd_sync_work_lock` | mutex | [Q] `hci_sync.c:640` |
| `hdev->unregister_lock` | mutex; `hci_cmd_sync_submit` takes it around the `HCI_UNREGISTER` test and the enqueue | [Q] `hci_sync.c:641, 720-742`; `hci_core.c:2670-2672` |
| `hci_dev_list_lock` | rwlock (spinning): `DEFINE_RWLOCK(hci_dev_list_lock)` | [Q] `hci_core.c:53` |
| `hdev->mgmt_pending_lock` | mutex, for `mgmt_pending` only; not used by mesh | [Q] `mgmt_util.c:297` |

### 2.1 Contexts and what they hold [Q unless marked]

| context | runs | holds |
|---|---|---|
| MGMT syscall | `mesh_send` (2517-2556), `mesh_send_cancel` (2471-2487), `mesh_features` (2404-2412) | `hdev->lock`; then `hci_cmd_sync_queue` → `unregister_lock` → `cmd_sync_work_lock` |
| cmd_sync worker | every `func` and its normal `destroy` | `req_lock` only (ML); V3 adds `hdev->lock` inside `mesh_send_done_sync`, `send_cancel` and the non-cancel error branch of `mesh_send_start_complete` |
| dequeue from `send_cancel` | `mesh_send_start_complete(-ECANCELED)` | `req_lock` + `cmd_sync_work_lock` (ML); + `hdev->lock` (V3, taken at V3 2487). Recorded: "start_complete … err=-125 (-ECANCELED, called from inside the dequeue, under cmd_sync_work_lock)" (phase 5 §C2 kprobe trace) |
| `hci_cmd_sync_clear` (unregister thread) | every queued `destroy(-ECANCELED)` | `cmd_sync_work_lock` only (`hci_sync.c:670-673`; caller `hci_core.c:2690` holds nothing) |
| delayed `mesh_send_done` | `mesh_send_done()` | nothing; ordered `req_workqueue` |
| HCI event (rx_work) | `hci_cc_le_remove_adv_set`, `hci_cc_le_clear_adv_sets`, `hci_le_ext_adv_term_evt` | `hdev->lock` |
| socket destructor | `hci_sock_destruct` → `mgmt_cleanup` (`hci_sock.c:2177-2183`, `mgmt.c:10913-10930`) | `read_lock(&hci_dev_list_lock)`, plus **whatever the thread dropping the last `sock_put` holds**: worker + `req_lock` in ML; `hdev->lock` in V3 (phase 5 §E trace: "mgmt_cleanup: … under hdev->lock in mesh_send_done_sync()"); `cmd_sync_work_lock` from the clear path |
| unregister | `hci_unregister_dev` (2666-2718) | `unregister_lock` for the flag; `hci_cmd_sync_clear`; `hci_dev_do_close` under `req_lock` (500-504); `mgmt_index_removed` under `hdev->lock` (2699-2701) |
| power off (Set Powered) | `set_powered_sync` → `hci_power_off_sync` (6066-6101) → `hci_clear_adv_sync` (6083) → `hci_dev_close_sync` (5536-5688) | worker + `req_lock`; `hdev->lock` inside `hci_clear_adv_sync` legacy (2147-2162) and around `__mgmt_power_off` (5605-5620) |

### 2.2 Lock order as the code establishes it

- **`req_lock → hdev->lock`** [Q]. Examples: `hci_dev_close_sync` 5605 under `hci_dev_do_close`'s
  `req_lock`, and `hci_remove_adv_sync` 2179 in the worker. The AUG 2/3 message states the same:
  "hci_req_sync_lock -> hdev->lock is the order this subsystem already uses".
- **`hdev->lock → unregister_lock → cmd_sync_work_lock`** [Q]. `mesh_send` 2517 → `hci_cmd_sync_queue`
  2536 → `hci_cmd_sync_submit` 720 and 735. Likewise `mgmt_set_powered_complete` 1352-1354
  (`hci_update_passive_scan` under `hdev->lock`). AUG 2/3 quotes the lockdep leg
  "`mgmt_set_powered_complete+0x1b0` … `hci_update_passive_scan+0x6c`".
- **`cmd_sync_work_lock → hdev->lock` is forbidden** [Q]. AUG 2/3: "hci_cmd_sync_clear() runs a destroy
  callback under cmd_sync_work_lock … Without those returns lockdep reports a circular dependency …
  (&hdev->lock) at: mesh_send_start_complete … but task is already holding lock:
  (&hdev->cmd_sync_work_lock) at: hci_cmd_sync_clear".
- **`hdev->lock → hci_dev_list_lock` (read)** happens in V3 when the destructor runs inside a locked
  completion. That is valid; the opposite order is impossible because a mutex cannot be taken under a
  spinning lock [Q, phase 5 §E; I].
- **ML: `cmd_sync_work_lock → unregister_lock`** [I, new here]. At unregister, a queued teardown entry
  gets its destroy, ML `mesh_next(hdev, NULL, -ECANCELED)`, under `cmd_sync_work_lock`. ML `mesh_next`
  ignores `err` (1110-1124) and calls `hci_cmd_sync_queue()`. With `HCI_RUNNING` still set (the clear
  at `hci_core.c:2690` precedes `hci_dev_do_close` at 2694), that reaches `mutex_lock(&hdev->unregister_lock)`
  (`hci_sync.c:720`). That inverts submit's own order. It is **not a reachable deadlock**:
  `HCI_UNREGISTER` was set under `unregister_lock` before the clear, so no thread can be inside
  `submit` past line 721. Lockdep can still record it as an order violation. `71af682ba469` guarded
  exactly this for `mesh_send_start_complete` ("calling mesh_next() synchronously would deadlock"
  [Q]) but not for the teardown entry's destroy.

---

## 3. The two machines

The reviewer asked for two machines, not one enum. Several defects below come from treating "this
request still exists" as "this request owns the controller or the advertising slot".

### 3.1 Machine A: request lifetime (per `mesh_tx`)

State names refined from the proposal (pending / starting / active / finishing / completed /
cancelled). Two places differ from it. "Pending" splits into QUEUED (no work entry) and START-QUEUED
(an entry exists), because the code treats them differently on cancel. "Cancelled" is not a distinct
terminal state: a cancel ends in the same `mesh_send_complete(..., false)` as a normal completion, and
emits the same event [Q, ML 2429, 2438; the protocol text quoted in V3 3/5: "For each mesh packet
canceled, the Mesh Packet Transmission Complete event will be generated"].

```
                     validation / per-socket BUSY / NOT_SUPPORTED (no object created)
  Mesh Send ──────────────────────────────────────────────────────────────────▶ REJECTED-CLEAN
     │ mgmt_mesh_add, hdev->lock
     ▼
  ACCEPTED ─(first enqueue fails)─▶ ML/V3: REJECTED-RESIDUE (listed, told FAILED)   HP: freed
     │ reply with handle
     ├── flag was clear ──────────────────────┐
     ▼                                        ▼
  QUEUED ──mesh_next picks head──────▶ START-QUEUED ──worker takes entry──▶ STARTING
   │  ▲                                  │   (entry on cmd_sync list)       (mesh_send_sync runs;
   │  └── enqueue fails in mesh_next:    │                                   sets ->instance)
   │      completed with event           │                                    │      │ error
   │                                     │ cancel: dequeue → -ECANCELED       │      ▼
   │ cancel ─▶ COMPLETED                 └──────────────▶ COMPLETED           │   COMPLETED (event)
   │                                                                          │ ok: done timer armed
   │                                                                          ▼
   │                                                                       ACTIVE
   │                                                       cancel ─▶ COMPLETED, slot orphaned
   │                                                                          │ timer fires
   │                                                                          ▼
   │                                                                       FINISHING
   │                                                       (teardown entry queued / running)
   │                                                                          │ done_sync
   │                                                                          ▼
   │                                                                       COMPLETED (event, freed)
   │
   └─ side exits from any non-terminal state:
        socket close  → no transition (each mesh_tx pins its socket; the destructor cannot run)
        power off     → ML: ACTIVE stays ACTIVE forever if the timer fires while down (stale owner)
                        V3: the timer's work runs on the closed device → COMPLETED
        unregister    → START-QUEUED: COMPLETED from clear (ML, V3) or LEAKED (AUG)
                        everything else: LEAKED (list never freed, socket pinned)
```

**State predicates.** "Unambiguous" means the predicate can be evaluated from data alone, without
assuming another invariant.

| state | predicate in code | unambiguous? |
|---|---|---|
| REJECTED-RESIDUE | on `mesh_pending`, no entry, never started, and userspace got FAILED | **No**: indistinguishable from QUEUED [Q, ML 2544-2547]. HP removes the state |
| QUEUED | on `mesh_pending` ∧ no `mesh_send_sync` entry with `data == tx` (`hci_cmd_sync_lookup_entry`) ∧ `instance == 0` | yes while the lookup is done under `cmd_sync_work_lock`; nobody evaluates it |
| START-QUEUED | on `mesh_pending` ∧ `mesh_send_sync` entry with `data == tx` on the list | yes (that is what `hci_cmd_sync_dequeue` tests) |
| STARTING | `mesh_send_sync(tx)` running | **no data predicate**: the entry is off the list (`hci_sync.c:324`); only `req_lock` being held by the worker shows it |
| ACTIVE | on `mesh_pending` ∧ `instance == le_num_of_adv_sets + 1` ∧ `delayed_work_pending(&hdev->mesh_send_done)` | **No**. `instance` is set during STARTING, even when scheduling then fails (ML 2348-2349 vs 2373-2374). The delayed work is hdev-global. In ML the only implied predicate is "head of the list", which is wrong after a cancel |
| FINISHING | teardown entry queued or running | **No**: the entry's `data` is `NULL` and names no request [Q, ML 1134] |
| COMPLETED | off the list, freed | yes (no object) |
| LEAKED | on the list after `HCI_UNREGISTER` | yes |

### 3.2 Machine B: scheduler and controller ownership (per `hdev`)

```
          Mesh Send with flag clear (hdev->lock)
  IDLE ───────────────────────────────────────▶ START-OWNED ──mesh_send_sync ok──▶ SLOT-OWNED
   ▲                                             │  (start entry queued/running)     (instance le+1 holds
   │                                             │ start fails                        the owner's data;
   │                                             ▼                                    done timer armed)
   │                                          HAND-OVER ◀───── done_sync ───── TEARDOWN-OWNED ◀── timer
   │  nothing pending                            │                              (teardown entry)
   └─────────────────────────────────────────────┤
                                                 └── head pending ─▶ START-OWNED (next request)

  Degenerate states the code reaches:
   SLOT-ORPHANED   owner cancelled while ACTIVE; slot and timer remain. Legitimate if the teardown
                   then matches no request (V3 3/5); wrong if it adopts the head (ML)
   STUCK           flag set, no entry, no timer: power-off swallowed the teardown (ML 1134 + 757-758)
   RESIDUAL-SLOT   the mesh instance exists while B is IDLE or owned by a later request:
                   after a failed start (all), after the ML teardown (never removed), and
                   re-enabled at power-on (extended, phase 5 §D4.2)
   DOUBLE-OWNED    two start entries for the window in ML (§4, T11)
```

| scheduler state | predicate | unambiguous? |
|---|---|---|
| IDLE | `!HCI_MESH_SENDING` | ML: no. The flag is clear during the teardown window (1097) and after a cancelled-start callback (2312), while requests are pending. V3: yes, given HP (V3 1102-1104 comment) |
| START-OWNED | flag ∧ a `mesh_send_sync` entry queued or running | queued: yes; running: no data predicate |
| SLOT-OWNED | flag ∧ mesh instance present ∧ timer pending | no request identity except `adv->mesh` (written, never read) and `tx->instance` (V3) |
| TEARDOWN-OWNED | flag ∧ teardown entry | no identity |
| HAND-OVER | ML: split across `mesh_send_done_sync` (clear) and its destroy `mesh_next` (set), with no common lock. V3: inside `mesh_next()` under `hdev->lock` (V3 1106-1121) | V3 only |

**`HCI_MESH_SENDING` conflates START-OWNED, SLOT-OWNED, TEARDOWN-OWNED and, in ML's `mesh_send()`,
"something is pending".** It says nothing about which request owns what [I].

### 3.3 Coupling: which request transition needs which ownership transition

| request transition (A) | must coincide with (B) | under | ML | V3 |
|---|---|---|---|---|
| ACCEPTED → START-QUEUED (newcomer) | IDLE → START-OWNED | `hdev->lock` | flag tested under `hdev->lock` (2530), but cleared elsewhere without it: drift (T11 window) | coupled (2611-2630; the flag changes only under the lock) |
| QUEUED → START-QUEUED (head) | HAND-OVER → START-OWNED | one lock, atomically with the previous owner's release | destroy `mesh_next`, no `hdev->lock`, flag set **after** the queue (1117-1123) | `mesh_next()` under `hdev->lock` (1112-1120) |
| STARTING → ACTIVE | START-OWNED → SLOT-OWNED | worker (`req_lock`) | identity not recorded except `->instance` | `->instance` used as the slot owner's tag (3/5) |
| STARTING → COMPLETED (error) | START-OWNED → HAND-OVER; slot must be released if created | `hdev->lock` for the list | flag cleared first (2312), list unlocked; slot left [Q phase 5 §D4.2] | locked (2369-2373); slot left (2/5 message: "Recovery of a residual advertising instance is not handled here") |
| ACTIVE → COMPLETED (cancel) | SLOT-OWNED → SLOT-ORPHANED (teardown later matches nobody) | `hdev->lock` | the teardown adopts the head: **drift**, the wrong request completes | the teardown matches `->instance`, finds nobody, removes the slot, hands over |
| FINISHING → COMPLETED | TEARDOWN-OWNED → HAND-OVER, slot removed **before** hand-over | `hdev->lock` for the list; no lock across HCI | flag cleared before teardown; slot never removed | removal (1137) → lock → complete owner → `mesh_next` |
| START-QUEUED → COMPLETED (cancel) | START-OWNED → HAND-OVER | `hdev->lock` | `send_cancel` calls `mesh_next` when the flag is clear (2445); the flag was cleared by the `-ECANCELED` callback (2312) | `dequeued` → `mesh_next()` under `hdev->lock` (2521) |
| any → LEAKED (unregister) | B abandoned | — | the clear completes START-QUEUED unlocked; the rest leak | same, minus `mesh_next` from the teardown destroy |
| ACTIVE across power-off | SLOT-OWNED → TEARDOWN must still happen | — | the teardown enqueue fails → STUCK | `hci_cmd_sync_submit` (V3 1175) |

### 3.4 List membership is not ownership

Every piece of data that encodes some ownership today. Kinds: **E** request existence, **S** start
ownership, **O** slot (advertising) ownership, **T** teardown ownership. "Who changes it" lists
writers with the lock held at ML, plus V3 where it differs.

| encoding | supposed to prove | proves it unambiguously? | who changes it, under which lock |
|---|---|---|---|
| membership of `mesh_pending` | E | **E only, and only with HP** (residue, T4). Says nothing about S/O/T [Q 2544-2547] | add: `mesh_send` (`hdev->lock`). Remove: `mesh_send` error (`hdev->lock`); `mesh_send_done_sync`, `mesh_next`, `mesh_send_start_complete`, `send_cancel` (ML: `req_lock` only; V3: `hdev->lock`); `-ECANCELED` from the clear (`cmd_sync_work_lock`, both); `mgmt_cleanup` (`hci_dev_list_lock` read; finds nothing of its own) [Q] |
| being the head of `mesh_pending` | used by ML as O+T ("the transmission that just ended") | **No**: false after a cancel of the owner, after residue (T4), and after a double start [Q 1100-1103; automated review on AUG] | implicit: any add or remove above |
| `HCI_MESH_SENDING` | "B not IDLE" (S ∨ O ∨ T) | **No**: no identity; cleared during the T11 window and by T8 while pending exists (ML); stale after power-off (ML) [Q §D0.1]. V3: true iff B not IDLE on a live device, given HP [Q 1096-1105] | ML: set `mesh_send` (`hdev->lock`) and `mesh_next` (`req_lock`); cleared `mesh_send_done_sync` and `mesh_send_start_complete` (`req_lock`, or `cmd_sync_work_lock`). V3: only under `hdev->lock` (2630, 1120) |
| a queued `mesh_send_sync` entry, `data == tx` | S for that tx | **Yes while queued**; invisible once running (`hci_sync.c:324`). ML can hold two of them for one tx (T11) [Q] | submit (`unregister_lock` + `cmd_sync_work_lock`); taken by the worker; removed by dequeue or clear (`cmd_sync_work_lock`) |
| a queued `mesh_send_done_sync` entry | T | **No identity** (`data == NULL`) [Q 1134] | queued by `mesh_send_done` (no lock); taken by the worker; cleared at unregister |
| delayed `mesh_send_done` pending | O: "the owner's interval is running" | **No identity**; survives the owner's cancel; re-arming is a no-op if pending [Q 2321; 9795 only cancel] | armed in `mesh_send_start_complete` (`req_lock`); cancelled only by `mgmt_index_removed` (`hdev->lock`) |
| `mesh_tx->instance != 0` | (V3) O for that tx | **Yes under I1**: only one `mesh_send_sync` runs between hand-overs, and a tx whose start then fails is completed in the same destroy. Set even when scheduling fails (2348-2374) [Q; I] | `mesh_send_sync` (`req_lock`); never cleared |
| mesh instance (le+1) in `hdev->adv_instances` | O | **No**: survives its owner (R1/ML), is reused by the next start, can be removed by power-off, Duration expiry or the legacy timeout while the owner is ACTIVE [Q §1.6]. `adv->mesh` holds the handle but is never read [Q 1720] | add/reuse: `mesh_send_sync` (**no `hdev->lock`**). Remove: HCI events, power-off and `hci_remove_adv_sync` (`hdev->lock`); V3 teardown via `hci_remove_advertising_sync` |
| controller set enabled / `HCI_LE_ADV` | "on air" | **No** request identity; reflects the last schedule, not the owner | `hci_sync` enable/disable in the worker; `hci_le_ext_adv_term_evt` (`hdev->lock`) |
| `sock_hold` in `mesh_tx` | keeps the socket alive while E | **Yes for E** (as a pin). It is why T15 is a non-transition (AUG 1/3) [Q 425-426] | `mgmt_mesh_add` / `mgmt_mesh_remove`, under whatever lock the remover holds |
| `sock_hold` in the cancel `mgmt_pending_cmd` | the cancel request's lifetime | yes, since `3c742feda8fc` | `mgmt_pending_new` (`hdev->lock`); `send_cancel_destroy` |

**The pattern [I].** Only two encodings carry request identity at the moment ownership is
exercised: a queued start entry (S), and in V3 `->instance` (O). T has no identity anywhere, so the
teardown must be coupled to O through `->instance` (V3 3/5) or a future owner pointer (§9).

---

## 4. Every transition

Lines are ML unless marked. The concurrency column lists what can run at the same time and touch
the same state.

| # | trigger | function : lines | lock held | reads | writes | may run concurrently |
|---|---|---|---|---|---|---|
| T1 | Mesh Send, scheduler idle | `mesh_send` 2491-2558 [Q] | `hdev->lock` | flag (2530), per-socket count (2522) | list add (2531), start entry (2536), flag set (2549), reply `&mesh_tx->handle` (2551-2552) | ML: the worker freeing the same tx without `hdev->lock` (AUG 2/3 KASAN: "slab-use-after-free in mgmt_cmd_complete … mesh_send_start_complete" [Q]). V3: none on the list (worker locked), except the clear path |
| T2 | Mesh Send, busy | same; `sending == true` | `hdev->lock` | flag | list add, flag set again | as T1 |
| T3 | rejected before acceptance | 2500-2528 | none / `hdev->lock` | flags, length, count | nothing | — |
| T4 | first enqueue fails | 2539-2547 [Q] `if (mesh_tx) { if (sending) mgmt_mesh_remove(mesh_tx); }` | `hdev->lock` | `sending` | **nothing**: the tx stays (inverted condition) | — |
| T5 | start work runs | `mesh_send_sync` 2325-2377 [Q] | `req_lock` | `adv_instance_cnt` (2334), tx param | adv instance add/reuse (2339, **without `hdev->lock`**), `tx->instance` (2349), controller (2374) | HCI events removing instances under `hdev->lock`; Add Advertising; Read Mesh Features |
| T6 | start succeeds | `mesh_send_start_complete` 2320-2322 | `req_lock` | `send->cnt` | arms the delayed work | — |
| T7 | start fails (`err != -ECANCELED`) | 2311-2317 [Q] | `req_lock` (ML); `hdev->lock` (V3 2369-2373) | — | flag clear (2312, ML), complete with event (2314), `mesh_next` (2316) | ML: syscall `mesh_send` (flag window) |
| T8 | start dequeued by `send_cancel` | same callback, `err == -ECANCELED` | `req_lock` + `cmd_sync_work_lock` (+ `hdev->lock` in V3) | — | ML: flag clear, complete; no `mesh_next`. V3 2364-2366: complete only | ML: syscall list readers |
| T9 | start entry cancelled at unregister | same, from `hci_cmd_sync_clear` 670-673 | `cmd_sync_work_lock` only | — | ML and V3: complete with event, **list unlocked**. AUG: return, tx left | syscall `mesh_send` / `mesh_features` under `hdev->lock` (still possible until index removal) [I] |
| T10 | done timer fires | `mesh_send_done` 1126-1135 [Q] | none | flag (1131) | queues the teardown entry with `hci_cmd_sync_queue`, which "`if (!test_bit(HCI_RUNNING, &hdev->flags)) return -ENETDOWN;`" (`hci_sync.c:757-758`); return value ignored | — |
| T11 | teardown runs | `mesh_send_done_sync` 1093-1106 + destroy `mesh_next` 1110-1124 [Q] | `req_lock` | the head (1100) | **flag clear first (1097)**; disable if `list_empty(&hdev->adv_instances)` (1098-1099); complete **head** (1102-1103); then the destroy queues the head's start (1117) and sets the flag (1123), or completes the head on failure (1121) | syscall `mesh_send` between 1097 and 1123 sees the flag clear and queues its own start; the destroy queues the head again → **double start** [Q, V3 1/5 message; recorded in phase 3 per the cover: "the hold test observed the second request started twice"] |
| T11-V3 | teardown runs | V3 `mesh_send_done_sync` 1123-1160 | removal and disable without `hdev->lock`; then `hdev->lock` | the tx with `instance == le+1` (1148-1153) | `hci_remove_advertising_sync(..., le+1, true)` (1137), complete the **owner**, `mesh_next` loop (1112-1120), flag cleared only when the list is empty | none on the list |
| T12 | cancel by handle | `mesh_send_cancel` 2456-2489 (syscall, `hdev->lock`) → `send_cancel` 2416-2449 (worker) [Q] | ML: `req_lock`; V3: + `hdev->lock` (2487) | `mgmt_mesh_find(handle)`, socket match (2433-2435) | dequeue the start, or complete (2436-2438); reply (2442); `if (!flag) mesh_next` (2445-2446). V3: `if (dequeued) mesh_next` (2521) | ML: syscall readers (AUG 2/3 KASAN in `send_count` from `mesh_features` [Q]) |
| T13 | cancel all (handle 0) | 2422-2431 | as T12 | `mgmt_mesh_next(hdev, cmd->sk)` loop | per entry as T12 | as T12 |
| T14 | cancel command itself cancelled | `send_cancel_destroy` 2451-2454 | `cmd_sync_work_lock` (clear) or `req_lock` | — | `mgmt_pending_free` | — |
| T15 | socket close | `hci_sock_destruct` → `mgmt_cleanup` 10913-10930 [Q] | `read_lock(hci_dev_list_lock)` + whatever the dropping thread holds | **every** hdev's `mesh_pending`, unlocked | would complete the socket's tx silently, but finds none: AUG 1/3 "It can never find one … the socket's reference count cannot reach zero while one of its entries is there" [Q] | worker unlinking and freeing nodes of other sockets: "mgmt_mesh_next() loads mesh_tx->sk from every node it passes … while the cmd_sync worker unlinks and frees nodes" [Q, AUG 1/3] |
| T16 | power off (Set Powered) | `hci_power_off_sync` 6066-6101 → `hci_clear_adv_sync(hdev, NULL, false)` 6083 → `hci_dev_close_sync` 5536-5688 [Q] | worker `req_lock`; `hdev->lock` inside | adv instances | legacy: removes instances with a timeout, the mesh one included, and emits Advertising Removed (2150-2160). Extended: Clear Sets → `hci_cc_le_clear_adv_sets` removes every host instance (1522-1533). `__mgmt_power_off` handles `mgmt_pending` only (9822-9855). `mesh_pending` and the flag are untouched | the delayed done work; queued start entries run after close and fail with `-EINVAL` [Q, phase 5 §D2: "start_complete … err=-22"] |
| T17 | power on | `hci_power_on_sync` path | — | adv instances | re-programs remaining instances; a residual mesh instance is re-enabled [Q, phase 5 §D4.2: "the power-on sequence re-programs and re-enables the mesh set with request 2's packet"] | — |
| T18 | unregister | `hci_unregister_dev` 2666-2718 [Q] | see §2.1 | — | `HCI_UNREGISTER` (2671) → the worker stops taking entries (`hci_sync.c:316-317`) → `hci_cmd_sync_clear` (2690): T9 for start entries; ML teardown entry: `mesh_next(-ECANCELED)` → queue fails → **completes the head**, unlocked (1112-1121); V3 teardown entry: destroy `NULL`, nothing → `mgmt_index_removed` under `hdev->lock` cancels the delayed work (9795) → the list is never freed | syscall MGMT commands until index removal |
| T19 | `hci_cmd_sync_clear` in general | only caller `hci_core.c:2690` [Q, grep] | — | — | = T18 | — |

**What T16 means for a request that is ACTIVE when the power goes off [Q, phase 5 §D0.1].** In ML
the done work later fires while the device is down. `hci_cmd_sync_queue()` returns `-ENETDOWN` and
nothing completes the owner or clears the flag. After power-on "Mesh Send 3 is acknowledged and
nothing is ever started for it" (scheduler STUCK). Phase 5 recorded this on the three-patch kernel;
the same tail exists at `08e90633377f`. V3 4/5 submits instead; recorded 55/55.

---

## 5. Invariants

The reviewer's seven come first, made precise; I8–I14 are added. "Owner" means the request in
STARTING, ACTIVE or FINISHING, i.e. Machine B not IDLE.

| id | invariant | precise statement |
|---|---|---|
| I1 | single owner | At any time at most one request is in START-QUEUED ∪ STARTING ∪ ACTIVE ∪ FINISHING, and at most one `mesh_send_sync` entry exists, queued or running. |
| I2 | accepted requests stay until their own end | A request that got a handle leaves `mesh_pending` only by (a) its own completion after its own transmission or start failure, (b) a cancel naming it or its socket, or (c) a stated unregister policy. Never because another request's teardown ran. |
| I3 | a rejected request leaves no residue | If Mesh Send returned a failure status, no `mesh_tx` for it remains on `mesh_pending`, and it is never started or completed. |
| I4 | hand-over is FIFO and atomic | The decision "start the head of `mesh_pending`, or go idle" and the matching flag change happen in one critical section of the lock `mesh_send()` tests the flag under (`hdev->lock`). The next owner is the oldest accepted request. |
| I5 | no work holds what cancel can free | Every pointer a queued or running work entry holds stays valid until that entry has run its destroy, or is dequeued (its destroy runs then). |
| I6 | deliberate drain at unregister | At unregister every request on `mesh_pending` is either completed with an event or freed silently, by one stated rule, under a lock that excludes list readers. Socket references are dropped. No callback under `cmd_sync_work_lock` takes `hdev->lock` or `unregister_lock`. |
| I7 | slot teardown belongs to its owner | The mesh advertising instance is created by the owner's start and removed by the owner's teardown (success, cancel-then-deadline, or start failure). No completed request's data stays on air or is re-enabled later. Other advertisers are untouched. |
| I8 | completion identity | Mesh Packet Complete for handle H is sent exactly once per accepted H, and only by H's own completion, failure or cancel. |
| I9 | list lock | Every read and every modification of `mesh_pending` and of `mesh_tx` fields after linking happens under `hdev->lock`, including the socket destructor and `-ECANCELED` callbacks. |
| I10 | flag truthfulness and liveness | `HCI_MESH_SENDING` is set iff Machine B is not IDLE. B never stays non-IDLE without a queued entry, a running entry or an armed timer that will move it on, including across power-off and power-on. |
| I11 | callback lock discipline | A destroy callback that can run under `cmd_sync_work_lock` (dequeue, clear) neither takes `hdev->lock` nor re-enters `hci_cmd_sync_submit`. |
| I12 | advertising list lock | `hdev->adv_instances` is changed only under `hdev->lock` (`hci_core.c:1673` contract), including by `mesh_send_sync`. |
| I13 | a cancelled request never goes on air | After a cancel naming it, a request's start never runs, and its data stops being advertised no later than its original deadline. |
| I14 | the internal slot is invisible | No Advertising Added or Removed event is ever sent for instance `le_num_of_adv_sets + 1`. |

---

## 6. Matrix: invariants × revisions

**H** holds. **V** violated (transition, lines). **·** not addressed: inherits the column to its left
in the lineage (ML for HP / V3; R1 + `3c742feda8fc` for AUG; R1 for FEB). **(H)** holds given an
assumption stated in the cell. Marks: the `[Q]`/`[I]` after each cell.

| | R0 `b338d91703fa` | R1 + `f3cb5676e5c1` | ML (+`71af682ba469`, `3c742feda8fc`, `b1f24c1ab523`) | HP | FEB v4 | AUG v2 as posted | V3 alone | V3 + HP |
|---|---|---|---|---|---|---|---|---|
| I1 single owner | V: T11 window, R0 1073 vs 2429-2435 [I] | V (same) | V: T11, 1097 vs 2530-2536 [Q V3 1/5 msg; recorded double start] | · V | · V (does not build) | V: the flag is still cleared before the lock in `mesh_send_done_sync` [Q /798 hunk] | (H) given single-enqueue success; still holds without HP (A is not started concurrently) [I] | H [Q runs 55/55] |
| I2 own end only | V: head completed (1075-1078); start error strands the queue (2244-2248, no `mesh_next`) [Q] | V | V: head completed (1100-1103) [Q; automated review "complete the wrong transaction", preexisting, High] | · V | · V | V, worse: cancelled starts run, then the teardown pops the next head [Q, automated review on 3/3] | H via `->instance` (1148-1153) [Q] | H |
| I3 no residue | V: 2443-2446 [Q] | V | V: 2544-2547 [Q] | **H** [Q diff] | · V | V [Q, automated review on 1/3 and 3/3, preexisting] | V: 2625-2628, and the residue is later **started** [Q phase 5: 53/55, "rejected start ×2"] | H [Q 55/55] |
| I4 atomic FIFO hand-over | V: split T11/destroy, no lock [Q] | V | V; `send_cancel` hands over on "flag clear" (2445) [Q] | · V | · V | V: `mesh_next` locked, but the clear outside it; start error has no hand-over on its base [I from /798] | H (`mesh_next` under `hdev->lock`, lockdep-asserted 1110) [Q] | H |
| I5 no freed pointers in work | V: `send_cancel` frees a tx whose start is queued [Q, `71af682ba469` msg] | V | (H) for `send_cancel` via dequeue (2427, 2436); the I1 double queue plus a start failure would free a tx with a second entry still queued [I] | · | · V | H by refcount (/800) [Q] | H (I1 removes the double queue) [I] | H |
| I6 unregister drain | V: no drain; on R0 the worker drained the backlog by running it [Q R0 `hci_sync.c:283-310`] | V | V: START-QUEUED completed unlocked (T9); teardown destroy completes the head via `mesh_next` (T18); the rest leak [Q phase 5 §D4.1; I] | · V | · V | V, documented: "The entry such a return leaves on hdev->mesh_pending stays there" [Q /798]; flagged as a leak [Q automated review] | V: as ML, minus the head completion (teardown destroy `NULL`) [Q] | V |
| I7 slot teardown | V: disables **all** advertising (1074), never removes the instance [Q] | V: never disabled while the mesh instance exists (list non-empty) [Q, V3 2/5 msg] | V (same) [Q] | · V | · V | · V | (H) success and cancel paths remove it (1137); a failed start leaves it, and extended re-enables it at power-on [Q §D4.2] | (H) same |
| I8 completion identity | V: wrong head [I] | V | V (wrong head) [Q] | · V | · V | V: plus a duplicate completion for a cancelled-then-failed start [Q, automated review on 3/3] | H [I, runs] | H |
| I9 list lock | V: worker side unlocked [Q] | V | V: worker unlocked; `mgmt_cleanup` unlocked [Q AUG 2/3 KASAN] | · V | V: `guard(spinlock)(&hdev->lock)` on a mutex → build error [Q: "incompatible pointer types passing 'struct mutex *' … 'spinlock_t *'", automated build report 2026-02-08, msg911613]; as a mutex guard it would self-deadlock in `mgmt_mesh_add`, called with `hdev->lock` held (2517, 2531) [I] | H on the worker side; `mgmt_cleanup` removed (1/3); `-ECANCELED` callbacks touch nothing [Q] | partial: worker under `hdev->lock`; the T9 clear path unlocked (2365 from the clear); `mgmt_cleanup` kept (10994) [Q] | partial |
| I10 flag truth and liveness | V: start error clears the flag with others pending; power-off STUCK [Q, I] | V | V: power-off STUCK (1134 + 757-758) [Q §D0.1] | · V | · V | V: power-off STUCK (not addressed) [I] | H for Set Powered (4/5, 1175); rfkill and `HCIDEVDOWN` untested [Q §D0] | H (same scope) |
| I11 callback lock discipline | V: destroy `mesh_next` under clear → submit [I] | V | V: `mesh_next(-ECANCELED)` → `unregister_lock` (§2.2) [I] | · V | · V | H: both destroys return on `-ECANCELED` [Q] | H: teardown destroy `NULL`; `-ECANCELED` branch only completes [Q] | H |
| I12 adv list lock | V: `mesh_send_sync` → `hci_add_adv_instance` without `hdev->lock` [Q 2270; I] | V | V (2339) [Q; I] | · V | · V | · V | · V (V3 2389-2413 unchanged) | · V |
| I13 cancelled never on air | V: UAF instead [Q] | V: cancelled ACTIVE stays on air for seconds (never torn down) [Q] | V: ACTIVE on air until 1000 s / Duration (16.96 s) [Q §B1]; START-QUEUED H (dequeue) | · V | · V | V: a cancelled START-QUEUED runs: "A cancel that arrives before the queued mesh_send_sync() now lets that send run" [Q /800] | H: ends at the original cnt × 25 ms deadline (1137) [Q] | H |
| I14 internal slot invisible | V: legacy power-off emits Removed for le+1 (`hci_clear_adv_sync` 2159 path) [I] | V | V [Q, phase 5 §D0.1: "Advertising Removed for instance 6" on the unpatched base] | · V | · V | · V | H: `mgmt_advertising_removed` returns for `instance > le_num_of_adv_sets` (V3 1336) [Q] | H |

---

## 7. Map of patches onto transitions

| patch | date, author | transitions changed | what it does to the machines | invariants |
|---|---|---|---|---|
| `b338d91703fa` | 2022-09-01, Brian Gix | defines T1-T18 | head-as-owner; flag as the only scheduler state; teardown = disable all | origin of I1-I4, I6-I8, I10, I12 violations |
| `f3cb5676e5c1` | 2025-06-25, Christian Eggers | T11 | `if (list_empty(&hdev->adv_instances)) hci_disable_advertising_sync(hdev);`. The author: "I am not sure whether this call is required at all, but checking the adv_instances list … seems to solve the problem" [Q, rv3-f3cb.html]. Protects other advertisers but the mesh instance keeps the list non-empty, so the mesh slot is never released | fixes "other advertisers" in I7, breaks "owner's slot released" in I7 and I13 |
| FEB v4 1/2 | 2026-02-08, Maiquel Paiva | T1 (allocation) | length check in `mgmt_mesh_add`: not state machine; the overflow was fixed in 2022 by `2185e0fdbb21` (Harshit Mogalapalli) [Q] | — |
| FEB v4 2/2 | 2026-02-08, Maiquel Paiva | T1, T12 (find) | `guard(spinlock)(&hdev->lock)` in `mgmt_mesh_find`/`mgmt_mesh_add`. Maintainer: "Not sure why you switched to use hdev->lock and not mgmt_pending_lock? And that is a mutex still, not a spinlock." [Q, https://www.spinics.net/lists/stable/msg912251.html, 2026-02-09] | I9 attempted; does not build [Q] |
| `3c742feda8fc` | 2026-08-06, Linmao Li | T14 | `send_cancel_destroy` frees the cancel command on both run and `-ECANCELED` | cancel-command lifetime (outside I1-I14; closes a socket pin) |
| AUG 1/3 | 2026-08-07, Baul Lee | T15 | removes `mgmt_cleanup()` and its call | I9 (destructor leg) |
| AUG 2/3 | 2026-08-07, Baul Lee | T7, T8/T9, T11, T12, T18; helpers | `hdev->lock` on the worker side around list work, not around the disable; `lockdep_assert_held` in `mesh_send_complete`, `mgmt_mesh_foreach/next/find/add`; both destroys return on `-ECANCELED` | I9, I11; makes I6 an explicit leak; leaves I1/I2/I4 |
| AUG 3/3 | 2026-08-07, Baul Lee | T1, T5, T8, T12 | refcount per queued pointer; `mgmt_mesh_remove` = unlink + put; a cancelled START-QUEUED **runs** | I5 by keeping objects alive; violates I13 and I8 (new) |
| `71af682ba469` | 2026-09-15, Lee Jones | T7, T8, T12, T13 | dequeue the start before completing on cancel; `mesh_next` after a start error unless `-ECANCELED`; `send_cancel` hands over if the flag is clear | I5 (cancel leg), I13 (queued leg), part of I10 (start error no longer strands) |
| `b1f24c1ab523` | 2026-09-27, Nguyen Ngoc Thang | T18 | the worker stops at `HCI_UNREGISTER`; the backlog is destroyed with `-ECANCELED` by the clear | turns every queued mesh entry at unregister into a T9 / teardown-destroy call: I6 and I11 now matter on every unplug with a backlog [I] |
| Hui Peng cleanup | 2026-09-19, Hui Peng | T4 | `if (mesh_tx) mgmt_mesh_remove(mesh_tx);`. The author: "Found by code inspection … I have not reproduced the leak on its own … Compile tested only." [Q, https://lkml.iu.edu/2609.2/10074.html] | I3 |
| V3 1/5 | this project | T1/T2 (comment), T7, T8, T11, T12, T13; `mesh_next` signature | the flag is set and cleared only under `hdev->lock`; `mesh_next()` is a locked loop that skips unqueueable heads; teardown destroy `NULL`; `-ECANCELED` branch completes only; `send_cancel` hands over iff it dequeued | I1, I4, I9 (worker side), I11 |
| V3 2/5 | this project | T11, T16 (events), T17 indirectly | `hci_remove_advertising_sync(le+1, force)` before the `list_empty` check; suppress Removed events for `> le_num_of_adv_sets` | I7 (success path), I13 (active leg), I14 |
| V3 3/5 | this project | T11 | complete the tx with `instance == le+1`, not the head | I2, I8 |
| V3 4/5 | this project | T10 | `hci_cmd_sync_submit` instead of `queue`, so teardown runs on a closed device | I10 |
| V3 5/5 | this project | T6 (comment only) | documents cnt × 25 ms vs interval | none (Count question, §9) |
| Option-1 Count alternative | this project (`99ccb3ab4861`, kept on `mesh/phase5-alternative-count-deadline-on-bluetooth-master-2026-10-03`) | T6 | deadline = 25 + (cnt − 1)·(interval + 10) ms | none of I1-I14. It lengthens ACTIVE; measured 20/55 because pre-existing Count-3 cases time out [Q §B3, §G2] |

### 7.1 The comparison table the reviewer asked for

Columns are the problem as a transition: current upstream (ML), the February proposal, the August
proposal, Hui Peng's cleanup, this project's v3, and what stays uncertain.

| transition / problem | current upstream (ML) | Feb 2026 | Aug 2026 | Hui Peng | v3 | remaining uncertainty |
|---|---|---|---|---|---|---|
| T11 flag clear → newcomer queues its own start (double start) | open (1097) | no | **no**: the clear stays outside and before the lock [Q /798] | no | fixed (1/5) | none for the live device, given HP |
| T11 teardown completes the head, not the owner | open (1100-1103) | no | no; 3/3 makes it more frequent [Q automated review] | no | fixed (3/5) | `->instance` is set before scheduling succeeds; harmless only because start failure completes synchronously [I] |
| T4 rejected request stays listed | open | no | no (3/3 touches the same lines, conflicting text) | **fixed** | depends on it [Q 1/5 msg] | the exact patch not yet validated (research review follow-up) |
| T12 cancel frees a tx with a queued start | fixed by dequeue (`71af682ba469`) | no | fixed by refcount on a base without dequeue; the start then runs | — | keeps the dequeue, hands over iff dequeued | whether the maintainers want "cancelled = never runs" (dequeue) or "lifetime only" (refcount) — the two disagree on I13 |
| T12 cancel of an ACTIVE request | completes it; the slot stays on air for seconds; a later teardown adopts the head | no | no | no | completed; slot removed at the original deadline; hand-over by the teardown | whether cancel should tear down at once (would need HCI in `send_cancel`) [I] |
| syscall readers vs worker frees (list lock) | open (KASAN reproduced by Baul Lee [Q /798]) | attempted, broken | fixed (2/3) | — | fixed for every worker path except the clear (1/5) | v3 has no `lockdep_assert_held` in the helpers |
| T15 destructor walks other hdevs' lists unlocked | open | no | fixed by removal (1/3) | — | **open** (10994 unchanged) | none; AUG 1/3's argument holds on every revision (`sock_hold` in `mgmt_mesh_add` since R0) [Q] |
| T9/T18 `-ECANCELED` at unregister | START-QUEUED completed unlocked; teardown destroy completes the head and calls into submit | — | leave everything on the list (leak, stated) | — | START-QUEUED completed unlocked; owner and rest leak | the drain policy is a maintainer decision (§9) |
| T10/T16 power-off swallows the teardown | open (STUCK) | — | open | — | fixed (4/5) | rfkill, `HCIDEVDOWN` and real drivers untested; `hci_cmd_sync_submit` can still fail on allocation |
| T5 failed start leaves the slot; T17 re-enables it | open | — | open | — | open (stated in 2/5) | needs an error-injection case (research review on 2/5) |
| T5 `hci_add_adv_instance` without `hdev->lock` | open [Q 2339, contract 1673] | — | open | — | open | not reproduced; [I] only |
| T6 Count vs deadline | cnt × 25 ms; slot never torn down, so seconds on air | — | — | — | the deadline now ends the slot: 1 event at the default interval [Q §B2] | an ABI question (§9) |

**Hypothesis: "August addressed request lifetime and left scheduler ownership underspecified; v3
addresses scheduler ownership and depends on lifetime cleanup."**

- **August half: confirmed by the code.**
  - Lifetime: 1/3 fixes the destructor walk, 2/3 the list lock, 3/3 pointer validity.
  - Scheduler: none of the three changes where the flag is cleared, whom the teardown completes,
    power-off liveness or slot teardown. AUG 2/3 still has `hci_dev_clear_flag(hdev,
    HCI_MESH_SENDING)` before `hci_dev_lock(hdev)` in `mesh_send_done_sync` [Q /798].
  - 3/3 widens the scheduler gap. It lets a cancelled start run, and the automated review the
    maintainer linked found, as a new issue, "State machine corruption due to unlinked transmission
    proceeding to execute", plus a duplicate completion event [Q].
  - The one scheduler-side change AUG makes is moving `mesh_next`'s hand-over under `hdev->lock`.
- **v3 half: partly refuted as stated.**
  - v3 is not purely about scheduler ownership. 1/5 also delivers AUG 2/3's worker-side list locking
    for every worker path except the clear callback: `send_cancel` 2487, `mesh_send_start_complete`
    2369, `mesh_send_done_sync` 1142.
  - So the two KASAN reports in AUG 2/3 (`send_count` vs `send_cancel`, `mgmt_cmd_complete` vs
    `mesh_send_start_complete`) are covered by v3 by construction [I; not re-run against AUG's
    reproducers, which are not public — NF].
  - v3 has a hard dependency on one lifetime fix, Hui Peng's T4 cleanup: without it I3 fails and
    the residue is later started [Q, 53/55].
  - v3 relies on `71af682ba469` for I5, which is already merged.
  - v3 does **not** depend on AUG. It leaves open AUG 1/3's destructor walk (T15) and the
    unregister policy (T9/T18), which AUG also leaves open, as a stated leak.

---

## 8. Overlaps, conflicts, and what a reconciled minimal set would need

This section is analysis for the operator, not a decision.

### 8.1 V3 1/5 and AUG 2/3 both put `mesh_pending` under `hdev->lock`

**Same idea, different shape [Q, both diffs]:**

| point | AUG 2/3 | V3 1/5 |
|---|---|---|
| `mesh_send_done_sync` | lock around the head completion only, after the flag clear and the disable | lock around owner completion **and** hand-over, after teardown; the flag is never cleared here |
| `mesh_next` | stays the destroy callback; takes the lock; returns on `-ECANCELED` | becomes a plain function called with the lock held (asserted); the teardown destroy is `NULL` |
| `mesh_send_start_complete` | returns on `-ECANCELED`; locks around the error completion; no hand-over (base pre-`71af682ba469`) | `-ECANCELED` completes without the lock; error path locks, completes, hands over |
| `send_cancel` | lock around the list loop; unlock **before** the reply | lock around everything including the reply and the hand-over |
| assertions | `lockdep_assert_held` in `mesh_send_complete` and four helpers | only in `mesh_next` |

**Hard conflict [I].** AUG's `lockdep_assert_held(&hdev->lock)` in `mesh_send_complete` would fire
on V3's `-ECANCELED` branch when it is reached from `hci_cmd_sync_clear()`, which holds no
`hdev->lock`. From `send_cancel` V3 holds the lock, so that path is fine. Combining the two needs one
policy for that branch: AUG's "touch nothing" or a deferred drain (8.2).

**Textual conflict [I].** Both rewrite `send_cancel`, `mesh_next` and `mesh_send_done_sync`; neither
applies on top of the other.

### 8.2 The `-ECANCELED` destroy from `hci_cmd_sync_clear`

**Three different policies exist today [Q]:**
- ML: complete with event, unlocked. For the teardown entry, the destroy runs `mesh_next` and
  completes the head after a failed submit (§2.2).
- AUG: leave everything on the list.
- V3: complete START-QUEUED unlocked; do nothing for the teardown entry.

**None is under `hdev->lock`, and none can be.** I11 forbids taking it there [Q, the AUG lockdep
chain].

**Since `b1f24c1ab523` this path runs on every unregister that has a backlog** [Q, commit message].

**A reconciled design needs two parts [I]:**
1. **The callback touches nothing.** It neither completes nor frees: AUG's rule. The object stays
   valid because it stays on the list.
2. **One drain, under `hdev->lock`, after the worker has stopped and the delayed work is cancelled.**
   The natural spot is `mgmt_index_removed()`, which already runs under `hdev->lock`
   (`hci_core.c:2699-2701`) and cancels the delayed work (9795). It would walk `mesh_pending` with one
   rule, complete-with-event or silent free, dropping the socket references.

**What that does to the other cases [I]:**
- It closes AUG's documented leak, D4.1, and the AUG automated review's leak finding.
- `mgmt_index_removed()` is skipped for devices still in `HCI_INIT`, `HCI_SETUP` or `HCI_CONFIG`
  (2696-2698). Mesh cannot be enabled in those states, so this is probably harmless, but it is
  unverified.

### 8.3 `mgmt_cleanup()`

- **V3 keeps it; AUG 1/3 removes it.**
- **AUG's argument holds on every revision [Q `mgmt_util.c:425-426`; phase 5 §E traces]:** the
  socket cannot be destroyed while it has entries.
- **V3 makes the walk run more often under `hdev->lock` [Q, phase 5 §E].** The final `sock_put` now
  happens inside locked completions. That protects the current hdev's list but not the others.
- **Removal is compatible with V3 and belongs in any reconciled set [I].** It touches different
  hunks (`hci_sock.c`, `bluetooth.h`, the end of `mgmt.c`).

### 8.4 AUG 3/3 refcount versus `71af682ba469` dequeue

- **Both repair I5 at T12.**
- **They disagree on I13** [Q /800: "suppressing the transmission as well is a separate change"].
  Dequeue drops the start; the refcount lets it run.
- **On ML the refcount's motivating UAF is already closed by the dequeue.** Hui Peng says the same
  about his own withdrawn UAF patch: "71af682ba469 … already fixed the use-after-free, and did it
  better than I had" [Q].
- **With V3's I1, no second entry can reference a freed tx [I].** A refcount then adds safety
  without a proven need.
- **If the maintainers still want it**, it must not replace the dequeue, or I13 and I8 break.
  (The automated review flagged the duplicate completion as new [Q].)
- **Text.** It conflicts with Hui Peng's hunk at `mesh_send()`'s error path.

### 8.5 Hui Peng's cleanup and V3 1/5

Different hunks, no textual conflict [Q, both diffs]. V3 1/5's comment and message state the
dependency [Q V3 1102-1104]. The phase 5 runs used a local equivalent, not the posted patch [Q,
research review "Correction"].

### 8.6 V3 2/5's predicate

- **The issue.** `instance > hdev->le_num_of_adv_sets` (V3 1336) also hides any hypothetical instance
  above the range. Today `hci_add_adv_instance` rejects `> le_num_of_adv_sets + 1` (1690), so only
  le+1 can exist [Q].
- **The research review asked for the exact form** (`== le_num_of_adv_sets + 1` or a helper). It
  would also serve `mesh_send_sync`, `mesh_send_done_sync` and 3/5's match, so all four places name
  the slot the same way [I].

### 8.7 A reconciled minimal set (for discussion)

| order | content | origin | invariants |
|---|---|---|---|
| 1 | T4 cleanup | Hui Peng, as posted (exact patch, his authorship) | I3 |
| 2 | remove `mgmt_cleanup()` | AUG 1/3 (Baul Lee) | I9 (destructor) |
| 3 | worker-side `hdev->lock` + atomic hand-over + lockdep assertions in the helpers; `-ECANCELED` callbacks touch nothing | V3 1/5 merged with AUG 2/3's assertions and its `-ECANCELED` rule; joint credit to be agreed with Baul Lee | I1, I4, I9, I11 |
| 4 | unregister drain under `hdev->lock` | **nobody has written it** | I6 |
| 5 | owner identity | V3 3/5 | I2, I8 |
| 6 | slot teardown with the exact predicate + event suppression; error-injection case for a failed removal or start | V3 2/5 refined | I7, I13, I14 |
| 7 | power-off liveness (separately sendable) | V3 4/5 | I10 |
| — | `mesh_send_sync` under `hdev->lock` around `hci_add_adv_instance` | **nobody has written it** | I12 |
| — | not included: AUG 3/3 (refcount), V3 5/5 (comment), Option 1 | — | Count is an RFC (§9) |

---

## 9. Open questions only the maintainers can answer

1. **Drain policy at unregister.**
   - Should requests still on `mesh_pending` when the index goes away get Mesh Packet Complete
     (userspace learns the handle is free, but the index is going away anyway) or be freed
     silently?
   - Is the drain's place `mgmt_index_removed()`?
   - Should power-off without unregister also drain? V3 4/5 completes on the closed device instead.
   - Today three policies coexist (§8.2), and none is stated anywhere [NF: no comment or document
     names one].
2. **What Count means.**
   - `doc/mgmt-protocol.rst`: "the number of times this packet will be sent before transmission
     completes" [Q, phase 5 §B1]. The kernel arms cnt × 25 ms against a 1280 ms default interval and
     sets Max Extended Advertising Events = 0 [Q].
   - Before V3 the slot was never torn down, so Count had no effect at all. With V3 it bounds
     airtime to one event at the default interval [Q §B2].
   - Is Count a controller event count (extended only), a host deadline, or advisory? The only known
     client sends cnt = 1 and retransmits itself [Q §B1].
3. **Should `HCI_MESH_SENDING` remain, or be derived?**
   - The flag conflates three ownership phases (§3.2).
   - Derived alternatives [I]:
     - "a `mesh_tx` with a non-zero owner tag exists, or a start entry exists".
     - An explicit `hdev->mesh_owner` pointer set at hand-over and cleared at teardown under
       `hdev->lock`. That pointer would also replace `->instance` as the identity, and make
       `adv->mesh` (written, never read [Q]) unnecessary.
   - Whether the subsystem prefers a pointer in `struct hci_dev` over a flag is a style call.
4. **Is `cnt × 25 ms` + `timeout = 1000` + Duration overflow one design or three accidents?**
   - The instance's 1000-second timeout (legacy expiry) and the extended Duration (16.96 s after
     u16 truncation) both outlive the host deadline [Q §B1; duration note].
   - With teardown at the deadline they no longer matter, except for a residual slot. Should the
     instance be added with a timeout that matches the deadline?
5. **Lock owner for `mesh_pending`.** `hdev->lock` (AUG, V3) or a dedicated mutex? The maintainer
   asked FEB "why … hdev->lock and not mgmt_pending_lock?" [Q msg912251]. AUG and V3 both chose
   `hdev->lock`. Neither has the maintainer's answer to that question on record [NF].
6. **Cancel of an ACTIVE request.** Should it tear the slot down at once (HCI from `send_cancel`,
   which runs in the worker and could) or at the original deadline (V3)? The protocol text allows
   "unsuccessful transmission" [Q, review v2 §A2]; it does not require immediacy.
7. **`hci_add_adv_instance` from `mesh_send_sync` without `hdev->lock`** (I12). Was it deliberate
   (worker-only access assumed), or an omission? Other worker paths take the lock (`hci_clear_adv_sync`
   2147, `hci_remove_adv_sync` 2179) [Q].
