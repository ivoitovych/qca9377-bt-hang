# EX-092 — a2dp-lost-third-card-has-no-a2dp-profile

**Claim.** At 14:30 on 2026-11-13 the MOMENTUM 4's PipeWire card offers no A2DP profile, only off and the three hands-free profiles; the active profile is headset-head-unit-msbc. GNOME Settings' output list (operator's screenshot, 14:26) shows only 'Handsfree - MOMENTUM 4' for the headset.

**Relevance.** The user-visible state matches the card: the panel has no headphones entry because A2DP is gone, as on 10-31.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/pw-card-routes.py /root/exp/qca9377-bt-hang/tmp/incident-20261113-1426/pw-dump-1430.json
```

## Output

Verbatim, 10 line(s), exit status 0.

```
device 72: MOMENTUM 4
  active profile: 261 headset-head-unit-msbc
  profile   0 off                                available=yes priority=0
  profile   3 headset-head-unit                  available=yes priority=1
  profile 260 headset-head-unit-cvsd             available=yes priority=2
  profile 261 headset-head-unit-msbc             available=yes priority=3
  active route: 2 headset-hf-input Input device=0 available=yes
  active route: 3 headset-hf-output Output device=1 available=yes
  route   2 headset-hf-input       Input   available=yes profiles=[3, 260, 261] devices=[0] desc='Handsfree'
  route   3 headset-hf-output      Output  available=yes profiles=[3, 260, 261] devices=[1] desc='Handsfree'
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T14:30:41+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
