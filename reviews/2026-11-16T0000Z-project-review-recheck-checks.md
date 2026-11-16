# Checks of the reviewer's recheck of the 2026-11-15 whole-project review

The reviewer's message is stored as `2026-11-16T0000Z-project-review-recheck-reaction-verbatim.md`.
The recheck itself (`3f8e8f62`, two files) is on a separate branch, like the review (`162d3b9`).
It read `main` at `a8d0eb45`. It is an opinion, not the truth: each item was looked up again on
`main` at `d6a8053` on 2026-11-16 and fixed where it held. Verdicts:
- **right**: the reviewer is right, and it is fixed;
- **partly**: right in part; what was wrong is said;
- **wrong**: the claim does not hold;
- **open**: not done; the reason is given;
- **operator**: waits for the operator's decision, on purpose.

Line numbers in the recheck are those of `a8d0eb45`; every item was found again by content.

## Before any send (recheck section 2, items 1 to 6)

| # | Item | Verdict | What was checked, and what changed |
|---|---|---|---|
| 1 | CO-35: the table's directory lacks the request, covers and backports (N-03) | **right** | `review-fixes-20261114/mail-from-send-20261114/` holds a byte-identical copy of `send-20261114/mail/`, with `COPIED-FROM.md` and its own `SHA256SUMS`; the table row points at it. Nothing old moved or deleted. |
| 2 | CO-02: a three-patch cover for the two-patch candidate (N-08) | **right; operator** | `msg/cover-alt.txt` describes the two patches and quotes only numbers recorded for that candidate (sco-tester 33 of the 35 posted cases, mgmt-tester 526/526, iso-tester 213/213, the race cases 2 of 2 against 1 of 2 on the base); l2cap-tester and the laptop are "not run". Checksums made. CO-30's README and the table say its RFC was tested on the withdrawn 2/2 and is not re-tested. The `Cc: stable` trailer form is the operator's. |
| 3 | Index rows and `rd-2026-11-14.md` name replaced directories; six without a marker (C-02) | **right** | `SUPERSEDED.md` in CO-35 `send/`, `send-20261102/`, `send-20261101-draft/`, CO-21 `patches-20261101/`, CO-43 `send-series-20261114/`, CO-02 `patches/main-v2/`; `send-v2-20261114/SUPERSEDED.md` names `alt-2of2/`. The index rows carry dated pointers; BRIEF calls the README table the record. |
| 4 | CO-43: patch 3 and the cover say the system path is unchanged (C-05) | **right** | Notes in `HELD.md` and the dossier; STATUS BT-18 says D v2's `.reset_resume` suppresses `needs_binding`. "Five patches" corrected. The kmemleak counts are both real: 11 of 12 in the first run, 12 of 12 in the package's re-run, none with the fix in either; STATUS BT-25 says so. |
| 5 | `<AUTHOR-EMAIL>` in a current package (C-06) | **right** | The CO-38 cover's `From:` line now has the author's address, as the other CO-38 mails do; it is published in the BlueZ 5.88 commits. |
| 6 | CO-03 against the Ubuntu bundle (R-01) | **partly** | Read from the staged `.deb` (`dpkg-deb -I`, `-c`, `-x`; nothing installed): `5.72-0ubuntu5.9~co03.1` carries the two BT-7 fixes and three U12 patches, and its `bluetoothd` has the hash STATUS gives. The bundle's own `5.72-0ubuntu5.9` is a different build without them. Both documents were right about their own build; BRIEF and the dossier now name both. |

## Code (items 7 to 11)

