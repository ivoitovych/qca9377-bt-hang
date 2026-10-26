# EX-074 — co02-boot-every-sco-link-closed-by-handle

**Claim.** On the boot with the CO-02 series, the HCI capture holds 36 SCO/eSCO links, and every one of them closed: each successful Synchronous Connect Complete is followed by a Disconnection Complete for the same handle with status 0x00, after the host's Disconnect. No setup failed, no link was left open, and the capture has no gap over 5 s between files. This replaces EX-073's count as the evidence for the closures: EX-073 counts the kernel's 'opcode 0x0406 status' debug line, which hci_event_packet() prints with status 0 for any Disconnection Complete while a Disconnect is pending, without the handle or the event's own status.

**Relevance.** The capture is the radio record, independent of the kernel's debug text. The reader matches by handle from the event bytes (scripts/sco-link-closure.py). Headsets are numbered in order of first link (1 = MOMENTUM 4, 2 = the earbuds, 3 = the Shure, by the times in EX-067 and EX-070). Reason 0x16 is 'terminated by local host', as expected after the host's Disconnect with reason 0x13. Timestamps are bt-capture's receive times, not the kernel's.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/sco-link-closure.py --from "2026-10-23 11:04:43" /var/log/bt-health/capture
```

## Output

Verbatim, 46 line(s), exit status 0.

```
files: 60, hci-20261023-035719.btsnoop to hci-20261025-191519.btsnoop
setup                       hs  type     held s  closed by  cmd-st  dc-st  reason      ms  outcome
2026-10-23 11:45:27.763892   1  eSCO      61.30  host       0x00    0x00   0x16      36.0  closed
2026-10-23 11:49:30.246936   1  eSCO      11.77  host       0x00    0x00   0x16       5.4  closed
2026-10-23 11:49:58.843834   1  eSCO      18.01  host       0x00    0x00   0x16      51.0  closed
2026-10-23 12:57:33.381275   1  eSCO      10.53  host       0x00    0x00   0x16      31.0  closed
2026-10-23 12:58:27.388247   1  eSCO       6.50  host       0x00    0x00   0x16       5.6  closed
2026-10-23 12:58:34.328306   1  eSCO      12.33  host       0x00    0x00   0x16      83.3  closed
2026-10-23 13:00:30.727291   1  eSCO      10.73  host       0x00    0x00   0x16      82.0  closed
2026-10-23 13:00:46.340287   1  eSCO      48.49  host       0x00    0x00   0x16      37.0  closed
2026-10-23 13:11:04.056496   1  eSCO      18.66  host       0x00    0x00   0x16      14.0  closed
2026-10-23 21:10:18.597914   1  eSCO      60.95  host       0x00    0x00   0x16      44.0  closed
2026-10-23 21:19:54.667987   1  eSCO      39.92  host       0x00    0x00   0x16      47.0  closed
2026-10-23 21:21:36.001571   1  eSCO      36.77  host       0x00    0x00   0x16      43.0  closed
2026-10-23 21:36:14.520690   1  eSCO      29.91  host       0x00    0x00   0x16      61.1  closed
2026-10-23 21:36:44.550745   1  eSCO      35.88  host       0x00    0x00   0x16      49.0  closed
2026-10-23 21:37:20.562843   1  eSCO      33.89  host       0x00    0x00   0x16      97.0  closed
2026-10-23 21:59:49.946536   2  eSCO      43.93  host       0x00    0x00   0x16     195.4  closed
2026-10-23 22:00:46.221430   2  eSCO      30.13  host       0x00    0x00   0x16     181.7  closed
2026-10-23 22:01:29.222548   2  eSCO     643.59  host       0x00    0x00   0x16     190.8  closed
2026-10-23 23:30:19.414258   2  eSCO      65.34  host       0x00    0x00   0x16     223.0  closed
2026-10-23 23:51:29.583615   2  eSCO       2.13  host       0x00    0x00   0x16     210.2  closed
2026-10-23 23:53:11.261517   2  eSCO       1.63  host       0x00    0x00   0x16     193.4  closed
2026-10-24 06:11:57.760845   2  eSCO      24.73  host       0x00    0x00   0x16     193.3  closed
2026-10-24 06:12:27.386887   2  eSCO      20.50  host       0x00    0x00   0x16     196.1  closed
2026-10-24 06:12:52.786897   2  eSCO      22.78  host       0x00    0x00   0x16     188.7  closed
2026-10-24 06:36:28.638705   3  eSCO      15.76  host       0x00    0x00   0x16      23.9  closed
2026-10-24 06:36:44.548701   3  eSCO      18.84  host       0x00    0x00   0x16      64.9  closed
2026-10-24 06:37:03.530667   3  eSCO    4888.31  host       0x00    0x00   0x16      32.0  closed
2026-10-24 07:58:32.248915   3  eSCO      22.10  host       0x00    0x00   0x16      75.0  closed
2026-10-24 08:01:24.838611   3  eSCO      12.87  host       0x00    0x00   0x16      54.9  closed
2026-10-24 08:01:37.940671   3  eSCO       9.90  host       0x00    0x00   0x16      52.9  closed
2026-10-24 08:01:48.088693   3  eSCO      37.28  host       0x00    0x00   0x16      25.9  closed
2026-10-24 08:02:25.614848   3  eSCO       6.80  host       0x00    0x00   0x16      42.7  closed
2026-10-24 08:02:32.590881   3  eSCO       7.03  host       0x00    0x00   0x16      12.9  closed
2026-10-24 08:03:51.915206   3  eSCO      67.19  host       0x00    0x00   0x16      64.0  closed
2026-10-24 08:06:40.345987   3  eSCO     121.70  host       0x00    0x00   0x16      17.9  closed
2026-10-24 11:10:26.131966   3  eSCO      32.20  host       0x00    0x00   0x16      20.0  closed

links 36   closed with Disconnection Complete status 0x00 36   (by host 36, by remote 0)   other outcomes 0
  headset 1: links 15, closed 15
  headset 2: links 9, closed 9
  headset 3: links 12, closed 12
failed setups (Synchronous Connect Complete status != 0): 0
capture gaps over 5 s between files: 0
last record read: 2026-10-25 23:02:05.898025
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T03:38:49+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
