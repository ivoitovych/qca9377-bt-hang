# EX-058 — e1-setup-only-58-links-three-boots

**Claim.** A diagnostic btusb build that applies only the QCA setup part of the upstream entry (E1: BTUSB_QCA_ROME without BTUSB_WIDEBAND_SPEECH and without the reset callback) ran 58 SCO links over three boots and two headset models with all 58 hang-ups answered and 0 command timeouts, where the stock driver timed out in all 12 recorded instances.

**Relevance.** Isolates the firmware setup from the entry's other effects: wideband, alt 1 and legacy 0x0428 are as in the deaths, the reset callback cannot have rescued anything, and the isolated change is enabling the QCA setup path, which loads the rampatch and NVM instead of leaving the controller on its ROM firmware. Per-link rows name the headset, air mode, alt-1 buffer count, seconds streamed and the outcome of the first command after the stream. The three boots are named by their ids, which do not change at the next reboot.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/sco-ledger-boots.sh 226965f1219c426a950d71e6845deb6d 855a927e5bff4155af4f13442ce34b4c 8709ee7c02d84d378eca24a204b75ed6
```

## Output

Verbatim, 76 line(s), exit status 0.

```
== boot 226965f1219c426a950d71e6845deb6d
setup                       headset             air     len27/9   streamed  outcome
2026-09-26T21:52:50.121505  MOMENTUM 4          msbc       3607      10.84  hangup-ok 58 ms
2026-09-26T21:53:12.290578  MOMENTUM 4          msbc       1242       3.76  hangup-ok 5 ms
2026-09-26T21:53:16.169517  MOMENTUM 4          cvsd          0       7.26  hangup-ok 36 ms
2026-09-26T21:53:23.582640  MOMENTUM 4          msbc       3340      10.05  hangup-ok 10 ms
2026-09-26T21:53:33.744602  MOMENTUM 4          msbc        820       2.49  hangup-ok 8 ms
2026-09-26T21:53:36.349638  MOMENTUM 4          msbc        877       2.64  hangup-ok 6 ms
2026-09-26T21:53:39.113547  MOMENTUM 4          cvsd          0       3.36  hangup-ok 24 ms
2026-09-26T21:53:55.111512  MOMENTUM 4          msbc       1832       5.51  hangup-ok 98 ms
2026-09-26T21:54:01.026556  MOMENTUM 4          cvsd          0       5.41  hangup-ok 63 ms
2026-09-26T21:55:05.013703  MOMENTUM 4          msbc       3555      10.70  hangup-ok 74 ms
2026-09-26T21:55:15.894592  MOMENTUM 4          cvsd          0       8.04  hangup-ok 53 ms
2026-09-26T22:01:20.322629  MOMENTUM 4          msbc      44700     134.12  hangup-ok 33 ms
2026-09-26T22:03:34.598654  MOMENTUM 4          cvsd          0     208.82  hangup-ok 38 ms
2026-09-26T22:07:03.575600  MOMENTUM 4          msbc       1612       4.87  hangup-ok 7 ms
2026-09-26T22:07:08.658573  MOMENTUM 4          msbc       1627       4.90  hangup-ok 30 ms
2026-09-26T22:07:13.673704  MOMENTUM 4          msbc       1022       3.08  hangup-ok 7 ms
2026-09-26T22:07:16.893590  MOMENTUM 4          cvsd          0       5.24  hangup-ok 6 ms
2026-09-26T22:07:22.295603  MOMENTUM 4          msbc     278555     835.70  hangup-ok 73 ms
2026-09-26T22:21:42.478644  MOMENTUM 4          msbc       2560       7.70  hangup-ok 56 ms
2026-09-26T22:22:17.569796  MOMENTUM 4          msbc      26385      79.17  hangup-ok 46 ms
2026-09-26T22:25:00.025635  MOMENTUM 4          msbc       1927       5.81  hangup-ok 6 ms
2026-09-26T22:25:05.960611  MOMENTUM 4          cvsd          0       2.87  hangup-ok 8 ms
2026-09-26T22:25:08.958569  MOMENTUM 4          msbc       2090       6.29  hangup-ok 54 ms
2026-09-26T22:25:20.450731  MOMENTUM 4          msbc       1065       3.22  hangup-ok 10 ms
2026-09-26T22:25:23.799627  MOMENTUM 4          cvsd          0       4.92  hangup-ok 15 ms
2026-09-26T22:25:28.872572  MOMENTUM 4          msbc      11030      33.11  hangup-ok 70 ms
2026-09-26T22:26:02.177717  MOMENTUM 4          cvsd          0       7.57  hangup-ok 36 ms
2026-09-26T22:26:14.027641  MOMENTUM 4          msbc       3432      10.33  hangup-ok 5 ms
2026-09-26T22:26:24.488772  MOMENTUM 4          cvsd          0       3.05  hangup-ok 7 ms
2026-09-26T22:26:27.679627  MOMENTUM 4          msbc     159555     479.69  hangup-ok 92 ms
2026-09-26T22:34:28.140561  MOMENTUM 4          msbc     640687    1923.08  hangup-ok 33 ms
2026-09-26T23:08:17.761526  MOMENTUM 4          msbc       2135       6.42  hangup-ok 9 ms
2026-09-26T23:08:49.466717  MOMENTUM 4          msbc      26300      78.93  hangup-ok 35 ms
2026-09-26T23:12:30.553700  MOMENTUM 4          msbc    1707427    5122.35  hangup-ok 74 ms

