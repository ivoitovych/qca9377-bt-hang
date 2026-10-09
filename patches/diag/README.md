# Diagnostic btusb builds — not for upstream

Kept on a private branch until 2026-10-09. Each build changes **one** variable against the
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

**What decides it** (reviewer's table, `reviews/2026-09-26-source-review-report.md` on the
review branch): same alt 1, same `27 → 9+9+9`, sustained stream, and commands keep completing
→ missing QCA setup is the cause, and the fix is the upstream entry (`dc16388d45ec`) as a
stable backport. Same fatal first-command timeout → setup alone is not enough; next is E2
(this build minus the Enhanced-setup quirk) before any wideband-off build.
