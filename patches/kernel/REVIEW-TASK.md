# Pre-submission review — one Linux kernel Bluetooth patch

*(The brief as given to the fourth reviewer on 2026-09-24, before the patch was sent; it
then asked that everything stay private until the mail had gone. Ported to `main`
2026-10-09.)*

## What is asked, in one paragraph

This is the last review before the patch is mailed. Three earlier reviews
found the code change correct. This one has two jobs of equal weight:

1. **Review the mail itself, as the maintainers will receive it.** Treat
   `0001-…patch` as the only thing that exists. It is the only thing the
   maintainers, the list's CI bot and the automated LLM reviewer (Sashiko) are
   certain to read. Everything else in this package is background they will
   never see unless they ask.
2. **Look beyond what we asked.** We know our own blind spots only as far as
   we have already found them. Anything you think deserves a look is in
   scope: the code around the change, its history, the kernel's other
   callers, the process, and things we have not thought of. If you research
   something and find nothing, a short "checked X, nothing there" is useful
   too.

"No finding" is a valid answer to either job.

## Part 1 — the mail, read cold (please do this first)

Please read **only** the `.patch` file before opening anything else, and
write down your first impression as a Bluetooth maintainer would have it. Is
the bug obvious from the diff and the first paragraph? Would you apply it
without looking further? What would you ask the author? That first read is
the one that counts on the list.

Then check the mail line by line:

- **Truth.** Is every sentence true against the current `bluetooth` and
  `bluetooth-next` trees? This matters most for the two-case description of
  `match->sk`, the `f53e1c9c726d` history, the BlueZ paragraph (commit
  `a734b06059cb`), and the "Tested on 7.0" paragraph. The module was built
  from Ubuntu's 7.0.0-31 source; is "7.0" honest enough?
- **Length and focus.** Is the message too long for a one-line fix? Would the
  capture excerpt or the BlueZ paragraph be better cut, shortened, or moved
  below `---`?
- **Tags.** `Fixes:`, `Cc: stable`, `Signed-off-by`. Should a stable version
  hint (`# 6.1.120+`) be added, or anything else?
- **Tree and base.** It is a regression fix going to stable, but it is based
  on `bluetooth-next` (`base-commit: 671d566d3c3b`). It also applies to
  `bluetooth`. Should the base be `bluetooth`?
- **Bots.** What would CheckPatch, GitLint, SubjectPrefix, VerifyFixes or
  VerifySignedOff flag? What would an LLM reviewer object to?
- **Recipients.** The plan is to send to linux-bluetooth, with Cc to Marcel
  Holtmann, Luiz Augusto von Dentz (author of `f53e1c9c726d`) and
  linux-kernel, as `get_maintainer.pl` lists them. The send uses
  `git send-email --suppress-cc=bodycc`, so `Cc: stable` stays a tag and is
  not mailed. Is that right?

### The plan — please challenge any of it

- One plain-text mail: the patch file, and nothing below `---` except the
  diffstat.
- No link to the author's public investigation repository.
- No separate bug report; the patch is the report.
- No reproducer in the mail. It is offered in a reply if a maintainer asks.
  Should it be offered up front instead, or included below `---`?
- No `Tested-by:` or `Reported-by:`: the author is both reporter and tester.
- The procedure fetches both trees minutes before sending. Last week's BlueZ
  v2 went out against a stale checkout after v1 had already been applied.

### ⚠️ This is the kernel, not BlueZ

The same author sent two BlueZ patches last week, and both were applied. The
mailing list is the same, but the rules are not:

| | BlueZ (userspace) | kernel (this patch) |
|---|---|---|
| `Signed-off-by` | forbidden | **required** (DCO) |
| subject | `[PATCH BlueZ] area: …` | `[PATCH] Bluetooth: MGMT: …` |
| recipients | the list only | list + maintainers + `linux-kernel` (`get_maintainer.pl`) |
| stable | — | `Cc: stable@…` as a **tag, NOT an email recipient** |
| CI | BlueZ build, gitlint, tests | kernel build (32/64, LLVM), sparse, checkpatch, gitlint, SubjectPrefix, VerifyFixes, VerifySignedOff, VM testers |

Please check the patch against the kernel's own rules:
`Documentation/process/submitting-patches.rst`,
`Documentation/process/stable-kernel-rules.rst`, and `MAINTAINERS` (BLUETOOTH
SUBSYSTEM).

## Part 2 — does the evidence hold up the mail?

The rest of the package is the background. For each claim in the mail, does
something here prove it, and is that proof sound?

- `README.md` covers the state, the send procedure, the three earlier reviews
  (ER1–ER3) and what was done about each, and the runtime tests.
- `evidence/exhibits/044-*` is the real-hardware observation from 2026-08-14:
  the kernel answered a flushed Start Discovery with status 0x00.
- `evidence/exhibits/049-*` and `050-*` are the virtual-controller reproducer
  run on the patched module (answers `0x0f`) and on the stock module of the
  same kernel (answers `0x00`).
- `repro-mgmt-flush-status.py` is the reproducer. `…original.py` is the
  unmodified version from an outside reviewer; the working copy fixes two
  transport bugs.

Two things are known to be untested: the `mgmt_index_removed()` path
(expected status Invalid Index), and runtime on any kernel other than 7.0.
The patch was only *built* at `bluetooth-next` and at `linux-6.1.y`.

## Part 3 — open ground (as wide as you like)

These are starting points, not a boundary:

- **Siblings.** Does `f53e1c9c726d`, or the series around it, leave the same
  `void *data` mismatch anywhere else? Look at other `mgmt_pending_foreach()`
  callbacks, other `cmd_status_rsp` users, and code that changed in stable
  backports but differs from mainline.
- **Blast radius.** Which commands are registered with `mgmt_pending_add()`
  and no `cmd_complete`, and so are reached by this flush? Does any userspace
  besides bluetoothd act on the wrong status?
- **Tests upstream.** `mgmt-tester`'s power-off discovery case passes on
  buggy kernels (see README). Should a BlueZ `mgmt-tester` case or a kernel
  selftest follow as a separate patch? Would offering one help this patch get
  applied?
- **The bigger investigation.** This patch came out of a long hunt for a
  QCA9377 controller wedge on SCO/alt-1 (public repository:
  <https://github.com/ivoitovych/qca9377-bt-hang>). Anything there that this
  patch changes, explains, or should be linked to later is welcome.
- **Anything else:** dark corners, a better way to say it, a reason not to
  send yet, related bugs, ideas we have not reached.

## What we would like back

1. Your cold first impression of the mail (Part 1, first paragraph), in a few
   lines.
2. A table of findings: where, what, why, suggested change, and severity
   (blocker / should / could).
3. What you explored in Part 3: what you found, and what you checked and
   found nothing in.
4. A one-line verdict: send as is / send after changes / do not send yet.
