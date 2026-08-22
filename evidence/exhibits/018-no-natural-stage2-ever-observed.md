# EX-018 — no-natural-stage2-ever-observed

**Historical claim.** The then-current classifier reported 14 stage-1 boots across the retained journal and zero uncensored USB-loss transitions. Its 9 reset / 5 shutdown breakdown requires re-capture because reset provenance was still inferred rather than positively established.

**Relevance.** This was the first whole-journal challenge to the two-stage model and its 45–66 s figure. The short intervals still cannot be read as natural survival times, but the exact terminator categories below are historical until re-captured with positive/kernel/unknown reset provenance.

## Extraction method

Re-runnable on the affected machine (several minutes — it reads the whole
retained kernel journal, 3.3 M lines; `--cache` keeps the dump for re-analysis):

```console
$ bt-stage2 --cache /var/tmp/stage2.log 2>/dev/null | tail -14
```

> **Edited 2026-08-13, after capture.** The command originally recorded here
> read the journal dump from a machine-local temporary cache whose path leaked
> editor-tooling metadata (a scratchpad directory name and session id) and was
> re-runnable on no machine, including this one — both against this
> repository's own publication rules. The command above is the equivalent
> documented invocation from "Reproducing this" below; the **output is
> unchanged** and remains the verbatim product of the original run over the
> same cached dump.

## Output

Verbatim, 14 line(s), exit status 0.

```

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

## Reproducing this

The command above reads a cached journal dump so the exhibit renders quickly.
To rebuild it from the machine — several minutes, 3.3 M lines:

```console
$ bt-stage2 --cache /var/tmp/stage2.log
```

`-b all` is not optional. Plain `journalctl -k` returned only the current boot
on this host, which would reduce this 22-boot history to one and report a single
window as if it were the whole record.

## The stage-1 windows, and what ended each

| first HCI timeout | window | ended by |
|---|---:|---|
| 2026-07-25 03:25 | 5 h 33 m | shutdown |
| 2026-08-07 11:25 | 27 m | shutdown |
| 2026-08-07 21:58 | 1 h 26 m | shutdown |
| 2026-08-08 02:50 | 3 h 14 m | shutdown |
| 2026-08-09 20:20 | **6 h 26 m** | our reset |
| 2026-08-10 07:24 | 37.75 s | our reset |
| 2026-08-11 06:06 | 29.30 s | our reset |
| 2026-08-11 09:11 | 18.91 s | shutdown |
| 2026-08-11 19:39 | 50.87 s | our reset |
| 2026-08-11 19:51 | 33.78 s | our reset |
| 2026-08-12 00:11 | 61.17 s | our reset |
| 2026-08-12 05:00 | 54.00 s | our reset |
| 2026-08-12 06:26 | 121.65 s | our reset |
| 2026-08-13 05:14 | **1 h 12 m** | our btusb unload |

> **Superseded twice.** `EX-020` re-captured this output after the F2 classifier fixes,
> but a later review found that both versions still inferred reset origin from absence of
> recognized bus errors. The current classifier separates positive intervention,
> kernel-treatment reset and unknown-origin reset. Do not cite the 9/5 terminator breakdown
> until the affected machine re-captures the retained journal under those categories.
> This and `EX-020` remain historical records of successive classifiers; `EX-016` is the
> directly checked uncensored-by-reset observation that remains current.

## Reading

**Nothing in this table measures the fault.** Every row is right-censored: a
lower bound on how long the controller survives, never an estimate of it.

The 29–121 s cluster that produced the documented "45–66 s" is the **watchdog's
reaction time**, not the device's. That is visible without statistics — the two
longest windows, 1 h 12 m and 6 h 26 m, are the boots where nothing fired
promptly, and the controller was still enumerated and error-free throughout
both. A figure computed over the short rows describes our software's latency
and was read as the hardware's.

This is outcome-dependent sampling in its most direct form. The watchdog exists
to reset a failed controller, so it fires on precisely the boots that progress,
and it fires **first**. Averaging what follows measures the instrument.

## What it does not say

It does **not** say stage 2 never happens on its own. Fourteen censored
observations exclude nothing beyond their own durations; the longest says only
that the device can sit in stage 1 for at least six and a half hours. The device
may well leave the bus unaided after some longer interval.

It says the **question has never been asked**, and that every number the project
has quoted about it came from boots in which we answered it for ourselves.

## The experiment that settles it

Cold boot into experiment mode. Use the machine normally. When BT-1 occurs, do
nothing at all — no `hciconfig`, no rfkill toggle, no btusb reload, no
reinstall, no mode change, no watchdog. Wait, and record whether the device
leaves the bus by itself and at what interval. If the operator needs the machine
back first, that observation is censored at whatever duration they tolerated,
which is still worth more than any row above.

A handful of such boots settles a question the project treated as closed for
months.

**Evidence window.** `2026-07-25T03:25:00+02:00` — `2026-08-13T05:14:00+02:00`

> **Annotation added 2026-08-22 (`BL-09`), derived from this exhibit's own
> content. The captured output above is untouched.** From the `first HCI timeout` column of the
> stage-1 table, whose rows run `2026-07-25 03:25` to `2026-08-13 05:14`. They are
> bare local times; the offset is this exhibit's own `captured` stamp,
> `2026-08-13T11:46:28+02:00`. Both endpoints fall inside the same CEST period as
> that stamp, so a single offset applies to the whole span and no boundary is crossed.
>
> ⚠️ `docs/investigation-plan.md` expected this exhibit to stay unjudgeable — *"no line
> in the file can place evidence that is gone"*. The table's first column is such a
> line, and placing it gives the answer the exhibit was written about: the window
> opens weeks before the oldest retained boot, so `bt-retention` now reports **GONE**
> rather than **not judgeable**, which is a stronger and more useful statement of the
> same fact. The evidence is gone; that is now derived rather than assumed.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T11:46:28+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d6d9b2dc` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
