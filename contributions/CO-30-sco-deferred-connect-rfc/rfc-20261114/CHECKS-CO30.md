# CO-30 RFC: checks

## Guest tests
See `README.md` (table) and `results/`. Kernels: `p123` = `6ab80e175065` (CO-02 v2), `rfc` = v2 plus the
RFC (`a20d76037148`, same tree as the committed RFC; only the commit message was changed after the
build, `git rev-parse <old>^{tree}` equals `co30-rfc^{tree}`). Tester `sco-tester-v2r` (36 cases) and
`v2s` (close-then-connect); runner `scripts/run-matrix.sh`. Commands:

    scripts/run-matrix.sh co30 3 p123,rfc v2r sco-tester
    scripts/run-matrix.sh co30close2 3 p123,rfc v2s sco-tester -p "RESEARCH eSCO CVSD - Close Then"
    scripts/results-co30.sh

(`logs/run-co30close-*.log` are 6 runs of an empty test selection, the `-p` prefix did not match; no
guest result.)

## Bot checks (patched side, `scripts/bot-rfc.sh`, `scripts/bot-rfc2.sh`)

The four mails fed to `git am`: the three v2 patches and the RFC, each with a Signed-off-by of the
author added locally (the real mails carry none). Output `project/tmp/bot-rfc/`, `project/tmp/bot-rfc2/`.

| Check | Result |
|---|---|
| CheckPatch, VerifySignedoff, SubjectPrefix | PASS |
| GitLint | first run FAIL: the notes block had 81 and 82 column lines and 4-space blank lines; notes rewrapped, whitespace stripped; **second run PASS** |
| BuildKernel, CheckAllWarning, BuildKernel32, CheckKernelLLVM | PASS |
| CheckSparse | WARNING `./include/net/bluetooth/hci_core.h:151:35: warning: array of flexible structures`, "in included file" of `net/bluetooth/sco.c`. The line is in a header none of our patches touches, and sco.c is not touched by the v2 series, so the base side of this check does not build sco.c and gives no comparison; the RFC adds no sparse warning of its own (the report lists only this note). Not compared with a base run |
| VerifyFixes | not run (the RFC has no Fixes tag) |
| TestRunner suites of the bot | not run for the RFC (the guest runs above cover sco-tester only; l2cap/mgmt/iso were not run on the RFC kernel) |

## checkpatch --strict (run on the host after the copy, 2026-11-14)
`cache/checkpatch/checkpatch.pl --strict --no-tree` on the RFC: only "Missing Signed-off-by" (1
error, 0 warnings, 0 checks, 145 lines).

## Not checked
mgmt-tester, iso-tester, l2cap-tester on the RFC kernel; hardware.
