# CO-25 acknowledgement: what round 1 found, the change made, and round 2 (2026-11-27)

**What this is.** The findings of review round 1 on our short reply to Zijun Hu (Qualcomm), our checks of each, the
one change made, and the request for round 2. It is self-contained; round 1's request is
[`2026-11-27T0450Z-co25-acknowledgement-review.md`](2026-11-27T0450Z-co25-acknowledgement-review.md). Nothing has
been sent. The operator sends the mail himself once a round is clean.

## Context in four lines

- **2026-10-29, our report:** without a btusb entry, the QCA9377 (USB `13d3:3503`) runs its ROM firmware (ROM 0x302,
  build 0x111) and stops answering after an mSBC link comes up. With btusb's QCA setup, which loads the Rome 3.2
  `rampatch_usb_00000302.bin` and `nvm_usb_00000302.bin`, 74 SCO links (50 mSBC, 24 CVSD) logged no timeout.
- **2026-11-24, our three questions:**
  1. Are the Rome 3.2 files the intended ones for this module, and if not, what should it load?
  2. Is there a list of the USB IDs that need this setup?
  3. Is the hang a known issue of this ROM?
- **2026-11-26 08:51 +0800, his answer**, to question 1 only, quoted whole:

  > no, let me try to up-stream QCA9377 BTUSB firmware, you may override
  > the one loaded currently by QCA9377 as WAR
  > we will think about how to support it.

## Round 1: five answers, one finding

All five reviewers (1, 2, 3, 6, 7) asked for the same change and nothing else. The answers given as reviewer 6 and
reviewer 7 are word for word the same text.

**The finding: v1 read his WAR sentence as a fact it does not state.** v1 said: "So the Rome 3.2 rampatch and NVM
that btusb loads for 13d3:3503 today are a workaround, and the intended QCA9377 firmware is still to come."
- **What is firm:** his "no". The Rome 3.2 files are not the intended firmware.
- **What is not:** "you may override the one loaded currently by QCA9377 as WAR". Its subject is "you" and its verb is
  "override", so the workaround is most naturally the act of replacing what is loaded now (reviewers 6 and 7). It does
  not say the Rome 3.2 files are the workaround. Reviewer 1 calls our reading a plausible one, but ours, not his.
- **Why it matters (reviewers 6 and 7):** the sentence would put in the list archive a Qualcomm endorsement he did not
  give, with the maintainers and the entry's author on Cc and `dc16388d45ec` in every stable line. Also, "is still to
  come" turns his "let me try" into a commitment.
- **Our check:** the quote above is his whole reply, read from the list archive. The grammar reading of reviewers 6
  and 7 holds: "you may override the one loaded currently" has "the one loaded currently" as its object, and nothing
  in the sentence names the Rome files as the workaround. Finding accepted.

**How to fix it: the reviewers differ.**
- **Reviewer 1:** keep our reading, marked as ours ("I take that as: …").
- **Reviewers 2 and 3:** do not interpret the WAR sentence at all. State only what "no" establishes. No hedge
  either: "If I read you correctly" invites another reply that nothing here needs.
- **Reviewers 6 and 7:** state what "no" establishes, then add the opposite reading with a hedge: "If I read the
  workaround correctly, the QCA9377 files go in place of the ones btusb loads now …".

**Chosen: reviewers 2 and 3.** Both readings of the WAR sentence are uncertain, and either could be quoted later. The
offer to test does not depend on either: when the firmware comes, how to load it will come with it. Reviewer 6's
benefit, telling him how we will test, is not lost, since he will say how. The first line takes reviewer 6's wording,
because it joins the thanks and the one firm fact.

**Everything else, all five agree, stays as it is:**
- questions 2 and 3 are not repeated, and no "they can wait" (that is still a reminder);
- the offer to test is the right size;
- no mSBC/CVSD split here, since it belongs in the results mail;
- nothing else to cut.

From reviewer 2: "available for testing" leaves room for firmware sent for testing before it is upstreamed. Taken.

**Reviewers 6 and 7's check, on the recipients:** our round-1 page said the 7 `RCPT TO` lines are "equal to his
recipients". That was loosely put. The right set is his recipients without us, plus him. The dry run (below) has his
address, the list, and his five Cc's, and not ours: 7 lines, the right set. The wording is corrected here.

## The change, before and after

Before (v1, `reply-2-zijun-hu-ack-v1.eml`, SHA-256 `fc13a291…`):

```
Thank you, that answers the main question.

So the Rome 3.2 rampatch and NVM that btusb loads for 13d3:3503 today
are a workaround, and the intended QCA9377 firmware is still to come.
When it is posted, I can test it on this module (13d3:3503, ROM 0x302
build 0x111) with the test that showed the hang: mSBC calls with
headsets, counting HCI command timeouts after each SCO link comes up.
```

After (v2, `reply-2-zijun-hu-ack-v2.eml`, SHA-256 `6848626f…`):

```
Thank you, that answers the main question: the Rome 3.2 rampatch and
NVM are not the intended files for this chip.

When the QCA9377 firmware is available for testing, I can test it on
this module (13d3:3503, ROM 0x302 build 0x111) with the test that
showed the hang: mSBC calls with headsets, counting HCI command
timeouts after each SCO link comes up.
```

The quote of his reply above it and the signature below are unchanged. Headers are unchanged: To him and the list,
Cc Marcel Holtmann, Luiz Augusto von Dentz, Shuai Zhang, Bartosz Golaszewski, Tibor Harcsa; In-Reply-To his mail.

## Checked on v2 (2026-11-27 19:11 UTC)

- `scripts/mail-lint.sh`: clean (headers, 72 columns, ASCII, no trailing whitespace).
- `scripts/reply-headers-check.py` against his mail: all PASS; reply-all gives 7 recipients.
- `git send-email --dry-run --confirm=never --suppress-cc=self --suppress-cc=body` from the project checkout:
  "Result: OK", 7 `RCPT TO`: him, the list, and his five Cc's.

## Round 2: please read only what moved

1. Does the new first line say exactly what "no" establishes, no more?
2. "When the QCA9377 firmware is available for testing": does it still promise anything on his behalf?
3. Anything else in the two new paragraphs?

Please answer with "send", or with each change and its reason.
