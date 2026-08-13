# EX-020 — stage2-recaptured-corrected-classifier

**Claim.** Re-run of the whole-journal stage-2 analysis under the CORRECTED classifier (review finding F2): 14 boots reached stage 1, zero progressed to stage 2 uncensored. Byte-identical to the pre-fix run.

**Relevance.** EX-018's recorded output was produced by a classifier biased toward FALSE naturals - dev_error was never reset at a boot boundary, and the USB patterns matched any device. A tool that invents naturals found none, and now the fixed tool finds none either, on the same journal.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ bt-stage2 --from /var/tmp/stage2.log | tail -14
```

## Output

Verbatim, 16 line(s), exit status 0.

```
source: 3286819 lines, 22 boot(s)


──────────────────────────────────────────────────────────────
  boots reaching stage 1        14
    ended naturally             0   <- the only ones that measure the fault
    ended by our intervention   9
    ended by shutdown           5
    still running               0

  No natural progression to stage 2 has been observed.
  Every stage-1 window so far was ended by us or by shutdown, so
  the fault's untreated trajectory is UNKNOWN — not 45-66s, not
  indefinite. The experiment that settles it is a boot left
  strictly alone after BT-1 until the device leaves the bus.
  longest window of any kind       23190.51s (6h 26m 30s, intervened)
```

## Why this exhibit exists, and what it supersedes

`EX-018` reported this result. Two things were wrong with it as a record, both
found by a full-tree review:

1. Its output was produced by a classifier with a real bias (finding **F2**).
   `dev_error` was never reset at a `-- Boot` separator, so after the first
   bus-level error anywhere in the journal, our own resets in every later boot
   were classified as hub recovery rather than intervention — and a disconnect
   following one would then read as **NATURAL**. Separately, the USB patterns
   matched *any* device, so unplugging a mouse could close a stage-1 window.

2. Its extraction command was later edited to a cleaner equivalent that had
   never been run, which is precisely the command/output drift `bt-exhibit`
   exists to prevent.

This exhibit fixes both: the command above is the command that produced the
output above, under the corrected classifier.

## The result did not move

The full analysis bodies are byte-identical, pre-fix and post-fix:

```console
$ diff old-body.txt new-body.txt && echo IDENTICAL
IDENTICAL
```

That is the expected direction. **Both halves of F2 bias toward false
naturals** — an unreset `dev_error` makes our resets look like passive hub
recovery, and unanchored USB patterns let an unrelated device's disconnect end
a window. A classifier that can only invent naturals found zero of them. The
corrected one, which cannot, also finds zero.

So the headline survives *a fortiori* rather than by luck, and it survives for
a reason that can be stated without reference to this particular journal.

**What was genuinely at risk** was the individual window durations, since a
stray disconnect could have truncated one. They are unchanged too, and the
longest uncensored-by-reset window — 4331.99 s in `EX-016` — was independently
checked line by line against the raw journal when it was first recorded.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T17:39:44+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d6d9b2dc` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
