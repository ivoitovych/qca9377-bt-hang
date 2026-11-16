# The project review after the second round of fixes: `main` verified at `bbec102f`

- **Written:** 2026-11-16T13:22Z (UTC), on the branch that holds the review.
- **Earlier pages on this branch:** the review
  ([`review-comprehensive-project-consistency-review-20261115-005742.md`](review-comprehensive-project-consistency-review-20261115-005742.md),
  `162d3b9`, on `main` at `da23558`) and the first recheck
  ([`review-reaction-to-comprehensive-project-review-20261115-204454.md`](review-reaction-to-comprehensive-project-review-20261115-204454.md),
  `3f8e8f62`, on `main` at `a8d0eb45`). Ids (F-01, T-08, N-02 …) and item numbers 1 to 26 are theirs.
- **What was verified:** `main` at `bbec102f` (2026-11-16 14:01 +0100), 59 commits after
  `a8d0eb45`, and the maintainer's own list of what was done,
  `reviews/2026-11-16T0000Z-project-review-recheck-checks.md` on `main`. Each claim of that
  list was looked up on the files; each item the first recheck left open was looked up again.
  Files were read; nothing was run.
- **Verdicts:** **confirmed** (the list's claim holds on the file) · **partly** (what is missing
  is named) · **not so** (the claim does not hold) · **open** (the list itself says so) ·
  **waits for the author**.

Written in the order verified; sections 1 and 2 (summary, what is left) are written last.

## 1. Summary

**The maintainer's list is accurate.** It has 26 numbered items and a few unnumbered ones. Every
claim in it that could be checked on the files was checked; none of the "right, fixed" claims
turned out to be false as a whole. Where it says a finding of the review was wrong or partly
wrong, it is right each time (T-04's wording, U13's two owners, P-04, CO-03 against the bundle,
the file count of C-06). The list is also candid about what it left open.

| the list's items | verdict here |
|---|---|
| 1, 2, 3, 5, 6, 7, 8, 9, 11, 13, 14 | **confirmed** |
| 4 | confirmed, except one sentence of `HELD.md` about which run the cover quotes |
| 10 | confirmed, except `bt_journal_count` and `bt_journal_first` in `tools/lib/journal.sh` |
| 12 | confirmed, except `docs/investigation-plan.md:60-61` ("three demonstrations") |
| 15, 16 | confirmed, except U8 (STATUS row and section), and the owner ids in the U13 and U29 sections |
| 17 | confirmed; the index shows the word "Historical" but not what supersedes EX-093 and EX-086 |
| 18 | confirmed for what it names; eight `patches/` items of the review were not touched |
| 19 | confirmed; the two newest files of 11-16 are not listed |
| 20 | as it says: partly; D-01 and D-02 open. "Dossiers corrected" covers seven dossiers, not CO-11, CO-04, CO-05, CO-23 |
| 21 | the 19 paths confirmed; "three truncated hashes" is about eighteen, and one has its full value in the tree |
| 23 | confirmed, except "the four `\|\| true` checks" (two remain). Its N-10 line understates the work: light mode *is* in the suite now (`tests/run-tests:12539-12622`); only the shell filter is proof-only |
| 22, 24, 25, 26 | wait for the author, as it says |

**Where the review stands.** Of its 15 High findings, 11 are fixed (S-01, T-01, T-08, I-01, C-02,
C-04, C-05, G-01, K-01, K-03, IS-02), one is fixed in the text and needs one command on a full
clone (M-01, the two port commits), and three wait for the author (P-01 to P-03). Of the Medium
and Low findings, most of those the first recheck called "partly" or "not addressed" were
worked on in this round; section 2 lists everything that is still open, and it is short enough
to read in one sitting. No finding became worse in the code.

