# Research and review task — Bluetooth Mesh in the Linux kernel and BlueZ, and our patch series

**Private. Do not post, mail, comment, open issues or contact anyone about it.** Nothing here has
been sent upstream. The author of the patches, and the only attribution in this repository, is
Iaroslav Voitovych.

## Why this task exists

A small fix grew into a five-patch kernel series and a four-patch BlueZ series that touch the
scheduling, teardown and accounting of Bluetooth Mesh transmissions in the kernel's
management interface. Two outside reviews have already improved it a great deal. Before
anyone sends it to the Bluetooth maintainers, the author needs to understand the **whole
story** of this code: why it exists, how it was meant to work, what its designers and
maintainers said about it, how it came to its present state, who uses it, where it is going,
and whether the series fits that picture or works against it.

Two decisions are **deliberately not taken** (§"Decisions left open"). The author does not want
to take them on our analysis alone. This task gives you everything we have, and asks you to go
far beyond it.

**This is an open-ended research task, not a checklist.** The questions below are where we
would start. Follow the evidence wherever it leads, add questions we did not think of, and
tell us what we got wrong, including about the framing of this task. If the most important
finding is something none of the questions asks about, that is the most valuable thing you
can give us.

## What you can read

The project's private repository, branch `diag/mesh-tester-ci` at commit **`1806e72`** (or
later). Everything below is under that branch (on `main` since 2026-10-09, same paths).

| path | what it is |
|---|---|
| `docs/mesh-tester-ci/TASK.md` | where it began: the list's CI bot fails `tools/mesh-tester` on every kernel patch since 2026-06-01 |
| `docs/mesh-tester-ci/phase1-findings.md` | read-only diagnosis: the kernel leaves the mesh packet on air |
| `docs/mesh-tester-ci/phase2-results.md` | first reproduction in qemu and a one-patch fix |
| `docs/mesh-tester-ci/PHASE3-TASK.md`, `phase3-results.md` | extended advertising handled; a two-patch series |
| `docs/mesh-tester-ci/REVIEW-TASK-SERIES.md`, `review-series-2026-10-02.md` | first outside review; it found a scheduler race |
| `docs/mesh-tester-ci/PHASE4-TASK.md`, `phase4-results.md` | the race reproduced and fixed; three patches |
| `docs/mesh-tester-ci/REVIEW-TASK-SERIES-V2.md`, `review-series-v2-2026-10-03.md` | second outside review; five findings |
| `docs/mesh-tester-ci/PHASE5-TASK.md`, `phase5-results.md` | **the current state**: every finding answered, every gate, the measurements behind the open decisions (§B), the Summary and Open lists at the end |
| `patches/mesh-tester/series-v3/` | the series as it would be sent: kernel `0000`–`0005`, BlueZ `bluez/0000`–`0004`, and `alternative/` (Option 1 below) |
| `docs/mesh-tester-ci/duration-overflow-note-v3.md` | a separate defect: `u16 duration` overflow for advertising timeouts above 65 s |
| `docs/mesh-tester-ci/tools-phase5/` | every script that produced a result |
| `docs/mesh-tester-ci/logs-phase5-SHA256SUMS` | checksums of all 253 raw logs; the logs themselves (45 MB) come as a separate archive from the operator, verifiable against this list |

Every claim in our files is marked **quoted** (command and output shown), **inferred** or **not
found**. Treat our inferences as hypotheses to test.

## The story as we know it

This is our current understanding. It is incomplete, and some of it may be wrong.

- **The kernel's mesh interface** came with `b338d91703fa` ("Bluetooth: Implement support for
  Mesh", 2022): Mesh Send / Mesh Send Cancel / Read Mesh Features management commands, an
  experimental feature flag, a pending queue (`hdev->mesh_pending`), a dedicated advertising
  instance numbered `le_num_of_adv_sets + 1`, and a host timer of `cnt × 25 ms` that ends each
  transmission. Its only known client is BlueZ's `bluetooth-meshd` through
  `mesh/mesh-io-mgmt.c`, which always sends Count 1 and does its own retransmissions.
- **`f3cb5676e5c1`** (2025, "mesh_send: check instances prior disabling advertising") made the
  advertising disable at the end of a transmission conditional on `list_empty(&hdev->adv_instances)`,
  to protect other advertisers. The mesh instance itself is on that list, so the disable never
  runs. The CI reply to that patch already showed the two mesh cancel test cases timing out.
- **The CI bot** has failed `TestRunner_mesh-tester` on every kernel patch since 2026-06-01;
  18 of 20 passed between 04-28 and 05-14. Nobody fixed it in four months.
- **Other 2026 work on this path:** `71af682ba469` (dequeue pending starts on cancel, now in five
  stable lines), `3c742feda8fc` (free the cancel command), a posted and still unmerged cleanup
  of `mesh_send()`'s inverted error path by another author (2026-09-19, lkml), and two August
  locking and lifetime proposals by others (see the v2 review, item C).
- **Our series v3**, base `bluetooth/master` `08e90633377f`: 1/5 keeps the scheduler's
  `HCI_MESH_SENDING` flag set through teardown and hands over under `hdev->lock`; 2/5 tears the
  mesh instance down through `hci_remove_advertising_sync()` and hides it from Advertising
  Removed; 3/5 completes the request that owned the instance, not the queue head; 4/5 keeps the
  done work running after a power-off, so the flag cannot stay set for good; 5/5 is a
  comment-only patch documenting the Count limitation. The BlueZ series adds emulator hooks, a
  leak fix in `src/shared/mgmt.c`, fault injection in the tester kernel config, and 30 new
  `mesh-tester` cases.
