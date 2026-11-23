# Upstream practice: the register of what we learned the hard way

How the upstreams we send to actually behave and what they expect: the Linux Bluetooth maintainers, the stable
team, the list bots, BlueZ, and later Ubuntu and PipeWire. Each entry is one fact, verified against a primary
source, with:
- **evidence:** the command or link, and the decisive output;
- **checked:** the date and the tree or tip it was checked on;
- **from:** the record it came from;
- **re-check:** whether it goes stale, and when to look again.

Statements from outside reviews enter only after such a check. At the end are three lists: what the sources
leave contested, giving both sides ("Contested"), what could not be verified ("Reported, unverified"), and what a
check refuted ("Dropped").

Seeded on 2026-11-23 from that day's checks. Filled the same day from all review records and all outside
reviewers' texts since September: 149 candidate facts, deduplicated, then checked against the kernel and BlueZ
trees and the kernel.org documents. Entries marked **stale** or **volatile** must be re-checked before they are
quoted.

**Before preparing any send, read this file, then the package's own README.** A brief for an outside reviewer
points here, so the reviewer does not rediscover these facts.


## Stable and trailers

**S-1. `Fixes:` names the commit that introduced the bug, and it also makes a commit a stable candidate.**
- Evidence: `git -C cache/linux grep -n -i -E 'AUTOSEL|Fixes:|noautosel' bluetooth-next/master -- Documentation/process/stable-kernel-rules.rst`:
  - l.122: the versions are taken "from Fixes: tags";
  - l.133–134: the stable "backporting tools (e.g AUTOSEL or scripts that look for commits containing a 'Fixes:' tag)";
  - l.136: `Cc: <stable+noautosel@kernel.org> # reason goes here, and must be present`.
- Checked: 2026-11-23, bluetooth-next `5063a0717aa2`.
- From: `reviews/2026-11-23T2100Z-fixes-and-stable-trailers-question.md`.
- Re-check: when the document changes.

**S-2. Leaving `Fixes:` off is not how to keep a patch out of stable; the only opt-out is `stable+noautosel`, with a reason.**
- Evidence: S-1, l.133–136.
- Practice: five of five outside answers of 2026-11-23 agree, and so do the documents.

**S-3. In Bluetooth, many commits that carry `Fixes:` without `Cc: stable` reach stable, weeks after
mainline.**
- Evidence: `tmp/kernel-queue-20261123/fixes-only-backports.py 2026-10-01 2026-11-23 <ranges>` on mainline commits
  after v7.3 (Bluetooth paths, no merges: 21 with `Cc: stable`, 87 with `Fixes:` only, 79 with neither). A backport
  counts if a stable commit names the upstream SHA as "commit … upstream" or "[ Upstream commit … ]":

  | backported into | with `Cc: stable` | `Fixes:` only | neither |
  |---|---|---|---|
  | 7.3.5 | 13 | 2 | 1 |
  | 7.3.6 | 14 | 36 | 12 |
  | 6.18.65 | 14 | 24 | 4 |

- Checked: 2026-11-23, after 7.3.6 and 6.18.65 were released.
- From: the same review record; an outside count on 7.3.5 alone had concluded the opposite.
- Re-check: monthly. The share depends on when the stable team's batches land, so count on more than one release.

**S-4. Stable copies name their upstream commit in two forms, "commit <sha> upstream" and
"[ Upstream commit <sha> ]".** A search for backports must match both. **The form does not tell who chose the
commit.** *Corrected 2026-11-23 evening:* this entry said the bracketed form marks the stable team's own picks.
An outside reviewer showed a counter-example, checked here: a `Cc: stable` commit whose stable copy uses the
bracketed form with Sasha Levin's sign-off.
- Evidence:
  - `git -C cache/linux log -n 1 878dd63b2828` (7.3.y) begins with
    `[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]` and ends with Sasha Levin's sign-off.
    `32d86e048d8e` has `Fixes:` and no stable tag.
  - `git -C cache/linux log -n 1 b415ba15d072` (6.18.y), the copy of `df5e35f1663a`, which has `Cc: stable`:
    `[ Upstream commit df5e35f1663a… ]`, `Cc: stable@vger.kernel.org`, Sasha Levin's sign-off.
  - So only a `[PATCH AUTOSEL]` mail on the list shows that the stable team nominated a commit itself.
- Checked: 2026-11-23 (`tmp/kernel-queue-20261123/check-precedents.sh`).
- Effect on S-3: the counts of commits **reaching** stable stand. They do not show by which route each one came.

**S-5. `Fixes:` with no stable tag is the usual form in Bluetooth.** Of the November commits in bluetooth-next with
`Fixes:`, 14 of about 100 also carry `Cc: stable`, and 6 of the latest 50.
- Evidence: `git -C cache/linux log --format=%h --since=2026-11-01 --grep='^Fixes:' bluetooth-next/master -- net/bluetooth drivers/bluetooth include/net/bluetooth`,
  again with `--grep='^Cc: stable' --all-match`.
- Checked: 2026-11-23, bluetooth-next `5063a0717aa2`.
- Re-check: per release cycle.

