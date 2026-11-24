# CO-25 reply v6: four outside reviews, checked, and v7 (2026-11-24)

**The draft:** `contributions/CO-25-qualcomm-rom-report/drafts/reply-1-zijun-hu-v6.eml` at `65f06f1`.

Reviewers 2, 3, 6 and 7 answered; reviewer 1 was still working. The full texts are kept privately; findings
only here. All four said to revise before sending, and none found a fault in the threading, the recipients, the
quote or the source facts. Reviewer 7 also ran a dry run on the committed bytes: 7 recipients.

| # | finding | who | check | in v7 |
|---|---|---|---|---|
| 1 | "the rampatch is the actual fix" goes beyond the report. The 74 links do not separate rampatch, NVM and `BTUSB_QCA_ROME`'s host-side effects, and a known erratum would not prove it either | 2, 3, 6, 7 | right: the report says so (`send/report.eml` "This does not separate the rampatch from the NVM") | Q3 asks whether a revision is known to address it |
| 2 | "btusb already gives it [the files] to three": only the flag is verified for the three, and the files depend on each ROM | 2, 3, 6, 7 | right: `reply-check-20261124/` verified the flags only | "BTUSB_QCA_ROME for three IDs whose commits name QCA9377 … I have measured only the last" |
| 3 | "three were added this year" reads as Q1's three. The 2026 ones are 13d3:3503, 0b05:1868 and 0b05:1825, added for BLE-scan errors, and 0b05:1825 is a QCA6174 board | 2, 6, 7 | right: `cfa67a1dbfd9` "QCA6174 SoC … ASUS Z170I PRO GAMING", `d54601f21faf` "QCA Rome 0x302", `dc16388d45ec` "0x2005" | named, with "all for BLE-scan errors" |
| 4 | "With that setup, in 74 SCO links" reads as 74 on the exact entry; it was 58 diagnostic and 16 exact | 2, 6, 7 | right (report) | split given |
| 5 | "only a power-off brought it back": the report says a warm reboot "did not always" | 2, 6, 7 | right (`send/report.eml:72-73`) | as the report |
| 6 | "btusb treats its Bluetooth part as ROME 3.2, and it works" reads as asserting Qualcomm's taxonomy; it also overlooks BT-17 on the same setup | 2, 3, 6 | right as a reading | states what the code does and the build change; the claim is scoped to the hang |
| 7 | "ROM build 0x111" should name ROM 0x302 too | 2, 6, 7 | right (v4 settled on the kernel's wording) | "ROM 0x302 build 0x111" |
| 8 | Concede his point first | 3, 6 | his two facts are verified (WHENCE, `9a364ea4`) | "I take the point that QCA9377 is a different product…" |
| 9 | Say the files are catalogued for QCA61x4; that is why only Qualcomm can answer | 3 (2 and 7 note it) | right: WHENCE l.5182 | one paragraph |
| 10 | "If it is right, those entries stand" invites removal of the entry that fixes the laptop | 6 | a fair reading | "If yes, further such IDs can be added the same way. If no, which files should they load?" |
| 11 | Name the symptom (first HCI command after mSBC link-up unanswered), so an erratum can be matched | 7, 2 | right (report l.24-26) | in the problem paragraph and Q3 |
| 12 | Add the build change 0x111 → 0x3e8 | 2, 7 | right (EX-055, the 11-13 boot) | added |
| 13 | "Are", not "Is"; "my laptop's", not "this laptop's"; "device table", not "no btusb entry" | 2, 6, 7 | right | done |
| 14 | "Every fact is from the check" (README) was false for v6 | 6 | right | corrected in the README |
| 15 | A dry run of an earlier file does not cover the final one | 2 | right | v7's exact file dry-run: 7 `RCPT TO`, "Result: OK" |
| 16 | `--confirm=never` was for scripted sends; in the operator's terminal use `--confirm=always` | 6 | right (`send/send.sh` uses it) | the send command given uses `--confirm=always` |

**Not taken:**
- **Reviewer 3's forum logs:** a forum's logs of 0cf3:e500 and 04ca:3015 loading the same files. A forum post is
  not a source we can cite, and Q1 already says only 13d3:3503 was measured.
- **Reviewer 6's `hci_qca` point:** it maps `qcom,qca9377-bt` to `QCA_ROME`. Left out on that reviewer's own
  advice: it would turn the mail into an argument.
- **Reviewer 7's structure,** leading with the question: the operator's structure (explain first, then three
  questions, each with what its answer would change) is kept.
- **Reviewer 3's opening,** "I may be using the names too loosely": it puts the fault in our naming, where the
  operator asked for neither blame nor self-blame. The concession of his facts does the same work.

## Reviewer 1 (arrived after v7), checked, and v8

Reviewer 1 also reviewed v6 and also said not to send it. Its five must-fix points are the same as findings 1–7
above, already fixed in v7.

| finding | check | action |
|---|---|---|
| Put back the kernel's own log line: "build 0x111" alone was misread on 11-02 (F-01), and v6 dropped the line; v7 only paraphrased it | right (`log.md`, 11-02) | **v8** quotes `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111` in place of the paraphrase |
| `qca_custom_btfws[]` has no 0x302 row, so the plain file names are right | right: two QCA2066 rows only (`btusb_main.c:3625-3629`, bluetooth-next) | added to the check record; no mail change |
| Send the `.eml`, not a rewrapped paste | right | the send command uses the file |

**Not taken from reviewer 1:**
- "only removing power brought the controller back": the report says a warm reboot "did not always", so
  sometimes it did. v7's wording stays.
- "I am not calling the product a QCA6174A": defensive. The concession of his facts already does this.
- "Their versions were not measured" for the 2026 IDs is wrong for one of them: `d54601f21faf` records
  "QCA Rome 0x302" for 0b05:1868. v8 claims no version for any of them.

v8: lint clean, all header checks PASS, and the dry run of the exact file gives 7 `RCPT TO`, "Result: OK".
