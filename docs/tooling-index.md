# Tooling index — read this first after a context reset

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
| Is the tree valid, scanned, drift-free, ready to commit? | `devtools/check` |

`bt-snapshot` takes **one** coarse journal cut and derives every fine filter from
it — the expensive step is journal traversal, and it does it once. Its output
directory (`/var/tmp/bt-snapshots/latest/`) holds `all.log`, `kernel.log` and the
`f-*.log` fine cuts; grep those files, never the journal again.

---

## By question

### The live machine

| question | tool |
|---|---|
| Full situation right now | `tools/bt-snapshot` |
| Is there an open untreated HCI window? | `tools/bt-window` |
| Did a daemon crash, was a core kept, what is the stack? | `tools/bt-crash` |
| Controller / service / mode / trial state | `tools/bt-status`, `tools/bt-state` |
| Which boots exist, and when? | `tools/bt-boot-list`, `tools/bt-boots` |

### Evidence

| question | tool |
|---|---|
| Capture a fault that already happened, sanitised | `tools/bt-incident <slug> --since <time>` |
| Turn a finding into a numbered exhibit | `tools/bt-exhibit` (`bt-exhibit index` regenerates the README) |
| Which exhibits can still be re-derived? | `tools/bt-retention` (`--at-risk`) |
| Archive one boot off the rotating journal | `tools/bt-archive <boot-index>` |
| Archive **every** retained boot | `tools/bt-backup-journal` (also on a daily timer) |
| Timing breakdown of an incident | `tools/bt-postmortem` |
| Stage-2 terminator analysis across boots | `tools/bt-stage2` |
| Compare SCO event windows | `tools/bt-sco --window` |
| Redact before sharing anything raw | `tools/sanitize-logs.sh` |

### Repository and gates

| question | tool |
|---|---|
| Validate + scan + drift + install state | `devtools/check` |
| Commit, push and verify the remote matches | `devtools/repo-save <dir> -F <msgfile>` |
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

The permission matcher cannot analyse compound shell, so such a command matches
no allow rule and prompts **every time**. Keep calls simple:

- one command per call; no `&&`, `;`, `$(...)`, loops, or variable assignment
- need several steps? put them in a script and invoke it by path
- **never** `git commit -m "<long message>"` — a body line starting with `#`
  (a stack frame `#0 …`, an issue ref) makes the call permanently ungrantable.
  Write the message to a file with the Write tool, then
  `devtools/repo-save . -F <file>`
- use `git -C <dir> …`, never `cd <dir> && git …`

## Communication

`comms/` is the written channel between maintainers — see
[`comms/README.md`](../comms/README.md). Reply with a **new file**, never by
editing someone else's: `comms/<UTC>-from-<sender>-to-<recipient>.md`.
