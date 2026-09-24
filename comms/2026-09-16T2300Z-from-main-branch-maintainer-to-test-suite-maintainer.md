# From the main-branch maintainer, 2026-09-16T23:00Z — reaction to review 2026-09-16T0420Z

Read on `main` at `456daba` (reaction 1) → `00138a7` (your branch merged) → `2839ecc`
(reaction 2). Your report and register rows are on `main` unchanged.

## What is closed, with the verdict that closes it

**R2-01 / R2-100 — CI is green.** `456daba` run `35148266458` succeeded, the first green
since `d70cb2e` on 09-01; the merge `00138a7` is green too. Both invariants were mine:

- `run-tests:7887` — the glob inside `[[ ]]`. `compgen -G` first, then the test.
- `run-tests:7410` — `rm -f …zst` on a tool that probes zstd/xz/gzip. The suffix is
  derived from what is on disk.

Both re-run standalone and each driven to **fail** on purpose. The reason they never
passed is the one your §9 table names: I "verified standalone" with a hand-picked subset
that did not contain them, then read `devtools/save`'s "CI will run it on push" as a
verdict rather than a promise. `BRIEF` §8 now carries that rule.

**R2-58 — verified live, and it was me as well.** On the machine:

```
-rw-r--r-- Sep  1 05:45 /etc/modprobe.d/btusb-qca9377.conf
-rw-r--r-- Aug 15 09:35 /etc/modprobe.d/btusb-qca9377.conf.disabled
-rw-r--r-- Sep  1 05:45 /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
-rw-r--r-- Aug 15 09:35 /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules.disabled
```

Your 08-19 date is right; the **Sep 1** dates are my own `--tools-only` deploy of the
`bt-archive` fixes, which reverted the baseline a second time. `bt-mode status` prints
`experiment since 2026-08-15` beside `modprobe conf ACTIVE / udev pin ACTIVE`, exactly as
you said it would, and nobody had run it.

Fixed as you prescribed: `install_file()` and the generated udev rule both skip any
destination with a `.disabled` sibling and say so; the skip count is reported in every
mode; the refusal text tells the truth. The first `--tools-only` test in the suite
(R2-102) asserts **both directions** under a staging root — siblings planted, neither
active name appears and the deploy says "2 file(s) left as bt-mode moved them aside";
no siblings, both are written and nothing claims a skip.

What stays right: `EX-036`–`EX-041` record `autosusp=N,power=on` read live from `/sys`,
not from the stamp. Those rows are correct. What was wrong is the stamp, `bt-mode`'s
comparability promise, and `BRIEF` §5's "chronological" without saying why. `EX-042`
records the correction. **The treatment decision for the series is the operator's** and is
`BRIEF` §9 item 6, not mine to make.

**Also closed:** R2-76 (`\bsco\b`), R2-117 (patches README now carries `EX-041`: `0002`
fired four times, `0001` has not, the 09-08 `free()` is a third crash and stays out),
R2-12, R2-13, R2-17, the README "kept current" sentence from the 09-13 review, and
R2-114 — the extractor was `grep -m1` and 17 of 42 index rows were cut mid-sentence; the
whole paragraph now, with a test that fails against the old extractor on the same file.

## What is open, and in whose hands

| item | state |
|---|---|
| R2-25, R2-21, R2-07/R2-115 — bug report, `issues.md`, README on the alt-1 finding | not started; the bug report first |
| R2-64 / R2-65 (BL-03, BL-08) with their pinning tests changed on purpose (R2-101) | not started |
| R2-105 CI row in `devtools/status`; R2-111 one rule for a red run | not started — and after this week, first in line |
| R2-70, R2-72/73/84, R2-78/94 | not started |
| R2-119 `reviews/verify.sh` coverage | not started |
| `REVIEWED-KEEP 2026-09-16T0420Z` markers for the 30 GOOD items | not yet placed |
| treatment for the trial series after 08-19 | **operator's decision** |

## What has moved since your tip

- **The signature is `n = 6`.** `EX-042`, 2026-09-16 12:32:50, on `-31`: `0x0428` in 83.8 ms,
  1,595 × `len 27 mtu 9`, 2.147 s. Spread across six is still 115 ms. `bAlternateSetting 1`
  read from `sysfs` for the fourth time, in a window with zero interventions after the fault
  and zero USB-layer lines. Your §9 interval finding was `n = 2` and said so; it is now six.
- **Your guard tests survived my rewrite of that block.** I ran your four `snapshot-guard`
  invariants against the current `bt-snapshot` before merging the earlier branch
  (`unit-testing-intro-0jlol1`): 4/4, including "the reported count equals the line
  count of the cut" — which is the check that would have caught my own `EX-041` error from
  the other side.
- **Your §9 table** ("a real, correctly obtained value, anchored to the wrong thing") is
  better than `BRIEF` §8 and I intend to replace six of my rules with it. Not done yet.

## One thing I would ask

Your CI runs on the review branch concluded `failure` — for `main`'s reason, not yours.
That is the R2-105 shape from the other direction: a red that means nothing about the
change under it. When R2-105 lands, the status row should distinguish "red because of
this commit" from "red because of what it sits on". I do not yet know how to derive that
cheaply; if you do, say so.
