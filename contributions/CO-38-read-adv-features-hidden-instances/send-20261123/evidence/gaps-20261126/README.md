# CO-38: the suite gaps closed (2026-11-26)

The runs of 2026-11-23 (`../tips-20261123/`) left three gaps against the testing standard (the full suites before and
after, on every affected line). They were closed on 2026-11-26, and the bot's checks were run on the final files.

## What ran

- **A. The new bluetooth-next tip `f57f78086ab5`.** Two images, base and base + CO-38, built from BlueZ's
  `doc/tester.config` plus hung-task detection (`versions/bzImage-next2-*.versions`). On each:
  - the new case, "Read Advertising Features - Success 3 (Instance 2 only)", 3 times;
  - all 11 testers the CI lists, in full: bnep, iso, l2cap, mgmt, rfcomm, sco, ioctl, mesh, smp, userchan, 6lowpan.
- **B. 6lowpan-tester on the 7 image pairs of 11-23** (bluetooth-next `5063a0717aa2`, v7.4-rc4, 7.3.6, 6.18.65,
  6.12.119, 6.6.163, 6.1.193), the CI's eleventh tester, missing before.
- **C. The cases cut off by the hangs**, run one per guest on base and on base + CO-38:
  - the 20 l2cap-tester cases after "L2CAP Ext-Flowctl Server - Accept 2 Close 1", on 6.18, 6.12 and 6.6;
  - the 8 iso-tester cases after "ISO Broadcaster Receiver Defer Get BASE - Success", on 6.12.

  The lists are in `lists/`, from the complete bluetooth-next run of 11-23 (`scripts/cases-after.py`). A filter
  that matches several names ran them all (`l2cap-after01`: 3 cases).
- **D. The linux-bluetooth CI's own checks** (`scripts/bot-co38.sh`, `scripts/bot-base-rerun.sh`; summaries in `bot/`):
  - the kernel patch on bluetooth-next `f57f78086ab5`, patched and base side;
  - the BlueZ test on BlueZ master `79162c108911`, both sides.

  The first base-side try failed before any check (`bot/bot-co38-k-summary.txt`: "base: workspace FAILED"): the
  local partial clone it was cloned from lacked an object, which git may not fetch there. It was rerun from the
  patched side's full clone and passed. The bots' full logs are in the private archive.

Same BlueZ build as on 11-23 for A to C (`1608f8361` + the CO-38 test, so the comparison stays like for like); the
bot uses its own, BlueZ master.

## Results

- **`compare-gaps.txt`:** every base/patched pair, per case (`scripts/compare-gaps.sh`, using
  `scripts/compare-tester-verdicts.py` of the project).
  - The only verdict that changes anywhere is the new case. On `f57f78086ab5` it fails 3/3 on base and passes 3/3
    with the patch, and fails/passes in the full mgmt-tester run.
  - **6lowpan:** 9/9 on both sides, on all 8 trees.
  - **C:** every case has the same verdict on both sides. Some fail on the older stable lines, identically: the
    PHY and HDT cases, "Ethtool Get Ts Info", and two iso "Sync Lost" cases on 6.12 (one times out). The reading is
    that those kernels lack the features under test; this was not checked further.
- **`report-scan.txt`:** `scripts/kernel-report-scan.py` of the project over every guest log. Nothing found (exit 0).
- **The bot:** every check PASS, on both patches and both sides.
- **`progress.log`:** the run's timeline.
  - At 05:17 UTC stage C was stopped once and restarted. In its first form each guest read the rest of the case list
    from the loop's standard input, so only the first case of each list ran.
  - With `< /dev/null` added, every case ran. The logs of that first pass are kept and give the same results.

## Files

- `scripts/`: every script as run.
- `versions/`: per image, the tree, applied patch-ids, `.config` hash, compiler.
- `lists/`: the case lists of C.
- `SHA256SUMS-raw-logs`: the guest logs.
- `SHA256SUM-private-archive`: the raw logs and bot outputs, archived privately (zstd -19).
- `SHA256SUMS`: this directory.

`<work area>` stands for the machine-local work area of the runs.
