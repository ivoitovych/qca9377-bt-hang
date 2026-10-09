# EX-050 — vhci-flush-stock-returns-wrong-status

**Claim.** Control for EX-049. With the STOCK bluetooth.ko loaded (srcversion 052335E5B69A055D6D15874, Ubuntu 7.0.0-31), the same virtual-controller procedure — power-off held inside HCI Write Scan Enable(0), Start Discovery submitted during the stall, stall released — makes __mgmt_power_off() answer the still-queued Start Discovery with a Command Status that is NOT 0x0f: the bug, reproduced on demand on the unpatched kernel.

**Relevance.** Paired with EX-049 on the same kernel build, same script, same procedure: the patch alone turns the flush reply into Not Powered. The byte seen here comes from match->sk; with a Set Powered pending across the flush it is taken from a socket pointer, so it need not be 0x00.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ cat /sys/module/bluetooth/srcversion; python3 /root/exp/qca9377-bt-hang/patches/kernel/repro-mgmt-flush-status.py 2>&1 | grep -v "Change Local Name params"; echo "exit=${PIPESTATUS[0]}"
```

## Output

Verbatim, 36 line(s), exit status 0.

```
052335E5B69A055D6D15874
Linux version 7.0.0-31-generic (buildd@lcy02-amd64-060) (x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, GNU ld (GNU Binutils for Ubuntu) 2.42) #31~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Aug 10 09:38:02 UTC 2
  hci virtual hci1 created
using hci1
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
  mgmt Command Complete index 1 opcode 0x0005 status 0x00 (Success) param 81000000
set connectable (so power-off emits Write Scan Enable)
  hci cmd Write Scan Enable params 02
  mgmt Command Complete index 1 opcode 0x0007 status 0x00 (Success) param 83000000
power off, stalling HCI Write Scan Enable(0)
  hci cmd Write Scan Enable params 00
  hci STALL Write Scan Enable (power-off window is open)
submit Start Discovery while power-off is blocked
release stall after 0.30s
waiting for the Start Discovery reply
  hci release stalled Write Scan Enable
  mgmt Command Status index 1 opcode 0x0023 status 0x00 (Success)
  mgmt Command Complete index 1 opcode 0x0005 status 0x00 (Success) param 82000000

BUG REPRODUCED: Command Status for Start Discovery is 0x00 (Success), not 0x0f (Not Powered).
This is the reported failure: a zero-length Success, which is what crashes bluetoothd's start_discovery_complete().
  hci controller thread failed: 'NoneType' object cannot be interpreted as an integer
exit=1
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-24T10:38:53+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `ef992099` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
