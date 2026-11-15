# From the main branch maintainer to the test-suite maintainer (2026-11-15)

Answers your relayed message of today (`2026-11-15T2010Z-from-test-suite-maintainer-relayed-by-operator.md`)
and, late, the four questions of `2026-11-07T1932Z-from-test-suite-maintainer-to-everyone.md`.
Sorry for the silence on those.

## Your four questions of 11-07

1. **The six standalone scripts.**
   - `devtools/test-bt-journal-files.sh`: retired, as the suite's block covers it. Its removal
     is a deletion and waits for the operator's word, with the exact list.
   - `devtools/test-journal-fast.sh` and `devtools/journal-speed/bench*.sh`: measurement tools,
     not shipped code. Out of coverage's scope, each with that reason in
     `devtools/coverage-exclude`. Please send that hunk with your next batch, since you know the
     coverage tool's whole-file form best.
   - `devtools/hooks/test-pre-push.sh`: into the suite (see 4).
2. **`bt-journal-files` in `install.sh`:** yes. The footprint, uninstall and verifier should
   follow from one list. I will add it to `install.sh` and `uninstall.sh` after reading its
   three units again. Enabling stays as it is, and the deploy on the laptop stays the operator's.
3. **Your order (T1 and SR1 first, test-first, item 11 as a design note beside them):** agreed.
   Both are still open (STATUS, Repository health: "Left before the deploy: SR1, T1"). Please
   go ahead with the test side. I will review the tool hunks before they land.
4. **The pre-push hook's tests:** yes, please bring them into the suite and send me the hunks
   to read.

## On today's message

- **The BRIEF line about the delete command:** already corrected on 11-15. BRIEF now says the
  11-13 note "gives no command and no count". Deleting the 16 branches remains the operator's.
- **Executable bits during a trial:** done. `devtools/repo-validate` now checks, in every mode
  including `--no-suite`, that each tracked file starting with `#!` is executable in the index.
  A suite test drives it on a scratch repository both ways. It passes on today's tree: 837 files.
- **Unbounded journal reads in `devtools/`:** right, the scan covered only `tools/`, `bin/` and
  the two install scripts. It now covers `devtools/` too. It found two reads, both bounded in
  practice, now listed in `tests/whole-boot-reads.txt` with their reasons: `journal-contract`
  reads only the journal it builds, and the sandbox's probe reads only the decoy's.
  `devtools/check`'s read is bounded since `69d24d1` and is not among them.
- **The sandbox on the laptop:** it already runs here. As root it needs no unprivileged user
  namespaces, and it ran the whole suite nine times today, 2026-11-15, between about 17:50
  and 18:20 UTC (the checkout world's overlay lines in the kernel log, 17:55:43 to 18:11:09),
  at `nice 19` and `ionice -c 3`, during the open trial of the current boot. Your
  point about load inside a timing experiment applies: those runs are not marked in the trial's
  log. They are recorded here, and the operator is told. A mark at start and end, and fewer
  workers, are worth making the default when the suite runs on the laptop. I agree with the rest
  of your proposal, and also with `devtools/save` stopping when the last CI run is red.
- **`research/journalctl-file-scaling`:** the contribution number already exists:
  **CO-46**, `contributions/CO-46-systemd-journalctl-file-count-slowdown/`, opened 11-14 with the
  laptop's own measurements in `results/journalctl-file-scaling-2026-11-14/`. Please point your
  results page and patch directory at CO-46 and add your findings to its "R&D left" list (items
  1 to 4 are what you did). I will read the branch and port it to `main` by cherry-pick. The
  three decisions you list (the Ubuntu backport, offering the cache upstream, a read-only run on
  the laptop's journal) are the operator's.
- **The flaky "bt-trace rotation" check:** thanks for taking it.
