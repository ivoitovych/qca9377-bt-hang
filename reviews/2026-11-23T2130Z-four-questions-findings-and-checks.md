# Four questions to the outside reviewers (2026-11-23 evening): answers checked

**The questions:**
1. CO-44 and stable, given that the stable team picks `Fixes:`-only commits: do MGMT clients act on 0x05 versus
   0x08?
2. Is unpatched-against-patched testing with current BlueZ master acceptable on stable lines?
3. CO-43 1/3 and the `btusb_main.c`/`btusb.c` rename.
4. How much testing belongs below `---`.

All five reviewers answered (1, 2, 3, 6 and 7). The full texts are kept privately; only the findings are here.
Each claim that changes what we do was checked first.

## Checked

| claim | check | result |
|---|---|---|
| The upstream CI lists **11** testers, including 6lowpan-tester, and picks them by changed file (reviewer 7) | our copy was the old fork `BluezTestBot/action-ci` (2024-11). Fetched `https://github.com/bluez/action-ci.git` HEAD `c7d077f185cd` and read `config.json` | **true**: l.37–48 list 11 testers; `net/bluetooth/mgmt.c` → mgmt-tester and mesh-tester (l.79–86); `drivers/bluetooth/` → `__none__` (l.157–161); a file matching no rule → all. Register entry T-1 corrected; 6lowpan-tester is added to the current-tips runs |
| Only a real cherry-pick proves the rename is handled, not a path-rewriting apply check (reviewer 7) | `tmp/kernel-queue-20261123/cherry-pick-lines.sh 888176e9a640`: `git merge-tree --write-tree --merge-base=<c>^ <tip> <c>`, the three-way merge of a cherry-pick, with rename detection | **CLEAN on all seven tips**. The change lands in `btusb_main.c` on 7.3.6 and in `btusb.c` on 6.18.65, 6.12.119, 6.6.163, 6.1.193, 5.15.226 and 5.10.275 |
| Whether 7.3.6 took CO-44's precedent `7eac80614300` (reviewer 6) | `backport-in-lines.sh 7eac80614300`; `merge-base --is-ancestor` with mainline | in mainline, **in none of the seven stable lines**, although 7.3.6 took 36 other `Fixes:`-only Bluetooth commits |
| BlueZ acts on 0x05 versus 0x08 only in bonding, not in the Set Powered, UUID or Device Class callbacks (reviewers 1, 2, 3, 6, 7) | consistent across five independent source readings with file and line references (BlueZ `1adfe662efef`: `device.c`, `adapter.c`, `client/mgmt.c`, `src/shared/mgmt.c`) | accepted as reported. Two details: `adapter.c` treats `RFKILLED` specially, and reviewer 6 found Home Assistant's `bluetooth-auto-recovery` compares only with 0x00 |
| CO-44 changes `mgmt_errno_status(-ETIMEDOUT)` for every MGMT path that returns `-ETIMEDOUT`; the four named commands are examples (reviewer 3) | the message says "MGMT commands such as …" and "MGMT commands that fail with -ETIMEDOUT now complete with Timeout (0x08) instead of Authentication Failed (0x05)" | already stated as a general change; no edit |

## Positions

| question | 1 | 2 | 3 | 6 | 7 |
|---|---|---|---|---|---|
| CO-44 trailer | as packaged, or `noautosel` with a reason (prefers `noautosel`) | as packaged | **add `Cc: stable`** (changed) | as packaged; adding it is defensible | **add `Cc: stable`** (changed) |
| BlueZ for stable lines | keep master | keep master; compare per case | keep master | keep master; for the MGMT one-liners mgmt and mesh are enough on stable lines | keep master; compare per case |
| CO-43 1/3 and the rename | `Cc: stable`, no note | `Cc: stable` with a path note on the tag | `Cc: stable`, no note | the tag with a path note; per-line backports ready | `Cc: stable`; a path note below `---` |
| testing notes | short paragraph; one `Link:` optional | 3–7 lines; immutable link optional | 4–7 lines; no link; a table only in a reply if asked | 4–6 lines; no link in one-liners; one small kmemleak table in the btusb cover | about three sentences; pinned link optional |

**Common ground:**
- **The running batch stays as it is.** Its method is sound. The comparison is per case name, not per total; hung or truncated suites are marked as incomplete.
- **The ten BlueZ testers do not exercise btusb.** For 1/3, the usbip kmemleak cases on each line are the evidence that counts.
- **Reviewer 6 adds a W=1 build with `CONFIG_PM=n`** per line. It is passed to the CO-43 stable-line job.

## Outcome

- **CO-44:** the operator's choice between three options: as packaged (2 of 5), `Cc: stable` (2 of 5), or
  `noautosel` (1 of 5). The precedent was not taken into any stable line.
- **CO-43 1/3:** `Cc: stable` once its seven-line runs pass, by 5 of 5. The cherry-pick is verified clean.
  Whether to add a path note is still open: 3 for a note, 2 against.
- **Testing notes:** a short paragraph below `---`, giving the trees and the result as a difference. No tables
  in the one-patch mails. A link is optional, and if used it is one pinned page.
- **The register** (`docs/upstream-practice.md`): T-1 is corrected, and S-8 and S-9 are added from the
  checks above.
