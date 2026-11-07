# CO-10 log

Append-only. Newest last.

## 2026-10-20 — rc2 out
The rc1 boot panic on a two-socket Xeon server was bisected to a sysfs patch, which was
dropped. rc2 (07:57 UTC) lists our three patches, and responses are due Thu 22 Oct 07:53:04
UTC (STATUS).

## 2026-10-21 — dossier opened
No decision yet.

## 2026-10-21, before 00:52:54 UTC (the build's start) — the operator: start CO-10
"I would start work on that urgent one … I would try to contribute it if we can." There was
no draft, so this is the first work on it.
- **The release candidate:** linux-stable-rc `linux-6.6.y` fetched; tip `c578c158a368`,
  "Linux 6.6.160-rc2".
- **Our three commits in it:** `4124ec5afa39` (BT-9), `9e665c9f2123` (BT-8), `c1d19f19c937`
  (QCA9377).
- **The run:** `experiments/build-and-test.sh`. Both kernels built in about 2 minutes each,
  and every run finished by 01:04:46 UTC. Results: `experiments/results-2026-10-21.md`.
  - BT-9 race: 6.6.159 fails 3/3, rc2 passes 3/3.
  - BT-8 reproducer: 6.6.159 0x00 2/2, rc2 0x0f 2/2.
  - mgmt-tester: one verdict differs out of 508, the race case.
  - No kernel reports.
- **The operator asked for the homework to be complete.** Found: rc2 carries 41 Bluetooth
  commits, 38 of them by other authors. So `experiments/all-testers.sh` runs every BlueZ
  tester on both kernels, in parallel, from 01:02 UTC.
- **No follow-up fix** for `96d006ae6445`, `86ef0f58bdec` or `dc16388d45ec` in bluetooth-next
  (fetched 2026-10-21), bluetooth (fetched 2026-10-21) or the mainline mirror (to 2026-10-18).
  A fetch of today's mainline was still running.
- **Package for outside reviewers:** `REVIEW-REQUEST.md`. The draft reply is in `drafts/`.

## 2026-10-21 01:02 to 01:36 UTC — every tester compared; draft version 2
- **iso-, sco-, bnep-, rfcomm-, ioctl-, smp-, userchan- and 6lowpan-tester:** identical
  verdicts on both kernels.
- **l2cap-tester:** both kernels hang at the same case ("Ext-Flowctl Server - Accept 2
  Close 1"). The guests were stopped. Of the 96 cases before it, one differs: "Ext-Flowctl
  Client - Defer limit", which failed 3/3 on 6.6.159 and passed 3/3 on rc2 in repeats. That
  is rc2's `e2910b42115a` (Pauli Virtanen's ecred fix).
- **mesh-tester:** 6.6.159 crashes in "Mesh - Enable 2" (KASAN stack-out-of-bounds in
  `set_mesh_sync`, then a GPF in `mgmt_pending_remove`). rc2 runs clean, with "Send cancel 1/2"
  timing out. The crash is rc2's `78504bca42ab`.
- **A mistake of ours, fixed:** the first `repeat-case.sh` passed a multi-word `-p` filter.
  test-runner hands the guest its arguments in one string, split at spaces, so the whole
  l2cap-tester ran and hung. The script now takes one word with `-s`, and says why.
- **Identity:** the BT-9 and BT-8 commits in rc2 are the same as sent and as mainline (same
  patch-id). The QCA9377 entry adds the same two lines (different context). No follow-up fix
  in today's mainline (`14c897740388`).
- **The draft:** version 2 states all four fixes and the regression result. No pending lines.

## 2026-10-21 01:43 UTC — three outside reviews of version 1; version 3
The reviews are in `reviews/2026-10-21-reviewer-{1,2,3}.md`. A fourth reviewer will answer
later. All three read version 1, with its [PENDING] line.

**Verdicts:**
- reviewer 1: send once the pending line is filled;
- reviewer 2: ready after minor fixes;
- reviewer 3: revise before sending; conditional approval.

**What each point led to:**

