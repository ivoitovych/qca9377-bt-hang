# CO-35 refreshed on the stable tips of 2026-11-14 (nothing sent)

Copied from `/root/exp/agent-work/lane5-status-stable-20261114/co35/` (kernel images and the
upstream reference patches stayed there). `CHECKS.md` has every command and result.

- **Mails for the send:** `mail/request-v4-20261114.eml` (7.3.y takes `608e0b7a675b` and
  `32d86e048d8e`), `mail/request-sci-7.3.y-20261114.eml` (7.3.y takes `5874f8d03268`), and the
  6.18.y, 6.12.y and 6.6.y series (`mail/<line>/`; the two patches byte-identical to
  `../send-20261102/`, the covers with today's release numbers). The 11-02 files are kept.
- **Tested today** (QEMU, 4 CPUs, BlueZ `tester.config` + the hung-task detector): "L2CAP
  Ext-Flowctl Server - Accept 2 Close 1" hangs on unpatched v7.3.4, v6.18.63, v6.12.117,
  v6.6.162 (7 hung-task reports each) and passes with the pair; full l2cap-tester with the pair as
  on 11-02 (7.3.4: 111/111 with the SCI fix, a stall in "SCI Fast Mode" without it).
- **State upstream (2026-11-14):** the pair is in v7.4-rc1 and in no stable queue or release;
  7.3.4 still lacks `5874f8d03268`.

**Changed on copy:** the five whole-tester logs (`logs/full-*.log`) stay in the work area: they
print the emulated controllers' addresses, which the publishing scan cannot tell from real ones;
their counts are in `logs/summary-full-*.txt`. `apply-check.sh` and `apply-old.sh` set a
throwaway committer `check@example.com` for the cherry-picks, where the run used
`@example.invalid` (the scan admits only the documentation domains).

**Checked on copy:** `logs/summary-v6.6.162-base.txt` (HANG, hung-task=7) against
`summary-v6.6.162-pair.txt` (passed, 1.113 s, clean), the same for v7.3.4, and `cmp` of the 6.6.y
patch 2 with the 11-02 copy (identical).
