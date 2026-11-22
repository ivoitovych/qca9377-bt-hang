# Kernel contributions review — work log (opened 2026-11-22T12:40Z)

An append-only journal (the "work log" class in `README.md`) of the effort that produces
`2026-11-22T1240Z-kernel-contributions-readiness.md`. Every finding is written here when it is
found, before the work moves on. Nothing already written is revised; corrections are later entries.

**Scope.** Every Linux kernel contribution, submitted or possible: patches, stable backport
requests, reports to kernel maintainers or vendors, and kernel defects registered without a
patch yet. BlueZ, PipeWire, WirePlumber, gvfs and systemd work is out of scope.

**Sources, in order of authority for one contribution:** its own dossier under
`contributions/CO-nn-*/` (README, log, send directories) → the submission and issue rows of
`docs/STATUS.md` → `contributions/README.md` → `BRIEF.md` → older reports in this directory.
A disagreement between them is a finding.

**Finding format.** `F-nn` · time (UTC) · where · what disagrees or is wrong · evidence
(file:line or command) · consequence.

## Findings

**F-01** · 12:45Z · `contributions/README.md` l.104 (CO-14) · The index row's state column still
says "idea", and the same cell's note says it is not an idea any more (the leak is reproduced and the
fix written, 11-14). · Consequence: a reader of the state column alone ranks CO-14 at the bottom.