**What this round added.** Ten new items (B-01 to B-10), three of them Medium in code or
packages (B-01 the restore verifier, B-05 the review document's checksum, B-08/B-09 CO-46), and
three privacy items (A-01 to A-03), one of them High.

**The one thing that got worse** is the subject of the review's section 3.2: section 3.1 here.

## 2. What is left

**For the author, first (3.1)**
1. `reviews/2026-11-16T0000Z-project-review-recheck-reaction-verbatim.md` and
   `reviews/2026-11-15T1751Z-project-review-fixes-reaction-verbatim.md` on `main` (A-01).
2. A refusal pattern on the save path; the `BANNED` list in CO-46's builder (A-02); the wording
   of the new `HISTORY.md` chapters (A-03); `comms/2026-11-15T2010Z-…` (N-01); P-01 to P-03.
3. Items 22, 25, 26 of the list.

**Before any send**
4. Regenerate `reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md` or
   mark it as the state before the review fixes (B-05).
5. CO-35: say in `COPIED-FROM.md` that the covers describe the whole first patch (3.4).
6. CO-02: `BRIEF.md:193` and `README.md:161` still say the cover is to do; CO-30's README path and
   checksum file; the 11-15 status report's CO-02 paragraph.
7. CO-43: the `HELD.md` sentence; notes and send commands for `A-review-fixes-20261114/`.
8. CO-38: `send-20261114/README.md:14-16`. CO-11: the front page and index row. CO-23: the old
   `send.sh`. CO-46: the register row, a row in "What to send", the six paths not on `main`, the
   `From:` placeholder (B-08 to B-10).

**Code**
9. `tools/verify-restored.sh:128` (B-01); `tools/bt-backup-journal` after a refused re-archive
   (B-02); the keeper's ownership check (B-03); `guard()` on a closed window (B-06).
10. `tools/lib/journal.sh:169-176`; `tools/bt-trial:782`, `:1032`, `:1056`; `scripts/ci-local.sh:659-669`;
    `scripts/bt17-provoke.py:131`; `scripts/build-btusb-stable-matrix.sh`; CI's identity job on a
    forced update; `repo-scan --range` on a new branch; `devtools/repo-scan:239-242`.
11. `install.sh` under `--tools-only` (the stamp, two messages); `tools/bt-incident`'s manifest.
12. The Low script items in untouched files (companion file).

**Documents**
13. `BRIEF.md`: `:145`, `:193`, `:215-216`, `:225`, `:315-317`, `:573`, `:689-691`, `:747`, `:825`, and a
    hand-off block that knows 11-15 and 11-16.
14. `docs/STATUS.md:88`, `:109`, `:267`, the truncated hashes; `docs/issues.md:811`, `:840`, `:898-900`,
    `:1102`, `:1550`, `:1567`, `:2122`, `:2130`, the U13 and U29 owners, U12's history.
15. `docs/investigation-plan.md:60-61`; the eleven older `docs/` files (D-01, D-02);
    `docs/sent-mails.tsv:7`, `:11-13`.
16. `patches/bluez/README.md:145`, `reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4`,
    `HISTORY.md:3346` (one reading of the bot time); `patches/diag/README.md:52`, `:126`;
    `patches/kernel/README.md:22`.
17. `reviews/README.md` (two files, `:170`, `:312`, `:63`, `:326`); `README.md:299-303`.
18. Dossier pages: CO-01, CO-03 (`:3`, `:9`), CO-04, CO-05, CO-06, CO-07, CO-09 (`:5`, `:34-48`),
    CO-14's row, CO-27, CO-28, CO-36, CO-39, CO-40, CO-44; the checksum files that fail (CO-04,
    CO-05, CO-12, CO-14, CO-30, the bundle); `contributions/README.md:22`, `:25`, `:105-115`, `:162`.
19. `HISTORY.md:11-12`, `:913-915`, `:4121-4124`, `:5020`, `:5030`, `:5146`.
20. `evidence/README.md:85`; the index pointer for EX-093 and EX-086; notes for E3 #6 to #11.

**Tests**
21. `tests/run-tests:2203`, `:3964`; `tests/machine-tools`; the staged `--apply` tests; the shell
    filter of the light mode; the Low items of 3.3.

**To confirm on a machine or a full clone**
22. `git merge-base --is-ancestor 8b71499 main` and the same for `a56141e` (3.6).
23. `scripts/sco-ledger.sh` on a boot of the laptop without a call (the list says it was not run).
24. Ownership and mode of the checkout that the keeper's root timer runs from (B-03).


## 3. Detail

Line numbers are those of `main` at `bbec102f`.

### 3.1 The working arrangement in the text (items 24 to 26): worse, and urgent for the author

The maintainer's list records item 24 as waiting for the operator, "asked again on 2026-11-16,
with N-01 named". While it waits, `main` gained text of exactly this kind, and no scan pattern
was added (`devtools/repo-scan` has none), so the forward-only approach that was proposed is not
in force.

- **A-01 (High, privacy, new, checked): the reviewer's chat messages are stored on `main`
  verbatim.** `reviews/2026-11-16T0000Z-project-review-recheck-reaction-verbatim.md`:
  - lines 12, 14, 18 and 50 of that file (not repeated here; the file has since been removed
    from the tip of `main`, see the page of 2026-11-16 that follows this one).
  The branch name was replaced by "[a separate branch]"; these four lines were kept. Read
  together they say that the commits under the author's name on that branch were made by
  something that is not the author, and that a hook exists to keep it so. This is the single
  most quotable text in the repository for the purpose the author fears, and it is on the
  public default branch. `reviews/2026-11-15T1751Z-project-review-fixes-reaction-verbatim.md`
  is the earlier message of the same kind (less explicit). Removing them needs a history
  rewrite (`BRIEF.md` §7, the backup-branch rule) or at least a follow-up commit that replaces
  the files; the second keeps them in history.
