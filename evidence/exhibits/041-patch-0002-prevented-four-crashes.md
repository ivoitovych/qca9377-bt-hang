# EX-041 — patch-0002-prevented-four-crashes

**Claim.** `patches/bluez/0002` has **fired four times** in 19 days of real use on the
affected machine. Each firing is a `transport_cb()` reaching the accept with a valid
`a2dp_setup` whose `stream` was NULL — the exact condition that, unpatched, dereferences
NULL inside `avdtp_stream_set_transport()`. **Four crashes were prevented, not merely
absent.**

**Relevance.** ⚠️ `EX-035` stated the gap precisely and could not close it:

> Both patches log before they bail, so a firing would be **positive** evidence that a
> crash was prevented. Zero means the protected paths were not reached at all. So this run
> does not test the patches' behaviour.

This closes it. It is the first runtime evidence that either patch does the thing it was
written to do.

## Extraction method

⚠️ **Use the `_COMM` field filter.** A plain `journalctl --no-pager --since … | grep` over
this machine's journal walks ~19 days of dynamic-debug output and did not finish in ten
minutes. Filtering on the indexed field answers the same question in about thirty seconds,
because journald selects on the field instead of streaming every record:

```console
$ journalctl _COMM=bluetoothd --since '2026-08-25' --no-pager -o short-iso | grep -E 'has no stream|Wrong size of start discovery'
```

## Output

Verbatim, 5 line(s), exit status 0.

```
2026-08-26T09:46:24+02:00 n bluetoothd[2854]: profiles/audio/a2dp.c:transport_cb() bt_io_accept: setup 0x556565854330 has no stream
2026-09-02T15:38:58+02:00 n bluetoothd[2956]: profiles/audio/a2dp.c:transport_cb() bt_io_accept: setup 0x5772c3346600 has no stream
2026-09-02T15:47:15+02:00 n bluetoothd[2956]: profiles/audio/a2dp.c:transport_cb() bt_io_accept: setup 0x5772c3382e60 has no stream
2026-09-02T19:28:35+02:00 n bluetoothd[2956]: profiles/audio/a2dp.c:transport_cb() bt_io_accept: setup 0x5772c33858f0 has no stream
2026-09-08T10:27:19+02:00 n bluetoothd[5226]: Wrong size of start discovery return parameters
```

## Reading

**Four firings of `0002`** — one on 08-26, three on 09-02, across two daemon lifetimes
(PIDs 2854 and 2956) and three distinct `setup` pointers on 09-02. This is not one event
logged repeatedly.

Each is the guard the patch adds:

```c
	if (!setup->stream) {
		error("bt_io_accept: setup %p has no stream", setup);
		goto drop;
	}
```

Reached only after `g_slist_find(setups, setup)` has already confirmed the setup is still
valid — so the setup lived and its stream did not, which is exactly the lifetime gap the
patch describes. Unpatched, control falls into `avdtp_stream_set_transport(setup->stream,…)`,
which dereferences the argument on its first line.

**The fifth line is `0001`'s string but NOT `0001`'s guard.** The identical message exists at
two sites; the pre-existing one sits below the `!adapter->discovery_list` branch and calls
`discovery_complete()`, ours sits inside it and only returns. `adapter->discovery_list` was
**non-empty** at that moment — `adapter_stop()` freed a list entry 158 µs later — so the
pre-existing check fired. `0001`'s own guard has still never fired.

## What `0001` does have

The **premise** of `0001`, observed in the wild on 2026-09-08:

```
10:27:19.051905  send_request  command 0x0023          START_DISCOVERY  (⚠️ label corrected 09-18, see below)
10:27:19.066260  can_read_data command 0x23 status: 0x00   ← Command Status path
10:27:19.066276  start_discovery_complete() status 0x00
10:27:19.066284  Wrong size of start discovery return parameters
```

`status: 0x00` with a reply too short for `mgmt_cp_start_discovery` is precisely the
"success status, NULL param" combination the patch argues `src/shared/mgmt.c` can deliver.
That was a claim from source reading; it is now an observation. It does not show `0001`
preventing a crash — only that the condition it guards is real on this hardware.

### ⚠️ CORRECTED 2026-09-18 — the label, the count, and the event

Found by a third-party review of the patches
([`reviews/2026-09-18T0700Z-third-party-bluez-patch-review.md`](../../reviews/2026-09-18T0700Z-third-party-bluez-patch-review.md)),
which took the label at face value and built a hypothesis on it.

1. **The label was wrong.** The first line above originally read `START_SERVICE_DISCOVERY`.
   `0x0023` is `MGMT_OP_START_DISCOVERY`; `MGMT_OP_START_SERVICE_DISCOVERY` is `0x003A`
   (`lib/bluetooth/mgmt.h:304`, `:456`). The request and the reply carry the **same** opcode,
   so there was no opcode mismatch and `request_complete()`'s index-only fallback was not
   involved. The wrong label had been copied into `patches/bluez/0001`'s message; fixed there.
