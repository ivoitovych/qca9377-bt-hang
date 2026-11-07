# CO-35 — the send package (v2, 2026-10-28): for review, NOT sent

Four mails to the stable team, under `Documentation/process/stable-kernel-rules.rst` (read in
v7.2.13's tree, unchanged in v7.3: `git diff --stat v7.2.13 v7.3 -- <that file>` prints nothing;
option 2 "ask the stable team to pick up a patch already mainlined", option 3
"submit a patch ... equivalent to a change already mainlined", and "ensure the fix or an
equivalent is applicable, submitted, or already present in all newer stable trees"). Nothing here
has been sent. Sending is the operator's decision, after an outside review of these files.

| file | mail | rule |
|---|---|---|
| [`request-v2.eml`](request-v2.eml) | 7.3.y and 7.2.y: apply `608e0b7a675b` then `32d86e048d8e` as they are | option 2 |
| [`6.18.y/`](6.18.y/) `0000`–`0002` | `[PATCH 6.18.y 0/2]` cover + the two backports, tested on v6.18.59 | option 3 |
| [`6.12.y/`](6.12.y/) `0000`–`0002` | `[PATCH 6.12.y 0/2]` cover + the two backports, tested on v6.12.114 | option 3 |
| [`6.6.y/`](6.6.y/) `0000`–`0002` | `[PATCH 6.6.y 0/2]` cover + the two backports, tested on v6.6.160 | option 3 |
| [`request-v1.txt`](request-v1.txt) | **superseded** (7.2.y only; kept as reviewed on 2026-10-28) | — |

Send order: `request-v2.eml` first, then the three series (newest line first), so that every
older line's request follows the newer lines' (the rule above).

## Recipients (all four mails)

- **To:** `stable@vger.kernel.org`
- **Cc:** Pauli Virtanen `<pav@iki.fi>` (author of both commits), Marcel Holtmann
  `<marcel@holtmann.org>` and Luiz Augusto von Dentz `<luiz.dentz@gmail.com>` (MAINTAINERS,
  BLUETOOTH SUBSYSTEM), `linux-bluetooth@vger.kernel.org`.

Source: `scripts/get-maintainers.sh` in the v7.3 tree on each upstream commit (2026-10-28):
Marcel Holtmann (maintainer), Luiz Augusto von Dentz (maintainer), linux-bluetooth (open list),
linux-kernel (open list), and for `32d86e048d8e` also Dan Carpenter (`blamed_fixes`: a sign-off
on `ab4eedb790ca`, the commit fixed).

- Decision: no Cc to linux-kernel and Dan Carpenter, because the request concerns only the
  Bluetooth subsystem and its own list, the stable list is the place of record, and Dan
  Carpenter's role is a sign-off on the fixed commit, not its authorship or the area.
- On the option-3 patches, the mailer by default also copies the addresses in their
  `Signed-off-by:` lines: `pav@iki.fi` (already Cc) and `luiz.von.dentz@intel.com` (Luiz
  Augusto von Dentz's commit address). Kept: that is the usual result for a stable backport
  and reaches the same two people.

`request-v2.eml` carries its To and Cc headers (Cc folded over four lines); the format-patch
files carry none, so for the series the To/Cc go on the mailer's command line, the same for
all three, sent as one thread per series (the patches replying to their cover). Do not use
`--suppress-cc=all` (it also drops the header Cc of the `.eml`); `--suppress-cc=self` is
enough. The dry run is the main session's: `--dry-run`, then check every `RCPT TO` of each
mail against the lists above.

## Why a cover letter (0/2) for each series

`stable-kernel-rules.rst` does not require one. Current practice on the stable list is mixed:
two-patch series by the stable maintainers usually have none; series by others often have one
(e.g. `[PATCH 6.6.y 0/2]` of 2026-10-16 for two Bluetooth hci_core/hci_sync commits, queued
by the stable team on 2026-10-16; `lore.kernel.org/stable/20261016021047.16461-1-artem@trailofbits.com`).
- Decision: one 0/2 cover per series, because it carries what applies to both patches once
  (the order, the reason, the tested base and results, the 6.12 limit), while each patch keeps
  its own `[ backport: ... ]` note for its own deviation, as upstream-style stable backports
  do.

## What each mail states

- **request-v2:** both commits by full ID and subject, in order; the Fixes target and that both
  lines carry it; that they are patches 2 and 7 of a larger series and the rest was not needed
  or tested; the case and that it never finishes on v7.3 and v7.2.13; what the hung-task
  detector shows on v7.3 (the task waits for its own socket lock; results file §5) and that
  `32d86e048d8e` releases that lock first (all four mails carry this, the covers in one
  parenthesis); the test (case passes,
  l2cap-tester 111 of 111 on both); that on v7.3 the suite first needs `5874f8d03268` for an
  unrelated SCI stall (one paragraph: the stable team may want that commit for 7.3.y anyway);
  that 6.18.y, 6.12.y and 6.6.y get backports; that 6.1.y, 5.15.y and 5.10.y show the same
  symptom once ECRED is enabled and are not covered.
- Decision: the mails state the hung-task observation, because it shows the "hang" is a kernel
  self-deadlock (what `stable-kernel-rules.rst` lists as "a hang"), not a test that waits for
  an event; it was observed with the detector on v7.3 (and 6.1.190, results file §5) only, so
  the covers say "On v7.3", and the source path it implies is not claimed in the mails.
- Decision: request-v2 does not *ask* for `5874f8d03268`, because it fixes a different defect
  (proposed BT-15) and carries a `Fixes:` tag for a 7.3-only commit, so the stable team's own
  selection is expected to take it (an inference); the mail states the fact, and a separate
  request follows only if 7.3.y releases go without it.
- Decision: request-v2 names 6.1.y, 5.15.y and 5.10.y as affected but not covered, because
  the case never finishes there either once ECRED is enabled (results file §3) and the stable
  team and the author should not read "lack ab4eedb790ca" as "unaffected"; no backport is
  offered for them, because the commits do not apply there and no fix was built or tested.
- **each series:** the reason, the base it was tested on, its deviations from upstream, its
  l2cap-tester totals and that every failing case also fails on the plain base; 6.12 states in
  one sentence that its low total is mostly BT-14 (`5bd0dec150f5`, queued for 6.12).

Dropped from v1, after the six outside reviews of `24d76cd`: the bisect sentence (reviewers 3, 4:
qualify or drop; the stable team needs the test, not the search), and "no hung-task report"
(found 2026-10-28: `doc/tester.config` builds have `CONFIG_DETECT_HUNG_TASK` off, so that
sentence claimed a check that could not fire; `img/config-*:# CONFIG_DETECT_HUNG_TASK is not
set`).

## The rules, item by item

- "already exist in Linux mainline": both commits are in `origin/master` (torvalds), 7.4 merge
  window (`git branch -r --contains 32d86e048d8ef`: bluetooth-next/master, bluetooth/master,
  origin/master, stable/master).
- "obviously correct and tested": tested as below; the backports change no code of the commits
  (annotations and three absent context lines only).
- "cannot be bigger than 100 lines, with context": not met by the size of the upstream pair
  itself (patch 1: 130 lines as checkpatch counts them, patch 2: 88 upstream). Inferred, not
  verified against a written exception: the stable trees take larger fixes as they were merged
  upstream; nothing in the backports adds to the size. Stated here so a reviewer can weigh it.
- "fix a real bug that bothers people ... a hang": the case never finishes (a deferred ECRED
  accept of two channels); the BlueZ test's own commit (`e9b6ee380`) says "This triggers
  deadlock on some kernel versions".
- option 3 "[ Upstream commit <sha1> ]" above the text, deviations "very clearly documented and
  justified": each patch's `[ backport: ... ]` note, and the cover.
- "all newer stable trees": 7.3.y and 7.2.y are asked for in the same round (request-v2), before
  the series.

## Checks (2026-10-28; commands and outputs in `../experiments/results-send-2026-10-28.md`)

- the patch mails' code is identical to `../backports/<line>/` (same `git patch-id`); the
  git-am'd trees equal the tested commits' trees (6 of 6);
- `checkpatch.pl` (v7.3): on every patch one ERROR on the `[ Upstream commit <sha> ]` line,
  the known false positive (that line is what `stable-kernel-rules.rst` prescribes); on patch 1
  upstream's own WARNING ("syzkaller ... Fixes:"); nothing else;
- `scripts/ci-local.sh --kernel` in backport mode: `git am` PASS on each newest tag; GitLint
  title 82/81 > 80 on patch 1 (upstream's subject plus the `[x.y.y]` prefix; cannot change);
  VerifyFixes PASS on 6.18.y, a warning on 6.12.y and 6.6.y (there `ab4eedb790ca` is present
  as its backport, `f87271d21dd4` and `efc30877bd4b`, not as an ancestor);
- `scripts/mail-lint.sh` on `request-v2.eml` and on each cover (with a To: line added for the
  check only).
