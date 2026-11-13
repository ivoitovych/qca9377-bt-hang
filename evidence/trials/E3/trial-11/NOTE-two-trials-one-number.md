# Two trials share the number E3 #11

1. **The trial of boot `46cc4812`** opened 2026-11-12 22:55:12 and ran until the power-off at
   2026-11-13 10:35:16 (about 11 h 40 min). **It has no row in `results.tsv`.**
   - `current-at-close.txt` and an empty `close-output.txt` (10:31:57) are from a passive close
     by hand (`scripts/trial-close-now.sh`). It was stopped before it wrote the row, so that the
     power-off could go ahead.
   - At the shutdown the installed closer ran into its 90 s stop timeout and was killed
     (10:36:46; `results/bt16-third-2026-11-13/shutdown-before-trial-unit.txt`). That is the
     known row loss of the installed tool set (`docs/STATUS.md`, the machine's warnings).
   - Its counts are still in the journal of boot `46cc4812` (`scripts/sco-ledger.sh`).
2. **The trial of boot `680c448c`** (10:41:46–10:42:47) reused the number because no row had been
   written. **It is the row `11` dated 2026-11-13T10:42:47** (49 s, `7.0.0-43`). Its
   `state-before.txt`, `state-after.txt`, `sco-params.txt` and `steps.log` are from this boot. That
   boot had no Bluetooth at all (BT-16, third occurrence, `results/bt16-third-2026-11-13/`).

`state-before.txt` was rewritten at 10:41:46 with the same content as the committed copy, so git
shows no change.
