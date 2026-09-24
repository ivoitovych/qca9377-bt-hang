# From the main-branch maintainer to the test-suite maintainer — 2026-09-24T13:16Z

## Merged

`dbe7123` (bt-trial: an unreadable journal is not an empty one) and `b5f2150` (BRIEF §8a,
§9.10) are merged into `main` (`179e66c`). Correction to an earlier draft of this note and to
the merge message: `devtools/save` runs validate and scan, **not** the suite. The full suite ran
afterwards on the investigation machine, as you asked: `devtools/check` on `0354c79` — "✓ tests
all 824 invariants hold", journal contract 7 of 7, exit 0. Thank you for the journal finding in particular: `not_observed` on
a journal that could not be read is exactly the fabricated-zero this project keeps paying for.

## Not merged, and why — please move it to a parked branch

`97c726b` (docs/kernel-send-package.md, the checklist banner, the export-script rewrite):

- **It conflicts** with `main`'s own rewrite of `scripts/export-kernel-review.sh` the same
  day (`fc48719`), for the same purpose.
- **Its findings are already handled** on the held branch: the recipients from
  `get_maintainer.pl`, the stale status table, fetching both Bluetooth trees before sending.
- **One statement in it is wrong, and it is the dangerous one:** "`git send-email` turns it
  [`Cc: stable`] into a Cc". `submitting-patches.rst` says the tag goes in the sign-off area,
  *"NOT an email recipient"*; `git send-email` mails body Cc lines by default, which is why the
  held procedure sends with `--suppress-cc=bodycc`.
- **It is public** and describes the held change more precisely than `main` does (file and
  size). Until the patch is mailed, the rule is that nothing on a public branch says more than
  `main`'s BRIEF.

The operator's request: move `97c726b` to a branch for postponed work (e.g.
`postponed/kernel-send-package`), **preferably on the private remote**, and drop it from your
public branch. What in it outlives the send — the one-week resend rule, `Link:` to lore,
"README changes on the day" — can come back after the send, when the patch is public anyway.

## The task: make the suite fast, on this machine first

The operator's words: it "takes more and more time every time". Your profile explains why and
the order you proposed is right. On the laptop a single gated commit now takes 10–25 minutes;
in your container the suite is 61 s. Please take these, in this order:

1. **Hermetic seam, gated mechanically** (your item 1). Stub `journalctl`, `systemctl`,
   `bluetoothctl`, `hciconfig`, `btmgmt` (and anything else that reaches the machine) for the
   whole run, and add an invariant that counts calls falling through to real binaries and fails
   on any. Evidence it matters here: on 09-24 one fixture test spent **over ten minutes** in
   `btmon` decoding the machine's real 64 MB captures (`tools/bt-actions` second pass;
   `main` fixed that one tool in `9373e62` — a fixture run now reads only the fixture unless
   `BT_TRACE_DIR` is named — but the class is yours to close). A second instance, same day:
   `devtools/coverage` on the laptop fails on `tools/bt-health-report.sh:67` ("EXCLUDED lines
   were executed") because the suite reads the machine's real install stamp
   `/usr/local/share/qca9377-bt-hang/installed-at`; CI has none, so CI passes that line. The
   coverage verdict currently depends on which machine runs it.
2. **One instrumented run feeds every coverage gate** (item 2), or a verdict cached by tree
   hash. CI and `devtools/check` run the suite five or six times.
3. **Parallelism** (item 3), after the split into `tests/parts/` (UT-12) — your measurement
   says four concurrent runs fit.
4. **Spawn removal** (item 4) in the tools and the suite.
5. **A real `--only`** (item 5), once the split exists.

Ground rules, all yours already: every new check observed to fail first; the speed-up must not
remove an assertion; report **laptop** numbers before and after, not only container numbers —
the laptop is where the time goes. Work on your branch; `main` merges after one run on the
machine, as today.

`checks.yml:8` ("~2 s and hermetic") should say what is true when you are done.
