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

### `BRIEF.md`, lines 1–100 (read in full)

- **FD-11 (Medium, stale against the README of the same tree).** `BRIEF.md:93`, "Submitted,
  under review: CO-02 …": the last dated sentence is of 2026-11-02 and describes v2 as "the
  fold of 2 and 3, the BlueZ test port, possibly the mismatch patch". `README.md:153-162` and
  the "What to send" table describe the v2 that exists: patch 1 plus a non-sleeping 2/2, the
  first candidate withdrawn because it can deadlock, the mismatch patch later and alone. The
  state block was "corrected 2026-11-15 where marked"; this bullet is not marked and not
  corrected.
- **FD-12 (Medium, overtaken upstream).** `BRIEF.md:94-97`, "Waiting for replies": "Every other
  authors' mesh fix is still `new` with no maintainer reply". The bullet says it was not
  re-read since 2026-10-28, which is honest, but the fact behind it changed in kind on
  2026-11-18: the maintainer applied his own fix for that path (`1d7a52778858`), which
  overtakes those patches and four of our own items. A reader who starts here, as the file
  instructs, meets the mesh work as still waiting.
- **FD-13 (Low).** `BRIEF.md:55-58`, the foundation bullet "E3 and kernel updates" is written
  in the present tense ("Before any new kernel boots, run `scripts/btusb-has-device.py` … if
  ABSENT, E3 is rebuilt for it first"). E3 is retired since `7.0.0-43` (the next bullet group
  says so). The check itself stays useful; the bullet could say that it is now a safeguard
  for a kernel that would lack the entry, not a standing duty.
- **FD-14 (Low, to confirm on the laptop).** `BRIEF.md:98-100`: "Since 10-29 lore is readable
  from here over git". From the environment of the upstream check of 2026-11-22 the same git
  archive answered 403. That is another machine, so it is not a contradiction; it is a reason
  to try the script once before relying on the sentence.
- **Known and unchanged (review S-12):** the file says it is "not the current snapshot"
  (`:9-10`) and that there is "one hand-off block, not a stack" (`:18-21`), and it carries a
  state block dated 2026-10-28 with corrections of four later dates above a hand-off block.
  The maintainer's record leaves this as an editorial decision.
- Consistent: the foundation bullets (device, BT-1 with 12 deaths and 74 links, the dangers,
  BT-9, BT-7 and BT-8); the accepted list against the stable trees read on 2026-11-22
  (`9a328ae01489`, `80861f424fe5`, `dafb564a498e` found again); the 1200-line budget (925 lines).

### `BRIEF.md`, lines 101–262 (the state block's second half and the hand-off block; lines over 520 characters were cut at 520)

- **FD-15 (Medium to High, a contradiction inside `BRIEF.md` on what may be sent).** The
  hand-off block, which the file says to read first, lists under "Patch ready" (`:191-192`):
  "CO-44, CO-38, CO-43 E, A and BT-24/25, **CO-04**, CO-22, CO-21, CO-20 patch 1, CO-39, CO-41;
  CO-35, **CO-05** + CO-26, **CO-12**, CO-23 and CO-37". Sixty lines above, the state block
  (`:104`, a correction dated 2026-11-23) says "CO-04, CO-05 1/2, CO-14 and CO-12 are
  overtaken by applied upstream fixes; CO-26 stands alone; CO-35's 7.3.y mails are not to be
  sent", and `README.md:181-183` says the same. The correction reached one of the two lists in
  the file. This is the same kind of drift the review of 2026-11-15 called its first finding
  (a hand-off that names what must no longer be sent), in a new instance.
- **FD-16 (Medium).** `BRIEF.md:210-214`, "New findings 11-14": "**CO-14 confirmed** … a fix in
  `mgmt_index_removed()` takes it to 0", and the lockdep cycle "none with CO-04". Both are
  overtaken by `1d7a52778858`, which flushes the pending sends in `mgmt_index_removed()` and
  removes the callback behind the cycle (upstream check, 3.3). The bullet is unmarked.
