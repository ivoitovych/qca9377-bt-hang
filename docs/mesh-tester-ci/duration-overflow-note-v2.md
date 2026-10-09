# Separate finding: the extended-advertising duration is computed in a u16 and overflows (v2)

Not part of the mesh series. Found while checking what "1000 seconds" means on the
extended advertising path (PHASE3-TASK.md item 3); corrected after the review of
2026-10-02 (its §4 and §E5). Trees: `bluetooth/master` `86ef0f58bdec` and `bluetooth-next`
`671d566d3c3b` (identical code here). Claims are **quoted** (command and output) or
**inferred**.

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
mesh instance, `mgmt.c:2337`). `adv->timeout * MSEC_PER_SEC` is computed as `long` and then
truncated to the `u16 duration` (i.e. taken modulo 65536). The controller field `Duration`
of LE Set Extended Advertising Enable is itself 16 bits in units of 10 ms, so the largest
duration the controller can be given is 655.35 s.

Provenance: present in `hci_sync.c` since the conversion
(`git -C cache/linux log --oneline -S'adv->timeout * MSEC_PER_SEC' bluetooth/master --
net/bluetooth/hci_sync.c net/bluetooth/hci_request.c` → `cba6b758711c Bluetooth: hci_sync:
Make use of hci_cmd_sync_queue set 2`); the expression predates it in `hci_request.c`, and
its original introducing commit has not yet been identified (`git log -S'timeout *
MSEC_PER_SEC' bluetooth/master -- net/bluetooth/hci_request.c` on the blobless clone
printed nothing; **not found**).

## What it does (inferred from the quoted code; arithmetic checked by hand)

`duration = (timeout * 1000) mod 65536`, `Duration = duration / 10` (integer division),
controller time = `Duration * 10 ms`.

| requested timeout (s) | `timeout * 1000` | mod 65536 | `/10` → Duration | controller stops after |
|---|---|---|---|---|
| 1 .. 65 | 1000 .. 65000 | unchanged | 100 .. 6500 | as requested |
| 66 | 66000 | 464 | 46 | **0.46 s** |
| 120 | 120000 | 54464 | 5446 | 54.46 s |
| 655 | 655000 | 65176 | 6517 | **65.17 s** (not 655) |
| 656 | 656000 | 640 | 64 | 0.64 s |
| 1000 (mesh) | 1,000,000 | 16960 | 1696 | **16.96 s** |
| 8192 | 8,192,000 | 0 | 0 | **no finite duration requested** |

Only timeouts of 1..65 s survive; from 66 s on the encoded value is wrong. It is *not* true
that every timeout above 65 s stops early: when `timeout * 1000` is a multiple of 65536
(timeout a multiple of 8192: 8192, 16384, …, 57344) the field is 0 and, with Max Extended
Advertising Events also 0, the controller is asked for no finite duration at all — the set
runs until it is disabled. With extended advertising the kernel arms no timer of its own
("Only use work for scheduling instances with legacy advertising",
`hci_schedule_adv_instance_sync()`, `hci_sync.c:2099-2105`), so nothing else ends it.

For the early-stop values the emulator and the kernel agree on what follows:
`emulator/btdev.c:5695-5700` starts a per-set timer of `duration * 10 ms` only when the
encoded duration is nonzero and then sends `LE Advertising Set Terminated` with
`BT_HCI_ERR_ADV_TIMEOUT`; `hci_le_ext_adv_term_evt()` (`hci_event.c`) removes the instance
on that status and emits `MGMT_EV_ADVERTISING_REMOVED` — the instance is gone long before
the time userspace asked for. For the mesh instance this is the 16.96 s of PHASE3-TASK item
3 (and every mesh set enable in the phase-3/4 logs carries `a0 06` = 1696); with the series
the mesh set is removed after its count anyway, so the mesh path no longer depends on it,
but ordinary instances with `timeout >= 66` do.

The legacy path is not affected: there the timeout is a kernel timer
(`hci_schedule_adv_instance_sync()` → `adv_instance_expire`, seconds).

## Candidate fix (not written as a patch here)

The intermediate u16 conversion must be removed. A wider calculation fixes representable
durations, but a complete fix must also preserve MGMT timeouts beyond the controller's
655.35-second duration range. Clamping alone shortens those requests and is not a complete
compatibility-preserving solution: a 1000-s MGMT timeout clamped to 0xFFFF ends at 655.35 s,
and the MGMT contract is a 16-bit number of seconds. The remainder needs either a kernel-side
expiry for extended advertising (as the legacy path has) or a re-arm of the set when the
controller reports the first duration's end; either needs its own analysis, and rejecting
requests above 655 s would be a behaviour change for existing clients. Separate patch,
separate thread.

## Reproducer plan (qemu only, nothing on the host adapter)

The emulator honours the duration (above), so mgmt-tester cases on `HCIEMU_TYPE_BREDRLE50`
can show both the wrong command parameter and the early removal:

1. Add Advertising instance 1, flags 0, duration 0, **timeout 66** (`0x42, 0x00`), small adv
   data. Expect `LE Set Extended Advertising Enable` `{0x01, 0x01, 0x01, 0xc8, 0x19, 0x00}`
   (Duration 6600 = 0x19c8, i.e. 66 s) — the current kernel sends
   `{0x01, 0x01, 0x01, 0x2e, 0x00, 0x00}` (46 = 0.46 s), a hard "Failed" with both hexdumped.
2. The same with `expect_alt_ev = MGMT_EV_ADVERTISING_REMOVED` and a
   `test_bredrle50_full(..., 4)` timeout: on the current kernel the event arrives ~0.5 s
   after the add; with a correct kernel it must **not** arrive within the 4 s.
3. Boundary cases on the same pattern, each checking the Duration bytes: **655**
   (expect 0xffdc = 65500; current kernel 0x1975 = 6517), **656** (would need 65600, which
   does not fit: the case documents what the fix chooses — clamp, kernel-side expiry, or
   re-arm — and must not see Advertising Removed before 4 s either way), **1000** (current
   kernel 0x06a0 = 1696; same remark), **8192** (current kernel 0x0000: no Advertising
   Removed ever; a correct kernel must still end the instance — a 4-s case cannot observe
   that, so this one asserts the Duration bytes only).
4. Run on the phase-3/4 images (which contain the series but not this fix) with
   `tools/test-runner -k <image> -- tools/mgmt-tester -s "timeout"` and confirm the failures;
   then on an image with the fix. mgmt-tester's existing ext-adv cases with
   `timeout: 1 second` (`add_advertising_param_test4`) must keep passing (1 s is below the
   overflow).

Cost: one mgmt-tester patch (six cases), one kernel patch in `hci_enable_ext_advertising_sync()`
plus whatever the >655 s remainder needs, two test-runner runs of ~1 min each.
