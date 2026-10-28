# Diagnostic btusb builds — not for upstream

Kept separately until 2026-10-09. Each build changes **one** variable against the
failing baseline (stock `btusb`, `13d3:3503` matched as a generic device, legacy `0x0428`,
wideband, alt 1).

## E1 — QCA ROME setup, no automatic reset

[`btusb-e1-qca-rome-setup-no-reset.patch`](btusb-e1-qca-rome-setup-no-reset.patch), against
Ubuntu `linux-hwe-7.0` `7.0.0-34.34~24.04.1` (`scripts/prepare-ubuntu-ksrc.sh`):

- `13d3:3503` added to `quirks_table` as `BTUSB_QCA_ROME` **only** — no
  `BTUSB_WIDEBAND_SPEECH`, so wideband behaves as under the stock generic entry;
- `hdev->reset = btusb_qca_reset` **skipped** for this ID, so a failure and its treatment
  never share a trial;
- `bt_dev_info` lines prefixed `E1:` in `btusb_setup_qca()`: ROM/patch/RAM version before
  setup, the status byte (rampatch / NVM present or to load), each load's return code, the
  version after the rampatch;
- `MODULE_VERSION` `0.8-e1`, so `/sys/module/btusb/version` names the running build.

`btusb_setup_qca()` also sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN` (upstream
behaviour): SCO setup stays on legacy `0x0428`, as in every death — the setup command is
**not** the variable here.

| built 2026-09-26 | |
|---|---|
| script | `scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-34 <patch>` |
| version / srcversion | `0.8-e1` / `0FF3E900DE4D28718D8573F` |
| vermagic | `7.0.0-34-generic SMP preempt mod_unload modversions` ✓ running kernel |
| sha256 | `f635c4472eddc5f31e728fdb5028891ce5fd248f45339b993df21695819bc404` |
| kept at | `tmp/runtime-e1/btusb.ko` (local, not committed) |
| stock `btusb` loaded | version `0.8`, srcversion `105BEF3957ED5EAC38501B9`; no `13d3:3503` entry |
| firmware on disk | `qca/rampatch_usb_00000302.bin.zst`, `qca/nvm_usb_00000302.bin.zst` (expected for QCA9377; the `E1:` lines will show the ROM version actually read) |
| initramfs | no Bluetooth module — `updates/` + cold boot is enough |

⚠️ **Not bit-identical to stock even without the patch.** An unpatched control build from
the same tree has the same source (diff checksum-verified, `include/net/bluetooth` identical
to Ubuntu's headers package) and the same function set, but the compiler inlined four helpers
(`btusb_recv_isoc`, two `.part`/`.constprop` fragments, `btusb_rtl_alloc_devcoredump`)
differently; most likely flags passed by Ubuntu's packaging. Behaviour, not bytes, is compared.

**Install / remove** (operator's decision; takes effect at the next **cold** boot, nothing is
loaded live — `EX-046`):

    scripts/module-updates.sh --module btusb install tmp/runtime-e1/btusb.ko
    scripts/module-updates.sh --module btusb remove

**Read after the boot:** `cat /sys/module/btusb/version` (`0.8-e1`); `journalctl -k -b 0 --grep
'E1:|QCA|rampatch|NVM'`; `scripts/supported-commands-survey.sh` on the boot's capture (197 or
200 commands; Enhanced advertised or not).

**E1 result (2026-09-26 → 29):** 37 SCO links over two boots, 37 hang-ups answered, 0 timeouts,
wideband streams to 5,122 s (`scripts/sco-ledger.sh -1`, `0`; `EX-055`, `EX-056`) — all one
headset (MOMENTUM 4). Missing QCA setup is the cause. Next: E3.

## E3 — the exact upstream entry, `dc16388d45ec`

The patch is `git -C cache/linux format-patch -1 dc16388d45ec` from mainline, unchanged
(kept at `tmp/runtime-e3/`, not committed: its upstream sign-offs carry addresses the
repository scan refuses, and the commit id reproduces it exactly): `13d3:3503` as
`BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`, with the reset callback, no diagnostic lines, and
`MODULE_VERSION` left at `0.8` — so `/sys/module/btusb/version` does **not** name this build;
the srcversion does. This is the build a stable backport request vouches for.

| built 2026-09-29 | |
|---|---|
| script | `scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-34 <patch>` (hunk applied at offset 1) |
| version / srcversion | `0.8` / `36ADEF2A3F27D16D77A320E` (stock: `105BEF3957ED5EAC38501B9`) |
| vermagic | `7.0.0-34-generic SMP preempt mod_unload modversions` ✓ running kernel |
| sha256 | `f13d86c406995d79f025ddecc1b7eddbd609a291bb168c4a2fe2e45bca245f60` |
| kept at | `tmp/runtime-e3/btusb.ko` (local, not committed) |
| compiled source | `grep -n 0x3503 tmp/btusb-build/drivers/bluetooth/btusb.c` → line 301, the entry |

**Install** (on the operator's word only; next cold boot):

    scripts/module-updates.sh --module btusb install tmp/runtime-e3/btusb.ko

**Read after the boot:** `scripts/module-updates.sh --module btusb status` and
`modinfo -F srcversion btusb` → `36ADEF2A3F27D16D77A320E`; `journalctl -k -b 0 --grep
'QCA|rampatch|NVM|Bluetooth: hci0'` (no `E1:` lines this time); the supported-commands survey
(202 with Enhanced); then the hard test with **both** headsets and `scripts/sco-ledger.sh 0`.
Pass: 0 timeouts, 0 `0x2005`; the reset callback only fires on a timeout, so a clean boot never
exercises it — the request must say so.

### E3 for 7.0.0-38 (built and installed 2026-10-10, on the operator's word; booted 2026-10-11 16:26)

**Since then** (added 2026-10-28; the section below is kept as written before the boot): `-38`
has run with this E3 since 2026-10-11 16:26 (`docs/STATUS.md`, the machine's section; the boot log
shows `QCA: patch rome 0x302 build 0x3e8`). The next kernel, `7.0.0-42`, needs the same recipe
before its first boot (`contributions/CO-09-ubuntu-kernel-qca9377-entry/log.md`, 2026-10-28).

`7.0.0-38.38~24.04.4` is installed (image and headers, `grub.cfg` regenerated 2026-10-09
06:02) and `GRUB_DEFAULT=0` boots the newest kernel, so the next reboot starts -38. Its stock
btusb has no `13d3:3503` entry (`grep -c "0x13d3, 0x35"` finds 26 IMC entries in its btusb.c,
none for 3503), so without E3 the adapter would fall back to the generic setup. -38 already
has the BT-9 fix `96d006ae6445` in `hci_event.c`.

| built 2026-10-10 | |
|---|---|
| source | `scripts/prepare-ubuntu-ksrc.sh 7.0.0-38.38~24.04.4` → `cache/ubuntu-7.0.0-38` (diff.gz sha256 matches the `.dsc`) |
| script | `scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-38 --krel 7.0.0-38-generic <patch>` (hunk at offset 1, as for -34) |
| patch | the same file as for -34; `git patch-id --stable` equals mainline `dc16388d45ec`'s (`2caa69bd…`) |
| version / srcversion | `0.8` / `D1DEA96A0C95BFAB05CEE01` |
| vermagic | `7.0.0-38-generic SMP preempt mod_unload modversions` ✓ |
| CRCs | `scripts/check-modversions.sh /lib/modules/7.0.0-38-generic/build/Module.symvers <ko>`: 134 used, 0 mismatched |
| sha256 | `351e260e053d9ae4c7abd46115f25409f9330b545c671c98a927ebb96495706b` |
| kept at | `tmp/runtime-e3-7.0.0-38/btusb.ko` (build tree `tmp/btusb-build-e3-7.0.0-38/`; the -34 one kept as `tmp/btusb-build-e3-7.0.0-34/`) |

**Install** (on the operator's word only; takes effect when -38 is first booted; -34 and its
E3 stay as they are):

    scripts/module-updates.sh --krel 7.0.0-38-generic --module btusb install tmp/runtime-e3-7.0.0-38/btusb.ko

The -38 initramfs has no btusb, so `updates/` + `depmod` is enough. **Read after the first -38
boot:** `modinfo -F srcversion btusb` → `D1DEA96A0C95BFAB05CEE01`; the QCA rampatch/NVM lines
in `journalctl -k -b 0`. Until then, picking -34 under GRUB's "Advanced options" keeps E3.

### E3 for 7.0.0-42 (built 2026-10-28; NOT installed — the operator's word is needed)

`7.0.0-42.42~24.04.1` was installed by the desktop's software updater on 2026-10-28 at 04:46
(`/var/log/apt/history.log`: `aptdaemon role='role-commit-packages'`, image, modules and
headers), and `GRUB_DEFAULT=0` boots the newest kernel, so **the next reboot starts -42**. Its
stock btusb lacks the entry: `scripts/btusb-has-device.py
/lib/modules/7.0.0-42-generic/kernel/drivers/bluetooth/btusb.ko.zst` → `ABSENT 13d3:3503 x0`
(control `0cf3 e300` → `FOUND 0cf3:e300 x1`). `/lib/modules/7.0.0-42-generic/updates` does not
exist yet.

| built 2026-10-28 | |
|---|---|
| source | `cache/ubuntu-7.0.0-42` (`scripts/prepare-ubuntu-ksrc.sh`, as for -38) |
| script | `scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-42 --krel 7.0.0-42-generic tmp/runtime-e3/0001-Bluetooth-btusb-Add-IMC-Networks-QCA9377-to-quirks-t.patch` (hunk at offset 12) |
| patch | the same file as for -34 and -38 |
| version / srcversion | `0.8` / `DDB92562D1890FC3D262993` |
| vermagic | `7.0.0-42-generic SMP preempt mod_unload modversions` ✓ |
| entry | `scripts/btusb-has-device.py tmp/runtime-e3-7.0.0-42/btusb.ko` → `FOUND 13d3:3503 x1` |
| CRCs | `scripts/check-modversions.sh /lib/modules/7.0.0-42-generic/build/Module.symvers <ko>`: 139 used, 0 mismatched |
| install check | `scripts/module-updates.sh --krel 7.0.0-42-generic --module btusb check <ko>` → `ready to install` (writes nothing) |
| sha256 | `7463a56bb9216bed4a70073bd155eba8b7d6d2ee5cfea511d0c8198893750f4b` |
| kept at | `tmp/runtime-e3-7.0.0-42/btusb.ko` (build tree `tmp/btusb-build-e3-7.0.0-42/`) |

**Install** (on the operator's word only; takes effect when -42 is first booted; nothing on the
running -38 changes):

    scripts/module-updates.sh --krel 7.0.0-42-generic --module btusb install tmp/runtime-e3-7.0.0-42/btusb.ko

The CO-02 `bluetooth.ko` exists for -38 only; a -42 boot runs -42's stock `bluetooth.ko`.
**Read after the first -42 boot:** `modinfo -F srcversion btusb` → `DDB92562D1890FC3D262993`;
`QCA: patch rome 0x302 build 0x3e8` in `journalctl -k -b 0`.

**What decides it** (reviewer's table, `reviews/2026-09-26-source-review-report.md` on the
review branch): same alt 1, same `27 → 9+9+9`, sustained stream, and commands keep completing
→ missing QCA setup is the cause, and the fix is the upstream entry (`dc16388d45ec`) as a
stable backport. Same fatal first-command timeout → setup alone is not enough; next is E2
(this build minus the Enhanced-setup quirk) before any wideband-off build.
