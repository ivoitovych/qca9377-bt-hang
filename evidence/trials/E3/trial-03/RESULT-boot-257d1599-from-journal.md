# Trial "E3 #3" of 2026-10-23 11:04 to 2026-10-29 15:20 (CO-02 module): result from the journal

This trial has **no row** in `evidence/trials/results.tsv`: the ordered reboot of 2026-10-29
15:20:14 stopped `bt-trial-auto` at 15:20:17, and the journal ends at 15:20:19 with its close
unfinished (`docs/STATUS.md`, the machine). Its result is whole in the journal of boot
`257d1599532e4cad941b5bb6178bb630` (`journalctl --list-boots`: 2026-10-23 11:04:43 to
2026-10-29 15:20:19).

Configuration: `7.0.0-38`, E3 `updates/btusb.ko` (srcversion `D1DEA96A0C95BFAB05CEE01`) and the
CO-02 series' `updates/bluetooth.ko` (srcversion `0D084A056A9EEFB98E8F331`, `EX-071`). Not plain E3
(`NOTE-not-plain-E3.txt`); its counts stay apart from E3's.

Command, run 2026-10-30 on boot `738e228b` (boot −1 is `257d1599`):

    scripts/sco-ledger.sh -1

Output summary line, exact:

    links 63   hang-ups answered 63   timeouts 0

Full output: `sco-ledger-boot-257d1599-whole.raw` beside this file (63 links, 2026-10-23 11:45:27
to 2026-10-29 04:46:13; MOMENTUM 4, Lenovo thinkplus GM2 pro and Shure AONIC 50; mSBC and CVSD;
the longest an mSBC link of 35,105 s on 2026-10-26). `EX-073` is the earlier ledger of the same boot.

The trial directory was reused at 2026-10-30 04:31:33 by a new "E3 #3" on `7.0.0-42` with the stock
`bluetooth.ko` (plain E3): this file and the `.raw` belong to the 10-23 trial only.
