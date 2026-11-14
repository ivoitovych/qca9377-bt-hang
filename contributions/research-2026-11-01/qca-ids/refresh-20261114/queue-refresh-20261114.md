# Queue refresh for CO-22 and CO-35, 2026-11-14 (public reads only; nothing posted)

Commands: `scripts/check-queues.sh`, `scripts/check-content.sh`, `scripts/tags-vs-tips.sh`, `scripts/apply-rc.sh` (logs in `logs/`, pages in `fetched/`). All times UTC.

## Result in one line

**None of the commits is in a stable release, in a stable-queue directory, or in a stable-rc branch of any line (CO-22: 7.3, 6.18, 6.12, 6.6, 6.1, 5.15, 5.10; CO-35: 7.3, 6.18, 6.12, 6.6). The newest releases are still the tags the packages were tested on.**

## Record of the checks

| what | how | times | result |
|---|---|---|---|
| newest releases | kernel.org `releases.json` (`fetched/releases-20261114T130831Z.json`) | 13:08:31 | 7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192, 5.15.225, 5.10.274 (mainline 7.4-rc2); 7.2.15 is the last of the EOL 7.2 line |
| branch tips equal the tags | `git ls-remote` of `stable/linux.git` against the tags (`logs/tags-vs-tips.txt`) | 13:44:38 | all seven `linux-<v>.y` tips equal the tag commits: no newer release |
| stable queue | the `queue-<v>/` tree listing of `stable-queue.git` (`fetched/queue-<v>-20261114T130831Z.html`), grep for `asus`, `rome`, `0b05`, `l2cap`, `connection-interval`, `btusb` in the file names (`logs/queue-check-20261114T130831Z.txt` section 2) | queue-7.3 13:08:33, 6.18 13:08:35, 6.12 13:08:36, 6.6 13:08:38, 6.1 13:08:40, 5.15 13:08:41, 5.10 13:08:43 | none of our patches: no file for the two ASUS commits, for `608e0b7a675b`, `32d86e048d8e` or `5874f8d03268` (the listed L2CAP and btusb files are other patches: "ignore connection responses ...", "reject mode changes ...", "reject invalid txwindow ...", Realtek IDs). The queues are large (507 to 1853 files), so a release is likely soon |
| released branch tips, content | plain files of `stable/linux.git` at each `linux-<v>.y` (`logs/content-check-20261114T134118Z.txt`), grep with controls | 7.3 13:41:19, 6.18 13:41:24, 6.12 13:41:28, 6.6 13:41:31, 6.1 13:41:35, 5.15 13:41:38, 5.10 13:41:40 | `btusb.c`: `0x0b05, 0x1868` x0 and `0x0b05, 0x1825` x0 on all seven; `l2cap_core.c` (7.3, 6.18, 6.12, 6.6): `l2cap_chan_lock_conn` x0, `l2cap_chan_close_unlocked` x0; 7.3 `hci_event.c`: `le_min_rate_interval = rp->min` x0 (the SCI fix is absent). Controls present in every file (`btusb_probe` x2, `l2cap_chan_del` x21, `hci_cc_le_read_conn_interval` x2) |
| release-candidate branches, content | same on `linux-stable-rc.git` | 7.3 13:41:43, 6.18 13:41:48, 6.12 13:41:52, 6.6 13:41:55, 6.1 13:41:59, 5.15 13:42:02, 5.10 13:42:04 | same zeroes on all seven lines. The rc tips are ahead of the releases (`l2cap_core.c` of 7.3.y rc: 197494 bytes against 196030 released), so a new release round is in progress without our commits |
| do our patches still apply on the rc tips | `git apply --check` of the full and the reduced patches on the three touched files of the rc branches (`logs/apply-on-rc-tips.txt`) | 13:45:14 to 13:45:32 | 7.3, 6.18, 6.12, 6.6: all four patches of both variants apply |

**Not reliable, not used:** cgit's log search (`qt=grep`) on git.kernel.org. `check-queues.sh` section 3 and 4 searches by subject returned 0 for everything, and the controls (`logs/queue-check-controls-20261114T133936Z.txt`: subjects that must be found, such as "Fix corrupted list in hci_chan_del" on `linux-6.6.y`) also returned 0, so the search does not work as I called it. The file-content checks above carry the result. (`stable-rc-check.sh` of the project does the subject search with git instead; not run here because it writes to `cache/linux`.)

The 5.15 and 5.10 lines had been checked last on 11-02; they are refreshed here.

## The corrected date sentence for the CO-22 mail

The mail (`refresh-20261114/mail/stable-request-asus-rome-v3.eml`, line 35-36) reads: "None of the seven trees has either ID, and neither commit is in a stable release or in the stable queue (checked 2026-11-14)." The README says 7.3 to 6.1 were checked on 11-14 at 01:05 UTC and 5.15 and 5.10 only on 11-02. Replace the sentence by (valid for all seven lines as of this refresh):

> None of the seven trees has either ID, and neither commit is in a stable release, in the stable queue or in a stable-rc branch of any of the seven lines (all seven lines checked on 2026-11-14 between 13:08 and 13:42 UTC; the release tips were 7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192, 5.15.225 and 5.10.274).

If the mail goes out on a later day, the sentence's date has to be redone on that day (`scripts/check-queues.sh`, `scripts/check-content.sh`); the rc branches are moving.

For CO-35 the same facts, for the covers and requests: "the two commits are in v7.4-rc1 and in no stable release, queue or rc of 7.3.y, 6.18.y, 6.12.y or 6.6.y (checked 2026-11-14 13:08 to 13:42 UTC); 7.3.y still lacks `5874f8d03268`".
