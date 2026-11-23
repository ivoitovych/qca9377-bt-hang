# CO-12 — M-2: extended-advertising duration overflow

> **2026-11-23: fixed by another author; not to be sent.**
> - **The fix.** Cen Zhang's "Bluetooth: hci_sync: Fix remaining advertising instance UAFs",
>   bluetooth-next `d7e77168da` (committed 11-19, signed off by the maintainer), does the timeout
>   conversion in `u32` and clamps it to `U16_MAX`. On the tip:
>   `set->duration = cpu_to_le16(min_t(u32, duration / 10, U16_MAX))`. That is this dossier's
>   clamp.
> - **Its origin.** His v2 changelog says the clamp answers concerns raised by Sashiko's
>   automated review of his v1.
> - **Our package.** `send-20261114/` now conflicts with the tip.
> - **Still ours:** the BlueZ duration tests (CO-38's held `bluez-split-20261114/series-b-held/`),
>   which should now pass upstream, and a stable request for the clamp once it is in mainline.
> - **Correction:** the readiness report of 2026-11-22 12:40Z called his series `new`, from
>   patchwork's state. The tree had it (work log F-46).

**State (2026-11-01):** reproduced in QEMU (22 mgmt-tester cases) and a clamp drafted
(`patch/draft-2026-11-01/`); not sent. The outside reviews agree the overflow is real; the clamp
is a mitigation (above 655 s it ends at 655.35 s, not at the requested time), so the mail names
the three options (clamp, reject, host deadline). **Same night:** tests reworked (all pass with
the clamp, every case ≥ 66 s fails on base), rebased on Cen Zhang's series, stable forms for
7.3.y to 5.10.y, commit message revised (`log.md`, 2026-11-01 night). Ready for an outside
review and the operator's word. The tests also found CO-38. The sections below are older.

**Target:** the Linux kernel (`net/bluetooth/hci_sync.c`).

**Comes from:** `M-2` (`docs/STATUS.md`), first seen during the mesh work.

## The finding

bluetooth-next `27731ba09195`, `hci_enable_ext_advertising_sync()`, lines 1702 to 1706:

```c
u16 duration = adv->mesh ? adv->timeout :
			   adv->timeout * MSEC_PER_SEC;
/* Time = N * 10 ms */
set->duration = cpu_to_le16(duration / 10);
```

- **The input:** MGMT Add Advertising carries `__le16 timeout` in seconds (`mgmt.h:565`), so
  userspace can ask for up to 65,535 s.
- **The overflow:** for a non-mesh instance, `timeout * 1000` overflows the `u16`. A timeout
  of 66 s becomes 66,000 ms, which truncates to 464 ms, so the controller is told 46 (460 ms).
  A multiple of 65.536 s becomes 0, which the HCI command reads as no limit.
- **The HCI field limit:** the field itself is 16 bits in 10 ms units, at most 655.35 s, so
  longer timeouts cannot be handed to the controller at all.
- **The design need:** this is why the 2026-10-05 review asked for "a timeout design, not a
  clamp" (for example, a host-side timer for long timeouts).
- **Pauli Virtanen's `8a8d51eeedeb`** fixed only the mesh case, whose timeout is already in
  milliseconds. It reached mainline in the 7.4 merge window (as `8a8d51eeedeb`, found in
  mainline master on 2026-10-28); no stable line carries it yet.

## Next

1. **A QEMU reproducer:** Add Advertising with timeouts of 60, 66 and 100 s, and read the
   HCI LE Set Extended Advertising Enable duration in the emulator's trace; also check when
   advertising actually stops.
2. **Then a design proposal,** and a patch if the maintainers agree.
