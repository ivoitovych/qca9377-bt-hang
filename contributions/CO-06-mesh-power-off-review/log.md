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

## 2026-10-28 — freshness walkthrough
- **His patch:** 14864878 still `new`, the bot's reply only, no newer version (his later patches
  14896431/14896432/14899266 are the adv-monitor and msft cancel paths).
- **The mesh queue is stalled as a whole.** Four other authors' mesh fixes are pending with no
  maintainer reply: Hui Peng 14831271 (09-19; our Tested-by of 10-06), this one (10-03), Cen
  Zhang 14880941 (10-12), Igor Putko 14888791 (10-14, CO-04). Meanwhile the maintainers applied
  only Pauli Virtanen's `87a49b610708` (`8a8d51eeedeb` in bluetooth-next) in this area. The
  maintainers have not engaged with any mesh fix since 10-05.
- **The comparison is old.** It ran on 10-05, before `87a49b610708` changed the mesh timeout units
  and the "Send cancel" behaviour. A reply needs it re-run on bluetooth-next `47d4d9f67e92` first.
- **Suggestion for the operator's decision:** one message on the mesh transmit path covering CO-04's
  lock inversion, this patch's unlocked completion and the stranded backlog, instead of separate
  replies on each thread. Missing: the re-run, the text, the decision.

## 2026-10-28, later — the combined message is withdrawn
The operator chose for CO-04 an independent fix of the mesh use-after-free, sent as its own patch
(CO-04's `log.md`). CO-04's finding is therefore not part of any reply here; a reply on this patch,
if the operator wants one, covers only this patch's own points (the unlocked completion, the
stranded backlog, the device-removal behaviour), after the re-run.
