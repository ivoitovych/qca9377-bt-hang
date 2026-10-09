# Separate finding: the extended-advertising duration is computed in a u16 and overflows

Not part of the mesh series. Found while checking what "1000 seconds" means on the
extended advertising path (PHASE3-TASK.md item 3). Trees: `bluetooth/master` `86ef0f58bdec`
and `bluetooth-next` `671d566d3c3b` (identical code here). Claims are **quoted** (command
and output) or **inferred**.

## The code (quoted)

`git -C cache/mesh-guest grep -n -B 2 -A 10 'MSEC_PER_SEC' HEAD -- net/bluetooth/hci_sync.c`
(inside `hci_enable_ext_advertising_sync()`):

    1666:	if (adv && adv->timeout) {
    1667:		u16 duration = adv->timeout * MSEC_PER_SEC;
    1668:
    1669:		/* Time = N * 10 ms */
    1670:		set->duration = cpu_to_le16(duration / 10);
    1671:	}
    1672:
    1673:	return __hci_cmd_sync_status(hdev, HCI_OP_LE_SET_EXT_ADV_ENABLE, ...

`adv->timeout` is a u16 in seconds (`struct adv_info`, `hci_core.h`; set from
`cp->timeout` of MGMT Add Advertising / Add Extended Advertising Parameters, or 1000 for a
mesh instance, `mgmt.c:2361`). `adv->timeout * MSEC_PER_SEC` is computed as `long` and then
truncated to the `u16 duration`. The controller field `Duration` of LE Set Extended
Advertising Enable is itself 16 bits in units of 10 ms, so the largest representable
timeout is 655.35 s.

Introduced with the hci_sync conversion: `git -C cache/linux log --oneline -S'adv->timeout *
MSEC_PER_SEC' bluetooth/master -- net/bluetooth/hci_sync.c net/bluetooth/hci_request.c` →
`cba6b758711c Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 2` (the same
expression existed in `hci_request.c` before; not pursued further here).

## What it does (inferred from the quoted code)

| requested timeout (s) | `timeout * 1000` | truncated to u16 | `/10` → Duration | controller stops after |
|---|---|---|---|---|
| 1 .. 65 | 1000 .. 65000 | unchanged | 100 .. 6500 | correct |
| 66 | 66000 | 464 | 46 | **0.46 s** |
| 120 | 120000 | 54464 | 5446 | 54.46 s |
| 655 | 655000 | 65000 | 6500 | 65 s (not 655) |
| 1000 (mesh) | 1,000,000 | 16960 | 1696 | **16.96 s** |

So on an extended-advertising controller every instance with a timeout above 65 s is
stopped early by the controller (`LE Advertising Set Terminated`, status
`HCI_ERROR_ADVERTISING_TIMEOUT`), and `hci_le_ext_adv_term_evt()` (`hci_event.c:5964-6004`)
then removes the instance and emits `MGMT_EV_ADVERTISING_REMOVED` — the instance is gone
long before the time userspace asked for. For the mesh instance this is the 16.96 s that
item 3 of the task describes; with the series the mesh set is removed after 75 ms anyway,
so the mesh path no longer depends on it, but ordinary instances with `timeout > 65` do.

Note the legacy path is not affected: there the timeout is a kernel timer
(`hci_schedule_adv_instance_sync()` → `adv_instance_expire`, seconds), and the
`duration`-to-timer path has its own units confusion (phase 1 §5: the "ms units" comment in
`hci_core.c:1707` is not implemented).

## Candidate fix (not written as a patch here)

Clamp instead of truncating, e.g. compute in `u32` and cap at `0xFFFF` ten-millisecond
units (655.35 s), and keep a kernel-side timer for the remainder when the request exceeds
what the controller can express — or document that extended advertising limits the
timeout to 655 s and reject larger values in `add_advertising()`/`add_ext_adv_params()`
with `MGMT_STATUS_INVALID_PARAMS`. Which one the maintainers prefer decides the patch; the
minimal correct change is the clamp (no controller can do more than 655.35 s, so a longer
request must be split or capped either way).

## Reproducer plan (qemu only, nothing on the host adapter)

The emulator honours the duration: `emulator/btdev.c:5695-5697` arms
`timeout_add(eas->duration * 10 ms)` per set and `adv_set_terminate()` (5584-5603) sends
`LE Advertising Set Terminated` with `BT_HCI_ERR_ADV_TIMEOUT` — so a mgmt-tester case can
show both the wrong command parameter and the early removal:

1. New `tools/mgmt-tester.c` case on `HCIEMU_TYPE_BREDRLE50`: setup powered + LE; run
   `MGMT_OP_ADD_ADVERTISING` instance 1, flags 0, duration 0, **timeout 66** (`0x42, 0x00`),
   small adv data. Expect `BT_HCI_CMD_LE_SET_EXT_ADV_ENABLE` with
   `{0x01, 0x01, 0x01, 0xc8, 0x19, 0x00}` (Duration 6600 = 0x19c8, i.e. 66 s) — on the
   current kernel the emulator receives `{0x01, 0x01, 0x01, 0x2e, 0x00, 0x00}` (46 = 0.46 s),
   a hard "Failed" with the hexdump of both.
2. Second case, same setup, `expect_alt_ev = MGMT_EV_ADVERTISING_REMOVED` with a
   `test_bredrle50_full(..., 4)` timeout: on the current kernel the event arrives ~0.5 s
   after the add (the emulator's terminate at 46 × 10 ms → `hci_le_ext_adv_term_evt` →
   `mgmt_advertising_removed(NULL, hdev, 1)`); with a correct kernel it must **not** arrive
   within the 4 s (the test is written to fail on arrival, like the mesh sequence tests do
   for the mesh instance).
3. Run both on the phase-3 images (`bzImage-bluetooth-patched`, which contains the series
   but not this fix) with `tools/test-runner -k <image> -- tools/mgmt-tester -s "timeout 66"`
   and confirm the two failures; then on an image with the clamp and confirm two passes.
   Also check that mgmt-tester's existing ext-adv cases with `timeout: 1 second`
   (`add_advertising_param_test4`, `mgmt-tester.c:9030`) still pass — they must, since 1 s
   is below the overflow.
4. For the series' own commit message the consequence is already applied: 1/2 says "with
   extended advertising the set stays enabled until the duration the controller was given
   ends" and claims the 1000 s only for the legacy path.

Cost: one mgmt-tester patch (two cases), one kernel patch of a few lines in
`hci_enable_ext_advertising_sync()`, two test-runner runs of ~1 min each.
