# EX-013 — which-workarounds-were-active-when

**Claim.** The retained boots split into two distinct experimental environments at 2026-08-10, the day the mitigation was installed. Boots before it ran with no watchdog and no health probes; boots after ran with autosuspend disabled, the radio pinned power/control=on, health probes issuing real HCI commands, and a watchdog able to reset the controller BEFORE any HCI timeout.

**Relevance.** Answers the question of which workaround was active during which log period, from evidence the machine recorded at the time rather than from what is installed now. It also invalidates pooling: any statistic computed across this boundary — including the 34-boot cross-tabulations in EX-002 and EX-003 — mixes two treatments and measures the workarounds as much as the kernel. Watchdog mode is read from its own startup banner, which logs EARLY mode ON or early mode off explicitly; autosuspend and power/control come from metrics.tsv keyed by boot_id. Unknowns print as ? rather than being assumed to be defaults.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ echo 'mitigation installed at:'; date -d @$(cat /usr/local/share/qca9377-bt-hang/installed-at) '+%Y-%m-%d %H:%M'; echo; bt-env-history | head -26
```

## Output

Verbatim, 29 line(s), exit status 0.

```
mitigation installed at:
2026-08-10 03:07

BOOT  DATE         WATCHDOG         AUTOSUSP    POWER   PROBES
─────────────────────────────────────────────────────────────────────────
-20   2026-07-16   off              ?           ?       none
-19   2026-07-25   off              ?           ?       none
-18   2026-08-02   off              ?           ?       none
-17   2026-08-07   off              ?           ?       none
-16   2026-08-07   off              ?           ?       none
-15   2026-08-07   off              ?           ?       none
-14   2026-08-08   off              ?           ?       none
-13   2026-08-08   off              ?           ?       none
-12   2026-08-10   on/?             N           ?       28
-11   2026-08-10   early+late/3/60  N           on      28
-10   2026-08-10   early+late/3/60  N           on      32
-9    2026-08-10   early+late/3/60  N           on      4
-8    2026-08-10   early+late/3/60  N           on      2
-7    2026-08-11   early+late/3/60  N           on      156
-6    2026-08-11   early+late/3/60  N           on      26
-5    2026-08-11   early+late/3/60  N           on      106
-4    2026-08-11   early+late/3/60  N           on      28
-3    2026-08-12   early+late/3/60  N           on      84
-2    2026-08-12   early+late/3/60  N           on      36
-1    2026-08-12   early+late/3/60  N           on      42
0     2026-08-13   early+late/3/60  N           on      200

  WATCHDOG   off = no startup banner in that boot. early+late means it could
             reset the controller BEFORE any HCI timeout, so even the
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T01:28:38+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d28ebac2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
