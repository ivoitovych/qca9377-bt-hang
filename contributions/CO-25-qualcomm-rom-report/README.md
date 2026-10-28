# CO-25 - Report to Qualcomm on the QCA9377 ROM firmware

**State:** **ready to send** (2026-10-28): `drafts/report-v2.txt`, approved by all six
outside reviewers in the final go/no-go round at `e2e0e00` (`reviews-2026-10-28.md`). Not
sent; it waits for the operator's own read and word. The sendable `.eml` and a dry run
(RCPT TO checked) are made on the day, before the send command is given.

**Comes from:** BT-1 (BRIEF section 0, Foundation). The kernel fix is upstream
`dc16388d45ec`; this report asks what the ROM firmware does wrong, which is not
known, and covers CO-22 (are other ROME USB IDs missing from btusb's table).

**The mail:** `drafts/report-v2.txt` (67 lines, ASCII, max 71 columns). To
linux-bluetooth; Cc Zijun Hu, Bartosz Golaszewski, linux-arm-msm, Marcel Holtmann,
Luiz Augusto von Dentz. `drafts/report-v1.txt` is the superseded first draft.
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
