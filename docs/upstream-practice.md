# Upstream practice: the register of what we learned the hard way

How the upstreams we send to actually behave and what they expect: the Linux Bluetooth maintainers, the stable
team, the list bots, BlueZ, and later Ubuntu and PipeWire. Each entry is one fact, verified against a primary
source, with:
- **evidence:** the command or link, and the decisive output;
- **checked:** the date and the tree or tip it was checked on;
- **from:** the record it came from;
- **re-check:** whether it goes stale, and when to look again.

Statements from outside reviews enter only after such a check. What could not be verified is listed at the end
as "reported, unverified". Seeded 2026-11-23; filled from the review records and the reviewers' texts after that
(the harvest of 2026-11-23).

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

**S-3. In Bluetooth, the stable team takes many commits that carry `Fixes:` without `Cc: stable`, weeks after
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

**S-4. The two stable backport forms.** A patch requested with `Cc: stable` arrives as "commit <sha> upstream". A
commit the stable team chose itself arrives as "[ Upstream commit <sha> ]", with a Sasha Levin sign-off. A search
for backports must match both.
- Evidence: `git -C cache/linux log -n 1 878dd63b2828` (7.3.y) begins with
  `[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]` and ends with `Signed-off-by: Sasha Levin`.
  `32d86e048d8e` has `Fixes:` and no stable tag.
- Checked: 2026-11-23.

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
- Checked: 2026-11-23.
- Re-check: per stable release.

**S-9. CO-44's precedent stayed in mainline.** `7eac80614300` (MGMT RFKILLED mapping, `Fixes:`, no stable tag) is
in mainline and in none of the seven stable lines. 7.3.6 took 36 other `Fixes:`-only Bluetooth commits but not
this one.
- Evidence: `tmp/kernel-queue-20261123/backport-in-lines.sh 7eac80614300`.
- Checked: 2026-11-23.
- Re-check: per stable release.

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

## BlueZ tests that accompany a kernel fix

**B-1. Post the test the same day, as its own BlueZ thread.** This happened in 7 of 11 kernel-fix/tester pairs
since 2025-11, and BlueZ often applies the test before the kernel fix. No maintainer objected to a test that fails
on unfixed kernels.
- From: `reviews/2026-11-23T0540Z-bluez-test-with-kernel-fix-practice.md`.

**B-2. A BlueZ patch carries the subject prefix `[PATCH BlueZ]`.**
- From: the review records of 2026-11-23.

**B-3. Generate each BlueZ test alone on the current master.** One cut on a tree that holds the other test applies
only with offsets.

## Patchwork and applied state

**P-1. Patchwork can show `new` for a series already applied.** Check applied state in the tree with
`git merge-base --is-ancestor` on a fresh fetch.
- Example: Cen Zhang's `d7e77168da`, applied three days before patchwork changed state.
- From: `reviews/2026-11-22T1240Z-kernel-contributions-review-worklog.md` F-46.

**P-2. A maintainer may answer several outside patches with his own fix.** `1d7a52778858` (bluetooth-next,
2026-11-19) overtook Hui Peng's mesh_tx patch, other authors' mesh fixes and our CO-04, CO-05 1/2, CO-06 and CO-14.
- From: `reviews/2026-11-22T1519Z-contributions-upstream-check.md`.

## Reported, unverified

(Filled by the harvest of 2026-11-23.)
