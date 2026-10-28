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

## 2026-10-28 — `-42` is coming, without the entry
- **Launchpad** (`tmp/walk-20261028/lp-hwe-7.0.json`): `7.0.0-42.42~24.04.1` created 2026-10-27
  23:45 UTC, **Updates, Pending** (not yet published); `-39` still only in proposed; `-38` in
  updates and security.
- **`-42` lacks the entry.** Its `.diff.gz` (SHA-256 `ab5b2722…b076`, matching its `.dsc`; the
  signature not checked; `cache/ubuntu-src/`): `zgrep -c "0x13d3, 0x3503"` → 0, and no other
  form of it (`0x3503`, "IMC Networks QCA9377": none). Control: the same diff adds 21
  `USB_DEVICE(0x…)` lines. Its newest base is "Upstream stable to v6.18.55, v7.2.9", one release
  before 6.18.56 / 7.2.10, which brought the entry. `scripts/commit-in-tree.py cache/linux
  cache/ubuntu-7.0.0-42 v7.0 dc16388d45ec 86ef0f58bdec`: both ABSENT (BT-8's fix also comes only
  with a later base); `96d006ae6445` (BT-9) PRESENT.
- **What it means for the laptop:** booting `-42` brings BT-1 back (stock btusb without the
  entry, the controller on its ROM firmware). E3 is built for `-38` only
  (`/lib/modules/7.0.0-38-generic/updates/btusb.ko`). `-38` arrived through the Software Updater
  (`/var/log/apt/history.log`: aptdaemon, 2026-10-08 17:40, with `linux-generic-hwe-24.04`);
  unattended-upgrades also allows `noble-security`, so `-42` can arrive either way once
  published, and GRUB boots the newest kernel.
- **Prepared:** `scripts/prepare-ubuntu-ksrc.sh 7.0.0-42.42~24.04.1` → `cache/ubuntu-7.0.0-42`
  (Bluetooth paths of `-42`). E3 for `-42` can be built as soon as its headers are installed:
  `scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-42 --krel 7.0.0-42-generic <patch>`
  with the patch E3 always used (`git -C cache/linux format-patch -1 dc16388d45ec`,
  `patches/diag/README.md` §E3), then `scripts/module-updates.sh --krel 7.0.0-42-generic --module
  btusb install <ko>`, both before the first boot into it (the recipe of `-38`'s build).
- **The operator's choice:** hold the HWE metapackages until E3 for `-42` is built, or install
  and build E3 before rebooting. Either way, no reboot into `-42` without E3.
- **The SRU question** has become less pressing: the next cycle after `-42` should take a base at
  or after 7.2.10/6.18.56, if Ubuntu's cadence holds. That is an inference, not a promise.
