# CO-34 — the send package (for review before sending)

**One mail, BlueZ, not sent.** The file to send is
[`0001-ioctl-tester-Fix-name-of-the-3-DH-packet-type-test.patch`](0001-ioctl-tester-Fix-name-of-the-3-DH-packet-type-test.patch),
exactly as it stands (BlueZ commit `1012a6df2` on master `b0bf49270d44`).

## What it fixes
BlueZ `tools/ioctl-tester.c` registers two cases under the name "Set Pkt Type - 2-DH" (lines 918
and 921 of master `b0bf49270d44`); the second runs the 3-DH packet types. A 3-DH failure would be
reported as a 2-DH one, and tools that match verdicts by case name cannot tell the two apart. The
patch renames the second case "Set Pkt Type - 3-DH". `Fixes:` the commit that added the tester.

## To whom
`linux-bluetooth@vger.kernel.org` only, as a single mail, with the `[PATCH BlueZ]` prefix. As for
the earlier BlueZ cleanups of 2026-10-18: no `Signed-off-by` (BlueZ's maintainer guidelines, rule
2), no Cc.

## Checked (`../log.md`)
- `scripts/pre-send-check.sh cache/bluez-upstream <patch>` on 2026-10-28: applies to master, not
  yet upstream: "OK to send". No competing patch on patchwork since 2026-10-12.
- The list bot's own BlueZ checks, run here with its code and image
  (`scripts/bot-ci-local.sh --space user`): CheckPatch, GitLint, BuildEll, BluezMake, CheckSmatch,
  bluezmakeextell, TestFunctional, IncrementalBuild, ScanBuild all PASS.
- ioctl-tester built from the patch and run in the bot's VM on bluetooth-next `47d4d9f67e92`:
  28 of 28 passed, "2-DH" and "3-DH" listed as two cases; kernel log clean.
- A pending series by Luiz Augusto von Dentz (patchwork series 1191414) edits other lines of the
  same file; the patch applies before or after it.

## The send (only on the operator's word)
On the day: re-run `scripts/pre-send-check.sh`, then a dry run, then the send, in the operator's
terminal, with an app password used once and revoked afterwards:

    git -C cache/bluez-upstream send-email --dry-run --to=linux-bluetooth@vger.kernel.org \
        --suppress-cc=all <this file>

## Questions for reviewers
1. Is the subject and message right for BlueZ (prefix, length, `Fixes:` form)?
2. Anything in the change itself, or in sending it alone, that a maintainer would object to?
