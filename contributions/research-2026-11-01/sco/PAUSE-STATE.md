# research-sco: pause state (2026-11-01, about 01:35 local)

**Resumed 03:3x and finished 03:52:44.** The matrix is complete (`results/run-summary-2026-11-01.txt`),
and the report was delivered. This file is kept as the record of the pause.

Research on CO-01 (the abandoned-setup SCO series) and CO-30 (the deferral RFC). Nothing was sent,
posted or reviewed. The laptop's Bluetooth was not touched. QEMU guests and file reads only.

## Running when paused (left running, nothing killed)
- `scripts/run-matrix.sh 1 1 both sco-tester-co01,sco-tester-co02,l2cap-tester-co01`: the third
  tester (l2cap) on kernel `both`. Its log is `logs/run-both-l2cap-tester-co01-c1-1.log`, and its end
  line is written to `progress.log` ("end ... kernels=both").
- Results so far (from the run's own output):
  - `both` + `sco-tester-co01`: Total 31, Passed 31.
  - `both` + `sco-tester-co02`: Total 33, Passed 33.

Note: about 01:45 the l2cap run still had no end line. The "failed" wait task at that time was
only my 580 s wait helper timing out, not the run. run-matrix gives each guest at most 900 s.

**Result of that run (ended 01:40:00):** `l2cap-tester-co01` on kernel `both` printed **no
Total**. The guest stopped at the teardown of "L2CAP LE Client - SCI Fast Mode". That case is not
one the series adds. The log has "Opcode 0x20a3 failed: -38" just before. run-matrix's 900 s limit
then killed qemu, `exit=124`.
- Before the hang, "L2CAP BR/EDR Client - Close Before Complete" **passed**, and "L2CAP BR/EDR
  Client - Timeout" timed out.
- Not yet known: whether the hang comes from the kernel and tester versions not matching. The
  testers are BlueZ `b0bf49270d44` of 10-26; the kernel base is `97a128698d9d` of 10-08.
- **Resume step 2 answers it:** the same tester on `base` (and on `co01`). If `base` hangs the same
  way, run l2cap-tester with `-p "Close Before Complete"` only.

## Done
### Upstream state (2026-11-01)
- **lore archive** fetched to `fb9a6f9b` (2026-10-31 22:56 UTC) and deepened 1500. Script:
  `scripts/lore-thread.py`.
- **CO-01, Hitalo Souza v3**:
  - patchwork 14875449 to 14875454: all `new`, no v4. His last list post was 2026-10-08.
  - Maintainer reply on the v3 cover, Luiz Augusto von Dentz, 2026-10-09 13:57 UTC, lore commit
    `65487831e1d9`: "Sashiko is flagging a few more problems" (with the sashiko link). The CO-01
    dossier says the bot's mail is the only reply. That is **wrong**.
  - The sashiko review of v3 (`tmp/sashiko/hitalo-v3.json`, `scripts/sashiko-reviews.py`) has
    findings on two patches:
    - 1/6: `hci_sco_setup()` still takes only the first link (`hci_conn.c:624` at `42b8c2d72926`);
    - 3/6: lockless `abort_reason` / state reads.
  - The BlueZ test series (patchwork 14875435) had its CI pull request closed by the bot on
    2026-10-24 ("never applied").
  - BlueZ #2562: on 2026-10-13 a reporter tested v3 on an Intel AX210 and found it does **not** fix
    their case (`tmp/bluez-issue-2562-comments.json`). In variant B, a new setup sent 6 ms before
    the abandoned link's Disconnection Complete gets 0x0a. The author is active there (2026-10-27).
- **CO-01 applicability**:
  - `git am` on bluetooth-next `42b8c2d72926` fails at 3/6 (`hci_event.c:3217`), because
    `fb8d5f9d25338` (2026-10-23) changed `hci_read_enc_key_size()`.
  - A 3-way cherry-pick is clean (no `flags` usage, so `94ae830c1415b` does not matter).
  - On its base `97a128698d9d`, `git am` is clean.
  - CO-02 v7 applies on top of it in both places.
- **CO-02**:
  - patchwork 14919266 to 14919269 are `new`; no human reply on lore.
  - **sashiko reviewed it on 2026-10-27 16:52 UTC** (`tmp/sashiko/co02-v7.json`, sashiko
    patchset 97061). It raised one "High" point on patch 1: the `sco->link` branch falls through,
    overwriting `setting`/`codec` and possibly calling `hci_sco_setup()` again.
    - From source: this is pre-existing, because `hci_conn_link()` returns the existing link at
      `hci_conn.c:1872-1873`. A duplicate setup is possible only on the enhanced path
      (`hci_conn.c:484`, state stays `BT_OPEN` until the queued work runs). It is not possible on
      the laptop's legacy path (`hci_conn.c:418`).
    - The CO-02 log says "sashiko: nothing yet". That record is now **outdated**.
  - **BlueZ**: `e37f17751` (2026-10-29) moved sco-tester to the mainloop, and BlueZ master is now
    `14bd6ab65`. The CO-02 BlueZ test mail no longer applies (`tools/sco-tester.c:27`), so a ported
    v2 is now owed. The CO-01 BlueZ sco-tester mail still applies to master.
- **New upstream code on these paths** since `47d4d9f67e92`: only `c278da2c47612` (hci_sync IRK,
  not SCO).
- **CO-30**: the RFC `git am` is clean on `42b8c2d72926` + CO-02 v7 (commit `98bc5ffb5088`). Its
  ordering premise holds from source:
  - `hci_disconnect_sync()` waits for `HCI_EV_DISCONN_COMPLETE` (`hci_sync.c:5990-5994`);
  - the event handler runs before the sync waiter is woken (`hci_event.c:8133` before `:8141`).

### Laptop evidence
- `scripts/sco-setup-scan.py` over `archive/bt-trace` (350 captures, 2026-09-24 to 10-30):
  - 428 SCO setups, 425 completed successfully;
  - 0 failed Command Status, 0 failed Synchronous Connect Complete;
  - 0 completions arriving with no setup pending, 0 times two links up at once.
  - The 5 Create Connection Cancels (09-25, 09-26) all fall inside controller hangs (BT-1, solved):
    none got a Command Complete. `scripts/sco-cmd-timeline.py` shows this for 13:30:00 UTC on
    09-25.
  - The full output is the background task output; **re-run it to keep a copy** (command below).
- Journal `-k -p err` for "Ignoring HCI|Opcode 0x0408|0x0428|0x043d": no entries.
- Ubuntu `7.0.0-42` carries `024e05f73a4c` (`commit-in-tree.py`: PRESENT), so the series' patch 2
  needs no lock adaptation there.

### Earlier project runs found (not in the CO-01 dossier)
- `tmp/co02-send/logs/hitalo-*.log` (2026-10-21/22): his sco-tester and l2cap-tester tests.
  - base and "ours" (the 2-patch CO-02): FAIL (3 new cases time out);
  - his series and his + ours: PASS, 31/31 and 113/113.
- CO-02 `experiments/results-2026-10-21.md:37`: his series alone, During 0/5.

## Half done: QEMU matrix (UP, BlueZ tester.config with KASAN and lockdep)
Images are in `img/`, built 01:15:44 to 01:26:52:
- `base` = `97a128698d9d`
- `co01` = `79b071b1d3a1`
- `co02` = `9ec346626595` (CO-02 v7 alone)
- `both` = `5528bc09a1ad`

Testers in `bin/` (BlueZ `b0bf49270d44` + each author's mail, `git am`):
- `sco-tester-co01`
- `l2cap-tester-co01`
- `sco-tester-co02`

## Resume (one command per call)
1. Check that the `both` l2cap run ended: `grep -n "end " /root/exp/agent-work/research-sco/progress.log`
2. `/root/exp/agent-work/research-sco/scripts/run-matrix.sh 1 1 base,co01,co02 sco-tester-co01,sco-tester-co02,l2cap-tester-co01`
3. `/root/exp/agent-work/research-sco/scripts/run-matrix.sh 3 1 both,co01 sco-tester-co01,sco-tester-co02`
   (the logs for run 1 exist and are skipped, so runs 2 and 3 are added)
4. Optional SMP: `/root/exp/agent-work/research-sco/scripts/build-kernels.sh smp /root/exp/qca9377-bt-hang/tmp/co02-w2/frag-smp.config both-smp=5528bc09a1ad21a2c80b3808e68d0944627a9406`,
   then `run-matrix.sh 3 4 both-smp sco-tester-co01,sco-tester-co02`
5. Optional CO-30 check at the bluetooth-next tip:
   `build-kernels.sh up2 - tipco02=7ac22ae8fa1b7bf1c4b70893790fae201555ba00 tiprfc=98bc5ffb5088ffda7f60b274286c0cc3cbc51b8e`,
   then `run-matrix.sh 1 1 tipco02,tiprfc sco-tester-co02` and the earlier retry tester
   `/root/exp/qca9377-bt-hang/tmp/co02-w2/bin/sco-tester-exp` with
   `-p "Reconnect During Disconnect Retry"`. run-matrix takes `bin/<name>`: copy that binary into
   `bin/` first with `cp`.
6. `python3 -I /root/exp/agent-work/research-sco/scripts/summarize-runs.py <logs/run-*.log>`
   (list the files; no glob)
7. Keep the capture scan output:
   `python3 -I /root/exp/agent-work/research-sco/scripts/sco-setup-scan.py --jobs 3 /root/exp/qca9377-bt-hang/archive/bt-trace`
   in the background, and save it as `logs/capture-scan.txt` via a helper.
8. Write the final report (per item, table, files). The draft conclusions are below.

## Draft conclusions (to confirm after the matrix)
- **CO-01**:
  - The series fixes nothing seen on the laptop: no failed or abandoned setup that completed, in
    428 setups.
  - It is stalled upstream: a maintainer pointed to sashiko findings on 2026-10-09, there has been
    no v4 for 23 days, and it no longer `git am`s on bluetooth-next.
  - Recommendation: **wait/drop as an active item**. No laptop run, no Tested-by. Keep the QEMU
    result (CO-01 + CO-02 together pass both test sets) as a note for CO-02's thread, only if asked.
  - Who decides: the operator.
- **CO-30**:
  - Still needed for a seamless switch only if PipeWire keeps its immediate retry. With CO-02 alone
    the user gets about 5 s of silence (U17) instead of never.
  - It changes `connect()`: EINPROGRESS or a block instead of ECONNABORTED, and the wait includes
    the old link's teardown, up to `HCI_CMD_TIMEOUT` (2 s) before it fails cleanly.
  - It does not cover:
    - a reuse before `hci_conn_timeout()` starts (the old link's codec is kept);
    - links that CO-01's `hci_disconnect_unused()` tears down with no `hci_conn` (the reporter's
      variant B on #2562).
  - Recommendation: **wait** for the maintainers' answer to CO-02. Compare it with a PipeWire-side
    retry (CO-31).
  - Who decides: the maintainers, then the operator.
- **Records now wrong**:
  - CO-01 README "nothing run yet" and "only reply is the CI bot's";
  - CO-02 README/log: "sashiko nothing yet" and "port if the tester series lands" (it landed:
    `e37f17751`);
  - contributions/README CO-01 "next: QEMU run" (done in part on 10-21/22, completed here).