- **A-02 (Medium, new):** `contributions/CO-46-systemd-journalctl-file-count-slowdown/build-review-package.py:25-27`
  is a third filter that names what it hides: a `BANNED` list with five product and model
  names, the work-area directory name, and the word for the shortening of a long conversation.
  The review's P-03 said this of `contributions/review-2026-11-02/build/build.py`; the pattern
  was repeated on 11-16.
- **A-03 (Medium, new):** the `HISTORY.md` chapters added on 11-15 and 11-16 describe the work
  as "five lanes at once", "four fix lanes, one per area", "one lane fixed them", "lane 11". The
  older blocks, not listed in the review, say more: `HISTORY.md:5754-5756` "**Agents:** the
  weekly limit of 11-02 ended 2026-11-05 09:00. The rule that remains: cheap agents for
  per-file reviews, the main context synthesises."
- **N-01** (the pasted transcript in `comms/2026-11-15T2010Z-…`): unchanged.
- **P-01:** the work-area path is now in 2,714 files and 11,062 lines (2,716 and 11,068 at the
  review): the authored copies in `docs/STATUS.md` and `docs/issues.md` were replaced, the logs
  remain. **P-02, P-03:** unchanged, apart from `BRIEF.md:208`, which no longer spells the path
  ("the lanes' directories `lane<N>-*-20261114/` in the work area").
- **Item 25 (P-04):** the list says the review was partly wrong, and it is right:
  `contributions/CO-25-qualcomm-rom-report/log.md` does say all fifteen were refused with `535`
  and revoked. What the list adds stands: the check used port 465, which the project's own
  fixed `smtp-login-check.sh` would now have to confirm on 587; not recorded.
- **Item 26:** unchanged; the review pages are on this branch only.

What the author may want to decide today, in this order: (1) the two verbatim files; (2) a
refusal pattern on the save path for the work-area name and the words of 3.2 of the review,
so that the count stops growing; (3) a rule that a reviewer's or a maintainer's message is
stored as its content (findings, numbers), not as its running commentary.

### 3.2 Code in `tools/`, `bin/`, the installer (the list's items 7, 9 to 12)

**Confirmed on the files:**
- Item 7 (T-08): `tools/bt-archive:362-387` counts every `boot-<id>.export.*` whether or not the
  new file's own name exists; an archive that cannot be decompressed blocks the replacement and
  is not swept; `--replace` is in the usage; tests at `tests/run-tests:15805-15880`. Read by the
  lead reviewer too.
- Item 10: `tools/bt-trial-audit` reports an unreadable window as UNRESOLVED (exit 2);
  `hci_alive`'s "cannot tell" gives `ended_unprobed`; the `bt-trial` header says which verbs
  send HCI; `start` sets a reused directory aside.
- Item 11: `install.sh` installs `bt-journal-files` and its units and writes the event unit's
  device drop-in; `uninstall.sh` and `tools/verify-restored.sh` know them; `tools/bt-verify-install`
  counts an artifact missing in the checkout and does not demand the archive unit from another
  checkout; `bin/bt-evidence` probes only with `BT_EVIDENCE_PROBE=1`; `bin/bt-usbmon` writes
  0700/0600; the dyndbg comment and `bt-mode` header agree.
- Item 12: `docs/restore-original-state.md`, `docs/changes-applied.md`, `docs/install.md`; "two
  controlled demonstrations" in the tooling index, the plan and the proposal.
- T-01 to T-03, T-06, T-11 and the Low items listed with T-11 (`bt-snapshot` by VID/PID,
  `bt-retention`, `evidence-window.sh`, `bt-journal-files`' guard, `bt-backup-journal`'s wording,
  the help ranges): fixed. Twelve earlier fixes spot-checked, none regressed.
- Item 14, T-04: the list is right and the review's wording was imprecise: `tools/bt-status` has
  a default that the variable overrides, not a hard-coded device. The README's narrowed sentence
  is correct in substance; its "27 of 38" is 27 of 40 files under `tools/`, and it omits
  `bt-diagnose` from the tools it names.

**Partly, or not so:**
- Item 10, `tools/lib/journal.sh`: "ends in status 2 on any failed or unreadable file" holds for
  `bt_journal` and `bt_journal_lines`; `bt_journal_count` and `bt_journal_first` (`:169-176`) still
  swallow a partial read.
- `tools/bt-trial:782`, `:1032`, `:1056`: the three journal reads before the results row still have
  no budget (T-09); the probe, abort and previous-shutdown counts still record 0 when their
  read fails; `abort --discard` still removes the directory (`:1210`).
