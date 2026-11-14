# BT-18 linux-usb question: decisions left to you

Draft: `question-linux-usb.txt`. Nothing has been sent. Every claim has a source in `SOURCES.md`.

1. **The optional URL line** (the GitHub `results/bt17-emulation-2026-11-13/` link). Keep it or
   delete it, together with its `[OPTIONAL …]` marker line. Without it, the mail still stands on
   its own (the setup is described in a sentence, as upstream precedent does).
2. **Sean Rhodes in Cc**, and the mail's sentence about his pending series ("restore powered-off
   Intel adapters"). Keep both or drop both. Keeping them tells the maintainers that the one
   pending btusb `reset_resume` would not change this.
3. **linux-kernel@vger.kernel.org** is suggested by `get_maintainer.pl` but left out (a question on
   the subsystem lists, as in 2014). Add it if you prefer.
4. **Greg in Cc, not To.** The question is addressed to Alan Stern. Move Greg to To if you prefer.
5. **The links [1] and [2] now point at mail-archive.com** (changed 2026-11-14). The lore links
   built from the Message-IDs answer "not found" (HTTP 300, checked 2026-11-14 for
   `lore.kernel.org/linux-usb/` and `/all/`): lore does not hold these 2014 messages. The
   mail-archive pages `msg38572` (Alan Stern, "Re: BUG: USB Reset-Resume Mechanism does not work
   for runtime resume") and `msg40098` (Loic Poulain, "[PATCHv4] rebind: …") carry exactly those
   Message-IDs (their `msgid` fields, read 2026-11-14). Open both once before sending.
6. **Send it as a new thread,** not as a reply to the 2014 thread (12 years old).
7. **Long lines:** the 15 log lines are verbatim and some are over 72 columns; everything else
   is wrapped at 72.
8. **Left out for length** (could be added to question 1): `callbacks.rst` says *"suspend is
   always followed by one of: resume, reset_resume, or"* disconnect; `power-management.rst:334-336`
   still says *"Later kernels will call the driver's disconnect method"*.
9. **Sending:** no `From:` line in the file. Dry-run first and check the RCPT TO list (9
   recipients: 2 To, 7 Cc).
