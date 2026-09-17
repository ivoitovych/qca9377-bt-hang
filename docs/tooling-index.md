# Tooling index — which tool answers which question

⚠️ **Read [`BRIEF.md`](../BRIEF.md) first** — it is the concentrated state of
knowledge (what is true, what is **retracted**, what is open) in under 200 lines.
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
| Commit, push and verify the remote matches | **`devtools/save <msgfile>`** (wraps `repo-save`) |
| **What did CI say about a commit?** | `devtools/ci [sha]`, `--wait`, `--recent N` — never a hand-typed `until gh run list … \| grep` loop; that prompted every time and read as "Parse error" |
| Did the BlueZ patch guards fire? | `tools/bt-guards` |
| Publish-safety scan (MACs, BSSIDs, emails) | `devtools/repo-scan` |
| How do the branches diverge? | `devtools/branch-status` (`--unique`, `--files`) |
| Coverage / comprehensiveness | `devtools/coverage`, `devtools/test-comprehension` |
| Do the fixtures still match real journalctl? | `devtools/journal-contract` |

### Deploying to the affected machine

| what | command |
|---|---|
| Deploy files, **arm nothing** | `sudo ./install.sh --tools-only` |
| Deploy and arm everything | `sudo ./install.sh --apply` |

⚠️ Use `--tools-only` on the investigation machine. `--apply` enables
`bt-hang-watchdog`, whose USB reset has three controlled demonstrations of
destroying this controller.

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

**So the fix is never another permission entry. It is a file under `tools/` or
`devtools/`, both of which are already granted — a new script there costs zero
new permissions for ever.**

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