- `install.sh`: `--tools-only` still writes the `installed-at` stamp; `:367` and `:819` still print
  the watchdog and "expect N" text under `--tools-only`; the redirect-written files still get no
  `.pre-qca9377-bt-hang` copy; `systemd/bt-usbmon.service:18` `BT_USBMON_BUS=3`.
- `tools/bt-incident:103-110`: the comment says the manifest records a missing timeline; nothing
  writes it there. `tools/sanitize-logs.sh`: the gap is documented in the header, and its final
  line "verified: no MACs, BSSIDs, UUIDs or IPv4 addresses remain" and the README sentence are
  unchanged.
- N-11: `shorter-boot-*` exports are still not listed; the list says open.

**New with this round (Low unless marked):**
- **B-01 (Medium):** `tools/verify-restored.sh:128` still counts `enable_autosuspend=N` as a
  failure. `uninstall.sh` now never reloads btusb, and `docs/restore-original-state.md:84`, `:88`
  say N is expected until the next boot, so a correct uninstall followed by the verifier exits
  1 whenever btusb is loaded.
- **B-02:** when `bt-archive` refuses a shorter re-archive and the `.prefix` marker stays,
  `tools/bt-backup-journal:156-158` tries again on every run, exits 1 each time and overwrites
  `shorter-boot-<id>`: the timer unit keeps failing. A corrupt old archive counts as few or no
  records and can still be replaced; the refusal message prints "records + 1" as if it were a
  count.
- **B-03:** the new keeper of `tools/bt-ui-capture` (`enable-light`): a root timer runs
  `"$SELF" start-light` every two minutes with no check that the script and its directory are
  owned by root and not writable by others (to check on the machine); `disable-light` prints
  "stopped and disabled" whatever `systemctl` returned; the option `--quiet-if-no-session` means
  "print only on a change".
- **B-04:** the `MISSING IN CHECKOUT` branch of `tools/bt-verify-install` prints the advice to
  run `--tools-only`, which cannot repair a checkout.

### 3.3 Tests (item 23)

**Confirmed:** `tests/README.md` (20 rehearsal checks, six wrappers), `tests/whole-boot-reads.txt`
(43 reads in 23 files), `autostop` in the guard with a new check that derives the verbs from
`tools/bt-trial`, `--section` passing `--jobs`, the results-width check, the weak globs, the
duplicate description, the fixture no longer built from the live `results.tsv`, the
`system-roundtrip` gate and its minimum of ten destinations. Item 9's test: ten stubs first on
the path, and it asserts exit 2, "REFUSED", "EX-046" and that no stub was called
(`tests/run-tests:16124-16140`); the refusal sits before `guard`. The identity switch is no
longer exported for the whole suite and is listed in `tests/system-resources.md`. In about
1,260 added lines no new check was found that cannot fail.

**Not so, in part:** "the four `|| true` checks" fixed: the awk `-f` trap check
(`tests/run-tests:2203`) and the exhibit scan (`:3964`) still end in `|| true`.

**Left (all Low):** rule 4's sentence about `BT_REPO` (`tests/README.md:67` against
`tests/run-tests:2355`, `:5653`); the fixtures table of `tests/README.md:301`; stale comments
(`:268`, `:2031`, `:3779`, `:3790`, `:5054`, `:6538`, `:6567`/`:6611`, `:6706`, `:9961`); the
`shift 2` scan that excludes `tools/lib/journal.sh` by path (about `:15800`) and its hard-coded
"all 18 option loops" (`:15788`); two new weak globs (`:16094`, `:16098`); the session-count
checks that total two directories (`:8124`, `:8192`). Open by the list's own word: 41 "pending"
whole-boot reads, `tests/machine-tools`, the staged `--apply` tests.

**New (Low):** the new tooling-index check (`tix_named`, about `:3385`) accepts a bare file name
anywhere in the index, so for nine executables "named" can mean the word occurs in prose; the
sanitiser test (about `:14000`) pins that IPv6 and two other forms are left unredacted, so
improving the tool fails the suite (it says so itself); `BT_REPO_SAVE_CONFIG_IDENTITY` stays set
for the rest of a worker if a check between its export and its unset fails.

### 3.4 `patches/`, exhibits, dossiers CO-01 to CO-35 (items 1, 3, 6, 15, 17, 18, 20)

**Confirmed:**
- Item 1 (N-03): the eleven mails in `CO-35-…/review-fixes-20261114/mail-from-send-20261114/` are
  byte-identical to `send-20261114/mail/` (SHA-256 compared), `COPIED-FROM.md` and both checksum
  files verify, the table row points there.
- Item 3: the six markers exist; CO-20 has `recipients.txt`, CO-21 has notes and recipients and
  its cover no longer says "Changes since the first draft"; the index rows of CO-04, CO-05,
  CO-20, CO-21 carry dated pointers; the Signed-off-by exception for CO-35 is written in the table.
