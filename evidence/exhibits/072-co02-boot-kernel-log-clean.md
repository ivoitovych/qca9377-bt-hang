# EX-072 — co02-boot-kernel-log-clean

**Claim.** The kernel log of the boot with the CO-02 series, from 2026-10-23 11:04:40 to the time of this exhibit (about 1.5 days, 27 or more SCO links on three headsets, three refusals), holds no WARNING, BUG, refcount, use-after-free, Call Trace, tx timeout or Oops line: the search exits 1 with no entries.

**Relevance.** Run 6 of the plan: none of the searched diagnostics on real hardware over ordinary use. *Narrowed 2026-10-26:* this first said an unbalanced hold "would show" a refcount warning or a use-after-free. It need not. An extra hold is silent in the log; it shows as a link that stays up after its sockets close, and `EX-074` shows every link of the boot closed. A missing hold shows only if the freed connection is caught being used, and this Ubuntu kernel has no KASAN. So the absence of these lines is supporting evidence, weaker than the emulator runs (lockdep and KASAN from BlueZ's `doc/tester.config`, and a KCSAN build). The error-level SCO lines of the boot are in `EX-073` (they predate the series, `CO-20`).

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k -b 257d1599532e4cad941b5bb6178bb630 --no-pager --grep "WARNING|BUG|refcount|use-after-free|Call Trace|tx timeout|Oops"
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
| captured | `2026-10-25T22:24:12+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `1` |
| redacted | `no` |
