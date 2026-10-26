# EX-076 — co02-patch1-hw-call-link-spans-the-runs

**Claim.** The Shure's eSCO link used by the three second-connect runs was set up at 05:39:59.141 and was still open at the end of the capture read, so it spans all three runs (05:40:32 to 05:42:55) as one link; no other link was set up in that capture after it. The five earlier links of the same capture (Hands-free switching from 05:31) all closed with status 0x00 by handle.

**Relevance.** Positive control for EX-075: the same capture file does hold Synchronous Connect Complete and Disconnection Complete events, read by handle, so EX-075's empty window is an absence, not a decode failure. Timestamps are bt-capture's receive times.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/sco-link-closure.py /var/log/bt-health/capture/hci-20261026-053053.btsnoop
```

## Output

Verbatim, 13 line(s), exit status 0.

```
setup                       hs  type     held s  closed by  cmd-st  dc-st  reason      ms  outcome
2026-10-26 05:31:22.827490   1  eSCO      62.92  host       0x00    0x00   0x16      38.0  closed
2026-10-26 05:32:56.075331   1  eSCO      68.40  host       0x00    0x00   0x16      37.9  closed
2026-10-26 05:34:56.236301   1  eSCO      16.73  host       0x00    0x00   0x16      60.0  closed
2026-10-26 05:35:13.113333   1  eSCO      64.02  host       0x00    0x00   0x16      92.0  closed
2026-10-26 05:36:44.047042   1  eSCO      21.51  host       0x00    0x00   0x16      58.9  closed
2026-10-26 05:39:59.141369   1  eSCO          -  -          -       -      -            -  OPEN-AT-END

links 6   closed with Disconnection Complete status 0x00 5   (by host 5, by remote 0)   other outcomes 1
  headset 1: links 6, closed 5
failed setups (Synchronous Connect Complete status != 0): 0
capture gaps over 5 s between files: 0
last record read: 2026-10-26 05:44:04.280783
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T05:44:04+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
