# Considerations on the project as a whole, from inside the work (2026-11-27)

**What this is.** A companion to the outside reviewer's
[`2026-11-23T1757Z-project-considerations.md`](2026-11-23T1757Z-project-considerations.md), written from the other
side: by the working session that prepared, tested and sent the work of the last weeks, from what it holds in mind at
the end of a long stretch. It is opinion with reasons. Almost nothing was re-read to write it; where a statement rests
on a record, the record is named. The operator's decisions are marked as his.

## 1. What the project is now

It began as one hang: a QCA9377 (`13d3:3503`) that stopped answering on the first HCI command after an mSBC call came
up, and recovered only by power-off. That question is answered.
- **The cause:** a missing device-table entry left the controller on ROM firmware.
- **The fix:** another author's entry, `dc16388d45ec`, loads the Rome 3.2 rampatch and NVM. This project had it
  backported to all seven stable lines, and it reached the Ubuntu kernel the laptop runs.
- **What is still not known:** what the ROM firmware does wrong.
- **What changed on 2026-11-26:** Qualcomm said the Rome 3.2 files are a workaround for QCA9377, and that it will
  try to upstream the intended firmware. The measurement stands; the meaning of the fix shifted.

What the project became along the way is a steady source of small, well-evidenced fixes for Linux Bluetooth and the
desktop audio path, found on one ordinary machine in daily use:
- **kernel:** one fix in mainline and five stable lines, now carrying a CVE;
- **BlueZ:** twelve commits in BlueZ 5.88;
- **stable:** three backports of another author's fix and the device-table backport;
- **others' work:** two test reports;
- **Qualcomm:** a vendor report that drew a real answer;
- **GNOME:** a gvfs fix merged;
- **in review:** a kernel fix and its BlueZ test, sent yesterday.

The goal the operator set, every daily-use Bluetooth bug fixed upstream, remains the mission. The hang was the first
instance, not the end.

## 2. What worked, and why

1. **Evidence before claims.** Every claim carries the command and the output (the exhibits), and corrections stay
   visible (BRIEF §5). When an overclaim slipped into our own text, it was caught by checking the evidence again, not
   by trust. The last two instances: "starts advertising" and "on air", where only command statuses were seen.
2. **Differential testing.** Base against base plus patch, case by case, on every affected line, with KASAN and
   lockdep. Only the difference is judged.
   - It made claims like "no other case changed" mean something.
   - It surfaced other people's defects (BT-26, BT-27, BT-28) without confusing them with ours.
3. **Doing the receiving side's homework.**
   - **Before sending:** run the list's own CI locally, check the tree rather than patchwork, check stable queues
     before a request.
   - **The result:** what was sent was applied unchanged, often the same day.
4. **Outside review as opinion, checked.** The operator's rule was "treat what reviewers say as opinion, not a
   command". Every claim was checked against the code or the record before it changed anything. Reviewers were
   right often, and wrong in ways that mattered:
   - a proposed rewrite would have said the CI runs all eleven testers for one file;
   - a claimed "unapplied" test was in master;
   - recommendations to copy linux-kernel rested on an outdated document.

   Taking them as opinion is what made them useful.
5. **The hardware as the final witness.** The laptop run of CO-38 added little to what QEMU proved about the code, and
   much to what a maintainer can trust. The operator's instinct was right.
6. **Watchdogs on long work.**
   - **What failed without them:** unattended batches failed silently twice earlier.
   - **The three levels added:** a per-guest hang detector, a progress watch, and a timed health check.
   - **What they caught:** a stall and a runner bug within a minute, and a false alarm was corrected the same hour.

## 3. What cost us, honestly

1. **Facts kept in many places.** The outside reviewer named it well: corrected in one place, stale one paragraph
   away. On 2026-11-26 alone:
   - BRIEF's hand-off still called a recipients decision "the operator's open choice" an hour after it had changed;
   - a README said "on air";
   - a STATUS paragraph still called the CO-25 reply unsent.

   The cause is structural, not carelessness.
2. **Replies missed.** Three same-day replies sat unread because they came through tracker notifications rather than
   the list: a merge, a review, a vendor answer. The tools to read each upstream exist. What was missing was the
   habit of reading them all, regularly.
3. **Authority drifting into assumption.** One recipients change was made from documentation and recorded as decided
   before the operator had decided it. It was caught by an assessment, not by the process. The lesson: a decision
   names who made it.
4. **Breadth.** Fifteen packages prepared in parallel in November, five of them overtaken by other people's applied
   fixes. Several workstreams stayed open, each costing something every time the records were reconciled.
5. **Disk and leftovers.** Free space fell to 29 GB of 432 before anyone looked. Unique work was nearly stranded in
   areas that no record listed. The housekeeping rule of 2026-11-26 exists because of it.
6. **Shell at scale.** Twice in two days a shell detail produced a silent wrong result:
   - a guest read a loop's input;
   - a check script took the first two text blocks instead of the two patches.

   Both were caught by looking at the output, which is the only reliable guard.

## 4. Review rounds: the operator's decision (2026-11-27)

The outside reviewer advised limiting review to one round before a send. **The operator disagrees, and this page
records his decision as the rule.**
- **What happened on 2026-11-26:** several rounds on one patch and its test produced two submissions in one day, each
  sharper than the last. The commit message became exact about `le_num_of_adv_sets`, the tester sentence stopped
  implying something false, and the test's notes stopped instructing the maintainer.