| point | who | done |
|---|---|---|
| Finish the other testers; check per-case verdicts, not script completion | 1, 2, 3 | done in version 2, by per-case comparison (`compare-tester-verdicts.py`); the one differing case was repeated 3 times per kernel |
| "No regressions in Bluetooth" is overbroad | 2, 3 | changed to "No new failures in those tests" |
| Put the exact rc2 commit in the mail | 2, 3 | added: `(c578c158a368)` |
| Show mgmt-tester's existing failures | 2, 3 | added: rc2 465/37/6, 6.6.159 464/38/6 |
| Confirm KASAN and lockdep in the generated configs; confirm the booted kernels | 2, 3 | done: 4 options on each config; every log names the intended kernel (results file) |
| A wider scan for kernel reports | 3 | `scripts/kernel-report-scan.py` (13 kinds): rc2 clean in all 18 logs; positive control found 6.6.159's crash. The mail now says "No kernel warnings or sanitizer reports on rc2 in these runs" |
| The comparator can hide duplicates and accept empty input | 3 | fixed: exit 2 on duplicate names or no verdicts |
| The build recipe and QEMU wrapper are not public | 3 | copied into `experiments/` with both configs; decisive lines in the results file |
| Link the rc2 run to the earlier isolated experiments | 3 | added to the results file |
| The comment in `all-testers.sh` names the wrong script | 2 | fixed |
| The QCA9377 entry: omit (1, 2) or one sentence (3) | split | middle course: "(emulated controllers, no Bluetooth hardware)" states the scope without singling out one patch |
| Check the threading headers against the announcement | 3 | the sendable copy's `In-Reply-To`/`References` match the saved announcement's Message-ID; To/Cc copied from its header |
| No reboot of the laptop into rc2 | 2, 3 | agreed; not done |

**The sendable copy:** version 3, `tmp/co10-20261021/send/reply-6.6.160-rc2-v3.eml`.

## 2026-10-21 01:55 UTC — the fourth outside review (of version 3); version 4
The review is in `reviews/2026-10-21-reviewer-4.md`. **Verdict:** "almost ready"; "close the
one comparison hole and then stop".

| point | done |
|---|---|
| The two mesh "Send cancel" timeouts on rc2 have no 6.6.159 verdict (the control crashed first) | **Closed.** Each mesh case after the crash was run alone on both kernels (`repeat-case.sh … cancel 3`, `Features 1`, `Send 1`). Send cancel 1 and 2 do not pass on 6.6.159 either (Timed out or Failed, 4/4), so they are not new. Every other mesh case matches. All ten runs are clean (`kernel-report-scan.py`). mesh-tester joins the same-verdict list |
| "BlueZ's emulator testers" is ambiguous (BlueZ also builds gap- and hci-tester, not in CI) | now "the BlueZ CI TestRunner suites" |
| "No new failures in those tests" | now "All other cases that ran on both kernels have the same verdict" |
| `mail-lint.sh` claims four headers and checks three; nothing checks threading or recipients | Comment corrected. New `scripts/reply-headers-check.py` checks In-Reply-To, References, Subject and reply-all recipients against the original: version 4 passes 7/7 with 20 of 20 recipients. Negative control: against Greg's separate rc2 announcement it fails four checks |
| `README.md` and `REVIEW-REQUEST.md` still say "Running", "[PENDING]" and "no regressions" | rewritten to the current state |
| Freeze what was sent | `README.md` "Next" item 3: record the commit, the file, the time and the server answer after sending |
| The QCA9377 wording, no reboot, no repository link in the mail | kept as in version 3 |

**The sendable copy (at version 4):** `tmp/co10-20261021/send/reply-6.6.160-rc2-v4.eml`. `mail-lint.sh`
flags only the two quoted lines; `reply-headers-check.py` passes 7/7. The v3 file name now
holds the same text, because it was edited in place before the copy.

## 2026-10-21 02:05 UTC — published addresses restored (the operator)
**The operator's remark:** addresses that upstream has already published are public and must
not be hidden. That has been the rule since 2026-10-13, and it is now written in BRIEF §7.

**This dossier had broken it twice:**
- the sendable reply was kept off the public copy "because it carries mail addresses";
- CO-10 reviewer 3's patchew link was replaced.

**Now:**
- the full sendable mail is public, as `drafts/reply-6.6.160-rc2-v4.eml`;
- the review request links the announcement on lore by its Message-ID;
- reviewer 3's link is back.

**Behind it:** `devtools/repo-scan` now accepts the addresses listed in
`devtools/repo-scan-public-addresses`, and `scripts/review-text-clean.py` no longer replaces
links (`comms/2026-10-21T0204Z-…`).