**F-02** · 12:45Z · `contributions/README.md` l.112 (CO-22), l.103 (CO-13), l.155 (CO-45) · The
three have an ID but no `CO-nn-*` folder. CO-22's material is in `research-2026-11-01/qca-ids/`
(a request at v3, an owners' call at v2). The page's own rule (l.169–170) says a dossier "is opened
as soon as anything is written about the item". · Consequence: a search over `contributions/CO-*`
misses a ready stable request.

**F-03** · 12:45Z · `contributions/README.md` l.92 (CO-02) · The row calls the 10-27 posting
"v7", then says "the next posting is **v2** (the series went out unversioned)". STATUS calls
it `[PATCH 0/3]`. The "v7" is the project's internal draft count. · Consequence: "v7" in a reply or
cover letter would confuse the maintainers. Use v1/v2 in anything sent.

**F-04** · 12:45Z · `contributions/README.md` l.99 (CO-09) · The "next step" cell still says
"when `-43` is installed … then E3 retires; until then a kernel without the entry needs E3
rebuilt first (the post-install hook is ready, not installed)". The state cell (same row) says done
(11-14). E3 was retired 11-12, and every `updates/` module was removed 2026-11-22
(`docs/STATUS.md`, machine section). · Consequence: the stale cell invites a rebuild nobody
needs.

**F-05** · 12:45Z · `contributions/README.md` l.57 (CO-30) · The RFC was tested on CO-02's
withdrawn sleeping 2/2. Its README names a base directory (`co02-v2/kernel`) that does not
exist, and it has not been re-tested on the non-sleeping 2/2. · Consequence: CO-30's test results do
not apply to the CO-02 candidate it builds on, so its readiness is below "RFC tested".

**F-06** · 12:45Z · `contributions/README.md` l.33–35 · Only CO-44 and CO-43 E have both send
commands and a checked dry run. CO-43 A's dry run (11-14) was made on an earlier file of the same
name (l.42). · Consequence: every other kernel package needs its commands and dry run made
from the project checkout before a send.

**F-07** · 12:45Z · `contributions/README.md` l.52 (CO-12) · Two opposite recommendations stand
side by side. D5 in `review-2026-11-02/followups.md` l.31 says RFC first, no `Cc: stable`. The 11-14
refresh says "the clamp now". The row records both, and the decision is open. · Consequence:
the package to send depends on an unmade decision. CO-12 is ready as code but not as a send.

**F-08** · 12:50Z · `README.md` l.223 vs `docs/STATUS.md` machine section (entry "Resolved; read
2026-11-22") · README's Environment block says "the running patched daemon is a rebuild of
5.72-0ubuntu5.5". STATUS (11-22) says the running `bluetoothd` is CO-03's build. · Not a kernel
item, but a foundation inconsistency: README is the front page and states the older daemon.

**F-09** · 12:50Z · `README.md` l.75–77 · "tested on every affected stable line and on the laptop
with three headsets" is true of the series **sent** on 10-27. It is not true of the v2 candidate
(`review-fixes-20261115/`), whose cover marks l2cap-tester and the laptop "not run" (README l.159–162,
`contributions/README.md` l.51). · Consequence: the claim must not be carried into v2's cover. In the
readiness table, CO-02 v2 counts as **not tested on hardware**.

**F-10** · 12:55Z · `BRIEF.md` l.107 and l.180–181 vs `docs/STATUS.md` machine section (11-22) ·
BRIEF says the running `bluetoothd` "lacks five CVE fixes of 2026-10-07" and that CO-03's build is
"staged on disk … not running until bluetoothd restarts". STATUS (read 2026-11-22) says CO-03's
build is the running daemon. · The same staleness as F-08, in the hand-off. Not a kernel item.

**F-11** · 12:55Z · `BRIEF.md` l.229–232 · The CI line says to read CI with `devtools/ci`. Neither
BRIEF nor STATUS records that the **access-audit** workflow has failed on every push to `main`
since at least 2026-11-16 (runs 43910811913, 43912769959, 43912852217, 44980804936; the same five
accesses each time: a test's `git clone` reading `/etc/{mailname,host.conf,hosts,resolv.conf}`, and
`devtools/repo-scan` trying to read a wording-list file outside the checkout). The `checks` workflow
passes. · Consequence: "CI green" is true only of `checks`. This is the project's tooling, not a
kernel package, but a kernel package's "local CI" claims are separate and unaffected.

**F-12** · 12:55Z · `BRIEF.md` l.104 vs `contributions/README.md` l.45–46 · BRIEF's sends list still
says "CO-04's independent fix when it is ready; CO-05 after its review". The "What to send" table
marks both "ready" and names their `review-fixes-20261114/` packages. · Stale wording in the
operator-decisions list; the table is the record.

**F-13** · 12:55Z · `BRIEF.md` l.199–202 · The one outside-review document for kernel packages is
`reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md` ("all twelve kernel
items verbatim"), answered in `reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.
Several packages were replaced after that review (`review-fixes-20261114/`, and CO-02's
`review-fixes-20261115/`). · Consequence, to check per item: the replaced packages have **not**
been through an outside round in their current form unless a later review says so.

**F-14** · 13:00Z · `docs/STATUS.md` l.52 (CO-02 row, "next" cell) · The cell still says "if Luiz
Augusto von Dentz's pending tester series … lands first, the BlueZ test needs a port". The same row
says the series landed on 10-29 (`e37f17751`). `contributions/README.md` l.92 says the test was
ported in the 11-14 v2 build. · The "next" cell is out of date. Neither STATUS row says the
port is done.

**F-15** · 13:00Z · `docs/STATUS.md` l.66 (the "Mesh advertising work" row) · The row's newest
entry is 2026-11-01. It still describes v3 (5 kernel + 4 BlueZ patches) as "being split into
separate contributions". Since then the split exists as CO-04, CO-05 + CO-26, CO-14 and CO-12,
each with a package of 11-14 (`contributions/README.md` l.45–46, l.52, l.104), and the mesh sends
were "held for now" on 11-15 (`contributions/README.md` l.46). · Consequence: STATUS, "the one
page that says what is current", has no current word on the mesh items.

**F-16** · 13:10Z · `reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` l.3–11 · The
only outside round that covered all twelve kernel packages (11-14; reviewers 1, 2, 3, 6, 7) was a
reading review: "None of them ran a build or a test". Reviewers 6 and 7 applied every patch to its
pinned base, and reviewers 2 and 3 read the source. · Consequence: "outside-reviewed" for these
items means read and applied, not independently tested. Every test number comes from this project.

**F-17** · 13:10Z · same file, l.67–69, 133–136, 170–175, 184–186, 207–211, 229–242 · After that
round, the following packages changed **code**, not only wording:
- CO-43 A: `bt_dev_err_ratelimited()`.
- CO-35: a new reduced prerequisite patch.
- CO-21: `air_mode` set first, and one locked pass instead of two counts.
- CO-43 BT-24/25: re-extracted onto E.
- CO-02 v2: both layouts.

CO-02's v2 2/2 then changed again on 11-15 (the non-sleeping alternative). · Consequence: those
packages' current code has not been seen by an outside reviewer in its current form. Each must be
checked against a later review before it is scored "reviewed". The extraction's item 11 and the
11-15 rounds should say which, if any, were.

**F-18** · 13:20Z · `HISTORY.md` l.4472–4473 · "D was judged a fallback, not a fix, with BT-18 sent to
linux-usb as a question first" reads as a sent mail. The question is **drafted only**:
`contributions/CO-43-…/README.md` l.44 ("is drafted: `drafts/bt18-linux-usb-question-20261113/`")
and STATUS l.89 ("the linux-usb question drafted"). `docs/sent-mails.tsv` has no such row (the
newest is CO-25, 2026-10-29). · Consequence: a reader of HISTORY could wait for a linux-usb answer
that cannot come. `HISTORY.md` is a narrative, so the fix is a dated correction line, not an edit.

**F-19** · 13:30Z · upstream (live, patchwork API, read 13:25–13:30Z) vs every record · **Cen Zhang
posted v2** of "Bluetooth: Fix advertising instance accesses without hdev->lock" on
**2026-11-19 00:32 UTC** (series 1215537; 1/2 = patchwork 14999296 "hci_sync: Fix remaining
advertising instance UAFs", 2/2 = 14999297 "hci_sync: Use controller handles for periodic
advertising"; state `new`, bot check `fail`). v1 (14927631) is now `superseded`. v2's 1/2 takes
`hci_dev_lock()` before `hci_add_adv_instance()` in `mesh_send_sync()` and releases it before
`hci_schedule_adv_instance_sync()` (`mgmt.c` hunks at 2347 and 2381). That is the change of **CO-05
1/2**, "Take hdev->lock in mesh_send_sync()" (`CO-05-…/review-fixes-20261114/variant-*/0001-*.patch`,
hunks at 2342 and 2381). It also locks `adv_expire_sync()` and dozens of `hci_sync.c`
advertising paths, including the extended-advertising duration code that CO-12 changes.
- CO-05's own `send-20261114/CHECKS.md` l.10 had predicted this ("it will be respun … If it
  lands, CO-05 1/2 is redundant").
- No record mentions the respin: STATUS was last re-read 11-15, `contributions/README.md` 11-16.

Consequence: CO-05 1/2 is now a near-duplicate of a posted, newer patch by another author. CO-12's
clamp must be rebased and re-checked against it. CO-04's `mesh_send_sync()` context changes.
Before any mesh or advertising send, re-check apply and behaviour on top of 14999296. The
readiness of CO-05 (and CO-26's order), CO-12 and CO-04 drops until then. Not checked here:
whether v2 still fails to apply to the bluetooth-next tip, and what its failing bot check is.

**F-20** · 13:30Z · upstream (live) · Unchanged since the 11-15 re-read, and so confirmed:
- CO-02's four mails 14919266–14919269 are all `new`, with comments 1/0/0/2.
- The mesh_tx Tested-by thread 14831271 is `new`.
- Other authors' mesh patches 14888791, 14864878 and 14880941 are all `new`.
- Wentao Liang's 14942649 (conflicts with CO-02 v2) is `new`; Jens Willmer's 14973994 is `new`.
- 14907537 (the 6.12.y getsockopt fix, BT-14) is still `new` on Bluetooth patchwork. STATUS says
  it was queued for 6.12 on 10-23; patchwork state is not the queue.

**F-21** · 13:45Z · stable queue (live: `scripts/stable-queue-check.sh bluetooth-l2cap-hold-conn-lock 7.3
6.18 6.12 6.6`, 12:46 UTC) vs `contributions/CO-35-…` and `reviews/2026-11-14T1400Z-…` l.149 ("Nothing is
queued", 11-14) · **`32d86e048d8e` ("Bluetooth: L2CAP: hold conn->lock for
__l2cap_ecred_conn_rsp_defer") is now QUEUED for 7.3** (`queue-7.3/bluetooth-l2cap-hold-conn-lock-for-__l2cap_ecred_con.patch`).
It is not queued for 6.18, 6.12 or 6.6. The stable team picked it up on its own between 11-14 and
11-22. · Consequence: CO-35's 7.3.y request mail ("Please backport 608e0b7a675b and 32d86e048d8e to
7.3.y") is now wrong as written. The prerequisite `608e0b7a675b` still has to be checked in
queue-7.3: if it was not taken with the fix, 7.3.y may get a fix that does not build or does not
apply. The 6.18/6.12/6.6 backports stay relevant. No record knows this.

**F-22** · 13:45Z (extraction pass, spot-checked) · CO-02 v2 candidate · the cover
(`review-fixes-20261115/msg/cover-alt.txt` l.16–18) says the sco-tester patches are "posted
separately". None is posted, and the ported v2 BlueZ tests exist only in the **superseded**
`send-v2-20261114/bluez/` and `send-v2-review-fixes-20261114/mails/`. The current candidate
directory has no BlueZ patch. `contributions/README.md` l.92 still quotes the superseded v2's
"sco-tester 31 → 35 of 35". The candidate's own numbers are 35 pass, 2 fail (the mismatch cases),
7 not run (`review-fixes-20261115/README.md` l.58–64). v2 2/2's message has a line of about 95
columns, while the bot's GitLint limit is 80, and the bot has not run on the candidate. ·
Consequence: CO-02 v2 is not one package yet. Its test patch must be moved into the candidate,
and its numbers stated from the candidate only.

**F-23** · 13:45Z (extraction pass) · CO-30 `rfc-20261114/` · Besides F-05, the RFC's notes block
says "[PATCH v2 0/3] … (KERNEL-V2-LINK)" and cites "patch 3 of the series". The CO-02 candidate
is now two patches, with patch 3 moved out. CO-30's README says the code is "unchanged from the
11-01 prototype", the RFC README says 10-21, and the patch header is dated 21 Oct. The dossier
has no `log.md` or `refs.md`, against the layout in `contributions/README.md` l.61–69.

**F-24** · 13:45Z (extraction pass, spot-checked) · `docs/STATUS.md` l.192 and
`contributions/CO-21-…/README.md` l.3 · Both say "the posted patch", but CO-21 was never posted. ·
The wording invites a false "submitted". `contributions/README.md` l.111 says the bot "checks only
the Signed-off-by". `CHECKS.md` l.134–136 also records VerifyFixes FAIL (partial history; passes
once a Signed-off-by follows `Fixes:`) and a CheckSparse warning that is the same on base. The
summary is shorter than the record. CO-21 has no `log.md`, and no BT-n/U-n issue row: it exists
in STATUS only as a bullet at l.192.

**F-25** · 13:45Z (extraction pass, spot-checked) · BT-13 · `reviews/2026-11-15T0115Z-submitted-contributions-status.md`
l.143: Wentao Liang's 14942649 (11-04, `Cc: stable`) fixes the same `hci_connect_sco()` failure
branch that BT-13 describes. `docs/STATUS.md` l.84 and `docs/issues.md` l.924–930 do not mention it,
and still plan "after CO-02 lands: a fault-injection reproducer, then a separate patch". The same
review (l.145) records Wentao Liang's 14942650, an identical change to Hui Peng's 14831271, which
the mesh_tx Tested-by row (STATUS l.61) does not mention. · Consequence: BT-13's planned
contribution is another author's posted patch. The project's possible roles are a test or nothing.

**F-26** · 13:45Z (extraction pass) · CO-43 · `contributions/CO-43-…/README.md` l.40–42 and
`contributions/README.md` l.153 still say E and A are packaged with "dry runs OK". l.42 of the index
says A's 11-14 dry run was on the replaced file. The dossier's patch table (l.47–53) still names
A's old subject ("failed resume" → now "failed runtime resume"). `docs/STATUS.md` l.95 (BT-24) says
"not reachable on E alone". `send-bt24-bt25-20261114/CHECKS.md` l.60 reproduces it on E alone with
an injected second sender. That is consistent only if "naturally" is meant. CO-43 has no
submission row in STATUS, only issue rows BT-17…BT-25.

**F-27** · 13:45Z (extraction pass) · CO-20 · `contributions/CO-20-…/README.md` l.14–15 names the
newline fix `f3d041ec63f7` "in bluetooth-next". `log.md` l.54 and `rd-2026-11-14.md` l.171 name
`f51ee3bb5fbe` (mainline). Probably both are right, one per tree (bluetooth-next rebases), but no
file says which tree each id belongs to. CO-20's README and log stop at 11-12 and 11-01; the 11-14
and 11-16 state is only in the index and the send directories. STATUS has no row for CO-20.

**F-28** · 13:55Z · stable queue (live, 12:47 UTC) · This completes F-21: **all three commits of
CO-35's two 7.3.y requests are now queued for 7.3**:
- `608e0b7a675b`: `queue-7.3/bluetooth-l2cap-add-l2cap_chan_close_unlocked-and-lo.patch`;
- `32d86e048d8e`: the patch named in F-21;
- `5874f8d03268` (BT-15): `queue-7.3/bluetooth-fix-the-le-read-connection-interval-respon.patch`.

None of the pair is queued for 6.18, 6.12 or 6.6. · Consequence: CO-35's
`request-v4-20261114.eml` and `request-sci-7.3.y-20261114.eml` are not to be sent. They are
superseded by the stable team's own pick-up, which is the outcome they asked for. CO-35 narrows
to the 6.18.y/6.12.y/6.6.y backport series. Their covers cite the 7.3.y request and must be
reworded. When 7.3.y next releases, BT-15's next step ("an option-2 request only if 7.3.y
releases go without it", STATUS l.86) closes.

**F-29** · 13:55Z · stable (live) · CO-22's two ASUS QCA ROME entries (`d54601f21faf`,
`cfa67a1dbfd9`) are in no queue of 7.3, 6.18, 6.12, 6.6, 6.1, 5.15 or 5.10 (12:47 UTC). They are
not on `linux-6.18.y` either: its newest `btusb.c` commits are of 11-06 and 11-10, none of them
these (`gh api repos/gregkh/linux/commits?sha=linux-6.18.y&path=drivers/bluetooth/btusb.c`). ·
CO-22's request is still needed. The other five lines' branches were not read (queue only).

**F-30** · 13:55Z (extraction pass) · CO-35 · The records give two counts for the backport review.
`docs/STATUS.md` l.81 says "six outside reviews" approved the hand backports. `CO-35-…/log.md` l.52
says five approved and reviewer 4 was unavailable. The date of the operator's Signed-off-by on
the backports is also given twice: `contributions/README.md` l.26 says "since 2026-11-02",
`log.md` l.57–59 says 10-28. The bot's `ci-local.sh --kernel` was last run on 11-02, and not on
the 11-14 or current packages (`send-20261114/CHECKS.md` l.53). `log.md` has no entry after 11-02;
the 11-14 and 11-16 states are only in the README banner.

**F-31** · 13:55Z (extraction pass) · `docs/STATUS.md` l.85 (BT-14) · The "next" cell says "watch
the next 6.12.y release, then rerun CO-35's 6.12 suite". `CO-35-…/log.md` l.162–164 records BT-14's
fix released in v6.12.115 (`4b26b1d3a94cc`). · STATUS is stale here. Whether CO-35's 6.12 suite
was rerun after 6.12.115 is not recorded: its 11-14 matrix ran on v6.12.117, which already
carries the fix, so the 79/111 there is not BT-14.

**F-32** · 13:55Z (extraction pass) · CO-22 and CO-25 · STATUS mentions **CO-22 nowhere** (no row
and no text), so a ready stable request is invisible on "the one page that says what is current".
CO-22's `refresh-20261114/CHECKS.md` l.10 and l.31 still say 5.15 and 5.10 were not checked on 11-14.
Its README l.21 and `queue-refresh-20261114.md` l.7 say all seven were (13:08–13:42 UTC). For CO-25's
reply v4 (`drafts/reply-1-zijun-hu-v4.eml`), no dry run is recorded and no send script exists:
`send/send.sh` covers the report only. · Consequence: the reply is a text ready for review, not
a send package.

**F-33** · 13:55Z (extraction pass) · CO-01 · The README's `State:` line (l.15) still says "idea;
nothing run yet". The index row (l.91) says stalled upstream, with a 68-run QEMU matrix on 11-01.
The maintainer's 10-09 reply and that matrix are in the index and `research-2026-11-01/README.md`
l.55, not in CO-01's own `log.md` or `refs.md`. Its `log.md` l.7 says only the bot had commented.

**F-34** · 14:05Z (extraction pass, spot-checked against the patch header) · CO-04
`review-fixes-20261114/patch-bare/0001-*.patch` l.57–60 · The patch already carries `Closes:
https://syzkaller.appspot.com/bug?extid=f20755f37da70df33a16` and a `Cc: stable` trailer. Two
records contradict that:
- CO-04's README l.24–26 and `log.md` l.73 say `Closes:` comes only "once shown to resolve it".
  The use-after-free was never reproduced here (the operator's 10-29 decision), and
  `followups.md` D4 recommends `Link:` if no syzbot test is run.
- The patch is 156 lines against stable's 100 (review answers l.107–109).

· Consequence: the package as it stands pre-decides D4 and the stable question in the direction
the records advise against. Before a send, swap to `Link:` unless the operator orders a syzbot
test.

Also in CO-04:
- `notes.txt` l.39–40 says "mesh-tester (10) pass". The local master run is 8/10 on every
  image; 10/10 is the bot's environment (`send-20261114/CHECKS.md` l.24, l.39), and F-07 of 11-02
  asked for the environment to be named.
- The bot was not re-run on the final, reworded mail.
- The 10-29 `patch/` directory lacks the `SUPERSEDED.md` that `contributions/README.md` l.22 says
  every older directory has.
- `docs/STATUS.md` l.101 (M-5) cites `send-20261114/circular-count.txt`, a superseded directory.

**F-35** · 14:05Z (extraction pass) · CO-05 · `contributions/review-2026-11-02/followups.md` l.84–87
(reviewers 2 and 6) says to wait for Cen Zhang's series, then at most one small patch. It also
says "No action now". `contributions/README.md` l.46 marks CO-05 "ready". CO-05's README l.41–42
says "Nobody has written the fix". Its own l.8–11 and `log.md` l.108–120 record two other authors'
patches that take the lock. The CO-05-specific checks exist only in the superseded
`send-20261114/CHECKS.md`. · With F-19, the 11-02 advice is now the current one: 14927631's
respin is out. CO-05 1/2 should be re-weighed, and possibly dropped in favour of a test of the
other author's v2. CO-26 (2/2) may stand alone.

**F-36** · 14:05Z (extraction pass) · CO-12 · The list bot was **not run** on the package
(`send-20261114/README.md` l.14, `CHECKS.md` l.28), so `contributions/README.md` l.52 "ready" means
code-ready. The case counts disagree across files: 22 AdvDur research cases, "15 new" (log l.48),
"eight" (review answers l.76), "fourteen" (CO-38 `bluez-split-20261114/README.md` l.11). STATUS
l.98 says "Advertising 127/127 on both sides" (11-01). The 11-14 run is 124 of 125
(`CHECKS.md` l.19). STATUS's origin text also names three commits
(`10bbffa3e88e`, `f16a491c65d9`, `cba6b758711c`), and the log l.73–74 resolves them. The
dossier README stops at 11-01.

**F-37** · 14:05Z (extraction pass) · CO-14 · There is a patch but no send package and no
outside review of the patch. The bot has not run. The full mgmt-tester comparison is not
completed: only "Remove" and "Suspend" subsets, and the tip was not run for those. `docs/issues.md`
l.803 says the M-5 sweep was "40 boots". CO-14's README l.37–38 and `RESULTS.md` l.99 say 60 per
kernel over three scenarios. CO-14 has no `log.md` or `refs.md`.

**F-38** · 14:05Z (extraction pass) · CO-38 · `followups.md` D12 recommends `Cc: stable`
"CO-38: yes", and reviewers 3 and 7 favour it (review answers l.72). The packaged patch has none,
and the index's state cell does not list it as open. The index row l.127 says the fix "passes
128/128 mgmt-tester 'Add' cases". The 11-14 measurement is 120/128 with the fix alone, and 128/128
only with CO-12's clamp too (`send-20261114/CHECKS.md` l.28). CO-38's README l.18–37 still
describes `send-20261102/` (a placeholder From line, a three-patch BlueZ series).

**F-39** · 14:05Z (extraction pass) · CO-44 · `NOTES-FOR-OPERATOR.md` l.27 lists reviewer 7 for
`Cc: stable`. The same file's l.38–39 lists reviewers 2, 6 and 7 against it at first. The review
answers l.47 say reviewers 1, 3 and 7 for and reviewer 2 against. · The operator's stable decision
rests on a count that the notes give two ways. The patch message calls HCI status 0x10 "Host
Timeout"; the README l.100–101 calls it "Connection Accept Timeout". The two names may come from
different specification editions (not checked here). The README l.110–112 (BlueZ mail after the
kernel patch lands) is overridden by l.147–151 and NOTES (the same day).

**F-40** · 14:05Z (extraction pass) · CO-06, CO-13, M-1 · CO-06 has three records:
- STATUS l.66 (11-01) still offers "one message on the mesh transmit path";
- CO-06 `log.md` l.38–42 withdrew it on 10-28;
- `reviews/2026-11-15T0115Z-…` l.163 says it "remains an option".

CO-13's Count measurements (airtime ~1 s whatever the Count, wrap at ≥52) are stated in
`research-2026-11-01/README.md` l.42, but no log in `research-2026-11-01/mesh/logs/` holds them.
**M-1**'s first clause (advertising never stops) is covered by no dossier. CO-04 fixes the
double start, and its notes say the done-path clause is "not changed".

**F-41** · 14:30Z · upstream (live: patchwork API and the bluetooth-next GitHub mirror) vs every
mesh record · **The maintainer fixed the mesh transmit path himself, and it is applied.**
- What: Luiz Augusto von Dentz's "[v5,11/17] Bluetooth: mgmt: Fix mesh transmission locking and
  lifetime" (patchwork 14998382, posted 11-17 as v1 and v5 on 11-18, state `accepted`), commit
  **`1d7a52778858`** in bluetooth-next (committed 2026-11-19 16:21 UTC). `master` (`cf357cfc025e`,
  2026-11-20) contains it: `gh api …/compare/1d7a5277…master` → `ahead`. `Fixes: b338d91703fa`.
- What its message says it does:
  - takes `hdev->lock` around every `mesh_pending`/`adv_instances` access in the cmd_sync
    callbacks and Mesh Send Cancel, never across HCI commands;
  - queues entries by handle instead of a raw `mesh_tx` pointer (the use-after-free);
  - clears `HCI_MESH_SENDING` only together with the removal of the transmission, "so Mesh Send
    can't start another one in between", and leaves none stranded if queueing fails;
  - does not take `hdev->lock` from `-ECANCELED` callbacks;
  - flushes the transmissions left when the controller is closed (also auto power-off) or the
    index is removed.
- How that matches ours:
  - CO-04's mechanism and design (F-34; CO-04 patch message l.6–39);
  - CO-05 1/2's lock;
  - CO-14's leak at removal (M-4);
  - the power-off completion problem behind CO-06;
  - the mesh_tx leak of Hui Peng's 14831271 (our Tested-by).
- In the same accepted batch:
  - `c592dfe9637c` "hci_sync: Hold hdev->lock in hci_schedule_adv_instance_sync()" (14998365).
    CO-05 left that call unlocked on purpose (cover l.11–14).
  - `8984b72f9508` "hci_sync: Lock the lookup in hci_disable_ext_adv_instance_sync()".
  - `7c8dcf322b0d` "MGMT: Fix use-after-free in mgmt_powering_down()".
  - 09/17, "mgmt: Reject zero multi advertising rotation duration" (14998380, next to CO-12),
    is still `new`.
- **Not done here:** a reading of the 301-line `mgmt.c` diff against each of our patches. The
  overlap above is from the commit message and the functions in its hunks (`mesh_send_complete`,
  `mesh_send_done`, `set_mesh`, `mesh_send_sync`, `mesh_send`, `mgmt_index_removed`,
  `mgmt_power_on`), not from a test.

· Consequence: CO-04, CO-05 1/2, CO-14's M-4 fix and the CO-06 reply are very likely
**superseded** by an accepted maintainer fix. Before any of them is sent, our harnesses should be
run on bluetooth-next `cf357cfc025e` to find any remaining gap:
- CO-04's UnregSweep lockdep and cancel cases;
- CO-14's kmemleak removal harness (86 → 0);
- CO-05's lock assertion;
- CO-26's fault injection.

A remaining gap would be a new, smaller patch; a clean run could be a Tested-by on the applied
commit (the operator's call). CO-26 (a failed add is ignored) may or may not be covered ("making
sure none is left stranded if queueing fails" is about queueing, not about
`hci_add_adv_instance()` failing): open. No record knows any of this; it all happened 11-17 →
11-19.

**F-42** · 14:30Z · upstream (live) · bluetooth-next moved from our packages' base `da3cc02587c6`
(11-12) to `cf357cfc025e` (11-20). It took accepted changes in files our packages touch:
- `hci_conn.c`, by Jeremy Dean Clifton, `1f150a0bb8a1` "Free the unset handle when adding a
  connection fails" and `56abe5c17b4d` "Refuse new connections once HCI_UP is cleared". This is
  CO-02 v2's file, and the first may touch the BT-13-like failure branch.
- `mgmt.c` (F-41), and Zhao Li's `5052141b19fe` "MGMT: Retain the selected legacy advertising
  schedule ID". These touch CO-38's and CO-44's file.
- `hci_sync.c` advertising paths, CO-12's file.

No accepted `btusb` change was seen in the patchwork list since 11-15. Leon Romanovsky's
"btusb: Fix MediaTek ISO claim locking" is `new`. · Consequence: every kernel package needs an
apply check on today's tip before a send. Their "applies to bluetooth-next" claims are of 11-14.

**F-43** · 14:30Z · upstream (live) · Zheng Shuhao's "Bluetooth: hci_sync: invoke destroy callbacks
outside lock" (patchwork 15008482, 2026-11-21, `new`) is about M-5's mechanism: a destroy
callback, `mesh_next()`, run under `cmd_sync_work_lock` (STATUS l.101). · M-5's row, "removed by
CO-04", should be re-read against both 1d7a52778858 and this patch.