- **Why not fewer rounds:** cutting them would lower the quality of what is sent, and that quality is the project's
  standing with upstream.
- **What made the rounds cheap was focus, not their number.** One patch, or one tightly connected pair, under review
  at a time. Working on many packages in parallel was heavy and redundant, and felt uncontrollable: context was lost
  across too wide a front.

**The rule:** review rounds continue until reviewers find nothing, and each round covers exactly one patch or one
connected set. A round's changes are listed before and after, so the next round reads only what moved.

## 5. The pipeline, as CO-38 walked it

One item, end to end, is the template worth keeping:

1. **Found while writing tests:** a lone instance 2 hidden.
2. **Traced in the source:** a number compared with a count; origin `b338d91703fa`, in 6.1 and later.
3. **Fix and test:** a one-line fix and a minimal tester case. The test fails without the fix and passes with it on
   every affected tree.
4. **Suites:** the full suites before and after, with gaps closed, not explained away.
5. **The list's own CI,** run locally on the exact files.
6. **Hardware:** before on the stock kernel, after on the patched one.
7. **Review:** focused rounds on that one patch, each change shown before and after.
8. **Sign-off and send:** the operator's own `Signed-off-by` and his send, from his terminal.
9. **After the send:** lore checked byte for byte, patchwork and CI recorded, the STATUS row written the same hour.
10. **The companion test, the same day,** naming the fix. When to apply it is the maintainer's call.

The step that is easiest to skip and most expensive to miss is the last: **record, then watch for replies**.

## 6. The records

- **What to keep:**
  - the retraction table;
  - the dated, never-edited review files with their findings-and-checks companions;
  - the exhibits;
  - "checked", "inferred" and "not found" on claims;
  - verbatim storage of every outside text.
- **What to change, in the operator's time:**
  - one home per fact, and other pages point to it;
  - replace stale text instead of annotating it;
  - shorter STATUS rows;
  - a hand-off that is rewritten, not appended.

  The README's direction block was rewritten in place on 2026-11-27 for exactly this reason.
- **Decisions carry their author.** "The operator's decision", "proposed, not decided", "a reviewer's preference".
  The difference is the project's authority structure, and losing it is how the recipients drift happened.

## 7. Tools and machinery

- **Worth turning into maintained tools:**
  - the base-against-patched suite runner, with its hang watchdog and per-case comparison;
  - the local CI runner;
  - the lore, patchwork and Launchpad readers;
  - the module installer, which checks symbol CRCs against every dependant;
  - the rescue export, which saves unique commits and files before a deletion.
- **The machine's safety rules are refusals in code, not prose**, and that held: no module was ever reloaded live;
  the patched module went in only through `updates/` and a cold boot.
- **What blocks us:** GNOME's GitLab refuses this machine. Its reviews can be read from their notification mail;
  that path is recorded.

## 8. The upstream relationships

- **Linux Bluetooth:** the maintainer applies small, clear fixes quickly. He also posts his own tests for kernel work
  still in review, which is the precedent our test timing now follows.
- **Stable:** requests with every line built and tested were queued without questions.
- **Qualcomm:** after two careful replies, a substantive answer and an offer to upstream firmware. That is a
  relationship to keep warm with one short acknowledgement and a test when the firmware comes.
- **GNOME:** a merged fix and a constructive review. Answering it well is the next obligation.
- **Ubuntu:** a filed SRU (Filelight) waits for a sponsor. A built BlueZ bundle has never been filed; the outside
  reviewer judged it the most value per hour.

## 9. Testing as the larger vision

- **The operator's impression:** each layer of the Linux Bluetooth stack lacks the comprehensive, randomised,
  whole-stack testing that would have caught what we found by hand.
- **The record bears it out:** almost every defect found lies between two events, at an object's end, on an error
  path, below the emulated controller, or between layers.
- **The outside design** in [`bt-test-suites/`](../bt-test-suites/README.md) says how to reach it: inventories,
  generators, invariants, coverage against the map.
- **Its most useful finding** is that upstream already has most of the instruments: hooks, simulated time, a
  multi-machine suite.
- **What is missing** is generation and accounting.
- **The smallest first contributions:** a coverage table, two functional tests in upstream's own form, and sniff and
  role-switch emulation. They are in this project's style: results that ask nothing of the maintainers.

## 10. Open items worth naming

- **Immediate:**
  - gvfs !369's four review points; the fourth, track numbering, needs facts before code;
  - the CO-25 acknowledgement;
  - the Filelight follow-up.
- **Next sends, one at a time:**
  - CO-44, rerun on the current tip;
  - the btusb series;
  - CO-02 v2, which needs real work on today's tree.
- **Held:** CO-22, until Qualcomm's firmware answer is weighed.
- **The laptop:**
  - it runs CO-38's patched module until the operator wants stock back;
  - the bluetoothd consequence of the bug (start-up cleanup skipped) is shown in source, not yet on hardware.
- **Records:** the outside reviewer's structural proposals (section 6) and the long-open decision lists.

## 11. A closing remark

The most valuable property of this project is not a fix. It is that the work would rather be shown wrong than stay
wrong, and that it writes the correction down where the next reader will find it. The second most valuable is
the operator's insistence on asking clearly and gracefully, taking the fault on our side and never on the reader's.
It is what turned a dismissive first vendor reply into an offer of firmware.

*Written on 2026-11-27 from the working session's own understanding, not edited afterwards.*
