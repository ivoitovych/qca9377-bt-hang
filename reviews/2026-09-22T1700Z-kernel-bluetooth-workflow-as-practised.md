# The kernel Bluetooth tree's patch workflow as practised — 2026-09-22T17:00Z

Asked for before any kernel patch from this project is tested or sent: how
patches reach `bluetooth-next`, what CI runs on them, how maintainers treat its
verdicts, what they say to submitters, and what is in the tree. Measured the
same way as BlueZ's workflow the day before (`2026-09-21T0900Z-…`), from the
same patchwork project — kernel and BlueZ patches share it — plus the tree
itself. Commands and full output: `…-survey-output.txt`, `scripts/kernel-bt-survey.py`.

## 1. The route

- **Trees.** `MAINTAINERS` (read at `bluetooth-next/master`): Marcel Holtmann and
  Luiz Augusto von Dentz; list `linux-bluetooth@vger.kernel.org`; two trees,
  `bluetooth.git` (fixes for the current cycle) and `bluetooth-next.git` (next
  merge window). The maintainer merges `bluetooth` into `bluetooth-next`
  regularly (merge commits on 09-16 in the `mgmt.c` log), then sends pull
  requests to the networking tree. A fix is applied to one of the two by him;
  the submitter does not choose the tree.
- **Mail, one patch per mail or a series; `git send-email`.** `Signed-off-by`
  required (kernel DCO), the opposite of BlueZ. Subject prefix `Bluetooth: `
  then the area — `net/bluetooth/mgmt.c`'s last 300 commits split exactly 9 /
  9 between `Bluetooth: MGMT:` and `Bluetooth: mgmt:`; either is house style.
- **Trailers in the last 300 Bluetooth commits** (`bluetooth-next/master`,
  `net/bluetooth` + `drivers/bluetooth`): `Fixes:` on 173, `Cc: stable` on 61,
  `Reported-by` on 12 of the last 60, `Reviewed-by` on 2 of the last 60. A
  fix with `Fixes:` and `Cc: stable` in the sign-off block is the normal form;
  a `Reviewed-by` is rare and not expected.
- **Stable.** Greg KH's form letter appears once in the window, to someone who
  sent a patch to the stable list directly: *"This is not the correct way to
  submit patches for inclusion in the stable kernel tree."* The correct way is
  the one this project's held patch uses — `Cc: stable@vger.kernel.org` on a
  mainline-bound fix. Another stable maintainer, on a request for a stable-only
  revert: *"I'd rather not carry a stable-only revert ahead of it — that would
  just make the stable trees diverge from Linus'."* Stable follows mainline.

## 2. The CI, and how its verdicts are treated

The same bot (`bluez.test.bot`) runs a kernel set: BuildKernel, BuildKernel32,
CheckAllWarning, CheckKernelLLVM, CheckPatch, CheckSparse, GitLint,
IncrementalBuild, SubjectPrefix, VerifyFixes, VerifySignedOff, TestRunnerSetup,
then `TestRunner_*` (mgmt-tester, l2cap-tester, … in a VM). Results go to
patchwork as checks and to the list as a mail, exactly as for BlueZ. There are
GitHub pull requests for kernel series too (`bluez/bluetooth-next`), the bot's
CI vehicle, never merged.

1000 patchwork entries, 2026-07-22 → 09-21: **312 kernel series with bot
checks — 133 accepted, 72 superseded, 107 still new.** Of the 133 accepted:

| | accepted kernel series |
|---|---|
| any bot check fail/warning at the accepted version | **70 (53 %)** |
| CheckPatch warning / fail | 17 / 2 |
| GitLint fail | 22 |
| SubjectPrefix fail | 4 |
| VerifyFixes fail | 0 (128 success) |
| a `TestRunner_*` fail | **44 (33 %)** |
| version ≥ 2 when accepted | 52 (39 %) |
| a maintainer comment on the patch before acceptance | **6 (4.5 %)** |
| comments = bot + patchwork-bot "applied" only | 93 |

So: lint and the VM testers are advisory here too, `VerifyFixes` is the one
check nobody fails (a `Fixes:` hash must resolve), and **the normal acceptance
is silent** — the bot's results, then patchwork-bot's "applied to
bluetooth-next" mail, no human word in between. Two of every five accepted
series went through a v2 first, so a respin is ordinary, and it is always a
new mail with a new series id (new PR), as on the BlueZ side.

## 3. What the humans say — and the second reviewer nobody sends to

87 non-bot comments on kernel patches match the rule words. What they are:

- **Review of substance**, by the maintainer and by regular contributors
  (Pauli Virtanen, Paul Menzel, Neeraj Kale…): lock ordering, lifetime,
  "please revalidate the KASAN crash on current bluetooth-next/master, there
  have been related fixes since v1". The recurring ask is *rebase and re-test
  on the current tip*, not style.
- **Process nits when they matter**: a missing `Fixes:` tag is asked for and
  the submitter adds it in v2 ("I will add the fixes tag in v2"); an HTML reply
  is bounced by the list; a table not sorted by USB id is pointed out.
- ⚠️ **Sashiko.** Four threads in the window have the maintainer or a
  contributor citing `https://sashiko.dev/#/patchset/<message-id>` — *"Sashiko
  found a problem"*, *"like captured by sashiko"*, *"Sashiko review complains
  about…"*, *"On Sashiko review comments: … it is pre-existing"*. Sashiko is
  the Linux Foundation's automated LLM patch-review system (compute funded by
  Google), which reads the public lists and reviews every submission; the
  maintainer reads its output and quotes it back to submitters. **Every patch
  sent to the list gets an adversarial machine review that the maintainer
  takes seriously, whether or not the submitter asked.** It reviews against the
  tree it chooses ("it applied the patch to bluetooth/master, instead of
  bluetooth-next"), so a patch must be right on both.

## 4. What this means for any kernel patch from here

- Form: `Bluetooth: <area>:` prefix, `Fixes:` with a resolving 12-hex hash,
  `Cc: stable` when the fault is in stable, `Signed-off-by`, checkpatch clean.
  `VerifyFixes` and `SubjectPrefix` then pass.
- Send: `git send-email` to the list with both maintainers on Cc, as
  `MAINTAINERS` says; `Reviewed-by` neither needed nor expected; the reply, if
  any, is patchwork-bot's "applied".
- Expect: the bot within ~2 h; a Sashiko review on the web within hours;
  possibly silence for days; possibly a one-line ask. Rebase and re-check
  against **both** `bluetooth/master` and `bluetooth-next/master` on the day of
  sending (`scripts/pre-send-check.sh` takes either).
- An external review before sending is exactly the shape of what happens
  after sending. Worth doing first.

## 5. Tips refreshed 2026-09-22

`cache/linux` now carries remotes `bluetooth-next`, `bluetooth`, `stable` and
mainline (`origin`), fetched blob-less:

| tip | commit | date |
|---|---|---|
| `bluetooth-next/master` | `06d991977eef` | 2026-09-21 |
| `bluetooth/master` | `6d91041bb38b` | 2026-09-21 |
| mainline `master` | `f0100363d8c3` | 2026-09-21 |
| `stable/linux-6.12.y` | `e2acc2211022` 6.12.111 | 2026-09-21 |
| `stable/linux-6.6.y` | `79643295eba1` 6.6.157 | 2026-09-14 |
| `stable/linux-6.1.y` | `1a8763b93150` 6.1.188 | 2026-09-14 |

`scripts/build-bluetooth-module.sh` can be pointed at any of them for a
compile check; `scripts/pre-send-check.sh` at any of them for applicability.
