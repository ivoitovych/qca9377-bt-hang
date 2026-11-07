# CO-05 — the send package (for an outside review round; nothing sent)

Regenerated 2026-10-29 on bluetooth-next **`1081a6ef8f1e0`** ("Bluetooth: btintel: check FIPS
status before firmware download", the tree's `master` that day), `git format-patch --cover-letter
--base`:

- [`0000-cover-letter.patch`](0000-cover-letter.patch) — `[PATCH 0/2] Bluetooth: MGMT:
  mesh_send_sync() and the advertising list`, with the notes and the test-report paragraph.
- [`0001-Bluetooth-MGMT-Take-hdev-lock-in-mesh_send_sync.patch`](0001-Bluetooth-MGMT-Take-hdev-lock-in-mesh_send_sync.patch)
  — `Fixes: b338d91703fa`. Changed since 2026-10-21: the testing paragraph moved to the cover letter
  (the numbers are the series', not one commit's); code unchanged.
- [`0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch`](0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch)
  — now with `Fixes: b338d91703fa` (reviewers 2 and 5); its trace re-taken on `1081a6ef8f1e0`; code
  unchanged.

The 2026-10-21 version and its review page are kept in [`2026-10-21/`](2026-10-21/README.md) (its
relative links to `../experiments/` now need one more `../`).

**Same code as tested:** `git patch-id --stable` of each final commit equals that of the commit
the images were built from (`e4b39f497093…` for 1/2, `c03eac506a29…` for 2/2;
`tmp/mesh/mk-final.sh`, worker's progress file).

## Recipients (`scripts/get-maintainers.sh` on 0001, and the preflight's run on each commit)

- To: Marcel Holtmann `<marcel@holtmann.org>`, Luiz Augusto von Dentz `<luiz.dentz@gmail.com>`
  (maintainers, BLUETOOTH SUBSYSTEM).
- Cc: `linux-bluetooth@vger.kernel.org`, `linux-kernel@vger.kernel.org`.
- `get_maintainer.pl` also names Brian Gix `<brian.gix@intel.com>` (`blamed_fixes`, author of
  `b338d91703fa`) for 1/2; whether that address still reaches him was not checked. The operator
  decides whether to Cc him.
- No `Cc: stable` tag: no damage was ever shown (I12 is a lock contract and KCSAN races); the
  `Fixes:` tags let stable pick it if the maintainers want.

## Checks (`../experiments/results-2026-10-29.md` has every command and output)

- `kernel-preflight` on each commit: checkpatch `--strict` 0/0/0, `W=1 -Werror` clean, sparse on
  `mgmt.c` base 0 patched 0.
- Pre-send: not in bluetooth-next or bluetooth `master`; applies with `git am`.
- The list bot's own checks (patched side): all PASS but VerifyFixes, which failed only because the
  local harness cloned history from 2023-01-01 and `b338d91703fa` is of 2022-09-01; re-run with
  older history: see the results file.

## Questions for the reviewers

1. Is the cover letter's test paragraph the right size, and is citing the withdrawn patch by link
   right?
2. Should Brian Gix be Cc'd (blamed_fixes) given the address is unverified?
3. Send together with CO-04's use-after-free fix (two threads the same day) or after it?
