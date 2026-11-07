# EX-075 — co02-patch1-hw-no-setup-or-disconnect-during-second-connects

**Claim.** On the laptop with the CO-02 series, during the three second-connect runs against the Shure AONIC 50's eSCO link (2026-10-26 05:40:32, 05:42:31, 05:42:44; experiments/hw-connect-twice/), the HCI capture holds no Setup Synchronous Connection, no Synchronous Connect Complete and no Disconnect or Disconnection Complete: the runs neither set up a link nor took the call's link down.

**Relevance.** Patch 1's case on hardware. Without patch 1 the refused second connect drops the call's hold, and the kernel disconnects the call's link about 10 ms later, which would show here as a Disconnect. The empty output is the result; EX-076 is its positive control (the same capture holds the link's own setup at 05:39:59 and earlier links' setups and disconnects).

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/capture-window.sh /var/log/bt-health/capture/hci-20261026-053053.btsnoop "2026-10-26 05:40:00" "2026-10-26 05:43:30" "Synchronous|Disconnect"
```

## Output

Verbatim, 0 line(s), exit status 0.

```
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T05:43:58+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
