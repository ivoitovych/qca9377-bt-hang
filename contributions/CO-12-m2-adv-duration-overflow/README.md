# CO-12 — M-2: extended-advertising duration overflow

**State:** investigating. The arithmetic is confirmed in source; no reproducer exists yet.

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
