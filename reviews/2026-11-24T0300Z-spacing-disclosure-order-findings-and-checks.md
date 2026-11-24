# Submission spacing, test disclosure and the remaining order (2026-11-24): four outside answers, checked

**The questions.** The operator asked the reviewers three things:
1. whether several independent submissions sent close together look suspicious, or break a rule;
2. whether netdev's rule on disclosing test-only kernel changes binds Bluetooth, and what to move above `---`;
3. where the CO-02 v2 and the CO-22 stable request go in the order.

Four answered (reviewers 2, 3, 6 and 7); reviewer 6 also answered a follow-up on its sample. The full texts are
kept privately; findings only here. The commits were checked in the trees with
`tmp/kernel-queue-20261124/check-review-commits.sh` (machine-local) and `git log --author` in the BlueZ cache.

## 1. Spacing: no rule, and bursts are applied (4 of 4)

| claim | source | check |
|---|---|---|
| netdev's 24 hours is for reposting the same work | `maintainer-netdev.rst` | confirmed: `:483` "Resending after review", `:486` |
| netdev caps 15 patches per series and 15 outstanding per tree | same | confirmed `:411`, `:421`; our queue is 7 kernel patches |
| Cen Zhang, three fixes within 59 s on 2026-06-23, all landed (reviewer 7) | git | confirmed: `352a59dc1f4a`, `518aa9505fa1`, `384a4b2fef9f`, author times 16:12:29 to 16:13:28 UTC, committed 07-06. The reviewer's hashes differ from mainline's |
| Kevin Dewald, four threads on 2026-10-27, all landed (reviewer 2) | git | confirmed: BlueZ `0d57c12f5`, `4f3428e9d`, `cad7a98e7`; kernel `60b10121db60` (11-02, after revisions) |
| Cen Zhang, four series in 17 min on 2026-11-21, answered on technical points only (reviewer 3) | list archive | not checked here (lore); none of the four is applied yet |
| Burst patches applied 71 % against 64 % (June–Nov); track record predicts outcome (37 % against 57 %) (reviewer 6) | CI mirror count | not re-run; recorded as the reviewer's measurement |
| The only expressed worry about volume is a contributor's own (2026-08-22); Greg Kroah-Hartman's "slow down" was about v3 of one patch | list archive | not checked here; consistent across reviewers 2, 3, 7 |
| No maintainer statement asking to space unrelated series | negative search by four reviewers | cannot be confirmed by a check; recorded as a negative result |

Reviewers 3 and 6 withdrew their earlier "several days to a week". The recommendations differ in degree:
- reviewer 3: one independent kernel series per day;
- reviewer 6: 24 to 48 hours;
- reviewer 7: CO-38 first, then CO-44 the next working day, since both touch `mgmt.c` and mgmt-tester;
- reviewer 2: one or two days for the two MGMT fixes plus CO-22.

**Changed:**
- `docs/upstream-practice.md` gains R-6, and X-6 keeps only the structure question.
- BRIEF's "one mail at a time, several days apart" becomes: one independent kernel thread per day, its BlueZ test
  the same day, CO-22 on CO-38's day, and nothing waiting for review of an unrelated thread.

## 2. Disclosure: move it into the body (4 of 4)

Formally, netdev's document does not name Bluetooth; reviewers 2, 3 and 7 call it not binding, and reviewer 6 calls
it not enforced on this list. All four recommend the change anyway. Accepted Bluetooth commits already do it.

| commit | what its body discloses | check |
|---|---|---|
| `9838a80096ba` ISO | emulated controller over vhci, "a debug delay … to widen the window", 64/64 → 0/64 | confirmed, `Cc: stable`, applied by the Bluetooth maintainer |
| `024e05f73a4c` | "a 40 ms diagnostic delay … an instrumented kernel" | confirmed |
| `9ff737119177`, `add463a65802` | "a test kernel with scheduling hooks", "a test kernel where the socket thread was paused" | confirmed |
| `555ff78fa719`, `56e20c3d8ad3` | "an instrumented kernel" | confirmed |
| `902fe40bce70`, `5a4bb6a8e981` | fault injection | confirmed |
| `ae9c8df1ffb8` | found by code inspection only, not observed at runtime | confirmed |
| `fa96916cfd05` btusb | no test account (reviewer 7's counterexample) | confirmed |
| the rule itself, with the hardware clause | `fe8a42931853`, 2026-10-01 | confirmed |

Reviewer 6's count: since October, 20 of 113 `Fixes:` commits by non-maintainers say how they were tested, up from 17 of 169.

**Changed (message text only; patch-ids unchanged):**
- **CO-43 1/3:** the body now says the leak was found by reading the code and confirmed in QEMU with an emulated
  controller over usbip, not on hardware, with the failed resume forced by a test-only module parameter (reviewers
  6, 7).
- **CO-43 2/3:** the found/reproduced sentence moves above `---`: a test-only delay widened the window, and the
  controller was emulated. Below `---`, one line names the delay's place.
- **CO-43 3/3:** the body names the test-only change: a forced resume failure, a delay in the failure path, and
  a second command inside it. It also gives the anchor result, 3 of 3 each way.
- **CO-26 A and B:** "found by reading the code", and "a test-only module parameter made the allocation in
  `hci_add_adv_instance()` fail". The trace stays; the note below `---` loses its repetition.
- **CO-38:** found with mgmt-tester while testing advertising instances; reproduced with the new case. Without
  the fix the reply lists no instance. This was checked against `read_adv_features()` on bluetooth-next: with
  only instance 2, `num_instances` drops to 0.
- **CO-44:** the body now says the timeout was seen on a QCA9377 and reproduced in QEMU with the new case. The
  btmon line is from the laptop's own capture (`results/incident-2026-11-12-1803/`).

Reviewer 3's wider point is open: audit every kernel bug-fix message for "how found / how validated". That is
done for the six packages above; CO-02 v2 and CO-35's backports are not yet.

## 3. Order: CO-02 and CO-22

- **CO-22:** it may go on CO-38's day as its own thread (4 of 4). Before sending, re-read the queues of the
  11-23 stable releases.
- **CO-02 v2:**
  - Four weeks of silence is no reason to wait longer, and readiness decides its slot (reviewers 2, 3, 7). It is
    not ready: its checks and bot run are open.
  - Post it as `[PATCH v2]` linking v1, naming the overlap with patchwork 14942649, and saying what the
    non-sleeping version changes (reviewer 7).
  - Reviewer 6 would first reply on the v1 thread: Sashiko's high-severity finding on patch 2 is valid, and v2
    will follow. That is a mail, so it is the operator's decision.
- **The order** (reviewers 3 and 7):
  1. CO-38 with its BlueZ test, and CO-22 the same day;
  2. CO-44 the next day;
  3. CO-02 v2 if ready, else CO-43 first;
  4. CO-26.

## Not taken

- Reviewer 2's draft sentences were rewritten so that each states what was actually done.
  - For 2/3, the delay is in `submit_or_queue_tx_urb()` after its suspend decision.
  - For 3/3, the failure is a failing interrupt-URB submission at resume
    (`evidence-summaries/apply-debug-co43.py.txt`).
- Reviewer 3's CO-26 wording gives the unpatched result as "-ENOENT". The trace in the body gives both values
  (`hci_schedule_adv_instance_sync -> -ENOENT`, `mesh_send_sync -> -2`), so the body keeps the trace.