- **Results** (all in qemu, emulator only, no radio): mesh-tester 55/55 with the series and the
  other author's cleanup applied locally, 18/55 unpatched; KASAN, lockdep and KCSAN report
  nothing from Bluetooth code; checkpatch, W=1 and sparse are clean on all five commits.

## Research — please go as wide and as deep as the evidence goes

These are starting points, not limits.

**1. Origins and intent.** How did Bluetooth Mesh come to Linux, from the first `meshd` in BlueZ
to the kernel management interface of 2022? Who designed it, in which list threads,
presentations, design documents or commit discussions, and what did they say the kernel side
was *for*? Why a management-interface mesh bearer at all, instead of raw HCI as the older
`mesh-io-generic` uses? What were the alternatives and why were they rejected? What did the
designers intend Count, the 25 ms step and the single transmit slot to mean?

**2. The specification.** What does the Bluetooth Mesh Protocol specification (1.0, 1.1 and any
later drafts) require of an advertising bearer: transmit count, transmit interval steps,
randomised delays, Network Transmit and Relay Retransmit states, and how these map onto
advertising events? Does the kernel's Count mean the same thing? Which layer is supposed to own
retransmission? How do other stacks (Zephyr, NimBLE, ESP-IDF, Android, vendor stacks) implement
the bearer, and which of their design choices bear on ours?

**3. How it came to its present state.** Reconstruct the history of `net/bluetooth/mgmt.c`'s mesh
code and its interaction with the advertising code in `hci_sync.c` and `hci_core.c`, from
`b338d91703fa` to today. That covers every commit, every thread, every review comment, every
bug report or CI signal, and every abandoned patch. Why did `f3cb5676e5c1` take the shape it
did, and did anyone notice the mesh instance at the time? Why did the CI failure stay red for
four months? Is mesh support treated as maintained, experimental or abandoned? Look for
statements that say so, not only for inferences from activity.

**4. Who uses it, and how.** `bluetooth-meshd` is the client we know. Are there others, such as
distributions, products, Home Assistant, Zephyr host tooling or research code? Could anyone
depend on today's behaviour, where the packet stays on air for seconds whatever Count says?
What does "don't break userspace" demand here, and what have maintainers said when similar
semantics were corrected elsewhere?

**5. Where it is going.** Current and planned work on mesh in BlueZ and the kernel, from the
maintainers or others: ISO and LE Audio pressure on the advertising code, the advertising-set
refactors, the locking and lifetime work, and any talk of deprecation. Who is active in this
area right now, and what would they expect a contribution here to look like?

**6. Anything else** you find that matters to how this code should be changed, or whether it
should be changed by us at all.

## Review — after the research, read our work against it

- Does the series agree with the architecture and the intent you found, or work around them?
  Is anything in it a local fix for a design problem that should be addressed differently?
- Each patch: is it correct, necessary and the right size? Is the split right? Is 4/5 within
  scope, and is 5/5 worth sending?
- The dependency on another author's unmerged cleanup: how should a series like this be
  presented, ordered, or coordinated?
- The tests: do they test what matters? What would the maintainers want to see that we did not
  run, including real controllers and radio measurements?
- The messages and the cover letter: claims that overreach, missing context, tone.
- Everything listed under "Open" at the end of `phase5-results.md`: which of those should be
  fixed before sending, after, or never?

## Decisions left open

The author has not taken these. Please give all the information needed to take them well. That
means facts, history, precedent and consequences on both sides. A recommendation is welcome but
not required.

**Decision 1 — Count versus the done deadline** (`phase5-results.md` §B). The protocol document
says Count is "the number of times this packet will be sent". The kernel ends a transmission
after `cnt × 25 ms`, while the advertising interval defaults to 1280 ms. Once the series makes
teardown effective, Count 3 at the default interval airs one event. Before the series, the
packet stayed on air for seconds, whatever Count said.

- *Option 1:* size the deadline for `cnt` events at the configured interval
  (`series-v3/alternative/`). Count 3 then airs three events. A Count-3 send then holds the single
  slot about 2.6 s instead of 75 ms, and six existing upstream mesh-tester cases time out until the
  tester changes.
- *Option 2:* keep the deadline and document the limitation (patch 5/5, comment only). The
  mismatch then stays for a separate change.
- *Other options we have not seen*, for example letting the controller count events with Max
  Extended Advertising Events, changing the protocol text, or something else entirely.

**Decision 2 — patch 4/5.** It fixes a pre-existing defect our new power-off tests found: a
power-off during a transmission leaves `HCI_MESH_SENDING` set, and no later mesh send ever
starts. It sits outside the original scope. Should it go with the series, separately, or be held?

## What we ask you not to do

- Post, mail, comment, open issues, or contact maintainers or authors.
- Run anything on real Bluetooth hardware. Running the testers in qemu is welcome, and the
  scripts are in `tools-phase5/`.
- Treat our documents as authoritative. Primary sources — code at a named commit, list archives,
  specifications, recorded talks — are the arbiter.

## Form of the answer

One document, any length the material needs. We suggest:

1. **A narrative history**, from the beginning to today, with every source cited (URL, commit,
   Message-ID, specification section, talk and timestamp).
2. **The architecture and its principles**, as their authors intended them and as the code has
   them today, with the gaps between the two.
3. **What you found that we did not know**, and what it changes.
4. **The review** of the series against that picture, by patch and as a whole.
5. **The two decisions**, with the material for each, and your view if you have one.
6. **Open questions** you could not settle, and where the answers probably are.

Mark each statement **quoted** (with its source), **inferred**, or **not found**. "I don't know"
and "you are asking the wrong question" are both useful answers.
