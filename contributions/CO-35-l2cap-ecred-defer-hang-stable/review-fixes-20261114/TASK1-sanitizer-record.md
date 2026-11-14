# CO-35 sanitizer record: were lockdep and KASAN in the built kernels? (2026-11-14)

**Answer: yes. The built kernels had CONFIG_PROVE_LOCKING, CONFIG_LOCKDEP and CONFIG_KASAN. The covers are right; the 11-02 note (`send-20261102/results.md:157`) and the 11-14 `CHECKS.md` (section 3, last paragraph) are wrong on this point.**

## Evidence (three independent items)

1. **The config, recreated as `build.sh` makes it** (measured; `scripts/recreate-config.sh`, logs `logs/config-v6.6.162.txt`, `logs/config-v7.3.4.txt`, full results `logs/dotconfig-<tag>.txt`).
   Exported the source of the tag from lane 5's kernel repository (`git archive`, read only), copied `doc/tester.config` (`cache/co02-w2c-bluez/doc/tester.config`, sha256 `814e84767ff48b81...`) to `.config`, appended `hungtask.config` (`b813f88225e988dc...`), ran `make ARCH=x86 olddefconfig`, as `co35/build.sh` does. Result for both v6.6.162 and v7.3.4:

   ```
   CONFIG_KASAN=y
   CONFIG_KASAN_GENERIC=y
   CONFIG_DETECT_HUNG_TASK=y
   CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=20
   CONFIG_PROVE_LOCKING=y
   CONFIG_DEBUG_MUTEXES=y
   CONFIG_DEBUG_LOCK_ALLOC=y
   CONFIG_LOCKDEP=y
   CONFIG_DEBUG_ATOMIC_SLEEP=y
   CONFIG_PROVE_RCU=y
   ```
   and no `# CONFIG_KASAN is not set` / `# CONFIG_PROVE_LOCKING is not set` / `# CONFIG_LOCKDEP is not set` line. The export trees were deleted afterwards.
2. **The compile logs of the real builds** (lane 5's `co35/logs/build-<tag>-<variant>.log`, the first full build of each tag): `CC kernel/locking/lockdep.o`, `CC kernel/locking/lockdep_proc.o` and `CC mm/kasan/common.o`, `report.o`, `init.o`, `generic.o`, `report_generic.o`, `shadow.o` appear in `build-v6.6.162-pair.log`, `build-v6.12.117-pair.log`, `build-v6.18.63-pair.log` (`mm/kasan/common.o` and `kernel/locking/lockdep.o` found; `grep -a -c`) and `build-v7.3.4-base.log`. (The later builds of each tag are incremental, so they do not recompile those objects.) Commands: `grep -a -m8 -i "kasan\|lockdep" <log>`.
3. **The scan of the patched runs.** `summary-<tag>-pair.txt` ends in `kernel=<ver>-dirty  clean`; `scripts/kernel-report-scan.py` counts lockdep, KASAN and hung-task reports (13 report kinds); the patched runs are clean and the base runs show `hung-task=7`. So the statement "no lockdep or KASAN report" is a statement about kernels that could have produced one.

Not found: a boot-log line ("KernelAddressSanitizer initialized", "Lock dependency validator") in the saved logs; the test-runner console logs in `co35/logs/case-*.log` keep the `Linux version` line but not the early boot messages. Evidence 1 and 2 stand without it.

## Which record is wrong

- `send-20261102/results.md:157` says: "The tester config enables hung-task detection only; no separate lockdep/KASAN-enabled build was made today (the "no lockdep or KASAN report" statement rests on the scan of the patched runs, whose config is tester.config)". The first clause is wrong: the tester config is what enables lockdep and KASAN; hung-task detection is what `build.sh` adds on top. (The rest of the sentence, that the statement rests on the scan of the patched runs with tester.config, is right.)
- `send-20261114/CHECKS.md` section 3, last sentence of the second-to-last paragraph: "the tester config has hung-task detection only (no separate lockdep/KASAN build) - as before": same error, copied from the 11-02 line.
- The covers (6.18.y, 6.12.y, 6.6.y; "No lockdep or KASAN report with the series.") and the 7.3.y request: correct as written. They may be made more exact (below) but need not change.

## Corrected sentences

For `results.md:157` and `CHECKS.md`:

> The kernels were built from BlueZ's `doc/tester.config`, which sets `CONFIG_PROVE_LOCKING`, `CONFIG_LOCKDEP` and `CONFIG_KASAN`, plus `CONFIG_DETECT_HUNG_TASK` (20 s) added by `build.sh` (recreated with `make olddefconfig` for v6.6.162 and v7.3.4 on 2026-11-14: all three are `=y`); the kernel logs of the patched runs were scanned for lockdep, KASAN and hung-task reports and none was found.

For the covers (optional, more exact; the current sentence stays true):

> Tested on v6.6.162 in QEMU/KVM (4 vCPUs) with BlueZ's doc/tester.config (lockdep and KASAN enabled) and the hung-task detector: ... No lockdep, KASAN or hung-task report with the series.
