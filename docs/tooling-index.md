# Tooling index — which tool answers which question

⚠️ **Read [`BRIEF.md`](../BRIEF.md) first** — it is the concentrated state of
knowledge (what is true, what is **retracted**, what is open, and the rules that were
paid for with their reasons) in under 500 lines.
This file is the layer below it: once you know *what* you are asking, this says
*which tool* asks it.


**Purpose.** Every routine question in this project already has a tool. Hand-typing
the pipeline instead is slower, costs a permission prompt, and has repeatedly been
*wrong* in ways the tool is not — a `tail -4` that hid the answer, a `grep -c`
that emitted two zeros, a timeout pattern that matched 8 of 173 events.

**One rule:** before assembling a shell pipeline, look here for the tool that
already does it. If none exists and the question recurs, write one.

---

## The three commands that answer almost everything

| question | command |
|---|---|
| What is happening on this machine right now? | `tools/bt-snapshot` |
| Is the repository committed, pushed, deployed, in sync? | `devtools/status` |
| **Commit and push everything** | `devtools/save <message-file>` — stages, indexes, validates, scans, pushes, verifies |
| Is the tree valid, scanned, drift-free, ready to commit? | `devtools/check` |

`bt-snapshot` takes **one** coarse journal cut and derives every fine filter from
it — the expensive step is journal traversal, and it does it once. Its output
directory (`/var/tmp/bt-snapshots/latest/`) holds `all.log`, `kernel.log` and the
`f-*.log` fine cuts; grep those files, never the journal again.

⚠️ **`bt-backup-journal` tests for a FILE, which is not the same as a backup.**
An archive taken while its boot was still being written is a prefix, and it
then reads as "already archived" for ever. Nine of twenty-one archives were
prefixes on 2026-08-31 — one holding 1.5% of its boot, another stopping 2.5 h
before the fault `EX-035` and `EX-036` rest on. `bt-archive --check` is the only
thing that tells present from complete; run it after any batch of archiving.

⚠️ **Read the BlueZ health block, not only the controller counts.** Every count
above it is about the QCA9377, and `EX-032` is the failure mode where the
controller is perfectly healthy and Bluetooth is dead anyway — a BlueZ crash
leaving the adapter powered and permanently non-scanning. Those four values are
taken **from the journal**, so they are the daemon's last logged state and not a
live read; that is deliberate, because this tool is run inside untreated windows
and must not talk to the adapter. They read `UNKNOWN` on a machine that does not
run `bluetoothd -d` — this project ships that on in
`etc/systemd/bluetooth.service.d/10-debug.conf`.

---

## By question

### The live machine

| question | tool |
|---|---|
| Full situation right now | `tools/bt-snapshot` |
| Is there an open untreated HCI window? | `tools/bt-window` |
| **What happened around the fault?** | `tools/bt-fault-window` (sequence + alt-1 counts + interval) |
| What USB state is the wedged controller in? | `tools/bt-usbstate` (alt setting, endpoint size) |
| Did a daemon crash, was a core kept, what is the stack? | `tools/bt-crash` |
| Controller / service / mode / trial state | `tools/bt-status`, `tools/bt-state` — **probe-free by default**; `--probe` sends an HCI command and is an intervention (never inside an open window) |
| Which boots exist, and when? | `tools/bt-boot-list`, `tools/bt-boots` |

### Evidence

| question | tool |
|---|---|
| Capture a fault that already happened, sanitised | `tools/bt-incident <slug> --since <time>` |
| Turn a finding into a numbered exhibit | `tools/bt-exhibit` (`bt-exhibit index` regenerates the README) |
| Which exhibits can still be re-derived? | `tools/bt-retention` (`--at-risk`) |
| Archive one boot off the rotating journal | `tools/bt-archive <boot-index>` |
| Archive **every** retained boot | `tools/bt-backup-journal` (also on a daily timer) |
| Is every archive **complete**, or only present? | `tools/bt-archive --check` (`--repair` fixes them) |
| Timing breakdown of an incident | `tools/bt-postmortem` |
| Stage-2 terminator analysis across boots | `tools/bt-stage2` |
| Compare SCO event windows | `tools/bt-sco --window` |
| Redact before sharing anything raw | `tools/sanitize-logs.sh` |