**Also corrected:** the times of versions 3 and 4 in this log, the draft and the review
headers. They had been written as "02:xx" and "03:xx" before those hours; the commit times
are 01:43 and 01:55 UTC.

## 2026-10-21, committed 02:19 UTC (`757abef`) — the four reviewers recheck version 4; version 5
The rechecks are in `reviews/2026-10-21-recheck-of-v4.md`.

**Verdicts:**
- reviewer 1: send as is;
- reviewer 2: approved, send as v4; the lockdep half-line optional;
- reviewers 3 and 4: one correction before sending.

| point | who | done |
|---|---|---|
| "same verdict" is not literally true: one 6.6.159 run of mesh "Send cancel - 1" Failed where rc2 Timed out | 3, 4 | The mail now says "either pass on both or fail on both" (exact, and shorter than the proposed wordings). The results, README and review request say the same |
| "No kernel warnings, sanitizer or lockdep reports" | 2 (optional) | taken: the configs and the scan cover lockdep |
| The results file still says the mesh cases "are not compared" | 4 | now says the isolated runs below close that gap |
| Approximate times "00:5x", "01:4x" | 4 | replaced by the build's start (00:52:54), the run span (01:02 to 01:36) and the commit time (01:43) |
| Two review headers still say links with addresses are removed | 2 | corrected |
| The scanner: an `@domain` entry passes any address at the domain, and the suffix rule passes `private-<listed address>`; the test's negative case sat on another domain | 2, 3, 4 | **Fixed.** Domain entries only for mailing-list hosts. Persons and Message-IDs are exact tokens, with no suffix matching. The list is rebuilt with exact entries (the whole tree scans clean). The suite now refuses three negatives on the listed person's own domain: a private address, `x-<listed>` and an unlisted Message-ID ending in a listed address. All checked by hand on a scratch repository |
| An app password is not one-time; deleting it locally does not revoke it; never put it in the chat | 3, 4 | README: the operator runs git send-email in their own terminal, git asks for the password there, and the password is revoked in the Google account afterwards; `smtp-login-check.sh` confirms the 535 |
| CI on `ccb46dc` still queued | 2, 3, 4 | GitHub's queue: runs from 00:37 UTC only now finish (`bd2f3cf` green). Not a gate for the mail, whose body and evidence `ccb46dc` did not change |

**The sendable copy:** `drafts/reply-6.6.160-rc2-v5.eml` (development host copy:
`tmp/co10-20261021/send/reply-6.6.160-rc2-v5.eml`). `mail-lint.sh` flags only the two
quoted lines of the announcement (73 columns, kept as written); `reply-headers-check.py`
passes 7/7 with 20 of 20 recipients.

## 2026-10-21, after 02:22 UTC — the four reviewers recheck version 5; version 6
They read the frozen commit `05f5aef`; their text is in `reviews/2026-10-21-recheck-of-v5.md`.

**Verdicts:** all four approve the mail. Reviewers 1, 3 and 4: send version 5 as it stands.
Reviewer 2: approved, with one precision edit, then freeze the mail.

