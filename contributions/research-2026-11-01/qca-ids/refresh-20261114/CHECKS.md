# CO-22 refresh: the ASUS ROME pair against today's stable tips, 2026-11-14 (UTC)

Work area: `/root/exp/agent-work/lane5-status-stable-20261114/co22/` (scripts `asus.sh`, `run-all.sh`; logs in `logs/`; mail in `mail/`; hashes in `SHA256SUMS`). Nothing was sent; the project tree was not written to. Trees: depth-1 fetches of the stable tags and depth-2 fetches of the two mainline commits from the GitHub mirrors (`../k-fetch.sh`, `../k-fetch2.sh`).

## 1. Facts

| what | value | source |
|---|---|---|
| the pair | `d54601f21faf1ab5728e98e2102c3f738be0c177` "Bluetooth: btusb: add ASUS 0b05:1868 to QCA Rome quirks" (committed 2026-10-14 18:38:17 UTC), `cfa67a1dbfd9425044f6eef037a114b2d108f436` "... 0b05:1825 ..." (18:38:20 UTC); in v7.4-rc1 and master; in mainline they touch `drivers/bluetooth/btusb_main.c` (the 7.4 split) | `gh api`, 2026-11-14 |
| in a stable release or queue | no: neither ID in the `btusb.c` history of v7.3.4, v6.18.63, v6.12.117, v6.6.162, v6.1.192 (newest 15 commits each, back to Aug/Sep); `grep -c` of both IDs in the tag's `btusb.c`: 0 and 0 for every tag (first line of each `logs/pick-<tag>.log`); `stable-queue-check.sh bluetooth-btusb-add-asus-0b05`: not in queue for 7.3, 6.18, 6.12, 6.6, 6.1 (2026-11-14 01:05 UTC). 5.15 and 5.10 queues were not checked today (11-02: not in queue) | status check files |
| tips today | 7.3.4 (11-10), 6.18.63 (11-10), 6.12.117 (11-10), 6.6.162 (11-06), 6.1.192 (11-06), 5.15.225 (11-06), 5.10.274 (11-06) | kernel.org `releases.json`, 00:40Z |

## 2. Cherry-pick and btusb.o (measured; `logs/pick-<tag>.log`, `logs/build-btusb-<tag>-{base,pair}.log`)

`git cherry-pick -x d54601f21faf cfa67a1dbfd9` onto the tag, in that order, in its own worktree; `btusb.o` built before (base) and after (pair) with x86_64 defconfig + `BT=m`, `BT_HCIBTUSB=m` (+ `BT_BREDR`, `BT_LE`, `USB`, `NET`, `INET`, `RFKILL`), `make W=1 drivers/bluetooth/btusb.o`:

| tag | cherry-pick | base btusb.o | pair btusb.o | warning sets |
|---|---|---|---|---|
| v7.3.4 | clean (rc=0; "Auto-merging drivers/bluetooth/btusb.c" - the rename is followed) | built, 0 warnings | built, 0 warnings | identical |
| v6.18.63 | clean | built, 0 | built, 0 | identical |
| v6.12.117 | clean | built, 0 | built, 0 | identical |
| v6.6.162 | clean | **fails** with W=1 (rc=2): four `-Werror=unused-function` errors from `btmtk.h`, on the plain tag too (`logs/build-btusb-v6.6.162-base-with-werror.log`, `-pair-with-werror.log`) | same failure | with `CONFIG_WERROR` off (`NOWERROR=1`): both build, 4 warnings each, **identical** (`logs/pick-v6.6.162.log`) |
| v6.1.192 | clean | built, 0 | built, 0 | identical |
| v5.15.225 | clean | built, 0 | built, 0 | identical |
| v5.10.274 | clean | built, 0 | built, 0 | identical |

After the pick each `btusb.c` has both IDs once and the diffstat is 4 insertions in `btusb.c` (`logs/pick-<tag>.log`). The tool used: the host's gcc (as in the 2026-11-01 run, same tsv result "OK" for all lines). Results agree with `research-2026-11-01/qca-ids/stable-cherry-pick-asus.tsv` (7.3.1, 6.18.60, 6.12.115, 6.6.161, 6.1.191 clean); 5.15 and 5.10 are new in this table and also clean. The 6.6 W=1 failure is the known btmtk `-Werror` issue of that line (a separate report draft exists: `drafts/btmtk-6.6-werror-report.eml`); it does not come from the pair.

## 3. Request v3 (`mail/stable-request-asus-rome-v3.eml`, new; v2 kept)

Differences from v2: the seven tips named above (7.3.4 ... 5.10.274); "neither commit is in a stable release or in the stable queue (checked 2026-11-14)"; one sentence on the 7.4 file split and git's rename detection (the cherry-picks land in `btusb.c`); one sentence on the 6.6.162 W=1 failure being independent of the commits. mail-lint: clean. The send-day recheck of the queues is still owed (F-39 style): re-run `stable-queue-check.sh bluetooth-btusb-add-asus-0b05 7.3 6.18 6.12 6.6 6.1 5.15 5.10` and look at the tips.

## 4. Daan Bouwman's patch, patchwork 14976888 (0cf3:e303, Surface Laptop 3 AMD)

What it is (read from `raw/pw-14976888.json` of the status check): `[PATCH] Bluetooth: btusb: Add QCA Rome support for Surface Laptop 3 AMD (0cf3:e303)`, 2026-11-12 15:24 UTC, state `new` at 2026-11-14 ~03:06 UTC, only the CI bot has commented (21:23 UTC). One hunk in `drivers/bluetooth/btusb_main.c`, two lines: `0cf3:e303` with `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`, placed after `0cf3:e301`. The author reports the device as QCA6174, shows the `lsusb`-style device listing, the rampatch/NVM 0x302 files loading, and says he tested on v7.2.15: stock btusb shows "unexpected event for opcode 0x2005", patched shows none. It carries `Cc: stable@vger.kernel.org` itself. It is not in bluetooth-next (btusb history, 2026-11-14 01:10 UTC) or mainline.

Answer: **ID survey only; not in the request.**
- It is not merged; a stable request may only name mainline commits. Once it is merged it carries its own `Cc: stable`, so the stable team will take it without a request from us; adding it would only double the thread.
- The ID is already in the survey as a candidate (`candidate-computers.tsv`: `0cf3:e303`, Surface Laptop 3; `linuxhw-bt-ids.tsv`; `dmesg-evidence.tsv`). The patch turns that candidate into a confirmed one by an independent author's device report. Record it in the survey with the patchwork ID.
- The owners' call mail (`drafts/owners-call-qca-rome-ids.eml`, line 30) still lists `0cf3:e303`: that line should go (the patch exists), and the mail's count of open candidates drops by one. This is a draft edit for the main session to decide.
- Not "nowhere": it supports the first paragraph of the request's argument (more ROME IDs missing from the table, the same symptom) and the survey's count; and it is a second 2026 patch of the same shape that the maintainers accepted without objection so far (the ASUS pair, merged 10-14), which suggests the owners' mail may get a quick answer. (inferred)
- Its text carries a tool note in the "Notes" block; nothing of it is copied into our files.

## 5. Not done / limits

Only `btusb.o` was built (as asked); no module was loaded and no device test was possible (the devices are the authors'). The 6.6 W=1 failure needs `CONFIG_WERROR=n` to build the object. 5.15/5.10 queue state was last checked 2026-11-02. A send-day recheck is owed.