### Repository and gates

| question | tool |
|---|---|
| Validate + scan + drift + install state | `devtools/check` |
| Commit, push and verify the remote matches | **`devtools/save <msgfile>`** (wraps `repo-save`: validates, scans content and message, refuses an AI author/committer identity, verifies the remote). **On a `kernel/*` branch it pushes to the `private` remote, never `origin`**, and refuses if no `private` remote exists (`scripts/prove-held-branch-guard.sh`) |
| **The held `kernel/*` branch**: where it stands, merge main into it, commit on it, push it — without git chains | `devtools/held status \| sync \| commit <msgfile> \| edit` — always returns to `main`; pushes only to `private`; regenerates the exhibit index when the merge conflicts there |
| **What did CI say about a commit?** | `devtools/ci [sha]`, `--wait`, `--recent N` — never a hand-typed `until gh run list … \| grep` loop; that prompted every time and read as "Parse error" |
| Did a **green** run hide anything (a missing tool, a swallowed error)? | `scripts/ci-log-search.sh <sha\|run-id> "<pattern>"` — the full log, not the failed step; found `rg: command not found` ×3 in a green run on 2026-09-20 |
| **Is a BlueZ CI-bot failure ours?** | `scripts/patchwork-checks.sh --failed-functional N` — which functional tests failed on the N most recent bluetooth patches, from the bot's own patchwork comments; `--patch ID` for one patch's check states. Settled the 09-19 `TestFunctional` failure in one run (12 unrelated patches, same two tests). `lore` blocks `curl`; patchwork's API does not |
| **How does BlueZ actually treat bot failures?** (accepted series' check states, respins, commenters) | `scripts/bluez-accepted-survey.py [PAGES]` → cached under `tmp/patchwork/survey/`; then `scripts/bluez-human-ci-mentions.py` for what humans said about the CI; `scripts/git-log-tab-count.sh <tree> [N] [--list]` for tabs / long lines that landed in the tree |
| **How does the kernel Bluetooth tree treat bot failures, and what do maintainers say?** | `scripts/kernel-bt-survey.py [PAGES]` — kernel series on patchwork: states, check states, commenters, aggregates, every human rule-related comment quoted |
| Lint a patch's commit message the way the BlueZ bot does | `scripts/gitlint-check.sh <bluez-tree> <patch>…` — gitlint in a `cache/` venv, BlueZ's `.gitlint`; reproduces the bot's B3 count on v1 |
| Derive the BlueZ v2 patches from v1 (tabs → spaces, two wrapped lines, changelog) | `scripts/build-v2.sh` → `patches/bluez/v2/`; then `BT_PATCH_DIR=patches/bluez/v2` in front of `checkpatch-check.sh`, `git-am-check.sh`, `scripts/build-mails.sh` |
| **Before mailing any patch: is it already upstream, and does it apply to today's master?** | `scripts/pre-send-check.sh <tree> <patch>…` — fetches `origin`, greps the subject in the log, apply-checks against `origin/master`; says `DO NOT SEND`. Written after both BlueZ v2 mails went out 6.5 h after v1 had been applied |
| Is a used app password really revoked? | `BT_SMTP_PASS='…' scripts/smtp-login-check.sh` — login only, sends nothing; `REVOKED 535` / `ALIVE` / `INCONCLUSIVE` (a dropped connection is never read as revoked) |
| Read a saved Gmail message (HTML) as greppable text | `scripts/mail-html-to-text.sh <saved.html>` → `tmp/<name>.txt` — how the bot's backtraces were read |
| **Why is CI red?** | `devtools/ci --failed [sha]` — prints the failing invariants and any stale coverage exclusion with the lines it hid; a red `--wait` does this automatically. Never `gh run view … --log-failed \| grep`: that prompted three times on 2026-09-19/20 and blocked an unattended session for an hour |
| Did the BlueZ patch guards fire? | `tools/bt-guards` |
| Publish-safety scan (MACs, BSSIDs, emails) | `devtools/repo-scan` |
| **Which review findings are still open, across every register?** | `devtools/review-open` (`--all`, `--counts`) — reads the status column of `reviews/README.md`; the gate before anything is submitted |
| Compile-test a kernel patch against the running kernel (no tree needed) | `scripts/build-bluetooth-module.sh [patch]` — `net/bluetooth` from `cache/linux` (or `BT_KSRC=<checkout>`) against `/lib/modules/$(uname -r)/build`; builds only, never installs |
| **Run a kernel Bluetooth patch on this machine** (module swap, stock daemon, mgmt-channel capture) | `scripts/runtime-mgmt-test.sh status \| stock-daemon \| load unpatched\|patched \| trigger <label> \| restore \| patched-daemon` — refuses while `bt-window` or a trial is open; modules in `tmp/runtime/` from `BT_KSRC=cache/ubuntu-7.0.0-31 scripts/build-bluetooth-module.sh` (Ubuntu's source for the running kernel, not vanilla) |
| **Kernel submission checklist on the patch commit** (checkpatch `--strict` with Fixes resolved, `W=1 -Werror`, sparse new-vs-base) | `BT_SPARSE=cache/sparse/sparse scripts/kernel-preflight.sh cache/full-bt-next` — HEAD must be the patch commit (`git am` it first). ⚠️ Ubuntu's sparse 0.6.4 is too old for 7.x: the kernel silently skips `C=1`; the script refuses without a `CHECK … mgmt.c` line. Current sparse is built in `cache/sparse` |
| **Regenerate the kernel mail on a tree's tip** (new base, optionally a new message) | `scripts/build-bluetooth-fulltree.sh <ref> <name> <patch>` to prepare `cache/<name>`, then `scripts/kernel-regenerate.sh cache/<name> <patch> [<message-file>]` — `git am` + amend + `format-patch --base`; fails unless the patch-id is unchanged; leaves HEAD at the patch commit for `kernel-preflight.sh`; output in `tmp/kernel-regenerated/` |
| **Every management reply in the captures** (command, Complete vs Status, status byte, per-file totals) | `scripts/mgmt-replies.sh <capture.btsnoop>…` — `BT_MGMT_KIND=STATUS`, `BT_MGMT_ONLY=<regex>`. Reads btmon's decoded form AND the undecoded `@ Control Event` records it prints in rotated capture files (the first version read those as "no replies"). Cross-check `capture/` against `trace/` — two independent recorders |
| **Put a self-built `bluetooth.ko` in front of the stock one for the next boot, or remove it** | `scripts/module-updates.sh status \| install <module.ko> \| remove` — checks CRCs against every dependant first, `depmod`, reports whether the initramfs matters; never loads anything live (`EX-046`) |
| Before replacing a module via `updates/`: will every installed dependant accept it? | `scripts/check-modversions.sh <Module.symvers> <module.ko[.zst]>…` — compares expected vs exported symbol CRCs |
| Change a format-patch's message without touching its diff | `scripts/patch-replace-message.sh <patch> <msgfile>` — refuses a file with no `---` or no diff |
| **Does a kernel patch build at another tree's tip — the real check** | `scripts/build-bluetooth-fulltree.sh <ref> <name> <patch>` — full worktree under `cache/<name>` (blobs on demand), `defconfig` + BT as module, `modules_prepare`, `make M=net/bluetooth` unpatched then patched with `-Werror`; needs `bison flex libelf-dev` (installed 2026-09-22). Worktrees `cache/full-bt-next`, `cache/full-6.1.y` exist; ~5 min each after the first checkout |
| Does a one-file kernel patch compile at **another** tree's tip (quick, no full tree) | `scripts/compile-mgmt-at.sh <sparse-worktree> <patch>` — that tree's `include/` first, `-Werror`, unpatched then patched. Whole-module builds across kernel versions need a full tree with `modules_prepare` (packages this host lacks); worktrees under `cache/linux-bt-next`, `cache/linux-6.1.y`, `cache/linux-6.12.y` |
| How do the branches diverge? | `devtools/branch-status` (`--unique`, `--files`) |
| Coverage / comprehensiveness | `devtools/coverage`, `devtools/test-comprehension` |
| Do the fixtures still match real journalctl? | `devtools/journal-contract` |

### Deploying to the affected machine

| what | command |
|---|---|
| Prove the BlueZ patches apply the way a maintainer applies them (`git am` alone/together/either order, BlueZ format rules) | `patches/bluez/git-am-check.sh <bluez-checkout> [<commit>]` |
| Deploy files, **arm nothing** | `sudo ./install.sh --tools-only` |
| Deploy and arm everything | `sudo ./install.sh --apply` |

⚠️ Use `--tools-only` on the investigation machine. `--apply` enables
`bt-hang-watchdog`, whose USB reset has three controlled demonstrations of driving
an already-wedged controller off the USB bus until power is removed.

---

## Writing commands so they do not prompt

⚠️ **Let journald do the filtering, or the scan is both too slow AND too narrow.**
`journalctl --since … | grep X` over this machine's journal walks ~19 days of
dynamic-debug output and does **not finish in ten minutes**. The same question
with `journalctl _COMM=bluetoothd --since … | grep X` answers in **thirty
seconds**, because journald selects on the indexed field instead of streaming
every record. On 2026-09-13 the slow form was abandoned and replaced by a grep
over one boot — which reported "the patch guard never fired" when it had fired
four times (`EX-041`). The too-slow scan and the false conclusion were the same
mistake.

⚠️ **The allowlist is not the bottleneck, and measuring this settled it.** On
2026-09-13 the operator asked for fewer permission prompts. **364 entries were
already granted**, `journalctl *` and `tools/*` among them. A tally of 3,584
Bash calls across this project's transcripts found **2,344 — 65% — containing a
pipe, `&&`, `$(...)` or a redirect**, and the matcher cannot analyse compound
shell, so every one of those prompts *however broad the allowlist is*. 226 were
the same question, now answered by `bt-fault-window` in one call.

**So the fix is never another permission entry. It is a file under `tools/`,
`devtools/` or `scripts/`, all of which are granted — a new script there costs
zero new permissions for ever.** `scripts/` (added 2026-09-19, see its README) is
for helpers and proofs that are not yet tools; their outputs go to `tmp/`
(ignored) and third-party sources to `cache/` (ignored). Neither the session's
`/tmp` scratchpad nor an inline pipeline: the first vanished with a reboot, the
second prompts every time and can leave an unattended session stuck for hours.

The permission matcher cannot analyse compound shell, so such a command matches
no allow rule and prompts **every time**. Keep calls simple:

- one command per call; no `&&`, `;`, `$(...)`, loops, or variable assignment
- need several steps? put them in a script and invoke it by path
- **no redirects and no trailing `| tail -N`** — if output needs trimming, the
  script should trim it. A pipe added for tidiness costs a prompt every run.
- ⚠️ **check whether the tool already does the step you are prefixing.**
  `git add -A; devtools/repo-save …` was typed for weeks; `repo-save` stages
  first thing on its own. The redundant `git add` is what dragged `git` into the
  command and tripped the *cd-before-git* rule on top of everything else.
- **never** `git commit -m "<long message>"` — a body line starting with `#`
  (a stack frame `#0 …`, an issue ref) makes the call permanently ungrantable.
  Write the message to a file with the Write tool, then
  `devtools/repo-save . -F <file>`
- use `git -C <dir> …`, never `cd <dir> && git …`

## Communication

`comms/` is the written channel between maintainers — see
[`comms/README.md`](../comms/README.md). Reply with a **new file**, never by
editing someone else's: `comms/<UTC>-from-<sender>-to-<recipient>.md`.
