# Review of the foundation documents (2026-11-23)

**Tree read:** `main` at `7bb47fc6` (2026-11-23 04:47 +0100, "records: the kernel items
overtaken upstream, and what is left to send").

**What this is.** A reading of the foundation documents by the reviewer of the whole-project
review of 2026-11-15 and of the upstream check of 2026-11-22, against what those two pieces of
work established. It is bounded by what one reading can hold, so it says exactly what was
read and what was not.

**Budget, set before reading.** The six foundation documents are about 1,014 kB
(`README.md` 32, `BRIEF.md` 86, `docs/STATUS.md` 186, `docs/issues.md` 243,
`contributions/README.md` 49, `HISTORY.md` 418). About 200 kB can be read in full with room
left to write findings. Order chosen, most-read documents first:
1. `README.md`, in full (32 kB);
2. `BRIEF.md`, in full (86 kB);
3. `contributions/README.md`: the "What to send" table and the index rows, long cells cut;
4. `docs/STATUS.md`: the head and the submission and issue rows, long cells cut, as far as
   the budget allows.
Not read in this review: `docs/issues.md`, `HISTORY.md`, and whatever of item 4 the budget
does not reach. The last section says where the reading stopped.

**What is checked.** Each document against itself, against the others already read, and
against facts established on 2026-11-22 from upstream (bluetooth-next `cf357cfc02`, the stable
lines and their queue, BlueZ 5.88 and master, Launchpad, PipeWire master).

Findings are appended as each part is read. Ids: `FD-nn`.

## Findings

### `README.md`, lines 1–125 (read in full)

- **FD-01 (Low, count).** `README.md:24-25`: "tools that tell a controller timeout, a
  `bluetoothd` crash and an audio-layer problem apart — four things that look identical to a
  user". Three are named. The fourth (a synchronous link that came up and worked) is named
  only further down, in "Is this your problem?".
- **FD-02 (Medium, stale against upstream of 2026-11-22).** `README.md:63`, the Tested-by on
  Hui Peng's mesh_tx leak patch: state "the patch is pending". The patch (patchwork 14831271)
  is still `new`, but the leak it fixes is now fixed by the Bluetooth maintainer's own
  `1d7a52778858` ("Bluetooth: mgmt: Fix mesh transmission locking and lifetime"), accepted on
  2026-11-18 and in bluetooth-next. "Pending" suggests it may still be applied; it has been
  overtaken.
- **FD-03 (Low).** `README.md:89`: the E1 row gives "`EX-055`, `EX-056`, `EX-058`" as the record
  of "58 SCO links, three boots". The 58 links are EX-058's three boots (34 + 21 + 3); EX-056's
  7 links lie inside one of them and EX-055 has none (review E-04). `BRIEF.md` was corrected
  not to read as a sum; the README row still invites that reading.
- Consistent, checked against the upstream reads of 2026-11-22: the eleven BlueZ commits and
  "all released in BlueZ 5.88"; the split "three fixes in the daemon and its shared code … the
  fourth fix … test infrastructure"; the stable releases of `dc16388d45ec`, `86ef0f58bdec` and
  the three backports of `96d006ae6445` (found again in the stable trees as `9a328ae014`,
  `80861f424f`, `dafb564a49`); CO-02's four mails still `new`.

### `README.md`, lines 126–250 (read in full)

- **FD-04 (Low, date).** `README.md:149`: the heading is "Current direction — 2026-11-15", and
  the block below it states facts of 2026-11-16 (the rewritten cover), 2026-11-19 (the mesh
  fixes overtaken) and 2026-11-22 (the stable queue; the running daemon in the Environment
  block). The heading's date is older than its content.
- **FD-05 (Low, precision).** `README.md:177-178`: "the 7.3 line was queued by the stable team
  itself on 2026-11-22". 2026-11-22 is the day it was read. In the stable queue's history the
  pair was added to `queue-7.3`, dropped on 2026-11-19 and re-added on 2026-11-20 (upstream
  check, companion file). "Seen queued on 2026-11-22" would be exact. The same sentence does
  not say that three sibling patches of the same series are queued for 6.18, 6.12 and 6.6,
  which is what our backports must now be rebased onto.
- **FD-06 (Low, forward).** `README.md:145-146`: "the entry is a two-line addition to
  `drivers/bluetooth/btusb.c`". True of every released kernel. On bluetooth-next the driver is
  now `drivers/bluetooth/btusb_main.c` (with `btusb_qcom.c`), so the sentence will need a
  second file name when that reaches a release.
- **FD-07 (Low, omission).** `README.md:160-164` (Ubuntu): `7.0.0-44` has been in noble-proposed
  since 2026-11-20 (Launchpad, read 2026-11-22). Nothing depends on it, but the paragraph gives
  the published versions as its subject.
- **FD-08 (Low).** `README.md:153`: "The kernel series and its BlueZ test are under review".
  The sentences that follow describe the real state accurately (no maintainer reply, patches
  `new`, the bot's rule, v2 as a resend). "Under review" is the lifecycle word of
  `docs/STATUS.md` for an outside review before sending; for a series that has had no human
  reply in four weeks, "sent, no reply" is what the rest of the bullet says.
- Consistent: the mesh items (`CO-26` kept, `CO-04` and `CO-05` overtaken on 2026-11-19: the
  commit's date in bluetooth-next); the next candidates against the upstream check (CO-35 for
  6.18, 6.12, 6.6; CO-22; CO-38; CO-44; CO-43; CO-20 patch 1; CO-21; CO-23; CO-37; CO-39; CO-41);
  CO-12 is rightly absent; the `BT_VID`/`BT_PID` paragraph (corrected since the review); the
  machine on `-43` with E3 retired; BT-16 at three boots; BlueZ 5.88.

### `README.md`, lines 251–367 (read in full)

- **FD-09 (Low, a block that predates the result).** `README.md:250-255`, the marked paragraph
  "The controller sometimes enters a non-responsive HCI state during synchronous-audio link
  transitions … whether [USB collapse] belongs to the fault's untreated trajectory is
  **unresolved**". It is introduced as the register's formulation and it is kept identical by
  a test, but on a page whose main section is "The controller hang was the missing `btusb`
  device-table entry" it reads as the present state of knowledge. It names neither the cause
  nor the condition the README itself gives eighty lines earlier (the first HCI command after
  a transparent SCO stream starts, on the ROM firmware). One sentence saying that the
  formulation is the pre-cause one, or moving the cause into it, would remove the two voices.
- **FD-10 (confirmed, with one addition).** `README.md:299-301`: "the 16 old remote branches
  were deleted on 2026-11-15". Checked on the remote on 2026-11-23 (`git ls-remote --heads
  origin`): five branches exist: `main`, `tests/test-suite`, `research/journalctl-file-scaling`,
  the branch that holds the whole-project review and its rechecks, and
  `research/contributions-upstream-check-20261122` (this review's). The first recheck's doubt
  about the deletion (N-06) is settled: they are deleted. Of the five, the review branch is
  the one whose removal is still the author's open decision.
- Consistent: the repository map against the tree as known from the review (the `results/` and
  `patches/diag/` lines were corrected); "two controlled demonstrations" with `EX-026` apart;
  the Contributing paragraph on author and committer (the gate now reads the fixed author);
  the tests comment that no count is spelled on purpose.
- Not a finding, a note: two lists of tools sit in the page for two properties ("work on any
  USB controller": `bt-diagnose`, `bt-state`, `bt-boots`, `bt-crash`, `sanitize-logs.sh`; "need
  no installation": `bt-diagnose`, `bt-state`, `bt-boots`, `bt-boot-list`, `sanitize-logs.sh`).
  They differ by one name each way; whether `bt-crash` needs installation and whether
  `bt-boot-list` is controller-independent was not re-read.

**`README.md` as a whole:** in good order. Every number that the review of 2026-11-15 found
stale is corrected, and the page already carries the upstream state of 2026-11-22 for the
mesh items and CO-35. What is left is the heading's date, one "pending" that has been
overtaken, and the pre-cause paragraph.