| # | Item | Verdict | What was checked, and what changed |
|---|---|---|---|
| 7 | `bt-archive`: an older archive with another compressor is deleted uncounted (T-08) | **right** | Reproduced with a fixture. Every `boot-<id>.export.*` is counted before the sweep, and a longer or uncountable one is kept. `--replace` is in the usage. Test: 4 checks. |
| 8 | `sco-ledger.sh`: a boot with no call reads as unreadable (N-02) | **right** | Confirmed with a stub `journalctl`: `--grep` exits 1 on no match. A no-match with empty stderr is now a measured zero; any other failure stays exit 2. Not run on the laptop's journal: the read-only run was still on its first boot after an hour at the lowest priority and was stopped. |
| 9 | The test that calls `runtime-mgmt-test.sh load` for real (N-05); the identity switch (N-04); `guard()` failing open (K-01) | **right** | The test runs with `modprobe`, `rmmod`, `insmod` and the rest stubbed first on the path and asserts that none was called. The refused swap code is removed from the script (it is in history); the usage no longer lists `load`/`restore`; `guard()` refuses when `bt-window` or `bt-trial` is missing or gives no usable answer; the daemon and `trigger` verbs are described as restarting `bluetoothd` and power-cycling the adapter. The identity switch is refused in any clone of the project and on `pushurl` and URL rewrites, before anything is staged; it is no longer exported suite-wide, and `tests/system-resources.md` lists it. |
| 10 | Verdicts not measured (K-04), `compile-mgmt-at.sh` (K-02), `bt-trial-audit` and `journal.sh` (T-10), `hci_alive` (T-09) | **right** | Each listed script exits non-zero or says NOT RUN when it did not measure; `compile-mgmt-at.sh` goes by `patch`'s exit status. The audit reports an unreadable window as UNRESOLVED (exit 2); `journal.sh` ends in status 2 on any failed or unreadable file. `hci_alive`'s "cannot tell" (no `hciconfig`) is no longer read as dead: `ok` records `ended_unprobed`. `bt-trial`'s header says which verbs send HCI. |
| 11 | `bt-journal-files` not installed, the archive unit's condition (I-03, N-09); `bin/bt-evidence`'s probe | **right; N-09 partly** | `install.sh` installs `bt-journal-files` and its three units where `zstd` exists, and the event unit gets the device drop-in; `uninstall.sh` and `verify-restored.sh` remove them. `bt-verify-install` does not demand the raw-archive unit from another checkout. `verify-restored.sh` and `uninstall.sh` needed no change for N-09: they only look for leftovers. `bt-evidence` sends no HCI unless `BT_EVIDENCE_PROBE=1`. `bt-usbmon` writes 0700/0600. |

## Documents (items 12 to 22)

| # | Item | Verdict | What changed |
|---|---|---|---|
| 12 | Restore and change documents still describe a btusb reload; "three demonstrations"; `docs/install.md` (I-01, I-04, I-05) | **right** | The reload is described only as a marked historical record; two controlled demonstrations plus `EX-026` in the plan, the proposal and the tooling index; the install guide says what is installed and how to verify it. |
| 13 | `BRIEF.md` lines (F-07, F-08, F-09, T-09, G-02, M-02) | **right** | The `-42` line, the persistent archive timer, the open investigations, the branch names, "Last updated", the survivals in the plural, the trial directory set aside as `.unclosed-<stamp>`, the `build=stock` label, nine CI jobs, the §9.2 survey recorded as dropped. |
| 14 | `README.md` lines (T-04, N-07, PA-01, M-02) | **partly** | The CO-02 and CO-25 bullets and the next candidates follow the send table. T-04: `tools/bt-status` does not hard-code the device (it has a default that the variable overrides); the false part was "every tool", now narrowed: 27 of 38 tools never read the variable. |
| 15 | `docs/STATUS.md` lines (C-03, IS-07, S-13, S-07, L-01, S-14, S-09) | **right** | CO-25 names the v4 draft; U26 and U27 evidence rewritten; the archiver dates agree with BRIEF; the M rows in order; the 10-18 branch survey marked superseded. |
| 16 | `docs/issues.md` (IS-03, IS-06, IS-07) | **partly** | BT-18 to BT-23 brought to 11-14; U8, U10, U12, M-3, "Evidence model", "On the wider claim" dated. U13 has two owners, CO-27 (BlueZ) and CO-42 (GNOME), not CO-42 alone. |
| 17 | Exhibits index, EX-043 (E-03, E-04) | **right** | The seven rows carry their marks, through each exhibit's own title, so the generated index keeps them; EX-043, EX-038 and EX-057 state their gaps. |
| 18 | `patches/*/README.md`, the check scripts (PA-01) | **right** | Dated notes; both check scripts resolve a relative `BT_PATCH_DIR`; checkpatch with no `total:` line is NOT RUN. |
| 19 | `reviews/README.md` (M-02) | **right** | 65 unlisted files indexed; R2-21, R2-25 and R2-64/65 re-run. R2-64/65's old check no longer fits the code (`autostop` is passive by default), so they are marked done. |
| 20 | Dossier front pages, `rd-2026-11-14.md`, older `docs/`, `HISTORY.md` (C-01, C-03, C-07, D-01, D-02, H-01) | **partly** | Dossiers and `rd-2026-11-14.md` corrected; `HISTORY.md` has dated correction notes, and its blocks moved there verbatim are unchanged. D-01 and D-02 (the older `docs/` files without a date label): **open**. |
| 21 | Identifiers in full (S-10) | **partly** | 19 elided `CO-nn-…` and `comms/` paths written in full in STATUS and `docs/issues.md`, and BRIEF's. Log-line ellipses are not identifiers. Three truncated hashes have no full value in any file: **open**. |
| 22 | One place for "current" (S-12) | **operator** | An editorial decision; the blocks stay. |

