# Five outside rechecks of the send packages (2026-11-23): findings checked and answered

**What was reviewed.** Reviewers 1, 2, 3, 6 and 7 each re-read the repository at `main` `18dcc5c8` (2026-11-23
17:45 UTC), after the reaction to their morning reviews. Only the findings are recorded here; the full texts
are kept privately. Each claim was checked on the tip before anything changed. The reviewers' opinions are
weighed, not taken as orders. Raw run logs stay machine-local.

**Overall.** All five find the four send packages technically ready:
- CO-38 first, then CO-44, CO-22's stable request beside them, and the CO-43 series;
- CO-26 later;
- what is left is send mechanics and the operator's decisions.

Reviewers 2, 3 and 7 withdraw their earlier holds: on the CO-38 test, on the CO-43 restructuring, and on
waiting for kernel acceptance before posting a BlueZ test. Reviewer 6 had predicted a stale send, which the
reruns did not show. Nobody found a code defect.

| # | finding (reviewers) | checked | outcome |
|---|---|---|---|
| 1 | CO-38 and CO-44 testing notes say "the rest is unchanged", but the patched images carried both fixes and both new cases changed (3, 7) | true (`CO-38-read-adv-features-hidden-instances/send-20261123/RUNS-20261123.md`) | **fixed:** both notes now say the image also carried the other one-line MGMT fix, and that besides the two new cases no result changed |
| 2 | CO-38 and CO-44 kernel patches still say `base-commit: da3cc02587c6`; CO-38 applies with an offset of 185 lines (6) | true | **fixed:** both are regenerated on `cf357cfc025e` (`git am`, then `format-patch --base`). The patch-ids are unchanged (`a15c80fa459b…`, `63e2170f7cdf…`). CO-38's hunk is now at line 9074. checkpatch: 0 errors |
| 3 | The CO-38 BlueZ test says `[PATCH]`, not `[PATCH BlueZ]` (6, 7) | true; CO-44's test has the prefix | **fixed:** `[PATCH BlueZ] mgmt-tester: Test a lone advertising instance 2` |
| 4 | CO-43 2/3: the reset is only below `---`; put one clause in the body (6) | the logs show "Resetting usb device." in 3 of 3 runs. On the tip, btusb sets `hdev->reset` only for Intel, MediaTek, QCA and Realtek (`btusb_main.c` l.4626, 4646, 4679, 4696, 4746), and `hci_cmd_timeout()` calls it if it is set | **fixed, qualified:** "on controllers with a vendor reset callback, such as QCA, the command timeout then resets the device". No stale send is claimed |
| 5 | CO-43 1/3's note reads as if the multi-URB case ran on 1/3 alone; it ran on base and on the full series (7) | true | **fixed:** the note says which cases ran on 1/3 alone and which on the whole series |
| 6 | `docs/STATUS.md` points CO-22 at the v3 directory and CO-44 at the 11-13 package; the BT-23 row says E "goes first"; `docs/issues.md` has old BT-23/24/25 pointers (2, 3, 6) | true (five places in STATUS, three in issues) | **fixed:** each gets a dated correction naming the current package and marking the old one superseded |
| 7 | The CO-43 series README opens with "will replace … once its tests are rerun" (3) | true | **fixed** |
| 8 | The "What to send" heading still says 2026-11-15 (3) | true | **fixed:** "(2026-11-15, updated 2026-11-23)" |
| 9 | The access-audit workflow is red while `checks` is green (3) | true; recorded in STATUS, Repository health, since 11-16 | no change; it is still an open repository-health item |
| 10 | The "third status" posting that maps to `ETIMEDOUT` exists: mirror #1191, 2026-11-22, "Bluetooth: lib: Map Connection Failed to be Established to ETIMEDOUT" (6) | confirmed with `gh pr list -R bluez/bluetooth-next`: #1191, `[PW_SID:1218946]`, 2026-11-22T22:20:56Z | CO-44's message already dropped the count of statuses, so no change |
| 11 | Stable: 1/3 of CO-43 could carry `Cc: stable` (3 leans yes); CO-44 could go to stable but the precedent is respectable (3) | — | the operator's decision; it is listed in the hand-off |
| 12 | Each MGMT run used one image with both fixes, not one per patch (2, 7) | true | not a hold for either reviewer; the notes now say it (row 1) |

**Also done in the same pass (not from a reviewer).** CO-26 was regenerated alone on the tip, with its fault
injection rerun: `contributions/CO-05-mesh-adv-list-lock-i12/co26-send-20261123/`.

**Earlier in the same day,** found by running the full suite in a container while a trial was open: six "What
to send" cells used relative paths, which made `checks` red on `418331c` and `18dcc5c`. Fixed in `0c78af2`,
and `checks` is green again.
