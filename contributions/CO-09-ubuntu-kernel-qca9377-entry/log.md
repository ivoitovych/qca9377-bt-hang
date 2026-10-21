# CO-09 log

Append-only. Newest last.

## 2026-10-08 — `-38` lacks the entry
`scripts/btusb-has-device.py`: ABSENT on stock `-34` and `-38`, FOUND on E3. E3 was rebuilt for
`-38` before its first boot.

## 2026-10-18 — `-39` lacks it too
`-39`'s diff has no `0x13d3, 0x3503`. As a control, it adds five Realtek entries. Its changelog
base is v6.18.51 / v7.2.5. Launchpad has no bug.

## 2026-10-20 — rechecked
No newer upload than `-39` (proposed).

## 2026-10-21 — dossier opened
