# E's stress test and the bt23 rerun (2026-11-13)

What ran, the verdicts and the tables are in `../package/E/CHECKS.md` ("Stress test"); A's run is in
`../package/A/CHECKS.md`. This directory holds the evidence:

- `harness/bt17-emu.py`: the emulator directory's hardened harness
  (`bt17-emu-20261113/harness/bt17-emu.py`, kept here unchanged as `bt17-emu.orig.py`) plus:
  - the `stress` scenario;
  - per-packet arrival records;
  - a `/dev/kmsg` reader;
  - re-attach after a usbip detach;
  - the re-queue of event bytes from an interrupt URB that the host unlinked after the emulator
    had completed it.

  `bt17-emu.diff` is the whole change. The other scenarios are unchanged, apart from that re-queue.
- `harness/run-guest.sh`: the emulator's runner with this directory's paths and a configurable guest
  timeout (`run-guest.diff`). `run-stress-batch.sh` and `run-bt23-and-controls.sh` are the batches.
- `logs/`: every guest log of this task (42), and the batch summaries `matrix-*.txt`. The final
  runs are `*-s2-*`, `*-ctl-*`, `*-bt23-*` and `ea-a-a-bt17-2`; the others are listed with their
  outcome in the CHECKS files.
- `kernel-report-scan.txt`: the project's `kernel-report-scan.py` over all 42 logs: every one
  booted the intended kernel and is clean.
- `kernels/`: what each guest kernel was built from (`*.commit`), the config fragment and the
  build scripts. The images are in `../img/`.
- `SHA256SUMS`: every file here and the five images.
