# `sco-params.txt` here is wrong: the capture holds both setups

Written 2026-10-18. `sco-params.txt` in this directory is kept as the closer wrote it. It says
"(no Setup Synchronous Connection inside this trial's window in either capture path)", while
this trial's row in `../../results.tsv` has `sco_sent` 2.

**Why it is wrong.** The closer ran `COLUMNS=200 btmon -T -r <file>` and matched the header
lines `HCI Command: Setup Synchronous Connection` and `HCI Event: Synchronous Connect
Complete`. Written to a pipe, `btmon` fits each header line into 80 columns and shortens the
name (`< HCI Comman.. (0x01|0x0028) plen 17`). It ignores `COLUMNS`; only `--columns=<width>`
widens it. So the match could never succeed, in this trial or any other. The same holds for
trials 01, 02 and 03 (`sco_sent` 1, 3 and 3); their captures no longer exist, so their
parameters cannot be recovered.

**What the capture holds**, re-read at full width
(`btmon -T --columns=200 -r /var/log/bt-health/capture/hci-20260926-020433.btsnoop`, window
02:04:00 to 15:40:00; device address replaced by `<addr>`):

```
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17   #107804 [hci0] 2026-09-26 02:09:36.646091
        Handle: 5
        Max latency: 13
        Setting: 0x0003
        Retransmission effort: Optimize for link quality (0x02)
        Packet type: 0x0380
> HCI Event: Command Status (0x0f) plen 4                            #107806 [hci0] 2026-09-26 02:09:36.648594
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17             #107810 [hci0] 2026-09-26 02:09:36.718696
        Status: Success (0x00)
        Handle: 6
        Link type: eSCO (0x02)
        Air mode: Transparent (0x03)
< HCI Command: Disconnect (0x01|0x0006) plen 3                       #110270 [hci0] 2026-09-26 02:09:44.049802
        Handle: 6 Address: <addr>
        Reason: Remote User Terminated Connection (0x13)
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17   #110276 [hci0] 2026-09-26 02:10:04.984475
        Handle: 5
        Max latency: 13
        Setting: 0x0003
        Retransmission effort: Optimize for link quality (0x02)
        Packet type: 0x0380
```

The first setup was answered and came up as a transparent (mSBC) eSCO link. The Disconnect
that ended it got no Command Status in this file, and neither did the second setup: the
pattern of the BT-1 signature on the stock driver (`BRIEF.md` §0; read from this file only, not
compared with the trace path's copy). The padding between each header and its
frame number is shortened here; the decoded lines are otherwise verbatim.
