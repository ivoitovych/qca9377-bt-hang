# CO-34 — log

## 2026-10-27 — patch written, the list bot's checks run
- **Patch:** `tools/ioctl-tester.c:921`, "Set Pkt Type - 2-DH" → "Set Pkt Type - 3-DH" for
  `set_pkt_type_3dh`. Commit `1012a6df2` on `b0bf49270d44`, worktree `cache/bt12-ioctl-tester`.
  The message has a `Fixes:` tag for `0da759f1a36d` (the hash was checked with `git log -1`; a
  first draft had it wrong) and no `Signed-off-by` (BlueZ's maintainer-guidelines, Rule 2).
- **Duplicates:** patchwork's bluetooth project has four ioctl-tester patches, none about this
  (`tmp/co02-v7ci/pw-ioctl-tester.json`). lore refused the automated search (HTTP 403).
- **The list bot's BlueZ checks** (`scripts/bot-ci-local.sh --space user --side patched`, its own
  code and image, `tmp/bt12/bot-bluez/`): CheckPatch, GitLint, BuildEll, BluezMake, CheckSmatch,
  bluezmakeextell, TestFunctional, IncrementalBuild and ScanBuild all PASS. The bot skips
  MakeCheck, MakeDistcheck and CheckValgrind for a change under `tools/`.
- **Compiled:** `CC tools/ioctl-tester.o` and `CCLD tools/ioctl-tester` appear in BluezMake.log
  (l.287, l.894) and in CheckSmatch.log (l.1056, l.1703). The binaries are gone afterwards
  because each check cleans the source in its post-run step. A first note here said the file
  had not been compiled, from a `find` after the run; that was wrong, and it was corrected before
  the commit.
- **CheckSmatch:** it reports "files found in the patch: ['tools/ioctl-tester.c']", and smatch's
  output has no entry for that file, so nothing is posted. The `bluetooth.h:232/237` lines appear
  in this run only under `tools/sco-tester.c` (CheckSmatch.log l.2135). That is why CO-02's
  sco-tester mail gets them: they come with sco-tester.c, not with our change.
- **The tester itself, in the bot's VM:** `scripts/bot-ci-local.sh --tree cache/co02-v7-kernel
  --base 47d4d9f67e92 --bluez-commit 1012a6df2 --side base --only TestRunner_ioctl-tester`
  (`tmp/bt12/bot-ioctl-tester/`). TestRunnerSetup PASS (kernel 7.3.0-rc6-01698-g47d4d9f67e92 with
  `doc/tester.config`, BlueZ at the patch), TestRunner_ioctl-tester PASS: "Total: 28, Passed: 28".
  The summary lists "Set Pkt Type - 2-DH" (l.954) and "Set Pkt Type - 3-DH" (l.955) as two cases.
  On master (`tmp/co02-v7ci/bot-full/base/`) the same 28 cases include two named "2-DH".
  `kernel-report-scan.py` on the log: clean. The script exited 0 with "ALL DONE, exit 0", which
  was the first run of its new exit status.

## 2026-10-28 — freshness walkthrough
- **Still needed, still applies.** BlueZ master is still `b0bf49270d44`; `scripts/pre-send-check.sh
  cache/bluez-upstream <patch>`: "OK to send". No other patch for it on patchwork since 10-12
  (`python3 -I scripts/patchwork-recent.py 2026-10-12`, 305 patches, none naming ioctl-tester).
- **Luiz Augusto von Dentz's pending series 1191414** (27 patches, 10-22, `new`) touches
  `tools/ioctl-tester.c` in 21/27 (GLib removed: the include, two struct fields, one `g_assert`)
  but not the duplicate name. With 21/27's `ioctl-tester.c` part applied, ours still applies
  (offset −2). So the two do not collide in either order.
- **Ready:** nothing is missing but the operator's yes and an app password.

## 2026-10-28 — six outside reviews of `24d76cd` (relayed by the operator; not consent)
All six approve sending it alone, unchanged. Reviewer 6: the duplicate is already in `0da759f1a36d`
(so the `Fixes:` is right) and the patch compiles with `-Wall -Wextra -Werror` on master; reviewer
4: it and Luiz Augusto von Dentz's pending GLib-removal patch apply in either order to identical
source. Left: the send-day freshness check, the dry run, the operator's word.
