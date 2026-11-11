# Work that needed this laptop's data or kernel setup (2026-11-11)

Everything here was done without touching the controller and without installing anything:
journal, sysfs and capture reads, builds, and runs in containers and QEMU guests. Packages,
built modules and kernel trees stay outside the repository, in
`/root/exp/agent-work/laptop-*-20261111/`. Each directory keeps its scripts and raw outputs;
`SHA256SUMS` where present.

| directory | what it holds | the main result |
|---|---|---|
| `bt16-and-trials/` | every boot's start-up classified (`A-*`), the source path (`B-mechanism.md`), power facts (`C-s5-power.md`), the trial records (`D-trial-records.md`), a hardware fact sheet without addresses (`E-hardware-facts.txt`) | BT-16: 1 of 11 E3 boots, 1 of 14 boots that load the QCA patch; the deciding value (status byte, `patch_version`) is in no record |
| `recordings-mining/` | per-link microphone and speaker signal tables, journal pattern counts, USB alternate-setting log | U15 and U20 answered; U8 answered; new patterns U30, U31 |
| `e3-kernel-hook/` | a kernel post-install hook, its tests in `ubuntu:24.04` containers with real kernel packages, install and rollback | not installed; `7.0.0-43` (noble-proposed) carries the entry, so the hook would retire itself there |
| `headset-session/` | one checklist (`SESSION-CHECKLIST.md`) and helpers for a supervised session with the headsets | about 2 hours, core 1 hour; nothing installed yet |
| `btusb-modules-and-emulator/` | CO-21 and CO-20 patches, procedure, bot CI output, and `scripts/usbip-bt-emu.py` | real btusb exercised in a guest through usbip |

## Checked again by hand before recording

- Trials: `journalctl -b -2 -u bt-trial-auto` shows the 90 s stop timeout at 17:31:58 on 11-09;
  `journalctl -b -1 -u bt-trial-auto` shows "controller does NOT respond" one second after the
  stop began on 11-10.
- `7.0.0-43`: Launchpad `getPublishedSources` lists it Published in Proposed since 2026-11-05;
  `e3-kernel-hook/logs/s6-present-43.log` line 84: `stock FOUND 13d3:3503 x1`.
- Emulator: `scripts/run-guest.sh base msbc-two-links-second 91` ends `RESULT … FAIL` (alt 0 while
  link 1 stays up); `co21s20` with the same scenario ends `RESULT … PASS`. Logs
  `guest-*-msbc-two-links-second-91.log`.
- MOMENTUM 4 microphone: `recordings-mining/results/sco_summary_all.txt`, read link by link. On
  links from 11-02 to 11-09 at most 1.7 % of microphone frames carry signal on links of 5 s or
  longer, and up to 7.2 % on links under 2 s (the worker's summary said 0 to 1 %; the table is the
  record). On 10-11 the same headset shows 99 to 100 %.

## Limits

- The emulator has no isochronous bandwidth limit. It proves which alternate setting btusb
  selects, not what happens to audio on real silicon, and it ran bluetooth-next, not Ubuntu's
  build.
- Whether the far end of a call hears silence from the MOMENTUM 4 is inferred: no test call was
  recorded.
- The hook's fallback was checked up to the generated GRUB configuration, not a real boot.
- The recordings have gaps: no raw capture for 10-31; USB traffic only from 11-04.

## Left out of this copy

The publishing scan refuses text shaped like an address, so these stay only in `/root/exp/agent-work/laptop-*-20261111/`: `lsinitramfs-42.txt`, `make-ci-mails.py`, the hook tests' `lib.sh` and four of its logs (`s2`, `s4`, `s5`, `s9`). `patterns_final.tsv` here omits the apport hook's own lines, so it differs from the hash in `SHA256SUMS`.
