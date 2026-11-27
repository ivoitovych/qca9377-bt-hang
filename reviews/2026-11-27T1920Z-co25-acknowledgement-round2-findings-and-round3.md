# CO-25 acknowledgement: round 2 findings, one line changed, and round 3 (2026-11-27)

**What this is.** Round 2 on the reply to Zijun Hu (Qualcomm): what the five answers found, our checks, the one line
changed, and round 3, which covers only that line. Self-contained. The earlier rounds are
[`2026-11-27T0450Z-co25-acknowledgement-review.md`](2026-11-27T0450Z-co25-acknowledgement-review.md) and
[`2026-11-27T1910Z-co25-acknowledgement-round1-findings-and-round2.md`](2026-11-27T1910Z-co25-acknowledgement-round1-findings-and-round2.md).
Nothing has been sent.

**His reply, the one we answer**, quoted whole (2026-11-26 08:51 +0800), to our question 1: "Are the Rome 3.2
rampatch and NVM the intended files for … a QCA9377 module that reports ROM 0x302? … If no, what should 13d3:3503
load instead?"

> no, let me try to up-stream QCA9377 BTUSB firmware, you may override
> the one loaded currently by QCA9377 as WAR
> we will think about how to support it.

## Round 2: five answers

- **"Send", no change:** reviewers 2, 3 and 7.
- **Reviewer 6: "send", with one optional nit.** "Available for testing, I can test it … with the test" uses the
  word three times; "available" alone also covers firmware sent before it is upstreamed.
- **Reviewer 1: not yet, one change.** Drop "that answers the main question:".
  - Question 1 asked two things: are these the intended files, and if not, what should the chip load.
  - "No" settles only the first.
  - "That answers the main question" says the whole question is answered.
  - So the paragraph should be only the negative that "no" establishes.

**Our checks.**
- **Reviewer 1: accepted.** Question 1 as sent has two parts, quoted above. "Let me try to up-stream QCA9377 BTUSB
  firmware" names what is to come, but no file to load now, so the second part is not answered. The claim costs
  nothing to drop, and the mail does not use the WAR sentence to fill the gap.
- **Reviewer 6's nit: not taken.** Reviewers 1, 2 and 3 each named "available for testing" as a reason the line is
  right: it is conditional, names no channel, and covers firmware sent for testing before it is upstreamed. Changing
  it would move a line three reviewers cleared. The repetition is real but harmless in a two-paragraph mail.
- **Reviewer 6, on round 1's count:** reviewers 6 and 7 gave identical text, so round 1 had four independent answers,
  not five. Agreed; round 1's page already noted the identical text. The finding stood on all four.

## The change, before and after

Before (v2, SHA-256 `6848626f…`):

```
Thank you, that answers the main question: the Rome 3.2 rampatch and
NVM are not the intended files for this chip.
```

After (v3, `contributions/CO-25-qualcomm-rom-report/drafts/reply-2-zijun-hu-ack-v3.eml`, SHA-256 `f61d6b84…`),
reviewer 1's exact text:

```
Thank you. The Rome 3.2 rampatch and NVM are not the intended files
for this chip.
```

Everything else is unchanged from v2: the quote, the second paragraph, the signature, the headers. The second
paragraph reads:

```
When the QCA9377 firmware is available for testing, I can test it on
this module (13d3:3503, ROM 0x302 build 0x111) with the test that
showed the hang: mSBC calls with headsets, counting HCI command
timeouts after each SCO link comes up.
```

## Checked on v3 (2026-11-27 19:18 UTC)

- `scripts/mail-lint.sh`: clean.
- `scripts/reply-headers-check.py` against his mail: all PASS; 7 recipients.
- `git send-email --dry-run --confirm=never --suppress-cc=self --suppress-cc=body` from the project checkout:
  "Result: OK", 7 `RCPT TO`: him, the list and his five Cc's.

## Round 3: one line

Is "Thank you. The Rome 3.2 rampatch and NVM are not the intended files for this chip." right as the opening? Please
answer "send", or give the change and its reason.
