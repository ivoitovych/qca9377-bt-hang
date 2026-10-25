# EX-069 — co02-only-three-refusals-this-boot

**Claim.** From the boot with the CO-02 series (2026-10-23 11:04:40) to the time of this exhibit, the user journal holds exactly three refused SCO connects, each the first connect plus PipeWire's two immediate retries within 80 microseconds: 2026-10-23 22:00:33.7376, 2026-10-24 06:12:22.3410 and 06:12:47.7352, the three earbuds switches of EX-067.

**Relevance.** No other connect on this boot was refused: the MOMENTUM 4's and the Shure AONIC 50's switches (EX-070) and every ordinary call took the fresh-link path. The refusal fires only where the old link is still closing when the connect comes.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/user-journal.sh --since "2026-10-23 11:04:40" -g "Software caused connection abort"
```

## Output

Verbatim, 9 line(s), exit status 0.

```
2026-10-23T22:00:33.737623+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:1
2026-10-23T22:00:33.737649+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:0
2026-10-23T22:00:33.737670+02:00 n wireplumber[2873]: connect(): Software caused connection abort
2026-10-24T06:12:22.340952+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:1
2026-10-24T06:12:22.340996+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:0
2026-10-24T06:12:22.341032+02:00 n wireplumber[2873]: connect(): Software caused connection abort
2026-10-24T06:12:47.735219+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:1
2026-10-24T06:12:47.735263+02:00 n wireplumber[2873]: connect(): Software caused connection abort. Remaining retry:0
2026-10-24T06:12:47.735301+02:00 n wireplumber[2873]: connect(): Software caused connection abort
```

**Evidence window.** `2026-10-23T22:00:33.737623+02:00` — `2026-10-24T06:12:47.735219+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-25T22:20:29+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