- **FD-17 (Medium).** `BRIEF.md:200-203`: "One document for outside reviewers holds all twelve
  kernel items verbatim … The operator shares it with the reviewers." That document now
  carries its own note that it was not regenerated and that one recorded checksum no longer
  matches; five of its twelve items (CO-04, CO-05, CO-12, and with them CO-14 and CO-06 in the
  text) are overtaken upstream; and `main` has a newer document for outside review
  (`d0d68155`, "five kernel submissions, a self-contained document for outside review",
  2026-11-22). The hand-off still presents the older one as the one to share.
- **FD-18 (Low).** `BRIEF.md:142`, "Open investigations": "CO-04's independent fix for the mesh
  use-after-free" is still listed as open. `:112-113`, "a reply on Jiale Yao's power-off patch"
  is still an open operator decision; that patch is overtaken by the same commit and CO-06 is
  to be closed (upstream check).
- **FD-19 (Low, date).** `BRIEF.md:148`: "Last updated: 2026-11-16 (corrections only …)". The
  file carries corrections dated 2026-11-22 and 2026-11-23 (`:104`, `:106`, `:182-183`).
- **FD-20 (Low).** `BRIEF.md:228-231`: the public repository "now has `main`, `tests/test-suite`,
  `research/journalctl-file-scaling` and the whole-project review's branch (`ls-remote`,
  2026-11-15)". On 2026-11-23 there is a fifth, `research/contributions-upstream-check-20261122`
  (FD-10). The same bullet says the two commits of the deleted `ci/upstream-ci-local` "are on
  `main` as the ports `8b71499` and `a56141e`": in the clone used for the rechecks those two
  ids were not ancestors of `main`; that clone was shallow, so the statement still needs one
  `git merge-base --is-ancestor` on a full clone.
- **FD-21 (Low, wording of the kind the author decided to remove).** `BRIEF.md:108` still says
  "the coordinator's choice"; `:149` "the five tracks". The pass of 2026-11-16 reworded the
  rest of the file.
- Corrected since the review and consistent now: the D1/D2 gloss (`:254-256`); the survivals;
  the trial directory and number reuse (`:132-138`); the persistent archive timer; the branch
  names; the CI line ("not true after 11-14"); the bundle against the staged build; the
  machine on `-43` and the running daemon (read 2026-11-22).

## Where the reading stopped, and what it means

**Read:** `README.md` in full (367 lines, 32 kB) and `BRIEF.md` lines 1 to 262 of 925 (the
introduction, the foundation, the whole state block and the whole hand-off block; about 40 kB,
with the longest lines cut at 520 characters). **Not read in this review:** `BRIEF.md` §1 to
§10 (lines 263 to 925: the bug statement, the signature table, settled and unsettled, the
retractions, the BlueZ patches, the constraints, the method rules, the open threads),
`contributions/README.md`, `docs/STATUS.md`, `docs/issues.md`, `HISTORY.md`. The plan's items 3
and 4 were not reached: the two documents read took the budget, mostly because `BRIEF.md`'s
state and hand-off blocks are long single lines. Nothing is concluded here about the unread
documents.

**Summary of what was found (21 findings, none in code).**
- `README.md` is in good order: three small items (the heading's date, one "pending" that has
  been overtaken, the pre-cause formulation of the fault), and it already carries the upstream
  state of 2026-11-22.
- `BRIEF.md` has absorbed the upstream check in its state block and not in its hand-off block.
  The one finding that matters before a send is **FD-15**: the hand-off's "Patch ready" list
  still names CO-04, CO-05 and CO-12. With it go FD-16 and FD-17 (the CO-14 finding and the
  outside-review document, both presented as current) and FD-11, FD-12 (the CO-02 and
  "waiting for replies" bullets of the state block).
- The cause is the one named in the review as S-12: the file keeps two long "current" blocks,
  each corrected in place by dated insertions, so a correction lands in one and not the other.
  A hand-off block rewritten for 2026-11-23, replacing the one of 11-14, would remove FD-15 to
  FD-20 at once, and it is what the file's own rule ("replaced, not topped up", `:20-21`) asks.

**Suggested order:** FD-15, then FD-16, FD-17, FD-11, FD-12 (all in `BRIEF.md`), then FD-02 in
`README.md`; the rest are small.

*Reading closed on 2026-11-23. This file is not edited after this point.*
