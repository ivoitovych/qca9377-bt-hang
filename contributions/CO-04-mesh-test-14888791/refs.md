# CO-04 references

**Upstream:**
- Patchwork 14888791 (Igor Putko).
- Patchwork 14831271 (Hui Peng), with our Tested-by of 2026-10-06.
- 14864878 (Jiale Yao) and 14880941 (Cen Zhang): the other pending mesh patches.
- `python3 -I scripts/patchwork-state.py 14888791 14831271 14864878 14880941`

**Our record:**
- `docs/STATUS.md`: the Tested-by row and the mesh row.
- `docs/mesh-tester-ci/STATE-MACHINE.md`: the update block on the gates, the lock-order
  inversion and I12.
- `docs/mesh-tester-ci/research-review-2026-10-05.md`: the research gates and the four
  prerequisites.
- `retest/mesh-tx-leak/REPORT.md`: how Hui Peng's exact patch was tested (reproducer, configs,
  VM logs). The model for this test.

**Tools:** `scripts/bluez-tester-compare.sh`, and the mesh-tester QEMU setup described in
`docs/mesh-tester-ci/README.md` (its reading order comes first).
