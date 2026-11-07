# CO-05 references

**Our record:**
- `docs/mesh-tester-ci/STATE-MACHINE.md`: the update block, I12 in the invariant table, and
  line 673 ("nobody has written it").
- `docs/mesh-tester-ci/research-review-2026-10-05.md`: the gates, and the rule against folding
  the non-mesh callers into the mesh series.
- `docs/mesh-tester-ci/gates-2026-10-05.md`: the gate results (ported to `main` in `9588c99`).

**Reviews:**
- `reviews/2026-10-20T2332Z-source-investigation-task.md`, item 4.
- `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI5.

**Upstream commits:**
- `d2609b345ebf`: the locking requirement.
- `b338d91703fa`: the mesh path.
- `eca0ae4aea66` and `c249ea9b4309`: the other callers.

**Tools:** `scripts/kernel-preflight.sh`, `scripts/build-bluetooth-fulltree.sh`, and the
mesh-tester QEMU setup (`docs/mesh-tester-ci/README.md`). KCSAN only on the 4-CPU wrapper.
