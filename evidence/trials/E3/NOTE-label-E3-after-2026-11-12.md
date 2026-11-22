# Rows labelled E3 after 2026-11-12 ran Ubuntu's stock btusb

Written 2026-11-22.

- **From 2026-11-12 22:55 the laptop runs `7.0.0-43-generic` with its stock btusb.** That btusb
  itself carries the upstream entry `dc16388d45ec` for `13d3:3503`, so E3, our own build of the
  same entry, was retired (`docs/STATUS.md`, the machine section).
- **The label stayed `E3`.** It comes from the trial unit's drop-in
  (`/etc/systemd/system/bt-trial-auto.service.d/override.conf`, `Environment=BT_BUILD=E3`, set
  2026-09-30). The drop-in's own comment said to remove it once the stock module was back; it was
  not changed until 2026-11-22.
- **Rows 11 to 14 of this series are on the stock module.** The `kernel` column of each row says
  `7.0.0-43-generic`, which is correct. The `build` column says `E3`, which is not.
  - Row 11: boot `680c448c` (BT-16, `trial-11/NOTE-failed-verdict-read-2026-11-16.txt`).
  - Row 12: boot `a033d9d8`, `trial-12/NOTE-row-recomputed-2026-11-22.md`.
  - Row 13: the 72-second boot of 2026-11-16 18:48, `trial-13/NOTE-journal-lost.md`.
  - Trial 14: the boot from 2026-11-18 13:48, open on 2026-11-22, `trial-14/NOTE-before-close.md`.
- **What this changes for a reader.** The fix under test is the same entry in both builds, so
  these rows still say whether the controller holds up with the entry present. They are not E3
  rows, and they do not count toward E3's own totals.
- **From the next boot** the drop-in says `BT_BUILD=stock-fixed` (changed 2026-11-22). That is a
  new series. It is not `stock`, which is the series of stock kernels *without* the entry
  (2026-08 and 09).
- The row values in `results.tsv` are left as the closer wrote them. Corrections are in these
  notes.