**S-6. Precedent for a status-mapping fix:** `7eac806143005` ("Bluetooth: MGMT: Return RFKILLED …") has `Fixes:` and
no `Cc: stable`, and it is not in 7.3.5 (S-3's count).
- From: the CO-44 package and the 2026-11-23 records.

**S-7. The stable team picks prerequisites and whole chains itself.** The CO-35 L2CAP pair, `32d86e048d8e` and
`608e0b7a67`, went into the 7.3 queue and 7.3.6 without our request (`backport-in-lines.sh`: 7.3.6 has
`878dd63b2828` and `5d038717af81`). The older lines got sibling patches first.
- From: `reviews/2026-11-22T1519Z-contributions-upstream-check-detail.md`.
- Re-check: per stable release.

**S-8. A stable release can bring a file rename.** 7.3.6 already has `drivers/bluetooth/btusb_main.c`, from the
backported btusb split. 6.18 and older still have `btusb.c`. A patch made on bluetooth-next applies to them only
with the rename, as a cherry-pick's rename detection does it.
- Evidence, in two steps:
  - `tmp/kernel-queue-20261123/apply-co43-1-lines.sh` (rewrites the path, then applies): OK on all seven tips.
  - A real cherry-pick: `tmp/kernel-queue-20261123/cherry-pick-lines.sh 888176e9a640` runs
    `git merge-tree --write-tree --merge-base=<c>^ <tip> <c>`, with rename detection. It is CLEAN on all seven
    tips, landing in `btusb_main.c` on 7.3.6 and in `btusb.c` on 6.18.65 down to 5.10.275.
  - Only the second proves what the stable team's cherry-pick will do.
- **Precedents (checked 2026-11-23, `tmp/kernel-queue-20261123/check-precedents.sh`):**
  - `df5e35f1663a` is a `btusb_main.c` fix with `Cc: stable`. 6.18.y has it in `btusb.c` as `b415ba15d072`,
    with the note "[ sashal: Adapted the patch to the Bluetooth USB driver's original source filename. ]".
  - `fa96916cfd05` is a `btusb_main.c` fix with `Fixes:` only. It is in `btusb.c` on 6.18.y (`ce982d4892f2`),
    6.12.y (`8b905b598c45`), 6.6.y (`41494c00aa34`) and 6.1.y (`45e27026c59b`), with no adaptation note.
  - So the stable team does take post-split btusb fixes into the older lines, once with a recorded manual
    adaptation.
- Checked: 2026-11-23.
- Re-check: per stable release.

**S-9. CO-44's precedent stayed in mainline.** `7eac80614300` (MGMT RFKILLED mapping, `Fixes:`, no stable tag) is
in mainline and in none of the seven stable lines. 7.3.6 took 36 other `Fixes:`-only Bluetooth commits but not
this one.
- Evidence: `tmp/kernel-queue-20261123/backport-in-lines.sh 7eac80614300`.
- Checked: 2026-11-23.
- Re-check: per stable release.

**S-10. The written rule is that `Fixes:` does not replace `Cc: stable`; the stable tooling picks `Fixes:` commits anyway.** The two statements are both in the documents and do not conflict: one is the submitter's duty, the other is the team's own selection (S-1, S-3).
- Evidence: `git -C cache/linux grep -n "Attaching a Fixes: tag" bluetooth-next/master -- Documentation/process/submitting-patches.rst` -> `:611:Note: Attaching a Fixes: tag does not subvert the stable kernel rules`. Web: https://www.kernel.org/doc/html/latest/process/submitting-patches.html "Attaching a Fixes: tag does not subvert the stable kernel rules process".
- Checked: 2026-11-23 (tree and web). Re-check: when the documents change.

**S-11. Two routes to stable.** Option 1: `Cc: stable@vger.kernel.org` in the sign-off area of a mainline-bound patch. Option 2: for a commit already in mainline, mail stable@vger.kernel.org with the subject, the commit ID, why, and the wanted versions. A device-ID addition qualifies.
- Evidence: `git -C cache/linux grep -n -E "^Option 2|If the patch already has been merged|just add a device ID" ... stable-kernel-rules.rst` -> `:140:Option 2`, `:143:If the patch already has been merged to mainline, send an email to`, l.15 `fix a real bug that bothers people or just add a device ID`. Web: https://www.kernel.org/doc/html/latest/process/stable-kernel-rules.html "send an email to stable@vger.kernel.org".
- Checked: 2026-11-23. Re-check: when the document changes.

**S-12. Stable size and content limits.** At most 100 lines with context; obviously correct and tested; no "theoretical race condition" without an explanation of how it can be triggered.
- Evidence: `stable-kernel-rules.rst` l.10-11, l.27 (`It cannot be bigger than 100 lines, with context.`). Web, same URL as S-11: "It cannot be bigger than 100 lines, with context."
- Checked: 2026-11-23. Re-check: when the document changes.

**S-13. A backport needing adjustment says so on the `Cc:` line.** Documented form: `Cc: <stable@vger.kernel.org> # see patch description, needs adjustments for <= 6.3`.
- Evidence: `stable-kernel-rules.rst:130`. Checked: 2026-11-23. Re-check: when the document changes.

**S-14. The stable maintainers answer a mail request with a one-line patchwork reply naming the line.** "Queued for 6.12, thanks." (Sasha Levin, 2026-10-11 on patchwork 14878736-38; 2026-10-23 on 14907537).
- Evidence: recorded in `docs/STATUS.md` rows of BT-9 and BT-14; confirmed there against the public stable queue (`scripts/stable-queue-check.sh ... QUEUED x2`).
- Checked: 2026-10-11 to 10-23 (record). Re-check: not volatile as a habit; the queue contents are (S-7).

**S-15. A mail request for a mainline commit with no stable tag worked within a day, for every live line.** Request mailed 2026-10-02, in `stable-queue.git` by 2026-10-03, released 2026-10-11 to 10-30 depending on the line. The original `dc16388d45ec` carries neither `Cc: stable` nor `Fixes:`; the copy `f7c862054609` carries `[ Upstream commit dc16388d... ]` and Sasha Levin's sign-off. The tree does not show whether the request or an automatic selection caused the copy.
- Evidence: `git -C cache/linux show -s --format=%B dc16388d45ec` ends with two `Signed-off-by:` lines and no Cc or Fixes; `git -C cache/linux show -s --format=%B f7c862054609` -> `[ Upstream commit dc16388d45ecbd3be0d8c9424dbbaa2c81806578 ]`, last line Sasha Levin's `Signed-off-by:`. Timeline: `docs/STATUS.md` BT-1 row, `stable-queue-check.sh bluetooth-btusb-add-imc-networks-qca9377 7.2 6.18 6.12 6.6 6.1 5.15 5.10`.
- Checked: 2026-11-23 (tree), timeline from the record of 2026-10-13 to 11-01. Re-check: per request.

**S-16. Stable `-rc` review mails run on a stated clock, and a Tested-by there is small and welcome.** "responses due Mon 19 Oct 16:02:05 UTC" for 6.6.160-rc1; three Tested-by replies were seen on that cover; a report needs no answer.
- Evidence: record of the rc cover read 2026-10-17 to 10-21 (`docs/STATUS.md` BT-1 row; `reviews/2026-10-20T2309Z-contribution-opportunities.md` CO-10).
- Checked: 2026-10-21 (record). Re-check: each release has its own deadline.

**S-17. An adapted stable backport has a fixed shape.** First body line `[ Upstream commit <full sha> ]`, the original trailers, a bracketed note by the adapter, the adapter's sign-off, then the stable maintainer's. Our adapted 6.12.y backport was accepted in this shape.
- Evidence: `git -C cache/linux show -s --format=%B 9a328ae01489` -> `[ Upstream commit 96d006ae6445679436b945593950fd465eba7e76 ]` ... `[ Iaroslav: test the quirk with test_bit() on hdev->quirks ... ]` / `Signed-off-by: Iaroslav Voitovych` / `Signed-off-by: Sasha Levin`.
- Checked: 2026-11-23. Re-check: not volatile.

## Testing expected before a send

**T-1. The upstream kernel CI (`bluez/action-ci`) lists eleven BlueZ testers and picks them by changed file.**
- The eleven: l2cap, iso, bnep, mgmt, rfcomm, sco, ioctl, mesh, smp, userchan and 6lowpan.
- The selection, by file:
  - `net/bluetooth/mgmt.c` (and `mgmt_util.c`, `mgmt_config.c`, `include/net/bluetooth/mgmt.h`) → mgmt-tester and
    mesh-tester;
  - `drivers/bluetooth/` → none;
  - a file matching no rule → all.
- Not in the CI: gap-tester, which needs D-Bus and bluetoothd and waits forever in a plain test-runner guest, and
  hci-tester.
- Evidence: `git -C cache/action-ci grep -n -E 'tester|mgmt|drivers' refs/remotes/bluez/HEAD -- config.json`,
  l.37–48, 79–86, 157–161.
- Checked: 2026-11-23, `bluez/action-ci` HEAD `c7d077f185cd`.
- Correction: an earlier reading of the old fork `BluezTestBot/action-ci` (2024-11) gave ten testers and no
  selection.
- Re-check: when the CI repository changes.

**T-5. The BlueZ testers never load btusb.** They run on emulated controllers over `vhci`, so they give no
coverage of a btusb change. For btusb, the evidence is the emulated USB device bound to the real driver over
usbip, with kmemleak, KASAN and lockdep.
- From: `reviews/2026-11-23T2130Z-four-questions-findings-and-checks.md`; T-1's `__none__` rule agrees.

**T-2. Every upstream moves within a day, so test on the tips of the send day.** On 2026-11-23 alone, bluetooth-next
gained 15 Bluetooth commits, BlueZ master moved, seven stable releases came out (7.3.6 … 5.10.275), and mainline
stood at v7.4-rc4. `base-commit:` follows the tip; regenerating it is mechanical (`git am`, then
`format-patch --base`), and the patch-id must stay the same.
- From: `reviews/2026-11-23T2010Z-intermediate-recheck-findings-and-checks.md`.

**T-3. Current BlueZ testers fail many cases on older kernels on both sides, so judge only the difference between
base and patched.** Examples on unpatched kernels: iso-tester 141 of 213 on 6.18.65; mgmt-tester 466 of 531 on
6.1.192 and 505 on 6.18.64.
- From: `contributions/CO-38-read-adv-features-hidden-instances/send-20261123/RUNS-20261123.md`.

**T-4. A test image carries only the patch that is sent.** A joint image does not support a note about one patch
that is sent days before the other.
- From: the intermediate recheck of 2026-11-23.

**T-6. A tester run can end with exit status 0 when the tester failed.** `tools/test-runner` only prints the tester's exit status in the guest and reboots; read the tester's output, not the exit code.
- Evidence: `git -C <BlueZ master at 1608f8361> grep -n -B2 -A4 "exited with status" -- tools/test-runner.c` -> `:2007: printf("Process %d exited with status %d\n"`; `:2255` `reboot(RB_AUTOBOOT)` and `:2256` `return EXIT_SUCCESS` (l.2007 reproduced now).
- Checked: 2026-11-23, BlueZ export `1608f8361`. Re-check: when `tools/test-runner.c` changes.

## BlueZ tests that accompany a kernel fix

**B-1. Post the test the same day, as its own BlueZ thread.** This happened in 7 of 11 kernel-fix/tester pairs
since 2025-11, and BlueZ often applies the test before the kernel fix. No maintainer objected to a test that fails
on unfixed kernels.
- From: `reviews/2026-11-23T0540Z-bluez-test-with-kernel-fix-practice.md`.

**B-2. A BlueZ patch carries the subject prefix `[PATCH BlueZ]`.**
- From: the review records of 2026-11-23.

**B-3. Generate each BlueZ test alone on the current master.** One cut on a tree that holds the other test applies
only with offsets.

**B-4. A BlueZ patch carries no `Signed-off-by`; a kernel patch must carry the sender's.**
- Evidence: BlueZ `HACKING` l.122–123: "Do *not* add 'Signed-off-by' lines … including them is actually an
  error". None of the operator's applied BlueZ commits has one (`git log -n 1 b79d4a887`).
- Checked: 2026-11-23, BlueZ master `1608f8361`. Also `doc/maintainer-guidelines.rst` l.59 ("Commit messages for bluez.git shall not contain Signed-off-by") and
  l.63–64 (for `bluetooth.git` and `bluetooth-next.git` "the signatures are required").

**B-5. Two pairs rechecked in the trees.** The test for the rfkill fix was applied 9 minutes after the kernel fix; the host-resolved-RPA test was applied about 5 hours before its kernel fix.
- Evidence: `git -C <BlueZ master at 1608f8361> log -1 --format=%cd 1445a64e6` -> `Fri Oct 23 18:04:34 2026 -0400`; `git -C cache/linux log -1 --format=%cd 65683fbed5c8` -> `Fri Oct 23 17:55:15 2026 -0400`; `git -C <BlueZ master at 1608f8361> log -1 --format=%cd dd9d5ba1f` -> `Wed Oct 14 09:18:04 2026 -0400`; `git -C cache/linux log -1 --format=%cd 397464709a20` -> `Wed Oct 14 14:38:29 2026 -0400`.
- Checked: 2026-11-23. Re-check: not volatile. The other nine pairs rest on B-1's record.

**B-6. A test names its fix in one of three ways: commit id or subject (3 of 11 pairs), "on some kernels" (3), nothing (4), below `---` only (1).**
- Evidence: the table of `reviews/2026-11-23T0540Z-bluez-test-with-kernel-fix-practice.md` (pw ids and commits per pair). Checked: 2026-11-23 (record). Re-check: with B-1.

**B-7. In one kernel thread the maintainer asked for an mgmt-tester case.** Kyle Pepper's v1, 2026-10-13.
- Evidence: the same record, lore archive searched by subject (limit stated there). Checked: 2026-11-23 (record). Re-check: not volatile.

## Patchwork and applied state

**P-1. Patchwork can show `new` for a series already applied.** Check applied state in the tree with
`git merge-base --is-ancestor` on a fresh fetch.
- Example: Cen Zhang's `d7e77168da`, applied three days before patchwork changed state.
- From: `reviews/2026-11-22T1240Z-kernel-contributions-review-worklog.md` F-46.

**P-2. A maintainer may answer several outside patches with his own fix.** `1d7a52778858` (bluetooth-next,
2026-11-19) overtook Hui Peng's mesh_tx patch, other authors' mesh fixes and our CO-04, CO-05 1/2, CO-06 and CO-14.
- From: `reviews/2026-11-22T1519Z-contributions-upstream-check.md`.

**P-3. bluetooth-next is rebased, so quote the mainline id.** `f3d041ec63f7` (7 Oct) is on no remote branch of the local tree; the same patch is `f51ee3bb5fbe` (14 Oct) in bluetooth-next, bluetooth, mainline and stable-master. Another patch has two SHAs: `65683fbed5c8` (bluetooth-next, 2026-10-23) and `7eac80614300` (2026-11-02, via a `for-net-2026-11-02` pull).
- Evidence: `git -C cache/linux branch -r --contains f3d041ec63f7` -> (empty); `git -C cache/linux branch -r --contains f51ee3bb5fbe` -> `bluetooth-next/master bluetooth/master origin/master stable/master`; subjects identical ("Add missing newline to bt_dev_{err,warn}_ratelimited()"); `git -C cache/linux log -1 --format=%cd 65683fbed5c8` -> `Fri Oct 23 17:55:15 2026`.
- Checked: 2026-11-23. Re-check: when citing any bluetooth-next id.

**P-4. Patchwork state is not stable-queue state.** 14907537 stayed `new` while the stable team had queued it ("Queued for 6.12, thanks.", 2026-10-23).
- Evidence: `docs/STATUS.md` BT-14 row; worklog F-20. Checked: 2026-11-22 (record). Re-check: per patch (S-14).

## Sending and recipients

**R-1. Bluetooth kernel entry in MAINTAINERS.** Two maintainers, `linux-bluetooth@vger.kernel.org`, trees `bluetooth.git` (fixes) and `bluetooth-next.git`; `F:` lines `include/net/bluetooth/` and `net/bluetooth/`. Recipients come from `scripts/get_maintainer.pl`, not a frozen list.
- Evidence: `git -C cache/linux grep -n -A 16 "^BLUETOOTH SUBSYSTEM$" bluetooth-next/master -- MAINTAINERS` -> `M: Marcel Holtmann`, `M: Luiz Augusto von Dentz <luiz.dentz@gmail.com>`, `L: linux-bluetooth@vger.kernel.org`, two `T:`, two `F:`; `git -C cache/linux ls-tree bluetooth-next/master scripts/get_maintainer.pl` -> blob present.
- Checked: 2026-11-23, bluetooth-next `5063a0717aa2`. Re-check: when MAINTAINERS changes.

**R-2. The address in MAINTAINERS can differ from the one on a sign-off, so run the script.** The entry lists `luiz.dentz@gmail.com`; his sign-off on `7eac806143005` and `dc16388d45ec` is `luiz.von.dentz@intel.com`. Both are published addresses.
- Evidence: R-2 output and `git -C cache/linux show -s --format=%B dc16388d45ec`. Checked: 2026-11-23. Re-check: per send.

**R-3. `git send-email --suppress-cc` categories.** `all` suppresses all auto cc values; the `cc` category covers addresses in the patch header's Cc lines; `body` is shorthand for sob, bodycc and misc-by; `self` drops the sender. So `all` removes what the header Cc lines would add; the page does not say this in one sentence, so dry-run to yourself and read the `RCPT TO` lines before any real send.
- Evidence: https://www.kernel.org/pub/software/scm/git/docs/git-send-email.html "will suppress all auto cc values"; `cc`: "avoid including anyone mentioned in Cc lines in the patch header".
- Checked: 2026-11-23 (web; the project's own observation of the dropped header Cc is not in the records read). Re-check: on a git upgrade.

**R-4. lore is reachable by scripted readers only through some routes; test on the day.** On 2026-11-23 a direct fetch of `https://lore.kernel.org/linux-bluetooth/<message-id>/` returned HTTP 403; `https://ratatoskr.run/m/<message-id>` returned the message. Earlier records show 200 (2026-10-18) and 403 (2026-10-20) from lore itself, and a shallow local archive with history gaps.
- Evidence: fetch of `https://lore.kernel.org/linux-bluetooth/CABBYNZK9Oy2iL5PosxRy1KPup0PgYDfPUxeHemjYjKyAUu4+=Q@mail.gmail.com/` -> 403; `https://ratatoskr.run/m/CABBYNZK9Oy2iL5PosxRy1KPup0PgYDfPUxeHemjYjKyAUu4+=Q@mail.gmail.com` -> message of 2026-10-08 16:17:47.
- Checked: 2026-11-23. Re-check: every use; stale by nature. Not contested: the records describe a moving state.

**R-5. A BlueZ v2 went out 6.5 hours after v1 had been applied (2026-09-21), so fetch master before mailing.** Evidence: incident in `BRIEF.md` section 8 (the record). Checked: 2026-09-21 (record). Re-check: per send (T-2 covers the tip rule).

## Message style

**M-1. BlueZ's `HACKING` rules for a patch mail.** Send to the list; `[PATCH BlueZ]` prefix; 50/72 formatting with quoted tool output exempt; split by top-level directory without breaking the build; bug fixes before features; a cover letter when introducing a feature.
- Evidence: a read of `HACKING` l.98-153 (l.128-131 split, l.133 bug fixes first, l.135-138 50/72, l.140 prefix, l.144 cover letter); outside reviewers read the same file 2026-09-18/19.
- Checked: 2026-11-23, BlueZ `1608f8361`. Re-check: when `HACKING` changes.

**M-2. Rule of one logical change, self-contained descriptions, and a public base commit.** "Separate each logical change into a separate patch"; the patch (series) and its description "should be self-contained"; the base commit should be in an official maintainer or mainline tree.
- Evidence: `git -C cache/linux grep -n -E "Separate each \*\*logical|self-contained|base-commit:" ... submitting-patches.rst` -> `:171`, `:90`, `:871`. Web: https://www.kernel.org/doc/html/latest/process/submitting-patches.html "Make sure that base commit is in an official maintainer/mainline tree".
- Checked: 2026-11-23. Re-check: when the document changes.

**M-3. The networking process document says bug fixes must state how the issue was found and validated.** The document is `maintainer-netdev.rst`; it does not name Bluetooth, so applying it to Bluetooth is an inference.
- Evidence: `git -C cache/linux grep -n "must state how the issue was discovered" ... maintainer-netdev.rst` -> `:289`. Web: https://www.kernel.org/doc/html/latest/process/maintainer-netdev.html "All bug fixes must state how the issue was discovered and validated".
- Checked: 2026-11-23. Re-check: when the document changes.

**M-4. `Fixes:` names where the issue originated, not every related commit.** "used to make it easy to determine where an issue originated"; an earlier incomplete repair is named in prose, with one `Fixes:` for the origin (project's check on `19cfe912c37b`, 2017 diff). The mapping precedent names the commit that made the path reachable (`7eac806143005`: `Fixes: cf75ad8b41d2`).
- Evidence: `git -C cache/linux grep -n -A5 "A Fixes: tag indicates" ... submitting-patches.rst` -> `:604-607`; `reviews/2026-11-23T0404Z-...` row 11 for the 2017 diff.
- Checked: 2026-11-23. Re-check: per case.

**M-5. Subject prefix.** `Bluetooth: <area>:`; for `net/bluetooth/mgmt.c` the last 300 commits split 9 / 9 between `Bluetooth: MGMT:` and `Bluetooth: mgmt:`, so both are house style; a `SubjectPrefix` check exists (4 of 133 accepted series failed it).
- Evidence: `scripts/kernel-bt-survey.py`, output `reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-survey-output.txt`. Checked: 2026-09-22 (record), stale: window of 300 commits from September. Re-check: before quoting a count.

## Review and response

**V-1. Waiting before a resend or ping.** Wait at least one week before resubmitting or pinging; comments are expected "within a few weeks (typically 2-3)"; add RESEND only to an unchanged resubmission. The networking document adds: resend the whole series, as a new thread, at least 24 hours apart; whether the Bluetooth tree follows that is not stated.
- Evidence: `git -C cache/linux grep -n -E "Wait for a minimum of one week|typically 2-3" ... submitting-patches.rst` -> `:371`, `:369`. Web: submitting-patches.html "Wait for a minimum of one week"; maintainer-netdev.html "Allow at least 24 hours to pass between postings".
- Checked: 2026-11-23. Re-check: when the documents change.

**V-2. The maintainer's recurring asks.** Rebase and re-test on the current tip; a missing `Fixes:` is asked for and added in v2. In 87 non-bot comments (2026-07-22 to 09-21) these outweighed style comments.
- Evidence: `reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md` section 3; survey output. Checked: 2026-09-22 (record), stale by window. Re-check: before quoting.

**V-3. Silence is the common state.** Of 383 kernel patches posted 2026-10-27 to 11-14, 66 were accepted, 165 superseded, 152 `new`; a series the maintainer engaged with stayed `new` 38 days.
- Evidence: `scripts/patchwork-state.py`, `scripts/patchwork-recent.py`, `tmp/patchwork/`. Checked: 2026-11-15 (record) on bluetooth-next `da3cc02587c6`..`98bab74158b0`; **stale**. Re-check: re-run patchwork before quoting.

**V-4. Normal acceptance is silent.** In 133 accepted kernel series (2026-07-22 to 09-21), 93 had only the bot's results and the patchwork-bot "applied" mail; 6 (4.5 %) had a maintainer comment before acceptance; 52 (39 %) were v2 or later.
- Evidence: `scripts/kernel-bt-survey.py` (`reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-survey-output.txt`). Checked: 2026-09-22 (record); **stale**. Re-check: re-run.

**V-5. The "applied" notice is an automatic mail.** The kernel.org patchwork bot for Bluetooth writes "This patch was applied to bluetooth/bluetooth-next.git (master)" on the thread, signed "I am a bot".
- Evidence: one such notice of 2026-11-05 16:32:10, read through `https://ratatoskr.run/m/<message-id>` on 2026-11-23 (its message-id contains an address, so it is not quoted here), with the sentence above. BlueZ Rule 5 asks maintainers to reply once code is pushed: `doc/maintainer-guidelines.rst:116-123`.
- Checked: 2026-11-23. Re-check: not volatile.

**V-6. The maintainer's own fix took about ten days from authoring to commit and is still bluetooth-next only.** `1d7a52778858` authored 2026-11-09, committed 2026-11-19; contained only in `bluetooth-next/master`.
- Evidence: `git -C cache/linux log -1 --format="%ad %cd" 1d7a52778858` -> `Mon Nov 9 16:30:35 2026 -0500 Thu Nov 19 11:21:32 2026 -0500`; `git -C cache/linux branch -r --contains 1d7a52778858` -> `bluetooth-next/master`.
- Checked: 2026-11-23, bluetooth-next `5063a0717aa2`; **volatile**: re-check when it reaches mainline.

**V-7. An adjacent applied commit can carry the same code as ours.** `d7e77168da` has CO-12's `u32` conversion and clamp.
- Evidence: `git -C cache/linux grep -n "min_t(u32, duration / 10, U16_MAX)" ... net/bluetooth/hci_sync.c` -> `:1792`. Checked: 2026-11-23, bluetooth-next `5063a0717aa2`. Re-check: not volatile.

## Bots and CI

**C-1. The kernel-side tester selection in `bluez/action-ci` also fixes where mgmt-tester runs.** For `mgmt.c`, `mgmt_util.c`, `mgmt_config.c` and `mgmt.h` the runners are mgmt-tester and mesh-tester; `hci`, `af` and `build` file groups run every tester. The config names no source branch for the testers, so "tests built from BlueZ master" is not shown (see the unverified list).
- Evidence: https://raw.githubusercontent.com/bluez/action-ci/main/config.json -> the `mgmt` mapping with `"testers": ["mgmt-tester", "mesh-tester"]`; others `"__all__"`.
- Checked: 2026-11-23. Re-check: when the repository changes.

**C-2. The CI's pull requests are its vehicle, never merged, and say so.** Posted text: "the BlueZ repo in Github is only for CI and testing purposes" and "please send your patch to the Linux Bluetooth mailing list". 0 merged, 1073 closed unmerged at 2026-09-21.
- Evidence: https://raw.githubusercontent.com/bluez/action-ci/main/cleanup_pr.py (the two quotes); `gh api "search/issues?q=repo:bluez/bluez+is:pr+is:merged" --jq.total_count` -> `0` (record, 2026-09-21).
- Checked: 2026-11-23 (text), 2026-09-21 (counts; **stale**). Re-check: re-run the count before quoting.

**C-3. A v2 is a new series id and so a new pull request; nothing is done on GitHub.** The bot keys pull requests by the patchwork series id and counts closed ones as handled; a respin cannot extend an existing one.
- Evidence: `sync_patchwork.py` comment quoted in `reviews/2026-09-21T0900Z-bluez-ci-workflow-as-practised.md` section 2, with four PR/series pairs from `gh pr list -R bluez/bluez`.
- Checked: 2026-09-21 (record). Re-check: if the bot code changes.

**C-4. Series pull requests are closed after more than 14 days, by a five-minute cleanup job.** `cleanup_pr.py`: pull requests with a patchwork SID get no comments and are closed after more than 14 days with an archive mail; the bot's mail of 2026-11-12 00:36 UTC said a series picked up more than two weeks ago and never applied "must be resent to the Linux Bluetooth mailing list". `sync.yml` runs "Cleanup PR" and "Sync Patchwork" every 5 minutes.
- Evidence: web `cleanup_pr.py` (rule summarised by the fetch tool: "closed only after more than 14 days"); `git -C <BlueZ master at 1608f8361> grep -n -E "cron|Cleanup PR|Sync Patchwork".github/workflows/sync.yml` -> l.4 `cron: "*/5 * * * *"`, l.38 `Cleanup PR`, l.45 `Sync Patchwork`; `gh api repos/bluez/bluetooth-next/pulls/1009` -> `closed_at 2026-11-11T23:58:09Z` while patchwork showed the series `new` (record, 2026-11-15).
- Checked: 2026-11-23 on BlueZ `1608f8361`. Re-check: bot behaviour; look again for any series older than 14 days. A v2 is also the resend.

**C-5. Lint is advisory.** 25 of 63 accepted BlueZ series (40 %) carried a CheckPatch or GitLint fail or warning at acceptance; of 133 accepted kernel series 70 (53 %) had some bot fail or warning and 44 (33 %) a `TestRunner_*` fail; `VerifyFixes` failed on none (128 success).
- Evidence: `scripts/bluez-accepted-survey.py 10`, `scripts/kernel-bt-survey.py` over the 1000 newest patchwork entries 2026-07-22 to 09-21; outputs kept in `reviews/`.
- Checked: 2026-09-21/22 (record); **stale**. Re-check: re-run before quoting any figure.

**C-6. The bot's own configuration is looser than the written rule.** `.gitlint` sets the title limit to 72 (HACKING says 50), leaves B1 at its commented default, and does not relax B3 (hard tabs); Rule 2 exempts logs, traces and verbatim information from the 72-column limit. So a 56-character subject (`923d95d0c`) passes the bot.
- Evidence: `git -C <BlueZ master at 1608f8361> grep -n -E "title-max-length|line-length=72".gitlint` -> `:15`, `:16`; `git -C <BlueZ master at 1608f8361> log -1 --format=%s 923d95d0c` -> `mgmt-tester: Add single advertising set tests` (56 characters); `maintainer-guidelines.rst:40-42`.
- Checked: 2026-11-23, BlueZ `1608f8361`. Re-check: when `.gitlint` changes.

**C-7. The bot asks for nothing; no reply is owed unless the failure is yours.** Its mail says "do not reply"; it reports only the first long line per patch. Replies took about 90 minutes (BlueZ) to 2 hours (kernel).
- Evidence: bot mails to patchwork 14831546/14831547 on 2026-09-19 22:05/22:10 UTC (`reviews/2026-09-20T0300Z-bluez-ci-bot-results.md`). Checked: 2026-09-20 (record); response time is **volatile**. Re-check: read a recent bot mail.

**C-8. A failing check can be the bot's baseline.** TestFunctional failed the same two `test_bap_unicast_set_transport_*` tests on twelve patches from ten unrelated series (2026-09-17 to 19); the maintainer called such failures a CI-environment problem on 2026-09-15. Later (2026-10-10): smatch's VLA at `btdev.c:479`, a pairing timeout on an unrelated patch, and the kernel bot's apply step on a stable backport; on 2026-11-14 a CheckValgrind failure in `test-hog` on master.
- Evidence: `scripts/patchwork-checks.sh --failed-functional 60` (2026-09-20 ~03:00 UTC); `patches/kernel/bt9-stable/results/ci-bot-2026-10-10.md`; `contributions/README.md` CO-39 row (11-14).
- Checked: 2026-09-20, 10-10, 11-14 (records); **stale, volatile**: re-run `patchwork-checks.sh` on the day and judge only the difference to base (T-3).

**C-9. The Bluetooth maintainer cites an automated reviewer (Sashiko) in threads.** On 2026-10-08 he wrote "Sashiko flagged quite a few problems:" on an SCO series; the practice predates 2026-11-11.
- Evidence: https://ratatoskr.run/m/CABBYNZK9Oy2iL5PosxRy1KPup0PgYDfPUxeHemjYjKyAUu4+=Q@mail.gmail.com -> Luiz Augusto von Dentz, 2026-10-08 16:17:47, quoted sentence above.
- Checked: 2026-11-23. Re-check: per submission. What the tool is and which tree it reviews against are in the unverified list.

**C-10. BlueZ's stale workflow closes unlabelled issues.** An issue or PR is marked stale after 30 days without activity and closed 5 days later; issues labelled `bug` are exempt.
- Evidence: `git -C <BlueZ master at 1608f8361> grep -n -E "days-before|exempt".github/workflows/stale.yml` -> `:16 days-before-stale: 30`, `:17 days-before-close: 5`, `:18 exempt-issue-labels: 'bug'`.
- Checked: 2026-11-23, BlueZ `1608f8361`. Re-check: when the workflow changes.

## Backports

**K-1. Stable lines at 2026-11-23.** 7.3.6, 6.18.65, 6.12.119, 6.6.163, 6.1.193, 5.15.226 and 5.10.275 are live; 7.2.15 (2026-11-01) is end of life; mainline v7.4-rc4. A cover naming "7.2.y" must be corrected to the live lines.
- Evidence: https://www.kernel.org/releases.json -> `stable 7.2.15 2026-11-01 iseol true`; the others `iseol false`.
- Checked: 2026-11-23; **stale** after the next release. Re-check: before every stable mail.

**K-2. Stable queues differ by line, so check each line on the send day.** For CO-35 the pair was queued for 7.3 but not 6.18, 6.12, 6.6, whose queues held three sibling L2CAP patches (S-7 gives the 7.3.6 result).
- Evidence: `scripts/stable-queue-check.sh bluetooth-l2cap-hold-conn-lock 7.3 6.18 6.12 6.6` (2026-11-22 12:46 UTC); `git grep` in `stable-queue.git`.
- Checked: 2026-11-22; **stale** (stable 7.3.6 to 5.10.275 followed on 11-23). Re-check: on the send day with a positive control.

## Distributions (Ubuntu, PipeWire)

**D-1. PipeWire's repository guidance (`AGENTS.md` at `c74b645a7`) makes the human the author and poster.** Merge request, issue and commit text must be human-written; original logs MUST be included; no speculation on root causes beyond helping to gather evidence; no automated posting on GitLab; maintainers may ban people who break the rules.
- Evidence: `git -C cache/pipewire-upstream grep -n -i "MUST be included" c74b645a7` -> `c74b645a7:AGENTS.md:28: - Original logs MUST be included`; the same file's "No automated posting on GitLab" and "PERMANENTLY BANNING" paragraphs. Web check of the master copy: not possible (GitLab returned an access-denied page).
- Checked: 2026-11-23 on the commit named. Re-check: before filing, against master.

**D-2. Ubuntu versions move under you.** On 2026-11-10 an unrelated upload took the numbers the bluez debdiffs used (`5.87-4ubuntu0.1`, LP #2172906); a security upload could take `5.72-0ubuntu5.9`; noble had bluez `5.72-0ubuntu5.8`, systemd `255.4-1ubuntu8.19` (Updates 2026-11-19), `linux-hwe-7.0` `7.0.0-43` (Updates) and `-44` (Proposed since 11-20).
- Evidence: Launchpad `getPublishedSources` read 2026-11-14 and 2026-11-22 (record; the Launchpad API is not on today's web list).
- Checked: 2026-11-22; **stale, volatile**. Re-check: on the filing day, base version first.

## Contested

**X-1. Does a race seen only with a deliberately widened window qualify for stable?** The rule text (S-12) excludes "theoretical" races unless an explanation of how the bug is triggered is given; it says nothing about widened windows.
- For leaving off `Cc: stable`: reviewers 1, 3 and 6, reviewer 2 ("defensible"), reading the "theoretical race" rule. For adding it: reviewer 7, reading that the rules do not require natural frequency.
- Primary source: `stable-kernel-rules.rst:27`; does not settle it. Re-check: if the stable team comments on a case.

**X-2. Does a MGMT status fix with a user-visible change belong in stable?** Against: the precedent `7eac806143005` (`Fixes:`, no `Cc: stable`, not in 7.3.6) and reviewers 1 and 6; one adds that it changes a numeric status clients may branch on. For: reviewers 2, 3 and 7, because the old value is simply wrong. The precedent shows what was done, not what is right; the stable team may still select it via `Fixes:` (S-3).
- Re-check: per release (S-9 tracks the precedent).

**X-3. Should a truthful `Fixes:` be omitted to keep stable out?** Reviewers 2, 3, 6 and 7: no, `Fixes:` records origin and stable intent is a separate decision; reviewer 1: omit it for a change with no client-visible effect (AUTOSEL noise). The documents say `Fixes:` is the preferred way to indicate the bug fixed (`submitting-patches.rst:604-614`) and that `noautosel` is the opt-out; neither says whether to drop it for a cleanup.
- Re-check: when the stable documents change.

**X-4. Where the testing detail and the maintainer-question go in a message.** Reviewers 2 and 3: long matrices below `---`; reviewer 7: one or two sentences in the body so they stay in git; reviewer 6: the user-visible change above `---` as in the precedent. On "if it was deliberate, please say": drop (reviewers 2, 3, 7), keep one line (reviewer 6), keep (reviewer 1). No primary source decides; M-3 only says fixes must state how they were found and validated.
- Re-check: not volatile.

**X-5. How big a BlueZ test for a one-line kernel fix may be.** Four reviewers: shrink (about 30 lines suffice, no timer windows); reviewer 1: normal size for the tester's infrastructure. The test was rewritten to 30 lines on 2026-11-23 and reviewers 2, 3, 7 withdrew their holds; no maintainer was asked.
- Re-check: when the test is reviewed upstream.

**X-6. Spacing and structure of several sends.** Unrelated patches several days to a week apart (reviewers 3, 6) against no rule and no need to wait (reviewer 7; the guide has no spacing rule); a dependent patch inside one series (reviewers 3, 6, 7) against a separate thread that says "depends on" (reviewers 1, 2). The only primary text is "Each patch should yield a kernel which builds and runs properly" (`git -C cache/linux grep -n "builds and runs properly" ... Documentation/process/5.Posting.rst` -> `:110`).
- Re-check: not volatile.

**X-7. Whether Ubuntu takes small or cosmetic fixes into a stable update.** `reviews/2026-10-20T2309Z-contribution-opportunities.md:228`: CO-19 "not worth a request: Ubuntu rarely takes a cosmetic fix"; `reviews/2026-11-22T1519Z-contributions-upstream-check.md:270`: the same item is a "backport candidate". Neither gives a source and the SRU wiki page could not be read today (HTTP 404 on three URL forms).
- Re-check: once the SRU page is reachable.

## Reported, unverified

One line each: claim, then source.
- Ubuntu stable-update rules (fix in the development release first; one Launchpad bug per fix with impact, test plan, where problems could occur; a debdiff through `ubuntu-sponsors`; acceptance not automatic): `reviews/2026-11-22T1519Z-contributions-upstream-check.md` and `reviews/2026-11-16T1300Z-co46-noble-sru-review-checks.md` (an outside reviewer, 2026-11-16); `https://wiki.ubuntu.com/StableReleaseUpdates` returned 404 on 2026-11-23.
- Ubuntu's HWE kernel takes commits from newer upstream stable bases, judged only from changelog subjects: `reviews/2026-11-22T1519Z-contributions-upstream-check.md`.
- A stable backport mail carries the original authors' chain plus the submitter's own sign-off: `contributions/README.md` (rule noted 2026-11-16, no source; ).
- The kernel CI runs mgmt-tester from BlueZ master, so a new case needing an unapplied fix fails other people's CI: "our own records" in `reviews/2026-11-23T0540Z-bluez-test-with-kernel-fix-practice.md` (; config.json names no branch).
- Maintainer approval needed for a stable prerequisite over 100 lines is "the maintainers' call": an outside reviewer, 2026-11-14, `reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.
- Stable maintainers apply a `Cc:` adjustment comment as sent: outside reviewers 2 and 7, 2026-11-23.
- A stable-only revert is declined ("I'd rather not carry a stable-only revert ahead of it"): one quote in `reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md`; Greg Kroah-Hartman's form letter for a patch sent straight to the stable list, same file.
- An HTML reply is bounced by the list: one case in the same survey.
- Sashiko is the Linux Foundation's automated reviewer funded by Google; it reviews against the tree it picks; `sashiko.dev` and `sashiko-nipa` can differ; its check shows on patchwork ("fail, high"): `reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md`, `reviews/2026-11-15T0300Z-submitted-status-review-checks.md`.
- Mail columns for stable notes (72) and the stable list's expectations: `BRIEF.md` section 8.
- Short messages, one purpose, observable before/after succeed; machinery-heavy patches fall behind: three outside reviewers, 2026-11-23.
- Median 4 days from first post to commit, 75th percentile 11, longest 23 (268 patches, 2026-10-15 to 11-22); `Cc: stable` and message length do not predict acceptance: outside reviewer 6, 2026-11-23, not recomputed.
- A week of traffic had 53 kernel and 63 BlueZ series, 22 with several revisions: outside reviewers 2 and 3, 2026-11-23, via BlueZ weekly report. Review patterns (a v2 after a reviewer found missed cases; a NAK on a cosmetic cleanup): outside reviewers 2, 3, 7.
- A message that calls a change a "cleanup" while carrying `Fixes:` is contradictory: outside reviewer 6, 2026-11-14 and 11-23.
- A dead 2022 `Link:` should be dropped unless verified the same day: `reviews/2026-11-23T0404Z-...`.
- Reports and tests: a failing test's "known failures" must be re-verified before a mail says so; mesh-tester failed 122 of 122 before `87a49b610708` (35 success and 1 fail after): project checker, `10-17c` record (; the commit exists on bluetooth-next but the rates were not rechecked). Whether a green bot result predicts acceptance: patchwork `14873331` checks.
- syzbot closes a bug only with its tag, otherwise `#syz fix`, and `#syz test` is a mail to an outside service: `reviews/2026-11-22T1519Z-contributions-upstream-check.md` (; the kernel docs mention syzbot only in `maintainer-netdev.rst:292`). A patch can be applied with only a syzbot Tested-by and no maintainer reply.
- A patch with only the bot's reply can stay `new` for months (14864878 since 2026-10-03): `reviews/2026-10-20T2309Z-contribution-opportunities.md`.
- BlueZ patches from this project were applied by the maintainer within 0 to 3 days; one redundant v2 after 16 days: an earlier `git log` of the BlueZ export, not rerun.
- Stale GitLab and GitHub state of other projects' merge requests (gnome-bluetooth !137, gvfs !368/369) and Bugzilla reports: `reviews/2026-11-22T1519Z-contributions-upstream-check.md`; project status, not practice.
- Two reviewer claims about our own packages' scope (apply check and build dates are different facts): outside reviewers 2 and 7.

## Dropped

- "`Fixes:`-only Bluetooth commits rarely reach stable", as a conclusion: refuted by S-3. 7.3.6 took 36 of 87
  `Fixes:`-only commits and 6.18.65 took 24; the reviewer's 2 of 87 holds for 7.3.5 only. A second local count
  (69 / 10 / 60 over 2026-10-14 to 11-17) used a different window and path set.
- The reading in `reviews/2026-11-12T1508Z-upstream-contributions-status.md` section 3 that the bot closes only series patchwork no longer lists as `new`: refuted by `cleanup_pr.py` ("closed only after more than 14 days") and by pull request 1009, closed with the series still `new` (`gh api repos/bluetooth-next/pulls/1009`, 2026-11-15).
- 's characterisation of `Fixes:` plus `Cc: stable` as "the normal form": superseded, not refuted; S-5 counts 14 of about 100 November `Fixes:` commits with the Cc.
- 's "two to three weeks not found in the tree": corrected; `submitting-patches.rst:369` says "typically 2-3".
