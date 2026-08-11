# EX-003 — desync-is-not-the-cause

**Claim.** The HCI desync signature is a companion symptom of this controller, NOT the cause of the hang: it appears in boots that never hang, and boots hang without it.

**Relevance.** Negative control for EX-002. Across 34 boots the desync appears in 8 boots that recorded no command timeout at all (one with 6250 occurrences over 45 hours), and 2 boots hung with zero desyncs. A signature carrying both false positives and false negatives cannot be offered upstream as the mechanism, only as an associated observation.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ cd /root/exp/qca9377-bt-hang && ./tools/bt-boot-stats
```

## Output

Verbatim, 47 line(s), exit status 0.

```
BOOT  DATE          HOURS   DESYNC  TIMEOUT  BUSLOST  HUNG
---------------------------------------------------------------
-33   2026-06-16      0.0        0        0        1    no
-32   2026-06-16      7.7        0        0        1    no
-31   2026-06-17     66.8        5        7        0   yes
-30   2026-06-20     55.5        3       17        0   yes
-29   2026-06-22     73.2     1235        0        0    no
-28   2026-06-25     77.0     3477       19        0   yes
-27   2026-06-29      4.2      640        0        0    no
-26   2026-06-29   -678.4      321       13        0   yes
-25   2026-07-01      3.0      669        0        0    no
-24   2026-07-01     29.1     5162       86        0   yes
-23   2026-07-02      8.0        6        0        0    no
-22   2026-07-02    120.9       38       12        0   yes
-21   2026-07-07     32.7        1        0        0    no
-20   2026-07-09     24.7        3        0        0    no
-19   2026-07-10     20.8        0        0        0    no
-18   2026-07-12      1.4        0        0        0    no
-17   2026-07-12     95.9     2556       25        0   yes
-16   2026-07-16    207.7     1364        4        0   yes
-15   2026-07-25   -538.6     6250        0        1    no
-14   2026-08-02    109.5       13       28        0   yes
-13   2026-08-07      1.0        0        0        0    no
-12   2026-08-07     10.5       26       15        0   yes
-11   2026-08-08      5.2        1        8        0   yes
-10   2026-08-08      2.7        1        0        0    no
-9    2026-08-08     45.4     1527       25        1   yes
-8    2026-08-10      1.5        4        8        1   yes
-7    2026-08-10      3.8        0        0        0    no
-6    2026-08-10      0.0        0        0        0    no
-5    2026-08-10      0.0        0        0        1    no
-4    2026-08-10     12.0     2514        6        1   yes
-3    2026-08-11      2.2        0        8        0   yes
-2    2026-08-11      9.3        2        6        1   yes
-1    2026-08-11      1.9        0        7        1   yes
0     2026-08-11      1.8      292        9        1   yes

boots examined            34
boots that hung           18

Is the desync signature a predictor of the hang?
  desync present AND hung   16
  desync present, NO hang   8   <- false positives
  NO desync, hung anyway    2   <- false negatives

  A signature with both false positives and false negatives is a
  companion symptom, not a cause. Report it as such.
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T00:43:58+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `5641d159` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
