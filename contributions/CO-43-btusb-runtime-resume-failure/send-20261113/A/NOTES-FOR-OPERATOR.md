# A — what is left to you

**Patch:** `0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch`, on bluetooth-next
`da3cc02587c6` (today's tip; bluetooth's tip `3b069de8a5d6` has the same `btusb_main.c`). It is
independent of E: it applies and builds alone, before E and after E, on both tips (`CHECKS.md`).

**Nothing has been sent.** The send is yours, with your own Signed-off-by.

## Your Signed-off-by

Put it on its own line after the last body line, before the `---`, with an empty line in between:

```
runtime PM is disabled, for example during a system sleep transition.

Signed-off-by: <your legal name> <yaroslav.voytovych@gmail.com>
---
Tested with an emulated device ...
```

Or `git am` the file and `git commit --amend -s`, then `git format-patch -1` again; the text below
the `---` then has to be put back by hand.

## Decisions

1. **The subject.** Chosen: "Bluetooth: btusb: Report a failed runtime resume for deferred data"
   (66 characters). Why: the waker calls `usb_autopm_get_interface()`, a runtime resume, and that is
   all the patch reports. "A failed resume" could be read as `btusb_resume()`, the USB resume
   callback, which the patch does not touch. Two of the outside reviewers proposed the word
   "runtime" too. The old subject is fine if you prefer it.
2. **The comment:** the one line `/* -EACCES: runtime PM is disabled, e.g. during system sleep */`,
   the example given. It claims no more than the message.
3. **The note below the `---`** (how it was tested). Optional; `git am` drops it. Delete it if you
   want the mail shorter.
4. **No `Fixes:`, no `Cc: stable`.** A only adds a message. Nobody in the reviews asked for stable.
5. **Order:** E and A are independent. The reviews' order was CO-44, then E, then A. A week between
   them is not needed; they touch different functions.

## What the message no longer claims (from the reviews)

- that nothing else logs the failure: btusb's own reset path prints
  `Failed usb_autopm_get_interface: -16` at the disconnect (it did in the emulator run too, at the
  same moment as the new line);
- that `-EACCES` means system sleep only;
- that `btusb_resume()` always sends the deferred data.

## The dry run

Done 2026-11-14 (`../dry-run-20261114/dry-run-co43-A.txt`): `Result: OK`, the five `RCPT TO`
lines listed in `send-commands.txt`. Run it once more after adding your Signed-off-by, from the
project checkout (its git config carries the SMTP server).