2. **"Observed once" was wrong.** The archived daemon log of the 08-14 session
   (`evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log`) holds the same
   delivery four more times, in the lifetime of the daemon that crashed, 32 minutes before it:

   ```console
   $ grep -c 'Wrong size of start discovery' evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log
   4
   $ grep -n -B1 'command 0x23 status: 0x00' evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log | grep -c send_request
   4
   ```

   Each is `send_request … command 0x0023` → 12 ms → `command 0x23 status: 0x00` →
   `Wrong size…` (20:31:22, :23, :26, :37). Premise count: **five** with clients present, not
   one.
3. **The crash itself is the sixth, and it is fully reconstructed.** The crashing daemon's
   last management lines (`grep -n '\[2821\]' … | tail`):

   ```
   4804  21:03:16.750850  src/adapter.c:discovery_remove() owner :1.125
   4811  21:03:24.943018  src/shared/mgmt.c:send_request() [0x0000] command 0x0023
   4812  21:03:26.994468  src/shared/mgmt.c:can_read_data() [0x0000] command 0x23 status: 0x00
   4813  21:03:26.994484  src/adapter.c:start_discovery_complete() status 0x00
   timeline 20116  21:03:26  KERN  bluetoothd[2821]: segfault at 0 ip 00005d6eb1ad1986 …
   ```

   Last client removed at 21:03:16; Start Discovery sent 21:03:24.943; **Command Status,
   status 0x00**, 2.05 s later; callback entered with the list empty; `segfault at 0`. The
   event is identified by its debug text: `src/shared/mgmt.c` prints `command 0x%02x status:`
   only on the `MGMT_EV_CMD_STATUS` branch and `command 0x%04x complete:` on
   `MGMT_EV_CMD_COMPLETE` (5.72 `mgmt.c:391,401`; master `:406,415`). The 37 normal Start
   Discovery completions in the same log are all `complete:`.
4. **Not established:** why the kernel answers Start Discovery with a successful Command
   Status. The five with-clients instances came 12–14 ms after the send; the crashing one came
   2.05 s after it, during the controller's HCI command timeouts (`0x0406 tx timeout` every
   2 s from 20:32:21 to 21:03:26 in that session). The patch says so and does not depend on it.

## ⚠️ The unrelated crash, cleared properly this time

A `bluetoothd` SIGSEGV on 2026-09-08 10:23:43 (PID 2841, the patched binary) sits in
`__GI___libc_free` under `g_main_loop_run` — a bad free, not a NULL dereference, and at
neither patched site.

It was first dismissed partly on the ground that `0002`'s path had never been taken. **That
ground was false** — see the correction below — so the clearance is restated on evidence
that holds:

1. **The crashing process never took our path.** In PID 2841's lifetime there are **zero**
   `has no stream` lines and **zero** `transport_cb` lines at all. The guard did not run in
   the process that crashed; the nearest firing is six days earlier in a different daemon.
2. **`goto drop` introduces no new free.** The `drop:` label —
   `setup_unref(setup); g_io_channel_shutdown(io, TRUE, NULL);` — was already reachable from
   three pre-existing paths, including `avdtp_stream_set_transport()` returning false. The
   patch adds a jump to an exercised label, not a new teardown.
3. **`0001` adds only an early `return`**, in a branch that already returns early on the
   adjacent `status != MGMT_STATUS_SUCCESS` condition.

It remains a **third, separate BlueZ defect** on this machine, which neither patch addresses
and which should not be folded into their submission.

## ⚠️ A correction, and the method error behind it

An earlier reading of this same question reported **"patch 0002's guard has never fired"**.
That was wrong. It came from grepping **one boot** and the retained `bt-snapshot` cuts rather
than the whole run, and reporting that absence as general.

This is the project's own recurring defect — *a zero from a capped scan is not a result* —
and it was committed here by the person who wrote that rule down. The narrow scan was also
the expensive one: the full-journal grep that would have found the firings was abandoned
after ten minutes, while the indexed `_COMM=bluetoothd` query answered it in thirty seconds.
**The scan that was too slow to finish and the scan that was too narrow to be true were the
same mistake**: not asking journald to do the filtering.

## What this does and does not support for submission

**Supports:** `0002` is a fix for a condition that occurs in normal use, four times in
nineteen days, on a stock Ubuntu audio stack. The patched daemon logged and recovered each
time instead of dying.

**Does not support:** any claim about `0001` preventing a crash. Its guard has not fired.
`0001` stands on its coredump analysis plus the observed zero-length reply — which is an
ordinary and sufficient basis for a NULL-dereference fix, and should be described as exactly
that.

**And neither relates to `BT-1`.** The controller wedge has now occurred **four times** with
both patches installed (`EX-036`, `EX-037`, `EX-038`, `EX-040`).

## Provenance

| field | value |
|---|---|
| captured | `2026-09-13T18:52:00+02:00` |
| window | `2026-08-25` → `2026-09-13`, 19 days |
| kernel | `7.0.0-30-generic` then `-31-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| corrects | an earlier in-session claim that `0002` had never fired |
| relates to | `EX-032`, `EX-035` |
