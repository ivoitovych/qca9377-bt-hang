# EX-015 — timeout-pattern-undercount

**Claim.** The kernel names the opcode in HCI command timeouts, so bt-trial's literal 'command tx timeout' pattern matched none of them and recorded timeouts=0 for a controller that had died with five.

**Relevance.** Trial stock #1 is the first uncensored baseline observation. It was written with bt1_status=not_observed against a journal containing five 0x0406 timeouts; the pattern, not the controller, produced the zero.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k --since '2026-08-13 03:00:25' --until '2026-08-13 05:19:38' --no-pager -o short-iso-precise | grep -cE "command( 0x[0-9a-f]+)? tx timeout"; journalctl -k --since '2026-08-13 03:00:25' --until '2026-08-13 05:19:38' --no-pager | grep -c 'command tx timeout'; journalctl -k --since '2026-08-13 03:00:25' --until '2026-08-13 05:19:38' --no-pager | grep -c 'link tx timeout'
```

## Output

Verbatim, 3 line(s), exit status 1.

```
5
0
0
```

## Correction applied to results.tsv

Trial `stock #1` was written by the defective classifier and has been corrected
in place. Both versions, so the edit is auditable:

| field | as written | corrected | source |
|---|---|---|---|
| `bt1_status` | `not_observed` | `confirmed` | five `command 0x0406 tx timeout` lines above |
| `timeouts` | `0` | `5` | same |
| `sco_to_timeout_s` | `none` | `13.746` | `bt-interval 05:14:16.715095 05:14:30.461003` |

`trial_result=failed` was already correct: it comes from the controller axis
(`hci_alive`), not from the journal pattern, which is why the two axes
disagreed. That disagreement is the only reason the defect was noticed — a
single-axis record would have read `survived` and been believed.

Nothing else in the row changed. `usb_lost=0` and `usb_present=yes` are
independently confirmed: the window contains no `USB disconnect` line, which is
the finding in its own right — the controller reached stage 1 and stayed there
for 4 m 48 s with no watchdog running.

**Evidence window.** `2026-08-13T03:00:25+02:00` — `2026-08-13T05:19:38+02:00`

> **Annotation added 2026-08-22 (`BL-09`), derived from this exhibit's own
> content. The captured output above is untouched.** The window is what the extraction command
> itself asked for: `--since '2026-08-13 03:00:25' --until '2026-08-13 05:19:38'`.
> Those are bare local times; the offset is this exhibit's own `captured` stamp,
> `2026-08-13T05:35:00+02:00`, fifteen minutes after the `--until` on the same day.
>
> The output itself is three bare counts, which is why the command's own bounds are
> the only thing in the file that can place it.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T05:35:00+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `e3f66b3e` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `1` |
| redacted | `no` |
