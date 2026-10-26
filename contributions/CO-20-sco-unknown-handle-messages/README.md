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

## The CO-02 boot (`257d1599…`, 2026-10-23 to 26): late by minutes, not seconds

Read 2026-10-26 (`journalctl -k -b 257d1599532e4cad941b5bb6178bb630 -p err` and the same boot
with `--grep "corrupted SCO|handle 0x[0-9a-f]+ reason 0x13|unknown connection handle"`). The
boot's only error-level kernel lines are these two kinds: 13 "corrupted SCO packet" and 64
"SCO packet for unknown connection handle N", against 36 links. Most come within about 100 ms of
the host's Disconnect of that handle, but some come much later:
- handle 11: Disconnect 13:01:34.795, a line at 13:11:03.971, about 9.5 minutes later. It is
  0.1 s before the next link's Synchronous Connect Complete (13:11:04.056 in the capture, which
  got handle 12), so it may belong to that setup;
- handle 12: Disconnect 13:11:22.700, a line at 13:27:12.852, about 16 minutes later, with no
  link before 21:10;
- handle 8: Disconnect 21:11:19.503, a line at 21:11:57.240, 38 s later;
- handle 5: Disconnect 11:49:42.011, a line at 11:49:44.507, 2.5 s later.

So at least some late lines are not a slow receive path draining the hang-up: handle 12's
line comes 16 minutes after its Disconnection Complete with no SCO link up (`EX-074` has every one of those links closed
with status 0x00). The same kinds of line are on the unpatched boot before it, so this predates
the CO-02 series. Not yet read in the capture.

## Next

Read the HCI captures at those six hang-ups:
- the Disconnection Complete against the following SCO data on the same handle;
- and what arrives on that handle in the seconds after.

`scripts/capture-window.sh` with a window around each time.
