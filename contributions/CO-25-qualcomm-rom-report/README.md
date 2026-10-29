# CO-25 - Report to Qualcomm on the QCA9377 ROM firmware

**SENT 2026-10-29 02:33:50 +0100** on the operator's word: `send/report.eml` as reviewed at
`cb645f5`, server 250, seven recipients as in the dry run, Message-ID
`<20261029013350.360574-1-yaroslav.voytovych@gmail.com>` (`log.md`, the send). Next: arrival on
lore, replies; one reply to the own mail if nothing comes in three weeks.

**State before the send (2026-10-29): v4 written.** A sixth, wider review round (seven reviewers:
usefulness, list practice, precedents) found v2 sendable in substance but not verbatim:
13d3:3504 is a Broadcom part, the 197/202 sentence misleads, "users are covered" is too broad,
the recipients came from the wrong file (round 6, `reviews-2026-10-28.md`); `report-v3.txt`
fixed these. A seventh round (six reviewers) judged v3 sendable after small corrections, one of
them a factual error in the timing sentence; `drafts/report-v4.txt` makes them, each checked
(`log.md`). `EVIDENCE.md` (with the firmware files' provenance) is the page its link points to,
pinned to a commit. Round 8 (six reviewers): GO, three small edits made. **The send package is
ready**: `send/send.sh` (dry run passed 2026-10-29, seven RCPT TO as intended; `log.md`). It
waits only for the operator's word: then `send/send.sh --send`. `report-v2.txt` and
`report-v3.txt` are superseded.

**Comes from:** BT-1 (BRIEF section 0, Foundation). The kernel fix is upstream
`dc16388d45ec`; this report asks what the ROM firmware does wrong, which is not
known, and covers CO-22 (are other ROME USB IDs missing from btusb's table).

**The mail:** `drafts/report-v4.txt` (ASCII, max 72 columns but the evidence URL). To linux-bluetooth; Cc
Marcel Holtmann, Luiz Augusto von Dentz, Zijun Hu, Shuai Zhang, Bartosz Golaszewski, Tibor
Harcsa. `drafts/report-v1.txt` to `report-v3.txt` are superseded.
**Claims with their exhibits (for reviewers):** `log.md`.

The recipients section and the reviewer questions below are from v1; the reviews
answered them (Zijun Hu added to Cc, the ID question first, signed "Iaroslav
Voitovych"; `reviews-2026-10-28.md`).

## Recipients

Found with the kernel's `scripts/get_maintainer.pl --no-git --no-git-fallback
--rolestats -f <file>`, run against MAINTAINERS of `cache/linux` (see `log.md`,
"How the recipients were found"; the working tree there is sparse and has no
`scripts/`, so the script came from `origin/master` and ran on a stub tree).

`drivers/bluetooth/btqca.c`:

- Bartosz Golaszewski `<brgl@kernel.org>` - maintainer, QUALCOMM BLUETOOTH DRIVER
- Marcel Holtmann `<marcel@holtmann.org>` - maintainer, BLUETOOTH DRIVERS
- Luiz Augusto von Dentz `<luiz.dentz@gmail.com>` - maintainer, BLUETOOTH DRIVERS
- `linux-arm-msm@vger.kernel.org` - list, QUALCOMM BLUETOOTH DRIVER
- `linux-bluetooth@vger.kernel.org` - list, BLUETOOTH DRIVERS
- `linux-kernel@vger.kernel.org` - generic

`drivers/bluetooth/btusb.c` (now `btusb_main.c` on master): the same two
BLUETOOTH DRIVERS maintainers and `linux-bluetooth`, no Qualcomm entry.

Draft headers: To linux-bluetooth; Cc Golaszewski, linux-arm-msm, Holtmann, von
Dentz. `linux-kernel` left out (a report, not a patch).

Not from MAINTAINERS, only from `git log` of `btqca.c` and `btusb.c` on
`origin/master` (Qualcomm addresses, published in those commits): Zijun Hu
(`zijun.hu@oss.qualcomm.com`, btqca and btusb, 2026-06 and 2026-09), Xiuzhuo Shang
(`xiuzhuo.shang@oss.qualcomm.com`, btqca firmware-version log, 2026-06), Shuai Zhang
and Vivek Sahu (btqca, 2026-01/02). Candidates for a Cc; reviewers decide.

## Questions for reviewers

1. Cc: only the MAINTAINERS list, or also Zijun Hu (the one Qualcomm engineer on
   both files)? The MAINTAINERS Qualcomm entry is one person plus a list.
2. "Cure": the draft says the rampatch/NVM cures it with the evidence being 0 in 74
   links against 12 of 12 recorded deaths. There is no count of ROM-firmware links
   that did not hang, so no rate; the draft says so. Is that enough, or should the
   draft not compare at all?
3. Is the "197 versus 202 supported commands" paragraph useful or noise (EX-055)?
4. The draft names no headset or device vendor except the USB ID and "IMC
   Networks" (from the upstream commit). Enough for Qualcomm to look up?
5. "A reboot did not always" recover it: EX-027 and EX-034 (failed), EX-017
   (recovered once). Cut as unnecessary?
6. Offer of logs "on request": acceptable, or attach one exhibit extraction?
7. The polite ROM-source/errata request: wording.
8. Name and address in the signature: the operator's call.
