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
- **Reviewer 3's forum logs:** a forum's logs of 0cf3:e500 and 04ca:3015 loading the same files. Not
  needed here: Q1 already says only 13d3:3503 was measured, and the commits carry the argument. *(Corrected after
  review: this first said a forum post "is not a source we can cite", which is too absolute. Kernel commits cite
  user reports, `0324d19cb998` among them; a forum log can show what one device reported, but not Qualcomm's
  intent.)*
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
- "only removing power brought the controller back": stronger than the report, which says "Removing power
  recovered the controller; a warm reboot did not always." v7 keeps those words. *(Corrected twice after review. This line first added "so sometimes it did", which does not
  follow. A later edit claimed EX-017 shows a warm reboot recovering the controller, but EX-017 itself says it
  "does not establish that a warm reboot recovers the controller": the controller enumerated 98 s after a
  recorded reboot request, and a power-off in between cannot be excluded (reviewer 7). The mail's sentence rests
  on EX-028 alone: a reboot after which the controller still failed, then a power-off that recovered it.)*
- "I am not calling the product a QCA6174A": defensive. The concession of his facts already does this.
- "Their versions were not measured" for the 2026 IDs is wrong for one of them: `d54601f21faf` records
  "QCA Rome 0x302" for 0b05:1868. v8 claims no version for any of them.

v8: lint clean, all header checks PASS, and the dry run of the exact file gives 7 `RCPT TO`, "Result: OK".

## The five reviews of v8 (reviewers 1, 2, 3, 6, 7), checked, and v9

All five call v8 sound. Four want a small v9; reviewer 6 calls it sendable, with one fix advised. Only reviewer 6
checked the sentences new in v7 and v8. The texts are kept privately.

| # | finding | who | check | in v9 |
|---|---|---|---|---|
| 1 | "no Bluetooth firmware of its own in linux-firmware" is false: linux-firmware `619d33958d72` (2020) "QCA: Add Bluetooth firmware for QCA9377" added `qca/rampatch_00230302.bin` and `qca/nvm_00230302.bin` (serial). Reviewers 2 and 3 also called it an over-concession | 7 (2, 3) | **right**: commit read via the GitLab API, files at WHENCE l.5297/5301. Our check record had said "QCA9377 appears only under ath10k", now corrected | clause removed; the opening concedes only the product difference |
| 2 | "58 on a diagnostic build with the same setup": that build had `BTUSB_QCA_ROME` without `BTUSB_WIDEBAND_SPEECH` or the reset callback | 1, 2, 6, 7 | right (report l.87-90) | "58 on a diagnostic build with BTUSB_QCA_ROME only" |
| 3 | "and with it the hang has not occurred" credits the files alone | 1, 2, 3, 6 | right (the report does not separate them) | the paragraph now states only where the files are listed and what only Qualcomm can tell |
| 4 | The log line is printed before the download (file build 0x3e8 against the controller's 0x111); restore the separate readback, "both return 0, a later read gives 0x3e8" | 2, 7 (1 notes it) | right: format string before `btusb_setup_qca_download_fw()`; EX-055 has both returns 0 and "after rampatch: … patch 0x000003e8" | sentence added below the log line |
| 5 | Q3's last sentence ("show whether the same setup is the remedy") re-opens the causal overclaim; restore the report's "affected ROM range" | 2, 3, 7 | right | "an affected ROM range" added; "That would help determine whether other modules with this ROM need the same firmware." |
| 6 | Q2's "Today an ID is added only after a user reports a failure" is universal | 2, 3, 7 | right: only three cases are shown | the three named as examples; "before users hit failures" (reviewer 6) |
| 7 | Q1's "further such IDs can be added the same way" is too strong | 2, 3, 7 | right | "that would support using the same setup for other matching IDs"; the no-branch asks about 13d3:3503 (reviewer 7) |
| 8 | "device table" → btusb's quirks table (`dc16388d45ec`: "the btusb quirks table") | 2, 7 | right | done |
| 9 | "Rome 3.2" as the source comment spells it | 3 | right | done in Q1 |
| 10 | The custom-firmware table rules out a subdirectory only; the NVM name can also take a board-ID suffix | 2, 7 | right; the check record already says the suffix needs the multi-NVM flag, and the 11-13 boot shows the plain name | records only |
| 11 | "did not always" does not imply a reboot ever worked; a forum log can be evidence | 2 | right | both lines of the v6 record corrected |
| 12 | `--confirm=always` shows the headers and asks; the body is seen by opening the `.eml` or `e` at the prompt | 7 | right as reported | said in the hand-over |

**Not taken:**
- **Reviewer 3's status sentence** (neither `QCA_PATCH_UPDATED` nor `QCA_SYSCFG_UPDATED` set): true, from the
  report, but the readback sentence already shows both loaded. One more sentence of mechanism was left out.
- **Reviewer 6's option of an early ask** ("My main question is…"): the operator's structure is kept.
  Raised with the operator.

v9: lint clean, header checks PASS, and the dry run of the exact file gives 7 `RCPT TO`, "Result: OK".

## The five reviews of v9 (reviewers 1, 2, 3, 6, 7), checked: v9 kept

Three (2, 6, 7) would send v9 as it is. Reviewer 3 suggests a small v10, and reviewer 1 one added paragraph. The
texts are kept privately; they are treated as opinions.

| finding | who | check | decision |
|---|---|---|---|
| Answer his firmware sentence: name the serial QCA9377 pair (`619d33958d72`) and say btusb does not request it | 1 | the facts are right: WHENCE lists `rampatch_00230302.bin` under "QCA61x4 serial chips", version `QCA6174_DEV.BLD.0111`, and btusb builds `rampatch_usb_%08x` from 0x302 | **not taken**. Reviewers 2, 3, 6 and 7 advise against it: it corrects his sentence in public and brings a second firmware family into Q1, with no basis for it on USB. Q1 already asks what 13d3:3503 should load if not these |
| Readback order: rampatch → version read → NVM, so "both … return 0, and a later version request reports 0x3e8" misorders it | 3 | **does not hold**: EX-055 also shows the next setup, after both downloads (17:11:25), reading patch 0x3e8, so the sentence is true in the order it states | kept |
| "btusb therefore loads" omits the status check (0x20) | 3 | true as code detail; the sentence is true for this controller | kept |
| "only Qualcomm can tell" → "what I am asking Qualcomm to clarify" | 3 | wording preference | offered to the operator |
| Present the main question in the opening | 3, 6 (2, 7 against) | preference | the operator's structure kept; offered again |
| Tense: "returned", not "return" | 1 | wording preference | offered to the operator |
| The reboot record correction went too far: EX-017 shows one reboot recovered it | 6 | **right** (`log.md` C10) | record corrected |
| `--confirm=always` shows headers only | 2, 6, 7 | right | in the hand-over |

Reviewers 2 and 7 dry-ran or inspected the committed v9 independently: 7 recipients, threading right.

## The five reviews of the v9 decision: send v9 unchanged (5 of 5)

All five agree to send v9 as it is and to leave the serial firmware pair out of the mail. Reviewer 3 withdrew
its readback objection after reading EX-055, which shows two reads of 0x3e8. Reviewers 2 and 7 confirmed that the
v9 blob at `42a5f18` is the one already dry-run (`df4622ac91a5`).

One factual correction, from reviewer 7: EX-017 does not show a warm reboot recovering the controller (see the
two corrected lines above and `log.md` C10). v9's sentence "a warm reboot did not always" needs only EX-028.
The review phase for CO-25 is closed. The send is the operator's.
