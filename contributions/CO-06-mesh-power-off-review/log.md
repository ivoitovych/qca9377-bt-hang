# CO-06 log

Append-only. Newest last.

## 2026-10-03 — his patch posted
Patchwork 14864878. The CI bot failed mesh-tester "Send cancel – 1/2" (timed out).

## 2026-10-05 — compared with ours in QEMU
Same base, same cases. The result: an unlocked fallback, a stranded backlog, and unlocked
completions at removal. The results are in `power-off-compare-2026-10-05.md` (private branch
`diag/mesh-tester-ci`), held until the reply is decided.

## 2026-10-13 — outside review
It recommends a review reply with no Tested-by, framed as one shared problem, and reporting
the device-removal behaviour. Not sent.

## 2026-10-18 — no newer version
14864878 is still `new`. His later patches 14896431 and 14896432 touch other paths.

## 2026-10-21 — dossier opened
The comparison is kept privately: commit `e69d5dd` on the private branch
`diag/mesh-tester-ci`, which is pushed. It is published or kept as the operator decides once
the reply is decided.
