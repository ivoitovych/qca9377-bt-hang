# CO-12 clamp, rebased 2026-11-14: checks

Nothing was sent. [measured] = command output, logs in `logs/` (SHA256SUMS). Draft = `contributions/CO-12-m2-adv-duration-overflow/patch/draft-2026-11-01/`.

## Trees and upstream
bluetooth-next `da3cc02587c629420603df4395179ec82955c941` (unchanged since the morning), bluetooth master `3b069de8a5d688c7e8381b99d6cdb7467fcae0de`, BlueZ `20ffd285b58facfd1f2478d159a5f941b09d5be1`.
- Not fixed upstream: the tip still has `u16 duration = adv->mesh ? adv->timeout : adv->timeout * MSEC_PER_SEC;` at `hci_sync.c:1747` [measured: grep]. patchwork since 2026-10-28, subjects with duration/timeout/clamp (`patchwork-recent.py`): nothing on advertising duration. Pauli Virtanen's mesh fix `8a8d51eeedeb` is the only related one.
- Cen Zhang's 14927631 (still `new`) keeps `u16 duration` in its rewrite of the same function and no longer applies to the tip: see `DESIGN.md` section 5.

## Rebase
- The draft's code applies to bluetooth-next and to bluetooth/master with `git apply --check` [measured]. Regenerated: `patch/0001-Bluetooth-hci_sync-Fix-extended-advertising-duration.patch` (`format-patch --base=da3cc025...`), real author, no Signed-off-by, commit message and the three-options note below `---` as in the 11-01 revision (`on-bluetooth-next`). Code identical to the draft.
- checkpatch `--strict` (`checkpatch.log`): only `Missing Signed-off-by`; `14 lines checked` [measured]. Fixes tag resolves.

## QEMU (KASAN + lockdep, 4 CPUs, 2 GB; images: plain = tip, clamp = tip + patch, fix = tip + CO-38 fix, clampfix = tip + patch + CO-38 fix; same config as the CO-38 images), 3 runs each, `summary.txt`
| set | plain | fix | clamp | clampfix |
|---|---|---|---|---|
| AdvDur (22 research cases of the 11-01 draft, `mgmt-tester-advdur`) | 10, 9, 9 of 22 pass | not run | **20 of 22** in all 3 runs | not run |
| CO-38 series `mgmt-tester -p Add` (128 cases, 8 duration cases of 1/3) | 119 | 120 | 127 | **128** |
| master mgmt-tester `-s Advertising` (125 cases) | 124 | not run | 124 | not run |

- AdvDur: the 11-01 figure 9/22 to 20/22 reproduces. The 10 or 11 cases that change are Duration 66, 120, 655, 656, 1000, 3600, 6357, 8192, 65535 s and Removal 66 s (and, in runs 2 and 3, one more timing case on the plain image). The two that fail with the clamp in every run are `AdvDur - Duration 1 s` and `AdvDur - Removal 1 s`: the log shows the right behaviour (`enable handle 1 Duration 100 (1000 ms)`, `Advertising Removed after 1018 ms`), the research test's own check fails, probably because it expects the instance to be still listed after 1 s [inferred]. They fail on the plain image too.
- Add: with the clamp alone 127/128: the one failure is "Add Ext Advertising - Instance 2 listed alone" (CO-38). With CO-38's fix and the clamp together 128/128 in all 3 runs. The 8 "Timeout ... " duration cases go Failed to Passed with the clamp, as on 11-01 [measured: compare-tester-verdicts.py].
- Advertising set: identical verdicts on plain and clamp in all 3 runs (the same single failing case) [measured].
- kernel-report-scan over all 24 guest logs: clean (rc 0) [measured].
- Load: the host's load average was 16 to 20 during these runs; no timing-sensitive case differed between kernels except the AdvDur plain count 10 vs 9.

## Not done
- No bot run for CO-12 (the 11-01 work did the stable forms; the kernel bot would repeat the CO-04/05 pattern and was not asked).
- The stable 7.3.y to 5.10.y forms and the on-series form (`co12-rework-20261101/patches/`) were not re-made; the stable forms apply to the same function and were verified on 11-01.
