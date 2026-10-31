# EX-086 — a2dp-lost-again-wireplumber-switch-releases-pending-acquire

**Superseded by EX-087.** The extraction's `-t wireplumber` matched nothing in the user journal ("No entries" below), so this exhibit supports nothing; EX-087 is the same read without it. Kept as the record of the failed extraction.

**Claim (unsupported here).** U12 again, 2026-10-31: WirePlumber (0.4.17) starts acquiring the MOMENTUM 4's A2DP transport at 13:42:16.187; 86 ms later, at 16.274, it switches the card from a2dp-sink to headset-head-unit-msbc and releases that transport while the acquire is pending; the hands-free link comes up at 16.478. At 18.964, after bluetoothd lost A2DP, it finds no default profile and keeps headset-head-unit-msbc, the best one left.

**Relevance.** The trigger side of EX-084/EX-085: the switch to the headset profile when an application opens the microphone, by WirePlumber's design, issues the Release that BlueZ 5.72 turns into an AVDTP Abort.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/user-journal.sh -b e672b4545c844ab88758175b455f8906 --since '2026-10-31 13:42:16' --until '2026-10-31 13:42:19.1' -t wireplumber --grep 'Acquiring transport|Setting profile of|Releasing transport|released$|acquire complete|Default profile not found|Found best profile'
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
| captured | `2026-10-31T14:54:57+01:00` |
| kernel | `7.0.0-42-generic` |
| capture boot id | `e672b454` |
| evidence boot ids | `e672b454` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `1` |
| redacted | `no` |
