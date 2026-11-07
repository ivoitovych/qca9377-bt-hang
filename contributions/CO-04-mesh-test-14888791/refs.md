# CO-04 references

**Upstream:**
- Patchwork 14888791 (Igor Putko).
- Patchwork 14831271 (Hui Peng), with our Tested-by of 2026-10-06.
- 14864878 (Jiale Yao) and 14880941 (Cen Zhang): the other pending mesh patches.
- `python3 -I scripts/patchwork-state.py 14888791 14831271 14864878 14880941`

- syzbot: https://syzkaller.appspot.com/bug?extid=f20755f37da70df33a16 ("KASAN: slab-use-after-free
  Read in mesh_send_sync"); its report thread
  https://lore.kernel.org/all/6ac5b02e.fe639fcc.32b100.000f.GAE@google.com/T/
- Baul Lee, v2 1/3–3/3 (14736726–8, 2026-08-07, `new`); Cen Zhang 14661052 (2026-07-03, `new`);
  Hui Peng 14831256 v3 (2026-09-19, withdrawn by its author, still `new`); Lee Jones `71af682ba469`
  (accepted, patchwork 14818191).
- 2026-10-29 mboxes of the pending patches, as posted: the worker's `tmp/mesh/patchwork/*.mbox`
  (sha256 in its `tmp/mesh/results/SHA256SUMS`).

**Our record:**
- `experiments/comparison-2026-10-29.md`, `experiments/results-2026-10-29.md`, `patch/`.
- Our V3 1/5 `266dda8daee0` (2026-10-04, never sent), `cache/mesh-guest`.
- `docs/STATUS.md`: the Tested-by row and the mesh row.
- `docs/mesh-tester-ci/STATE-MACHINE.md`: the update block on the gates, the lock-order
  inversion and I12.
- `docs/mesh-tester-ci/research-review-2026-10-05.md`: the research gates and the four
  prerequisites.
- `retest/mesh-tx-leak/REPORT.md`: how Hui Peng's exact patch was tested (reproducer, configs,
  VM logs). The model for this test.

**Tools:** `scripts/bluez-tester-compare.sh`, and the mesh-tester QEMU setup described in
`docs/mesh-tester-ci/README.md` (its reading order comes first).
