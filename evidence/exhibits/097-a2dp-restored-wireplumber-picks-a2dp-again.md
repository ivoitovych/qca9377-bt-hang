# EX-097 — a2dp-restored-wireplumber-picks-a2dp-again

**Claim.** After the A2DP reconnect of 15:13:00 on 2026-11-13, WirePlumber sets the MOMENTUM 4's card to a2dp-sink at 15:13:00.400 by itself; the card then offers all eight profiles again (off, four A2DP, three hands-free), with a2dp-sink active and the 'Headset' output route.

**Relevance.** The desktop side recovers on its own once bluetoothd has A2DP again; the user-visible loss was only bluetoothd's missing session.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ python3 -I /root/exp/qca9377-bt-hang/scripts/pw-card-routes.py /root/exp/qca9377-bt-hang/archive/incidents/20261113-a2dp-lost-third/pw-dump-after-connectprofile.json
```

## Output

Verbatim, 14 line(s), exit status 0.

```
device 72: MOMENTUM 4
  active profile: 10 a2dp-sink
  profile   0 off                                available=yes priority=0
  profile   3 headset-head-unit                  available=yes priority=1
  profile   5 a2dp-sink-sbc                      available=yes priority=18
  profile   6 a2dp-sink-sbc_xq                   available=yes priority=17
  profile   9 a2dp-sink-aptx                     available=yes priority=19
  profile  10 a2dp-sink                          available=yes priority=20
  profile 260 headset-head-unit-cvsd             available=yes priority=2
  profile 261 headset-head-unit-msbc             available=yes priority=3
  active route: 1 headset-output Output device=1 available=yes
  route   1 headset-output         Output  available=yes profiles=[5, 6, 9, 10] devices=[1] desc='Headset'
  route   2 headset-hf-input       Input   available=yes profiles=[3, 260, 261] devices=[0] desc='Handsfree'
  route   3 headset-hf-output      Output  available=yes profiles=[3, 260, 261] devices=[1] desc='Handsfree'
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T15:13:26+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
