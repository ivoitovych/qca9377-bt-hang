# CO-44 send package of 2026-11-23

It replaces `../send-20261113/` after the outside review of 2026-11-23
(`../../../reviews/2026-11-23T0404Z-five-kernel-submissions-review-findings-and-checks.md`,
findings 4–8).

**Changed in the kernel patch** (its message only; the diff is byte-identical):
- The body now leads with the misleading user-visible error.
- The "user-visible change" sentence moved above `---`.
- Removed:
  - the count "the two HCI statuses", since another posting may map a third status to `ETIMEDOUT`;
  - the LE-connection paragraph;
  - "if it was deliberate, please say";
  - the 2022 `Link:`, since nobody could verify what it shows;
  - the paragraph declining stable.
- The notes below `---` are cut to one test paragraph.
- No `Cc: stable`. This follows the closest precedent, bluetooth-next `7eac806143005`
  ("MGMT: Return RFKILLED …", 2026-11-02, `Fixes:` and no stable tag). The maintainer can add it.
- The subject is kept. Reviewer 7 offers "Bluetooth: MGMT: Report command timeouts correctly";
  that choice is the operator's.

**The BlueZ test** (`bluez/`) is unchanged from `../send-20261113/bluez/`. Its subject is 46
characters.

**Checked 2026-11-23:**
- the kernel patch applies to bluetooth-next `cf357cfc025e`;
- `checkpatch.pl --strict --no-tree --no-signoff`: 0 errors, only the "unknown commit id" warning
  that `--no-tree` gives;
- the BlueZ test applies to BlueZ master `1adfe662efef` (11-22).

**Done 2026-11-23 (later the same day):** item 1. The run is in
`../../CO-38-read-adv-features-hidden-instances/send-20261123/RUNS-20261123.md`, where one image
per line carried both fixes. On bluetooth-next `cf357cfc025e` the case fails 3/3 on base and
passes 3/3 patched, and nothing else changes in mgmt-tester, l2cap-tester, smp-tester or
mesh-tester. The same holds on 7.3.5 to 6.1.192. The patch's testing note now gives
`cf357cfc025e`.

**Still to do before a send:**
1. ~~Rerun mgmt-tester, l2cap-tester and smp-tester, base against patched, on today's tip
   (`mgmt.c` changed by +294/−83 since `da3cc02587c6`), then update the notes.~~ Done, see above.
2. The operator adds his Signed-off-by. Then rerun checkpatch and the bot's sign-off checks on the
   exact file, and do a new `git send-email` dry run. `../send-20261113/send-commands.txt` STEP
   2a/2b still applies; only the file paths change.
3. **The BlueZ test goes the same day**, as its own mail after the kernel mail's lore link. That
   is the established practice (`../../../reviews/2026-11-23T0540Z-bluez-test-with-kernel-fix-practice.md`:
   7 of 11 pairs; BlueZ often applies such tests before the kernel fix). The operator asked on
   2026-11-23 to follow the practice.