links 34   hang-ups answered 34   timeouts 0

== boot 855a927e5bff4155af4f13442ce34b4c
setup                       headset             air     len27/9   streamed  outcome
2026-09-28T18:25:28.585230  MOMENTUM 4          msbc       3195       9.60  hangup-ok 26 ms
2026-09-28T18:25:52.037353  MOMENTUM 4          msbc       3465      10.42  hangup-ok 53 ms
2026-09-28T18:26:40.451323  MOMENTUM 4          msbc       5147      15.46  hangup-ok 93 ms
2026-09-29T01:56:54.744223  MOMENTUM 4          msbc        645     148.73  hangup-ok 57 ms
2026-09-29T02:24:33.867231  联想thinkplus-GM2 pro  msbc       5709      16.87  hangup-ok 206 ms
2026-09-29T02:24:53.534217  联想thinkplus-GM2 pro  cvsd          0       1.94  hangup-ok 188 ms
2026-09-29T02:25:00.990181  联想thinkplus-GM2 pro  cvsd          0       1.39  hangup-ok 185 ms
2026-09-29T02:25:04.160248  联想thinkplus-GM2 pro  msbc        897       2.46  hangup-ok 186 ms
2026-09-29T02:25:08.666254  联想thinkplus-GM2 pro  msbc        714       2.04  hangup-ok 195 ms
2026-09-29T02:26:48.549315  联想thinkplus-GM2 pro  cvsd          0       7.00  hangup-ok 224 ms
2026-09-29T02:27:32.549290  联想thinkplus-GM2 pro  cvsd          0     171.08  hangup-ok 199 ms
2026-09-29T02:30:27.882268  联想thinkplus-GM2 pro  msbc       5761      17.07  hangup-ok 176 ms
2026-09-29T02:30:59.800363  联想thinkplus-GM2 pro  msbc       4211      12.39  hangup-ok 204 ms
2026-09-29T02:38:44.261304  联想thinkplus-GM2 pro  cvsd          0      13.90  hangup-ok 184 ms
2026-09-29T02:39:43.845426  联想thinkplus-GM2 pro  msbc       3940      11.58  hangup-ok 197 ms
2026-09-29T04:25:17.788343  联想thinkplus-GM2 pro  msbc       2083       6.05  hangup-ok 192 ms
2026-09-29T15:30:41.874201  MOMENTUM 4          msbc       2377       7.14  hangup-ok 17 ms
2026-09-29T15:41:10.779335  MOMENTUM 4          msbc       4642      13.95  hangup-ok 81 ms
2026-09-29T15:42:26.746406  MOMENTUM 4          msbc       3272       9.84  hangup-ok 65 ms
2026-09-29T15:45:38.108298  MOMENTUM 4          msbc       2672       8.03  hangup-ok 22 ms
2026-09-29T15:45:52.353376  MOMENTUM 4          msbc       1905       5.73  hangup-ok 6 ms

links 21   hang-ups answered 21   timeouts 0

== boot 8709ee7c02d84d378eca24a204b75ed6
setup                       headset             air     len27/9   streamed  outcome
2026-09-29T18:20:50.515505  MOMENTUM 4          msbc        637     167.77  hangup-ok 48 ms
2026-09-29T18:24:21.137437  MOMENTUM 4          msbc        640      85.85  hangup-ok 42 ms
2026-09-29T18:30:01.944440  MOMENTUM 4          msbc        650     166.32  hangup-ok 54 ms

links 3   hang-ups answered 3   timeouts 0

TOTAL over 3 boot(s): links 58   hang-ups answered 58   timeouts 0
  联想thinkplus-GM2 pro      12
  MOMENTUM 4               46
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-02T01:15:25+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `c34cfa10` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
