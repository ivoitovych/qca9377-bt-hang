# EX-088 — a2dp-lost-again-no-a2dp-reconnect

**Claim.** After the A2DP loss of 2026-10-31 13:42:18.96 (EX-085), bluetoothd logs no change of the MOMENTUM 4's a2dp-sink state up to 14:55:00: A2DP stays disconnected for at least 72 minutes while hands-free stays connected, so the sound panel offers only Handsfree.

**Relevance.** U12's lasting effect: nothing reconnects A2DP; the user is left with hands-free audio until the headset reconnects.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b e672b4545c844ab88758175b455f8906 --since '2026-10-31 13:42:19' --until '2026-10-31 14:55:00' -o short-iso-precise --no-pager -t bluetoothd --grep 'a2dp-sink state changed|Hands-Free Voice gateway state changed'
```

## Output

Verbatim, 1 line(s), exit status 1.

```
-- No entries --
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-31T14:55:28+01:00` |
| kernel | `7.0.0-42-generic` |
| capture boot id | `e672b454` |
| evidence boot ids | `e672b454` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `1` |
| redacted | `no` |