| point | who | done |
|---|---|---|
| "fail on both" can be read as both runs ending Failed; Failed and Timed out are distinct tester verdicts | 2 (recommended), 3 (preferred, not required) | **Version 6:** "No other case that ran on both kernels passes on one and not on the other", the measured property; reviewer 2's preferred form, in plainer words. The only change to the mail; v5.eml is kept. `mail-lint.sh`: the two quoted lines only; `reply-headers-check.py`: 7/7, 20 of 20 recipients |
| Scanner A: the list-host filter is not anchored at "@", so subdomains of a list host pass | 3 | **Not so in our code:** the `@host` lines keep their "@" in the pattern, so it is `(@lists\.linaro\.org)$`; the two addresses reviewer 3 quotes are refused (checked by hand; reviewer 3's test likely left out the "@"). A test now pins it: a subdomain of a listed host and a host that only ends with its name are refused |
| Scanner B: the maintainer's own address is matched as a substring, so "private-<maintainer's address>" passes | 3, 4 | **Fixed.** Exactly the address, or one of the maintainer's own git send-email Message-IDs (`<14-digit date>.<pid>-<n>-<address>`, 15 such in the tree, all of sent patches). Tests: the prefixed address is refused, the Message-ID passes |
| Scanner C: made-up addresses quoted by reviews are allowed everywhere | 2, 3 | **Fixed.** They left `repo-scan-public-addresses` for a new `devtools/repo-scan-quoted-examples`, which pairs each with the file quoting it; the scan lets it through only while no other tracked file contains it. Tests: allowed in its file, refused once another file carries it |
| kernel.org was allowed as a whole domain | 2 | **Fixed.** Its five addresses in the tree are listed exactly (three on the rc2 Cc, the patchwork bot, one Message-ID) |
| The review request links `blob/main`, so a frozen review follows moving files | 4 | Relative links now: they resolve at the commit the reader opened |
| README "tested in full", though l2cap-tester was stopped where it hangs | 3 | Reworded; and "a one-time app password" is now "an app password, revoked after the send" |
| This log: "02:2x UTC" and a sentence on old times joined to the v5 paragraph | 3, 4 | The heading gives the commit time; the sentence is back with the paragraph it belongs to |
| CI still queued | 2, 3, 4 | GitHub's queue. Not a gate for the mail |

## 2026-10-21, 02:50 UTC — the four reviewers recheck version 6; the send command corrected
They read the frozen commit `1eda14a`; their text is in `reviews/2026-10-21-recheck-of-v6.md`.
**All four: send version 6**, with no further revision, test or review round; only the
freshness checks and the operator's word remain.

**The send command was wrong, found by a dry run before any send.** The planned
`git send-email --suppress-cc=all` also suppresses the `cc` category, the addresses on the
file's own `Cc:` lines. `--dry-run` of v6 with it (02:50 UTC): one `RCPT TO`, Greg's. With
`--suppress-cc=self --suppress-cc=body` (02:51 UTC): all 20 `RCPT TO`, the announcement's
`In-Reply-To` and `References`, and nothing added from the body. The README and BRIEF now give
that command. Earlier sends used "all" with explicit `--to`/`--cc`, which was right for them.

**Freshness, 02:51 UTC:** `git ls-remote` linux-stable-rc `refs/heads/linux-6.6.y` →
`c578c158a36845a2b642bd491adaa7e4a479e04f`; `https://www.kernel.org/pub/linux/kernel/v6.x/stable-review/`
lists `6.6.160-rc1` and `6.6.160-rc2` only. To be repeated just before the send.

| point | who | done |
|---|---|---|
| `--all` reads the working tree but looked for a quoted example in the index, so an unstaged copy in another tracked file went unseen | 2 | **Fixed:** the location check searches the tree the content came from (pushed commit, index for staged additions, otherwise the working tree). Test added |
| The public list's header still said kernel.org is allowed | 2 | Corrected |
| The maintainer's address comes from the local `git config user.email` first, so a private address set there would be exempt | 2 | **Backlog** (reviewer 2: not for CO-10): derive it from data the repository controls, or require a public-list entry |
| CI still queued | 2, 3, 4 | GitHub's queue; not a gate for the mail |

## 2026-10-21 03:05:42 UTC — SENT
On the operator's word ("Please send it."), version 6.
- **Freshness, minutes before:** `git ls-remote` linux-stable-rc `refs/heads/linux-6.6.y` →
  `c578c158a36845a2b642bd491adaa7e4a479e04f`; the kernel.org stable-review listing has no
  `6.6.160-rc3` (count 0; `6.6.160-rc2.xz` count 1, the control).
- **The file:** `drafts/reply-6.6.160-rc2-v6.eml` at `8881e10`; `git hash-object` of the file
  sent = the committed blob, `e8ab46352a3c`.
- **The command:** `git send-email --confirm=never --suppress-cc=self --suppress-cc=body` on
  that file, from the development host, with the app password the operator gave for it.
- **The server:** `Result: 250` from smtp.gmail.com; 20 `RCPT TO`, the announcement's 20
  recipients; `In-Reply-To` and `References` `<20261020075535.084584701@linuxfoundation.org>`.
- **Message-ID:** `<20261021030542.1434603-1-yaroslav.voytovych@gmail.com>`,
  `Date: Wed, 21 Oct 2026 05:05:42 +0200`.
- **The password:** in no settings file afterwards (grep). The operator deleted it in the
  Google account; the login-only check (587 tls) then got
  `AUTH LOGIN→334 user→334 pass→535` ("5.7.8 Username and Password not accepted") for it
  (fingerprint `sha256:35ff3945`, first seen 03:05:42 UTC) and for all 11 earlier ones:
  **revoked**.

**Next:** watch the thread and the 6.6.160 release for the `Tested-by`.
