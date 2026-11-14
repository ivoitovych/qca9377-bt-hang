# Evidence behind CHECKS.md

Copied unchanged on 2026-11-14 from the work area `/root/exp/agent-work/co44-send-20261113/`
(`logs/`, `scripts/`, `controls/`), so that what `../CHECKS.md` cites is in the repository and
not only on one disk. Left out: `controls/mgmt-tester-control`, a built test binary (it is
rebuilt from `controls/no-condition-complete.diff`). Paths inside the files still name that work
area, where the runs happened; the kernel and BlueZ trees stayed there.

Also left out: the five full tester logs (`logs/testers/{mgmt,l2cap}-full-{base,patched}.log`,
`controls/mgmt-full-patched-control.log`). They print hundreds of emulated controllers'
addresses, among them random advertising addresses that the publishing scan cannot tell from a
real device's. Their verdicts are in `logs/testers-analysis.txt` and `../CHECKS.md`; the logs
themselves stay in the work area. The new case's own logs (`mgmt-newcase-*.log`) and smp-tester's
are here.

Also left out: the two `controls/*-local-check-only.patch` copies. They carry a Signed-off-by in
the operator's name, made only to check what the bot and `git send-email` do once he signs, and a
signed patch he did not sign himself does not belong in the repository. They remain in the work
area; their checks are `controls/kernel-with-sob-checkpatch.txt`, `…-get_maintainer.txt` and
`../dry-run-20261114/dry-run-co44-kernel-*-sob.txt`.
