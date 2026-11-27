# CO-25: the acknowledgement to Qualcomm, for one focused review round (2026-11-27)

**What this is.** A self-contained review request for one short mail: our reply to Zijun Hu (Qualcomm) on the
linux-bluetooth thread "[REPORT] btusb: QCA9377 13d3:3503 on ROM firmware: HCI hang during mSBC SCO". Please review
only this mail. Nothing has been sent; the operator sends it himself if the round is clean.

## The thread so far

1. **2026-10-29, our report.** Without a btusb entry this QCA9377 (USB `13d3:3503`) runs its ROM firmware (ROM 0x302,
   build 0x111). In twelve recorded failures, the first HCI command after an mSBC SCO link came up got no reply.
   With the QCA setup path, which loads `qca/rampatch_usb_00000302.bin` and `qca/nvm_usb_00000302.bin` (the Rome 3.2
   files), 74 SCO links logged no command timeout: 50 mSBC, still on alt 1 with legacy `0x0428`, and 24 CVSD. The
   upstream entry is `dc16388d45ec` (Tibor Harcsa), in mainline and every live stable line.
2. **2026-10-29, his first reply:** QCA9377 is not ROME (QCA6174A), btusb does not support it, and linux-firmware has
   no firmware for it.
3. **2026-11-24, our second mail,** three questions:
   1. Are the Rome 3.2 rampatch and NVM the intended files for a QCA9377 that reports ROM 0x302? If not, what should
      `13d3:3503` load?
   2. Is there a list of the USB IDs that need this setup?
   3. Is the loss of HCI responses after mSBC link-up a known issue of ROM 0x302 build 0x111?
4. **2026-11-26 08:51 +0800, his answer, to question 1 only** (quoted from the list archive, linux-bluetooth archive
   commit `566e2f82`):

   > no, let me try to up-stream QCA9377 BTUSB firmware, you may override
   > the one loaded currently by QCA9377 as WAR
   > we will think about how to support it.

   Questions 2 and 3 are not answered.

## The draft (`contributions/CO-25-qualcomm-rom-report/drafts/reply-2-zijun-hu-ack-v1.eml`)

To him and the list; Cc as on his mail (Marcel Holtmann, Luiz Augusto von Dentz, Shuai Zhang, Bartosz Golaszewski,
Tibor Harcsa). Body:

```
On Thu, 26 Nov 2026 at 08:51 +0800, Zijun Hu wrote:
> no, let me try to up-stream QCA9377 BTUSB firmware, you may override
> the one loaded currently by QCA9377 as WAR
> we will think about how to support it.

Thank you, that answers the main question.

So the Rome 3.2 rampatch and NVM that btusb loads for 13d3:3503 today
are a workaround, and the intended QCA9377 firmware is still to come.
When it is posted, I can test it on this module (13d3:3503, ROM 0x302
build 0x111) with the test that showed the hang: mSBC calls with
headsets, counting HCI command timeouts after each SCO link comes up.

Iaroslav
```

## Checked (2026-11-27)

- `scripts/mail-lint.sh`: clean (headers, 72 columns, ASCII, no trailing whitespace).
- `scripts/reply-headers-check.py` against his mail: all PASS. In-Reply-To and References name his Message-ID, the
  subject is "Re:" plus his, and reply-all gives his 7 recipients.
- `git send-email --dry-run --confirm=never --suppress-cc=self --suppress-cc=body` from the project checkout: "Result:
  OK", 7 `RCPT TO` lines equal to his recipients.
- The quote is his text, byte for byte.

## Questions for the reviewers

1. **His sentence "you may override the one loaded currently by QCA9377 as WAR".** The draft reads it as: the files
   btusb loads today are a workaround, which may be used until the intended firmware comes. Could it instead mean
   "you may replace the currently loaded one", that is, an invitation to load something else now? If the reading is
   uncertain, should the reply state it as our understanding ("If I read you correctly, …")?
2. **Questions 2 and 3 are not repeated.** The project's rule is no reminders after vendor silence. Is leaving them
   out right, or does a one-line "the other two questions can wait" read better?
3. **The offer to test.** Is it the right size: a test on this module, with the test that showed the hang? Should it
   say that the count will separate mSBC from CVSD links, as the report did?
4. **Anything a maintainer would not need.** The rule is zero noise.

Please answer with "send", or with each change and its reason.
