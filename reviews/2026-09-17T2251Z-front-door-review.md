# Front-door review — 2026-09-17T2251Z

**Covers:** the tree at `0f25bea` (`origin/main` tip, 2026-09-18 "BRIEF: back to 200 lines").
**Branch:** `review/2026-09-17T2251Z`. **Predecessor:** `2026-09-16T0420Z-comprehensive-code-review.md`
(every file, at `3cf4dd6`) and the maintainer's reaction
`comms/2026-09-16T2300Z-…`, which closed R2-01/R2-100, R2-58, R2-76, R2-114, R2-117 and
parts of R2-04/R2-105.

**Scope and method.** Not every file — five: `README.md`, `BRIEF.md`,
`patches/bluez/README.md`, `docs/bug-report.md`, `docs/issues.md`, plus the two patch
files. Each is read twice, as two strangers: **(M)** a BlueZ or kernel maintainer who has
just received the patches by mail and opened the repository to see where they came from
and whether the runtime claim holds; **(U)** a person with a Bluetooth fault on a
different controller, headset or distribution, deciding in two minutes whether this
project helps them. Findings are `FD-nn`, appended per file; the deliverables — a README
skeleton, the patch mail-body note, and the order of work — are §7, written last.
Severity: **HIGH** (a reader is misled or turns away), **MED** (a reader has to hunt),
**LOW**, **NOTE**, **GOOD** (keep).

## 0. What the two readers arrive with

**(M)** arrives from a `[PATCH BlueZ]` mail. They want, in this order: is the fix
correct (the commit message must carry that alone); has the guard ever fired (EX-041,
four times); what hardware and what circumstances (one paragraph); and, only if curious,
how the crash site was found in a stripped binary. They will spend two minutes on the
front page. They will not read HISTORY.

**(U)** arrives from a search for "Bluetooth stops working Linux" or a `command tx timeout`
line in their own journal. They want: is this my hardware; if not, is this my symptom; can
I run one thing to find out; what does it cost to try; what transfers if my controller is
different.

Both want the same three things on the first screen: what this is, what is established
now, and where the evidence is. Neither wants to be told which sections are stale.
