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
- The tester itself is run next, through the kernel-side setup.
