# EX-049 — vhci-flush-patched-returns-not-powered

**Claim.** With the patched bluetooth.ko loaded (srcversion 66D38200362CD82D3F68A9D, Ubuntu 7.0.0-31 source + the held patch), a virtual controller on /dev/vhci drives the flush path deterministically: power-off is held inside HCI Write Scan Enable(0), Start Discovery is submitted during the stall, the stall is released, and __mgmt_power_off() answers the still-queued Start Discovery with Command Status 0x0f (Not Powered) before the Set Powered completion, i.e. with a Set Powered pending across the flush (the match->sk != NULL case).

**Relevance.** The runtime observation the third review asked for, on the fixed path itself; no real hardware involved. Script: patches/kernel/repro-mgmt-flush-status.py (an outside reviewer's design; two transport bugs fixed, original kept beside it). The stock control run is the next exhibit.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ cat /sys/module/bluetooth/srcversion; python3 /root/exp/qca9377-bt-hang/patches/kernel/repro-mgmt-flush-status.py 2>&1 | grep -v "Change Local Name params"; echo "exit=${PIPESTATUS[0]}"
```

## Output

Verbatim, 36 line(s), exit status 0.

```
66D38200362CD82D3F68A9D
Linux version 7.0.0-31-generic (buildd@lcy02-amd64-060) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #31~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Aug 10 09:38:02 UTC 2
  hci virtual hci0 created
using hci0
  hci cmd Reset params -
  hci cmd Read Local Supported Features params -
  hci cmd Read Local Version params -
  hci cmd Read BD ADDR params -
  hci cmd Read Local Supported Commands params -
  hci cmd Read Buffer Size params -
  hci cmd Read Class of Device params -
  hci cmd Read Local Name params -
  hci cmd Read Number of Supported IAC params -
  hci cmd Read Current IAC LAP params -
  hci cmd Write Connection Accept Timeout params 007d
  hci cmd Set Event Mask params fffffbff01000000
power on
  hci cmd Read Page Scan Type params 00081200
  mgmt Command Complete index 0 opcode 0x0005 status 0x00 (Success) param 81000000
set connectable (so power-off emits Write Scan Enable)
  hci cmd Write Scan Enable params 02
  mgmt Command Complete index 0 opcode 0x0007 status 0x00 (Success) param 83000000
power off, stalling HCI Write Scan Enable(0)
  hci cmd Write Scan Enable params 00
  hci STALL Write Scan Enable (power-off window is open)
submit Start Discovery while power-off is blocked
release stall after 0.30s
waiting for the Start Discovery reply
  hci release stalled Write Scan Enable
  mgmt Command Status index 0 opcode 0x0023 status 0x0f (Not Powered)
  mgmt Command Complete index 0 opcode 0x0005 status 0x00 (Success) param 82000000

PATCHED: Command Status 0x0f (Not Powered).
The flush passed match->mgmt_status through.
  hci controller thread failed: 'NoneType' object cannot be interpreted as an integer
exit=0
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-24T05:06:32+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `20fbb9a2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
