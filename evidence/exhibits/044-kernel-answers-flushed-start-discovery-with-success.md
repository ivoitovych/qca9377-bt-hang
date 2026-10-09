# EX-044 — kernel-answers-flushed-start-discovery-with-success

**Claim.** On 2026-08-14 the kernel answered bluetoothd's pending Start Discovery (0x0023) with a Command Status whose status byte is 0x00 (Success), both at the fatal 21:03:26 instance and at the 20:31:22 with-clients instance, and in the same microsecond announced Class Of Device zeroed and New Settings 0x0ada (powered bit clear): the reply is the power-off flush of pending commands, and its status is wrong.

**Relevance.** Identifies the management event behind patches/bluez/0001's crash from the kernel's side, read from bin/bt-capture's surviving btsnoop (the bt-trace copies rotated out). A command flushed by power-off must be answered NOT_POWERED (0x0f); Success with no parameters is what start_discovery_complete() then dereferenced. The 2.05 s gap at 21:03 is the HCI command timeout of the preceding Write Scan Enable during the controller wedge, after which the kernel powered the device off on rfkill; at 20:31 the power-off followed a power-on by 11.5 ms during rfkill cycling. Output contains no device addresses (the tool drops any line carrying one).

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/tools/bt-ctrl-window /var/log/bt-health/capture/hci-20260814-201826.btsnoop 21:03:24.9 21:03:27.0 --hci; echo '---- 20:31:22, the first with-clients instance ----'; /root/exp/qca9377-bt-hang/tools/bt-ctrl-window /var/log/bt-health/capture/hci-20260814-201826.btsnoop 20:31:22.44 20:31:22.47
```

## Output

Verbatim, 37 line(s), exit status 0.

```
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 21:03:24.942839
        01 00 23 00 05 07  ->  Command Complete for Start Discovery (0x0023), status 0x05 Auth Failed
< HCI Command.. (0x03|0x001a) plen 1  #127375 [hci0] 2026-08-14 21:03:24.942886
@ Control Command: 0xffff            {0x0001} [hci0] 2026-08-14 21:03:24.942998
        23 00 07  ->  Start Discovery (0x0023)
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 21:03:26.994426
        02 00 23 00 00  ->  Command Status for Start Discovery (0x0023), status 0x00 Success
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 21:03:26.994458
        07 00 00 00 00  ->  Class Of Device Changed
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 21:03:26.994463
        06 00 da 0a 00 00  ->  New Settings: 0x00000ada
---- 20:31:22, the first with-clients instance ----
@ Control Command: 0xffff            {0x0001} [hci0] 2026-08-14 20:31:22.440102
        05 00 01  ->  Set Powered (0x0005)
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.440119
        01 00 05 00 00 d1 0a 00 00  ->  Command Complete for Set Powered (0x0005), status 0x00 Success
@ Control Command: 0xffff            {0x0001} [hci0] 2026-08-14 20:31:22.442398
        07 00 01  ->  Set Connectable (0x0007)
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.442423
        01 00 07 00 00 d3 0a 00 00  ->  Command Complete for Set Connectable (0x0007), status 0x00 Success
@ Control Command: 0xffff            {0x0001} [hci0] 2026-08-14 20:31:22.442468
        06 00 01 00 00  ->  Set Discoverable (0x0006)
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.447825
        01 00 06 00 00 db 0a 00 00  ->  Command Complete for Set Discoverable (0x0006), status 0x00 Success
@ Control Command: 0xffff            {0x0001} [hci0] 2026-08-14 20:31:22.447925
        23 00 07  ->  Start Discovery (0x0023)
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.459406
        02 00 23 00 00  ->  Command Status for Start Discovery (0x0023), status 0x00 Success
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.459421
        07 00 00 00 00  ->  Class Of Device Changed
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.459428
        06 00 da 0a 00 00  ->  New Settings: 0x00000ada
= bluetoothd: Wrong size of start discove..   [hci0] 2026-08-14 20:31:22.459497
@ Control Command: 0xffff            {0x0001} [hci0] 2026-08-14 20:31:22.459832
        07 00 00  ->  Set Connectable (0x0007)
@ Control Event: 0xffff              {0x0001} [hci0] 2026-08-14 20:31:22.459837
        01 00 07 00 00 d0 0a 00 00  ->  Command Complete for Set Connectable (0x0007), status 0x00 Success
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-19T16:19:03+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `a840c7c0` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