- Item 6: the dossier, `BRIEF.md:203-206`, `BUNDLE.md` and the index row now name both builds
  (`co03.1`, staged, with the BT-7 fixes; the bundle's `5.72-0ubuntu5.9`, without). The read of
  the staged package itself cannot be checked from the tree.
- Item 15: `docs/STATUS.md:50` names the v4 draft; the CO-34 cell; the M rows in order.
- Item 17: EX-043, EX-038 and EX-057 state their gaps; the seven exhibits say "Historical claim"
  in their own label and in the generated index (97 of 97 rows match; nothing quoted the old
  labels). `BRIEF.md` no longer sums EX-055, EX-056 and EX-058.
- Item 18: the two check scripts resolve a relative `BT_PATCH_DIR`; `patches/kernel/README.md`,
  the `v2/` row, `patches/bluez/btdev-vla/README.md`.
- **Withdrawn by the review:** E-04's remark that `BRIEF.md` attributes "alt 1" to EX-031; the
  wording there is `evt 5` and `len 27 mtu 9`, which the exhibit has.

**Partly, or not so:**
- Item 17: the index marks the seven rows with the word only. `tools/bt-exhibit:276` drops the
  parenthesis, so EX-093 and EX-086 show no "superseded by EX-094 / EX-087" in the index.
- Item 20, "dossiers corrected": true of CO-03, CO-09 (its State paragraph), CO-37, CO-38, CO-39,
  CO-41, CO-44. Not touched: `CO-11-…/README.md:6` and its index row (`contributions/README.md:96`)
  still name `ubuntu/ready-20261102/`, which is marked superseded; `CO-04-…/README.md:3` and
  `CO-05-…/README.md:9` (state of 10-29) and `CO-04-…/send-20261114/README.md:4` ("The send file
  is `patch/0001-…`"); `CO-03-…/README.md:3`, `:9` ("0/70 → 70/70"); CO-01, CO-06, CO-07 old
  "State:" lines and `BRIEF.md:111` (CO-06 "must be re-run first"); CO-23 (`README.md:6`,
  `patch/send/send.sh` still present, the notes' "still wrong" list); CO-28 `:52`; CO-27 step 4;
  `contributions/README.md:99` (CO-14 "idea"); `contributions/README.md:22` (a "superseded line at
  its top" where the marker is a separate file).
- The list's last note says CO-09's boot time is not settled. `docs/issues.md:43`, `:1070` and
  `BRIEF.md:82`, `:116`, `:179` settle it as 22:55; only the CO-09 banner (`:5`) says 22:57.
- CO-30 (item 2): the dated note and the table say "not re-tested"; `rfc-20261114/README.md:3`,
  `:27` still name `../co02-v2/…`, and its checksum file still fails.
- CO-35: `docs/issues.md:898-900` still says "7.3.y and 7.2.y … (`send-20261102/`)".
- `patches/`: the bot time is now "CEST most likely" in `patches/bluez/README.md:150-153` while
  the heading at `:145` and `reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4` still say UTC;
  `patches/diag/README.md` has a dated note and its body (`:52`, `:126`) unchanged;
  `patches/kernel/README.md:22`; `patches/diag/stable-request-dc16388d45ec.md:9`; the three
  address-elided hashes in `docs/sent-mails.tsv:11-13`; `HISTORY.md:5020`.
- Checksum files that still list files not in the tree or fail: CO-04, CO-05, CO-12, CO-14, CO-30.
- E-02: `BRIEF.md:139` now says rows #6 to #11 are unexplained and excluded; it says "#3 to #11
  all `failed`", which includes #9, a `confirmed` row.

**New (Low):** the CO-35 covers say the first patch is "sent whole as merged, 78 changed lines",
and `COPIED-FROM.md` offers the reduced patch 1 as a drop-in without saying the covers would then
be false; `CO-03-…/README.md:14-22` gives the bluetoothd hash as `59d2ea79...` (no full value in
any file) and cites an `artifacts/…deb` that is not on `main`, and `docs/STATUS.md:267` attaches
that hash to the package where the dossier says it is the daemon's; the new session
`evidence/sessions/20261116-002107-shure-paired-in-handsfree-no-codec-row/NOTES.md:40-42` prints
a local home path (`/home/i/…`), the first in `evidence/`.

### 3.5 `scripts/` and `devtools/` (items 8, 9, 10 and the commits of 11-16)

**Confirmed:**
- Item 8 (N-02): `scripts/sco-ledger.sh:34-37` must read one line or it exits 2; at `:57-62` an
  exit 1 with empty standard error is a measured zero, anything else exits 2. Read by the lead
  reviewer; no ordinary path was found where a real failure becomes a zero. The list is candid
  that it was not run on the laptop's journal.
- Item 9: `scripts/runtime-mgmt-test.sh:94-98` refuses `load` and `restore` before anything
  else; the swap code is gone; `guard()` (`:50-70`) refuses when a tool is missing or silent; the
  daemon and `trigger` verbs are described as disturbing the controller.
  `devtools/repo-save:48-77` refuses the identity switch in the project's checkout, in any clone
  of it, on a non-local `url` or `pushurl` and on URL rewrites, before staging;
  `tests/run-tests:16276-16330` pins each case.
- Item 10: `scripts/compile-mgmt-at.sh:29-33` goes by `patch`'s exit status. Fifteen of the
  first half's script findings and eleven of the second half's are fixed, among them
  `btusb-has-device.py`, `build-bluetooth-fulltree.sh`, `discovery-stop-race.py`,
  `journal-archive-grep.py`, `bt-device-record.sh`, `export-local-work.py`, the five `prove-*`
  scripts, `bot-ci-local/harness.py`, `supported-commands-survey.sh`, `desktop-capture-archive.sh`,
  `kernel-preflight.sh`, `get-maintainers.sh`, `gitlint-check.sh`, `export-kernel-review.sh`,
  the six `/root/exp` paths.
- `devtools/`: the gates `awk-coverage` (no gawk), `journal-contract` and `ci --recent` exit 2;
  `repo-validate` handles symlinks and odd file names; `repo-scan --range` scans commit by
  commit; `.gitignore`'s comment; `checks.yml:26` "NINE JOBS".
- The Message-ID fragment in the allow-list: the list's explanation holds, and a test refuses
  another address at that host.

**Partly, or not addressed:**
- `scripts/ci-local.sh:659`, `:660`, `:669`: a functional configure, build or junit failure still
  compares as PRE-EXISTING and exits 0. `scripts/bt17-provoke.py:131`: a device that disappears
  still loops "waiting" and ends 0.
- `scripts/build-btusb-stable-matrix.sh:78`, `:80` (pass condition fixed to `13d3:3503`), `:11`,
  `:22` and `scripts/backport-check.sh:7`, `:20` (stable list of 2026-10-02, no 7.3.y).
- CI's identity job after a forced update examines the pushed tip only (`checks.yml:63-70`);
  `repo-scan --range` on a new branch still uses `--not --remotes`, while `repo-save` was changed
  to `--remotes=origin` for the same reason; `awk-coverage:379-384` turns a red suite into a
  failure only with `--min`.
- `devtools/repo-scan:239-242`: the wider allow-list (`noreply@` and `no-reply@` at any host,
  `modprobe@`, `systemd-`, one private-looking address) is unchanged, and three more exact
  tokens were added. `devtools/held:69`, `:74`. `devtools/README.md:246`. `devtools/save:160`.
- `README.md:299-303` still cites a branch convention "in `reviews/README.md`", which has none.
- About twenty-five Low script items in files not touched (listed in the companion file).

**New with this round:**
- **B-05 (Medium, checked):** the outside-review document
  `reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md:3850` records
  SHA-256 `7713f414…` for `contributions/CO-21-btusb-sco-alt-setting/review-fixes-20261114/0000-cover-letter.patch`;
  the file now hashes to `7a677049…`, because commit `9fdee116` rewrote the cover's change
  paragraph. `scripts/kernel-review-pack/build.py` says to rerun after any package change. The
  other 52 pairs match. (And that document still embeds the packages of before the review
  fixes.)
- **B-06 (Low, checked):** `guard()` refuses whenever `tools/bt-window` exits non-zero, and
  `tools/bt-window:156` exits 1 for a window that is closed or treated. After an incident has
  been dealt with, the daemon and `trigger` verbs answer "no usable answer (exit 1)". The test
  at `tests/run-tests:16164` models the no-timeout case with exit 1, where the real tool prints
  that line and exits 0 (`tools/bt-window:77-80`).
- **B-07 (Low):** `scripts/README.md` now states two rules its scripts do not keep: "no
  machine's paths" (`scripts/bt-trace-archive.py:35`, `scripts/raw-capture-archive-all.sh:6`) and
  "`|| true` only with the hidden status named" (`scripts/ci-local.sh:292-293`, `:606`, `:664`).
  `scripts/cd-trace/trace.py:47-50` and `record.py:22-25` start `strace` before a user lookup that
  can raise. `scripts/sco-switch-windows.sh`: the new branch for status 141 is dead code.

### 3.6 `BRIEF.md`, `README.md`, `docs/STATUS.md`, `docs/issues.md`, `HISTORY.md`, `reviews/`, `comms/` (items 13 to 16, 19 to 22)

**Confirmed:**
- Item 13, every sub-claim: the `-42` line, the persistent `bt-raw-archive.timer`, the open
  investigations, `tests/test-suite`, "Last updated: 2026-11-16", survivals in the plural, the
  trial directory set aside (matches `tools/bt-trial:312`), `build=stock` qualified (`:143`), nine
  CI jobs, the device survey recorded as dropped with its source.
- Item 14: the CO-02 and CO-25 bullets, the next candidates, the `BT_VID` sentence, the CO-35
  scope, the `patches/diag` line.
- Item 15 and 16: U26 and U27 evidence rewritten; the archiver dates; the 10-18 branch survey
  marked superseded; BT-18 to BT-23 and BT-25's "Next" brought to 11-14; U12's "Next"; "On the
  wider claim" dated; U13 with two owners in STATUS (the list is right: CO-27 for BlueZ and
  CO-42 for GNOME, not CO-42 alone); the note that U21 to U28, U30 and U31 have rows only.
- Item 19: 65 rows in the new "Files not listed" section of `reviews/README.md`; R2-21 and R2-25.
- Item 20: six dated notes in `HISTORY.md` (`:913`, `:1861`, `:2727`, `:3278`, `:3343`, `:4122`),
  the moved blocks untouched; the milestones.
- Item 21, the 19 paths: `CO-nn-…` and `comms/` paths are written in full in STATUS,
  `docs/issues.md`, `README.md` and `BRIEF.md`.

**Partly, or not so:**
- Item 21, "three truncated hashes have no full value": the count of truncated hashes left is
  about 18 (14 in `docs/STATUS.md`, 3 in `docs/issues.md`, `BRIEF.md:825`), and at least one has
  its full value in the tree: `docs/STATUS.md:50` `1f81392a…cbf7` is in
  `contributions/CO-25-qualcomm-rom-report/log.md:270`. Elided paths remain in
  `contributions/README.md:105`, `:106`, `:115`, `:162` and in `contributions/rd-2026-11-14.md` (11).
- `BRIEF.md:225` (the hand-off): "CI: green on every push since `2a3f253`" is not marked,
  while `HISTORY.md`'s new chapters record five red runs on 11-15 and three on 11-16. The
  hand-off block is dated 11-14 and does not mention CO-46, the light mode, U21's recurrence or
  the review; those are only in `HISTORY.md`.
- `BRIEF.md:193` and `README.md:161` say CO-02's cover is still to do; the table
  (`contributions/README.md:47`) says `msg/cover-alt.txt` was rewritten on 11-16, and it exists.
- `BRIEF.md:215-216` still lists lanes as running, CO-38's flake as "not shown" and CO-39 and
  CO-41 as "no report yet". `BRIEF.md:145` says the test-suite maintainer "merges `main` into"
  the branch; the messages say it is rebased. `BRIEF.md:689-691` (§9.2's six tasks). `BRIEF.md:573`
  (the lessons files). `BRIEF.md:747` (v2 "prepared … operator's decision"). `BRIEF.md:315-317`
  ("the one reset issued before any timeout"; `HISTORY.md:913-915` now says the conflict with
  Phase 10 is "not settled here", and the exhibit dates settle it).
- The bot time has three readings now: `BRIEF.md` §6 (3 h 21 min by the UTC label),
  `HISTORY.md:3343` (not established), `patches/bluez/README.md:150-153` (probably CEST, 81 to 86
  minutes). `HISTORY.md:3346` says "`BRIEF.md` §3 has the same correction"; it is in §6.
- `docs/issues.md`: U8 has a dated note under an unchanged "that test is next" (`:1550`), and
  `docs/STATUS.md:109` still says "installable only after trial E3 #1 closes" (the first recheck
  called S-08 fixed; that was wrong, the phrase had only moved in the cell); the U13 and U29
  sections name no owner; U12's two histories; U10 (`:1567`); "Why this class of bug goes
  unreported" (`:2122`, `:2130`); the BT-9 header (`:811`, `:840`); "five patches" (`:1102`,
  `docs/STATUS.md:88`); `:898-900`.
- `reviews/README.md` does not list the two newest files of 11-16; `:312` cites
  `tools/bt-trial:465-466` where the call is at `:490`; `:170` "329 invariants"; `:63`, `:326`
  the `review/…` branches. `reviews/2026-11-15T0115Z-submitted-contributions-status.md` still
  calls CO-02's lock cycle "possible … not settled" and names the superseded package.
- The ports `8b71499` and `a56141e` that `BRIEF.md:228-231` and `docs/STATUS.md:463` call "on
  `main`": in this clone they are not ancestors of `main` and are reachable only from older
  remote branches. The clone is shallow, so this needs one command on a full clone:
  `git merge-base --is-ancestor 8b71499 main`.
- Open by the list's own word, and unchanged: D-01, D-02 (eleven older `docs/` files without a
  date label; `docs/missing-quirks-entry.md` is still "the full argument" in `README.md:103-106`),
  S-12, the requests in `comms/` to and from the second maintainer.
- `docs/investigation-plan.md:60-61` still says "three demonstrations", two lines under the
  corrected paragraph.

### 3.7 CO-36 to CO-46, and the new CO-46 material

**Confirmed:** items 4 and 5 (the CO-43 held notes, STATUS BT-18, the CO-38 cover's `From:`), the
front-page notes of CO-37, CO-38, CO-39, CO-41, CO-44, the bundle's placeholder wording, the
`rd-2026-11-14.md` corrections, U23 and U24.

**Not so:** `CO-43-…/send-series-20261114/HELD.md` says the series cover's "1 to 4 objects per
run" quotes the re-run; the re-run's `kml-e.txt:8` has 5 objects, so the cover quotes the first
run.

**Left (Low unless marked):** `CO-38-…/send-20261114/README.md:14-16` still says the flake is "not
shown" directly under the note that says it is one (Medium); CO-40 ("bundle … or file alone");
CO-39's send README title; CO-44 `README.md:18-23`; the bundle's checksum file (7 lines fail);
CO-37's send README `:51`; CO-36; CO-43's `A-review-fixes-20261114/` still without notes or send
commands.

**CO-46, new since the first recheck:**
- **B-08 (Medium):** the dossier says the cause is found and a stable-update request is drafted
  (2026-11-16); `contributions/README.md:151` still says "not yet checked against systemd main",
  `contributions/rd-2026-11-14.md:86` "not started", and CO-46 has no row in "What to send".
- **B-09 (Medium):** six paths the dossier's tables rest on are not on `main`; they exist only
  on the remote branch `research/journalctl-file-scaling`
  (`results/journalctl-file-scaling-{cause,verify,host,remaining}-…`,
  `results/journalctl-sru-packaging-2026-11-16/`, `patches/systemd/journal-file-scaling/`).
- **B-10 (Low):** the packaging patch has `From: <AUTHOR-NAME> <AUTHOR-EMAIL>`; `sru-noble/` is
  called self-contained and has no checksum file; "477.7" in the README against "477.8" in
  `evidence.md:45`. `reviews/2026-11-16T1300Z-co46-noble-sru-review-reviewer-7-verbatim.md`
  promises a `-checks.md` that is not on `main`, and keeps the line "Worked for 3m 1s" (see 3.1).

### 3.8 CO-02 (item 2), read by the lead reviewer

**Confirmed:** `contributions/CO-02-sco-connect-reuses-closing-link/review-fixes-20261115/msg/cover-alt.txt`
describes two patches and no longer mentions a third; it says l2cap-tester and the laptop were
not run; `patches/alt-2of2/` holds `[PATCH v2 1/2]` and `[PATCH v2 2/2]`; the directory has a
checksum file and it verifies; `send-v2-20261114/SUPERSEDED.md` names the current candidate; the
dossier README has a note of 2026-11-16 and `log.md` an entry of that day (44 of 44 checksum
lines verify, by the CO-02 reader). Left: item 6 of section 2, and from the CO-02 reader:
`docs/STATUS.md:52` (the CO-02 submission row) ends at the 11-13 note although the dossier calls
it the current record; `BRIEF.md:93` keeps the 11-02 description of v2 and `BRIEF.md:242` the
D1/D2 gloss; the cover's "33 of the 35 posted cases" and "base 31" are not recorded as such in
the new directory (its README has "44 cases: 35 pass, 2 fail, 7 not run"; the raw logs are not
in the tree, as it says); the cover no longer mentions that v1's patch 1 ran on the laptop 3 of
3 (EX-075 to EX-077); patch 2's message has one line of about 96 characters.

## 4. Corrections to the earlier pages of this review

- **S-08** was called fixed in the first recheck. It is not: `docs/STATUS.md:109` still says
  "installable only after trial E3 #1 closes". The maintainer's record had it right.
- **T-04**: `tools/bt-status` has a default that the variable overrides; "hard-codes" was wrong.
- **R-01, CO-03 against the bundle**: not a contradiction, two builds that were not told apart.
- **P-04**: the dossier's log does say all fifteen passwords were refused and revoked.
- **E-04, EX-031**: withdrawn (3.4).
- **IS-07, U13**: two owners, not CO-42 alone.

## 5. Companion file

Each part's verification as written, with the current line and a short quote for every item:
[`review-second-recheck-of-comprehensive-project-review-20261116-132247-detailed.md`](review-second-recheck-of-comprehensive-project-review-20261116-132247-detailed.md)
