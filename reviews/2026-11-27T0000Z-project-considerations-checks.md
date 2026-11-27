# The project considerations of 2026-11-23: where each point stands (2026-11-27)

The page is `2026-11-23T1757Z-project-considerations.md`, an outside reviewer's opinion, written three days before
this check. Each point is weighed against what happened since; nothing here is a decision.

## Already done or overtaken since 2026-11-23

- **§9 item 1, send CO-38:** sent 2026-11-26, with its BlueZ test the same day (STATUS rows).
- **§3 "one item in flight":** CO-38 went alone, as advised.
- **§3 "check upstream by tree":** done before the CO-38 send.
- **§6 "raw output in git":** the CO-38 suite-gap logs of 11-26 went to the private archive, with only checksums
  in the dossier.
- **§7 "work left in a private area":** a housekeeping rule now exists (export, record, clean at the end of each
  task), and 74 GB of old work areas were cleared on 11-26 after their unique content was saved.
- **§8 "how wide" and "a test report on others' fixes":** still open; see below.
- **§9 item 3, CO-22:** **held** since 11-26. Qualcomm answered that the Rome 3.2 files are a workaround for
  QCA9377, which changes the case for sending more IDs on them.

## Points that stand and are cheap

- **§3 "limit review rounds":** CO-38 had about eight rounds on 11-26, each smaller. The last four changed only
  wording below `---`. A rule to weigh: one full round, then only the points it raises, then send.
- **§3 "split by size":** one-liners alone and first; locking series (CO-02, the btusb series) as an RFC with their
  reproducer.
- **§3 point 6 and §9 item 2, the Ubuntu bundle:** filing it is, in the reviewer's judgement, the most value per
  hour. It is still unfiled.
- **§9 item 4, test reports on the maintainer's mesh fix:** use the mesh harnesses of the overtaken items as a
  test report, and close CO-04, CO-05 1/2, CO-06, CO-12 and CO-14 with one line each. Not done.
- **§5 point 4, the base-against-patched harness as one tool:** the scripts of 11-23 and 11-26
  (`run-tips.sh`, `run-gaps.sh`, `compare-gaps.sh`) are that harness in pieces. They are the natural first tool of
  `bt-test-suites/`.

## Points that are larger and the operator's to decide

- **§2, records:** one fact, one home; replace rather than annotate; drop BRIEF's state block; fixed-shape STATUS
  rows; generated pages.
- **§4, code:** port `bt-trial` and the evidence tools to Python; one exit-code convention; usage from one function;
  sort `scripts/` into tools and one-run records.
- **§5, tests:** split `tests/run-tests` by tool; the container as the default way to run it while a trial is open;
  refuse a save while the last CI run is red.
- **§6, evidence:** close the trial series with a final note and stop automatic trials; checksum lists that verify.
- **§8, direction:** say in the README's first paragraph what the project has become; close dormant register items;
  offer Tested-by on others' fixes the week they are posted.
- **§7 and §9 item 7:** decide the open decision lists (D1 to D14 of 11-02, D-1 to D-7 of the incident) and the
  review branches once, in writing.
