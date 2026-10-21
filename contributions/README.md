# Contributions — one dossier per possible contribution

Every possible upstream or distribution contribution gets a folder here. Its findings,
experiments, ideas, decisions and references collect in that folder, so nothing is
forgotten or lost between working sessions. The IDs come from
`reviews/2026-10-20T2309Z-contribution-opportunities.md`; new items take the next free
`CO-nn`.

**What stays where:**
- `docs/STATUS.md` remains the one page that says what is *current*.
- `docs/issues.md` remains the evidence register per issue.
- A dossier holds the working material and links to everything else.
- **Nothing is moved into a dossier.** Exhibits, patches already sent, captures and review files
  stay where they are, because mails, commits and STATUS already point at them; the dossier
  links to them.
- **Raw recordings stay in the git-ignored archive** (they carry real device addresses). A
  dossier names each one by path and, where it matters, by SHA-256.

## A dossier's layout

| file | what it holds |
|---|---|
| `README.md` | the front page: what the contribution is, where it comes from, its state, the next step and who decides it |
| `log.md` | an append-only journal: dated entries for findings, experiments, reviewer input, decisions; nothing written there is edited, corrections are new entries |
| `refs.md` | pointers: issues, exhibits, captures, reviews, upstream threads, patchwork IDs, commits |
| `experiments/` | one file per run: command, output, verdict (created with the first run) |
| `patch/`, `drafts/` | once a patch or a mail or bug draft exists |

States, in order: **idea** · **investigating** · **reproduced** · **patch written** ·
**ready to send** · **sent** · **accepted** · **released**; or **waiting** (on a person or a
date), **blocked** (on a decision), **dropped** (with the reason in `log.md`).

**Nothing in a dossier is sent anywhere without the operator's word.**

## Index

| ID | dossier | target | state | next step | decides |
|---|---|---|---|---|---|
| CO-01 | [Test the abandoned-setup SCO series](CO-01-sco-abandoned-setup-series/README.md) | kernel (another author's series) | idea | QEMU run on the exact patches | the operator, for a laptop run and any Tested-by |
| CO-02 | [A new SCO connect reuses the closing link (U7)](CO-02-sco-connect-reuses-closing-link/README.md) | kernel; maybe PipeWire | investigating: mechanism read in source | `hci_vhci` reproducer in QEMU | the operator, for any send |
| CO-03 | [U12: bluetoothd rebuild and the Ubuntu backport](CO-03-bluez-u12-backport/README.md) | Ubuntu (BlueZ 5.72) | investigating: the fix does not apply as is | hand backport, build, tests | the operator installs; the operator files |
| CO-04 | [Test Igor Putko's mesh patch 14888791](CO-04-mesh-test-14888791/README.md) | kernel (another author's patch) | idea | QEMU run, including the lockdep case | the operator, for any reply |
| CO-05 | [Mesh I12: advertising list changed without `hdev->lock`](CO-05-mesh-adv-list-lock-i12/README.md) | kernel | reproduced (QEMU, 2026-10-05) | write the mesh-path patch | the operator, for the send |
| CO-06 | [Review reply on Jiale Yao's mesh power-off fix](CO-06-mesh-power-off-review/README.md) | kernel (another author's patch) | blocked | the operator's decision | the operator |
| CO-07 | [U6: GNOME input meter fix for Ubuntu](CO-07-gnome-u6-input-meter/README.md) | Ubuntu (GNOME Settings 46.7) | idea | one recorder reading with the Sound panel open | the operator files |
| CO-08 | [U10: PipeWire quirk for the Tronsmart T8](CO-08-pipewire-u10-sbc-xq/README.md) | PipeWire | blocked | the operator's marked test sound per mode | the operator |
| CO-09 | [The QCA9377 entry in Ubuntu's kernel](CO-09-ubuntu-kernel-qca9377-entry/README.md) | Ubuntu (kernel) | waiting | watch Ubuntu's stable updates; rebuild E3 per kernel | the operator, for a request |
| CO-10 | [Tested-by on 6.6.160-rc2](CO-10-stable-6.6.160-rc2/README.md) | stable kernel | blocked; deadline 2026-10-22 07:53 UTC | the operator's decision | the operator |
| CO-11 | [Small items: btmon for Ubuntu, the flaky BlueZ test](CO-11-small-btmon-and-flaky-test/README.md) | Ubuntu; BlueZ | idea, low value | none planned | — |
| CO-12 | [M-2: extended-advertising duration overflow](CO-12-m2-adv-duration-overflow/README.md) | kernel | investigating: arithmetic confirmed in source | QEMU reproducer | the operator, for the send |
| CO-13 | Mesh "Count" question to the list | kernel (uAPI) | idea | — | the operator |
| CO-14 | Mesh at device removal (lock order, drain policy) | kernel | idea | maintainers' direction first | the operator |
| CO-15 | U11/U3: a new headset becomes the default (opt-in) | WirePlumber | idea; draft in `patches/wireplumber/` | — | the operator |
| CO-16 | U9: reconnect after Bluetooth off/on (narrow opt-in) | BlueZ | idea | — | the operator |
| CO-17 | U2, U4: one capture each | PipeWire/WirePlumber; GNOME | idea | captures in a manual test | the operator |
| CO-18 | U8: earbuds silent in mSBC | kernel / btusb | idea; belongs with CO-01 and CO-20 | — | — |
| CO-19 | U1 | PipeWire | dropped: fixed in 1.2; not worth a stable request | — | — |
| CO-20 | [SCO error messages at call hang-up](CO-20-sco-unknown-handle-messages/README.md) | kernel / btusb | investigating | read the HCI captures at those hang-ups | — |
| CO-21 | btusb with two SCO links at once | kernel / btusb | idea | only if CO-01 shows it | — |
| CO-22 | Other QCA ROME USB IDs missing from btusb's table | kernel | idea | a survey of hardware-probe data | — |
| CO-23 | One-off events (AONIC 50 drop, BT-6, bluetoothd bad `free()`) | — | waiting for a second instance | — | — |
| CO-24 | U5: default codec for a headset with no saved choice | WirePlumber | idea | needs a fresh device or the operator's word | the operator |
| CO-25 | BT-1's ROM-firmware mechanism | — | closed unless the operator wants laptop runs | — | the operator |

Items without a link have no dossier yet. One is opened as soon as anything is written about
the item.