## Tests (item 23)

| Item | Verdict | What changed |
|---|---|---|
| The 23 assertions of recheck 3.4 | **partly** | Fixed: the counts in `tests/README.md` and `whole-boot-reads.txt`, `autostop` in the `bt-trial` guard, `--section` keeping `--serial`, the four `\|\| true` checks, the vacuous width check, the weak globs, the duplicate description, the fixture built from the live `results.tsv`, the `system-roundtrip` gate and empty list, the silent skips. **Open:** the 41 "pending" whole-boot reads (each tool's decision); the missing commands in `tests/machine-tools` and the staged `--apply` tests, which use only `0cf3:e300`, (both need a full suite run, which waits while a trial is open). |
| N-10, light mode | **partly** | `bt-ui-capture`'s header names its one non-passive step; `scripts/bt-ui-atspi.py` reports failed registrations. Light mode is still exercised only by `scripts/prove-ui-capture.sh`: **open**. |
| New tests | — | A review-fix section (37 checks) and 16 blocks next to their tools (40 checks), each run against the merged tree with stubs on the path. The full suite runs in CI. |

## The author's decisions (items 24 to 26)

| # | Item | Verdict | Note |
|---|---|---|---|
| 24 | The working arrangement in the text, and a scan pattern (P-01 to P-03, S-11, N-01) | **operator** | Asked again on 2026-11-16, with N-01 named. |
| 25 | Whether all fifteen passwords were revoked (P-04) | **partly wrong; operator** | `CO-25`'s `log.md` does say it: fifteen app passwords, each refused with `535`, revoked. The check used port 465, which this project counts as inconclusive; a check on 587 is not recorded. |
| 26 | Where the review files live | **operator** | Unchanged. |

## The new items not covered above

- **N-06** (a comms note says the 16 branches are still to be deleted; BRIEF says they are deleted): `comms/` is append-only, so BRIEF's hand-off block carries the correction.
- **N-11:** the refused `shorter-boot-*` exports are still not listed by `bt-archive --list`. An existing test asserts that they are not, so changing it is a decision about that test. The refusal message names the file. **Open.**
- **G-02, the Message-ID fragment:** the allow-list entry is the tail of a published Message-ID that the scanner cuts at `=`, so it cannot be a real address. It stays an exact-match entry, with the reason in its comment, and a test shows that another address at that host is still refused.

## Not raised by the reviewer, found while fixing

- Two greps for the hang message in `docs/install.md` and `docs/STATUS.md` did not use the project's spelling; corrected.
- The CO-38 row of `contributions/README.md` named a work area that no longer exists; it now says so.
- Some facts could not be settled from the files, and they are marked as unsettled where they appear:
  - the time zone of the BlueZ bot's reply;
  - whether the CO-04 counts of 9 and 8 of 12 differ in subset or in rerun;
  - CO-09's boot time, 22:57 in its banner and 22:55 in STATUS.
