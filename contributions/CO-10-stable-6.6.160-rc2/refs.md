# CO-10 references

**Our record:**
- `docs/STATUS.md`: the rows for the QCA9377 entry, BT-9 and BT-8.
- `patches/kernel/bt9-stable/README.md`: the mgmt-tester case and the QEMU reproducer.

**Tools:** `scripts/stable-rc-check.sh "<subject>" 6.6`

**Upstream:** the stable list thread "[PATCH 6.6 0000/1651] 6.6.160-rc2 review" (2026-10-20).
A local copy of the announcement is in `tmp/stable-6.6.160-rc2-cover-20261020.txt`, which
has the Message-ID, the reply list and the deadline.

**Trees and builds** (development host):
- `cache/stable-6.6.y`, a worktree of `cache/linux`.
- The images: `tmp/mesh-tester-ci/bzImage-co10-6.6.160-rc2` and `bzImage-co10-6.6.159`, with
  their configs.
- The logs: `tmp/co10-20261021/`, `tmp/co10-20261021-testers-rc2/` and
  `tmp/co10-20261021-testers-159/`, each with `SHA256SUMS`.
- BlueZ testers: `cache/bluez-bt9`.

**This dossier:** `REVIEW-REQUEST.md`, `experiments/results-2026-10-21.md`,
`experiments/build-and-test.sh`, `experiments/all-testers.sh`,
`drafts/reply-6.6.160-rc2.txt`.

**Tools:** `scripts/compare-tester-verdicts.py` (verdicts by test name, two logs).
