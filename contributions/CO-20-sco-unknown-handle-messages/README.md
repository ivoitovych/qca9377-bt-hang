# CO-20 — SCO error messages at call hang-up

**State:** investigating. Measured, and the source is read; the captures are not read yet.

**Target:** the Linux kernel (`hci_core.c`, btusb). It may turn out harmless.

**Comes from:** a check during the contribution survey (2026-10-21), and `U8`.

## The finding

**The measurement** (current boot, through 2026-10-21 00:19, local time):
- 9 mSBC calls on the MOMENTUM 4, all hung up cleanly, 0 timeouts.
- 14 kernel lines "SCO packet for unknown connection handle", at the hang-up of 6 of the 9
  calls.
- Two came 4 to 6 s **after** their call ended: handle 10 at 11:55:51, and handle 17 at
  00:12:37.

**The source:**
- **"SCO packet for unknown connection handle"** (`hci_core.c:4043`, bluetooth-next) comes
  when `sco_recv_scodata()` finds no connection for the handle.
  - It is rate-limited, so 14 lines may stand for more packets.
  - btusb already checks each SCO header's handle when it takes the packet. So this line
    means the connection existed then, and was gone when the receive work handled the
    packet.
- **"corrupted SCO packet"** (btusb, `btusb_recv_isoc()`) fires in two cases:
  - when reassembly goes wrong;
  - when `btusb_validate_sco_handle()` rejects a header whose handle is not a live SCO
    connection, which includes data for a connection already deleted.
  - So that message alone does not show a reassembly failure.

## Readings, none tested

- Harmless data the controller delivers around the deletion.
- The "link left up" class of CO-01.
- For the late lines: a slow receive path, or a controller still sending on the old handle.
  Leftover USB transfers do not explain seconds.

## Next

Read the HCI captures at those six hang-ups:
- the Disconnection Complete against the following SCO data on the same handle;
- and what arrives on that handle in the seconds after.

`scripts/capture-window.sh` with a window around each time.
