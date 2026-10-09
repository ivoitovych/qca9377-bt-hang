# The kernel send package — what goes out, to whom, and what must be true on the day

*Written 2026-09-24 by the test-suite maintainer at the operator's request, before the
kernel patch was mailed (it was sent that evening and applied 2026-09-29 as `86ef0f58bdec`).
Kept on a private branch until 2026-10-09; the patch and its checks are now in
[`patches/kernel/`](../patches/kernel/README.md).*

> ⚠️ **Different corners of Linux have different rules, and this project has now sent patches
> to two of them.** BlueZ (userspace, `bluez.git`) and the kernel's Bluetooth subsystem
> (`net/bluetooth/`) share a mailing list and a patchwork project, and **almost nothing else
> about how a patch must look**. The first difference is the loudest: `Signed-off-by` is an
> error in BlueZ and mandatory in the kernel. So every rule below names **where it comes
> from**, and the BlueZ experience is kept in its own section, marked as such.

**Sources, read 2026-09-24:** the kernel's `Documentation/process/submitting-patches.rst` and
`stable-kernel-rules.rst`, and `MAINTAINERS`, all from mainline `master` (the GitHub mirror —
this environment's egress policy refuses `git.kernel.org`); the measured practice in
[`reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md`](../reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md);
and the BlueZ record in [`patches/bluez/README.md`](../patches/bluez/README.md) and BRIEF §9.7.

---

## 1. What is being sent

**One mail, one patch:** the one-line change to `net/bluetooth/mgmt.c` held on
`kernel/mgmt-flush-status`. It is **not** the patch for the controller fault this project is
named after — that one does not exist yet (`BT-1`, BRIEF §9.6) — and none of
[`pre-submission-checklist.md`](pre-submission-checklist.md) §2–§4 are about it.

To read it before it goes: the held branch on the private remote, or on the investigation
machine `devtools/held edit` → `patches/kernel/`, or `scripts/export-kernel-review.sh`, which
writes the exact reviewer package to `tmp/review-kernel-0001/`. Its `0001-*.patch` is in
`git format-patch` form — **that file is the mail body**, headers included. It is on no public
page and should not be until the mail exists.

## 2. Who it goes to — from `MAINTAINERS`, not from memory

| | | source |
|---|---|---|
| **Maintainers** | Marcel Holtmann, Luiz Augusto von Dentz | `BLUETOOTH SUBSYSTEM`, `M:` — covers `net/bluetooth/` |
| **List** | `linux-bluetooth@vger.kernel.org` | same entry, `L:` |
| **List** | `linux-kernel@vger.kernel.org` | `THE REST` (`F: *`) matches every file, and `submitting-patches.rst`: *"should be used by default for all patches"*. **BlueZ mails never go here — a kernel difference** |
| **Cc: stable** | `stable@vger.kernel.org`, as a **trailer** in the commit message; `git send-email` turns it into a Cc | `stable-kernel-rules.rst`. Never to the stable list on its own — Greg KH's form letter |
| **The author of the commit named in `Fixes:`** | whoever `get_maintainer.pl` reports for it | kernel practice: the person whose change is being fixed is told |
| ❌ **NOT netdev** | — | `NETWORKING [GENERAL]` covers `net/` but has **`X: net/bluetooth/`**. Its maintainer profile (`maintainer-netdev.rst`: `[PATCH net]` tags, its timing rules) therefore **does not apply** here, though the path starts with `net/` |

**The practical rule:** on send day, in the kernel tree, run
`scripts/get_maintainer.pl patches/kernel/0001-*.patch` and send to what it prints — the
kernel's own advice (`submitting-patches.rst`, *Select the recipients*). A send command that
names only the list silently drops the maintainers, LKML and the `Fixes:` author: check the
command, not only the prose around it. The Bluetooth entries carry **no `P:` line** — there is
no Bluetooth-specific written rulebook, so the kernel-wide documents plus measured practice
are the whole of it.

**Where it then appears:** `https://lore.kernel.org/linux-bluetooth/<Message-ID>/` (keep the
Message-ID `git send-email` prints) and `https://patchwork.kernel.org/project/bluetooth/list/`.
It lands in `bluetooth.git` or `bluetooth-next.git` — **the maintainer chooses**, not the
sender. Expect the CI bot within ~2 h, a **Sashiko** review on the web within hours (the
maintainer quotes it), then possibly days of silence. **Acceptance is silent** — the only
signal is patchwork-bot's "applied".

## 3. What the mail contains — and what it does not

**Contains:** subject `[PATCH] Bluetooth: MGMT: …`, the commit message, `Fixes:` as
`12-hex ("subject")`, `Cc: stable@vger.kernel.org`, `Signed-off-by` with a real name, the
diff. Optionally a note below the `---` line, which reviewers read and `git am` drops.

**Does NOT contain:**

- **The bug report.** [`bug-report.md`](bug-report.md) is about the controller fault — a
  different, unresolved defect in a different file. Attaching or citing it would bury a
  one-line fix under an intermittent hardware investigation it does not depend on.
- **Exhibits, captures, or any file from this repository.** `submitting-patches.rst`: *"try
  to make your explanation understandable without external resources."* If a maintainer asks
  for the capture, it is offered in a reply, then.

**Links — the kernel rule is not the BlueZ habit.** `submitting-patches.rst` *encourages*
`Link:` tags to background on the web and prefers lore.kernel.org; `Closes:` is for a bug
report. So a `Link:` to the BlueZ patch thread on lore would be within the rules if the
background is wanted — optional, since the message must stand alone either way. A link to
**this repository** is a different matter: it brings its history with it, including the
address purge [`pre-submission-checklist.md`](pre-submission-checklist.md) §1 marks *must happen
before submission* (never done) and the text BRIEF §9.9 records as neutralised on `main` but
still in history. Both BlueZ mails carried such a link below `---`. **Whether the kernel mail
does is a decision to take on purpose.**

## 4. The rules, by where they come from

### Kernel-wide — `submitting-patches.rst`, `stable-kernel-rules.rst`

| Rule | Note |
|---|---|
| **`Signed-off-by` required**, *"using a known identity"* | The DCO is a legal statement; the name must be the real one (it differs from the address spelling — checklist §5) |
| **`Fixes: <12 hex> ("<exact subject>")`** | Exempt from line wrapping — its length is not a checkpatch defect. The bot's `VerifyFixes` compares the subject to the real commit |
| **`Cc: stable@vger.kernel.org`** in the trailers | Stable follows mainline; never a stable-only submission |
| **LKML on Cc by default** | See §2 |
| **Resend: wait at least one week** before resubmitting or pinging; `RESEND` only for an *unmodified* patch | *"Wait for a minimum of one week before resubmitting or pinging reviewers"* |

### Bluetooth subsystem — `MAINTAINERS` and measured practice (no `P:` profile exists)

| Rule | Note |
|---|---|
| To the list and both maintainers, from `get_maintainer.pl` | §2 |
| Subject `Bluetooth: MGMT:` or `Bluetooth: mgmt:` | In `mgmt.c`'s last 300 commits each spelling appears exactly 9 times |
| **Check against both trees on the day**: `bluetooth/master` and `bluetooth-next/master` | The maintainer picks the tree; the patch must apply to either |
| The CI bot runs `CheckPatch`, `GitLint`, `VerifyFixes`, `VerifySignedOff`, `SubjectPrefix`, builds and `mgmt-tester` etc. | Warnings are common and not fatal: 53 % of *accepted* series had a bot fail or warning; only `VerifyFixes` was never failed |

### This project's send lessons that DO transfer

| Rule | What it cost |
|---|---|
| **Fetch before sending, and check the patch against the fetched tips** | Both BlueZ v2 mails went out 6.5 h after v1 had been applied — visible in one `git fetch` |
| ⚠️ **Read what `scripts/pre-send-check.sh` fetched before trusting "OK to send"** | It fetches `origin` and checks `origin/master` of the tree it is given. `cache/linux` holds the Bluetooth trees as remotes named `bluetooth` and `bluetooth-next`; unless the tree passed in has one of them as `origin`, it checks some other master. Its first line prints the tip it used |
| **One mail, `git send-email`, keep the Message-ID** | Every later URL is derived from it |
| **Nothing is sent without the operator's explicit word, on the day** | As for both BlueZ sends |

### BlueZ-only rules — do NOT carry these over unexamined

| BlueZ rule | In the kernel |
|---|---|
| **No `Signed-off-by`** (BlueZ `HACKING`: including one *"is actually an error"*) | **Reversed** — mandatory |
| **No hard tabs in quoted code** (GitLint flagged both BlueZ messages) | The kernel bot runs GitLint too, so a warning is **likely** — but tab-indented code in kernel commit messages is common and the warning advisory. Converting to spaces is an option, not a rule; it is a message change after review, so decide before the last review, not after |
| **No v2 for a lint finding before a human replies** | Holds, and the kernel says it more strongly: one week before any resend |

## 5. The moment after sending — what must change publicly

The held branch stays private only until the mail exists; after that the patch is on lore.
Then, and not before:

- [`README.md`](../README.md) says *"No kernel patch exists yet."* True for the controller
  fault, false for this one — it changes on the day.
- A status table for the kernel patch like [`patches/bluez/README.md`](../patches/bluez/README.md)'s:
  Message-ID, lore, patchwork series, bot results, the applied commit when it lands.
- BRIEF §9.8–§9.9 move from "prepared" to "sent", and `patches/kernel/` comes to `main`.

## 6. One more external review — yes, and of a different kind

Three external reviews have looked at **whether the fix is right**, and all three said it is.
What went wrong with BlueZ was never the code: it was the **send** — a stale tree, a v2 nobody
needed, a convention taken from the wrong project. And the commit message has changed since
the third review. So a fourth review should read the message fresh, and then the mail **as it
will leave**, against §2–§4: recipients, every trailer, anything below `---`, the send-day
check output, and anything in the package that points somewhere it should not.
`scripts/export-kernel-review.sh` includes this file in the package and asks those questions.
