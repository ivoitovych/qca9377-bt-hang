# EX-077 — co02-patch1-hw-voice-data-without-a-gap

**Claim.** Through the three second-connect runs, voice data flowed on the call's link (handle 9) without a break in both directions: from 05:40:25 to 05:43:05 the largest gap between two SCO packets was 11.9 ms controller-to-host and 15.6 ms host-to-controller, about 53,300 packets each way.

**Relevance.** Rules out a short drop that came back with the same handle, which the program's once-a-second table reads could not see (reviewers 3 and 4). Without patch 1 the link would have been disconnected about 10 ms after the first refused connect and the data would stop.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/sco-data-gaps.py /var/log/bt-health/capture/hci-20261026-053053.btsnoop "2026-10-26 05:40:25" "2026-10-26 05:43:05"
```

## Output

Verbatim, 2 line(s), exit status 0.

```
ctrl->host  handle 9: 53334 packets, 2026-10-26 05:40:25.004391 to 2026-10-26 05:43:04.994493, largest gap 11.9 ms after 2026-10-26 05:42:21.934479
host->ctrl  handle 9: 53332 packets, 2026-10-26 05:40:25.003430 to 2026-10-26 05:43:04.993801, largest gap 15.6 ms after 2026-10-26 05:40:39.058382
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-26T05:44:08+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
