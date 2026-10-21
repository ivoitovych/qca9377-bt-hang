# Tooling index — which tool answers which question

⚠️ **Read [`BRIEF.md`](../BRIEF.md) first** — it is the concentrated state of
knowledge (what is true, what is **retracted**, what is open, and the rules that were
paid for with their reasons) in under 1000 lines.
This file is the layer below it: once you know *what* you are asking, this says
*which tool* asks it.
A first-time reader should start with [`README.md`](../README.md) and
[`docs/STATUS.md`](STATUS.md); `BRIEF.md` is the maintainers' hand-off.


**Purpose.** Every routine question in this project already has a tool. Hand-typing
the pipeline instead is slower and has repeatedly been
*wrong* in ways the tool is not — a `tail -4` that hid the answer, a `grep -c`
that emitted two zeros, a timeout pattern that matched 8 of 173 events.

**One rule:** before assembling a shell pipeline, look here for the tool that
already does it. If none exists and the question recurs, write one.

---

## The four commands that answer almost everything

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
| **Search the archived boots' journals** (boots the system journal no longer holds) | `scripts/journal-archive-grep.py '<regex>' ~/bt-journal-archive/boot-*.export.zst` — streams each export, prints matching `MESSAGE=` lines with local time and a count per boot; skips `.partial`. Answered 2026-10-11 that the suite never reset USB device 99 (44 bus-3 resets found, none of 99). ⚠️ A boot is archived only when it ends, and journald (`SystemKeepFree=20G`) can discard a long boot's start before then |
| Timing breakdown of an incident | `tools/bt-postmortem` |
| Stage-2 terminator analysis across boots | `tools/bt-stage2` |
| Compare SCO event windows | `tools/bt-sco --window` |
| Redact before sharing anything raw | `tools/sanitize-logs.sh` |
| **Keep every raw HCI capture before rotation deletes it** | `scripts/bt-trace-archive.py`: closed captures from `/var/log/bt-health/trace/` and `/root/bt-trace-keep/` → `archive/bt-trace/*.zst` (git-ignored), each verified by SHA-256 after decompression, rows in `MANIFEST.tsv`; never deletes; 10 GB budget (warns at 80 %, stops at 100 %). Runs on the transient timer `bt-trace-archive.timer`, which a reboot removes (gone since the 2026-10-13 reboot; restarting it is the operator's decision). Proof: `scripts/prove-bt-trace-archive.py` (14 checks, a corrupting compressor among them). Read an archived capture with `zstd -dc <file>.zst` into `tmp/` |
| **Is an A2DP stream carrying sound or encoded silence?** (per second or bucket: SBC configuration, frames, frames with signal, largest scale factor) | `scripts/sbc-frame-levels.py [--from T] [--to T] [--bucket N] <capture.btsnoop>…`; outgoing ACL (monitor opcode 4); prints "no SBC media frames" and exits 1 when nothing matched. `U10` was read this way |
| **Does a capture carry key material?** (link key replies and notifications, LE encryption, SMP) | `scripts/hci-key-records.py <capture.btsnoop>…` — counts and first time per kind, **never the key bytes**. The T8 reconnect of 2026-10-11 00:34:29 carries a Link Key Request Reply: a raw capture is not publishable by address substitution alone |
| **Publish a log or capture with consistent device addresses** | `addr-pseudonym.py`, kept privately with the table (never in this checkout): `check` (real or unlisted addresses, every form, both byte orders, raw bytes) and `apply` (a substituted copy; the manufacturer prefix is kept for public addresses, the type bits for random ones). The table and the rules are kept with it |

### Desktop audio and UI capture (U1–U11)

| question | tool |
|---|---|
| **Instrument a manual audio test session** — who asked for each profile/volume/default change, what WirePlumber and PipeWire's Bluetooth backend decided, what GNOME Settings decided and drew | `sudo tools/bt-ui-capture plan` (default; changes nothing) → `start` (live: PipeWire daemon log level, `sco.c` connect/teardown debug, AT-SPI recorder, system/session bus monitors, GNOME Settings launchers with `G_MESSAGES_DEBUG`, the recorder if absent, a `bt-mark`) → `stop` (restores what `start` recorded). `stage-restart` / `unstage` for what needs a restart (pipewire-pulse requests, WirePlumber debug; effective at the next login, nothing restarted). `status`, `collect [--since T] [--until T]` (journal cut, monitor files, the HCI captures covering the window, sanitised copies). How to run a session and read it: [`ui-capture.md`](ui-capture.md); why each knob: [`ui-capture-research.md`](ui-capture-research.md) |
| What does GNOME Settings' UI do, as events? | `scripts/bt-ui-atspi.py --address <a11y bus>` — passive (match rules only, no AT-SPI registry listener; GTK 4.14 emits regardless); run by `bt-ui-capture` as unit `bt-ui-atspi` |
| Prove `bt-ui-capture` without a session (while a trial is open) | `scripts/prove-ui-capture.sh [tool]` — stubs on PATH, seams into `tmp/`, a private dbus-daemon for the AT-SPI path; 67 checks. Pass a modified copy to watch a check go red |
| Debug-only patches for decisions nothing logs | `docs/ui-capture-patches/` — GNOME Settings 46.7 sound panel (U4, U1, U6), btusb SCO fragment drop (U8); plans in `ui-capture-research.md` §Task 4; nothing built |

### Repository and gates

| question | tool |
|---|---|
| Validate + scan + drift + install state | `devtools/check` |
| Commit, push and verify the remote matches | **`devtools/save <msgfile>`** (wraps `repo-save`: validates, scans content and message, refuses a tool author/committer identity, verifies the remote). **On a `kernel/*`, `plan/*`, `diag/*`, `review/*`, `attribution/*`, `postponed/*` or `config/*` branch it pushes to the `private` remote, never `origin`**, and refuses if no `private` remote exists (`scripts/prove-held-branch-guard.sh`) |
| **The held `kernel/*` branch**: where it stands, merge main into it, commit on it, push it — without git chains | `devtools/held status \| sync \| commit <msgfile> \| edit` — returns to `main`, except `edit` (stays on the held branch on purpose) and a `sync` that stops on a conflict (on the held branch, mid-merge, naming the file); pushes only to `private`; regenerates the exhibit index when the merge conflicts there |
| **What did CI say about a commit?** | `devtools/ci [sha]`, `--wait`, `--recent N` — the verdict is `checks.yml`'s run; the access audit, a workflow of its own, is shown on a line of its own. Never a hand-typed `until gh run list … \| grep` loop; it read as "Parse error" |
| Did a **green** run hide anything (a missing tool, a swallowed error)? | `scripts/ci-log-search.sh <sha\|run-id> "<pattern>"` — the full log, not the failed step; found `rg: command not found` ×3 in a green run on 2026-09-20 |
| **Is a BlueZ CI-bot failure ours?** | `scripts/patchwork-checks.sh --failed-functional N` — which functional tests failed on the N most recent bluetooth patches, from the bot's own patchwork comments; `--patch ID` for one patch's check states; **`--rate CONTEXT [N] [BEFORE]`** — one check's fail/success count over the N most recent patches carrying it (e.g. `TestRunner_mesh-tester`: 20 of 20 kernel patches 09-19 → 09-27 fail, ours among them). Settled the 09-19 `TestFunctional` failure in one run (12 unrelated patches, same two tests), and A2's of 10-18 (`pair_bredr` fails alone on 7 patches in 10 days). Its matcher reads both forms of the bot's FAIL line since 2026-10-18; before, it missed the newer `RemoteError` form and under-counted. lore answered a plain `curl` user agent with Atom feeds on 2026-10-18 (it had refused fetchers) |
| **Did a kernel change any BlueZ tester verdict?** (two test-runner logs of the same tester, e.g. a release candidate and its base) | `python3 -I scripts/compare-tester-verdicts.py <log A> <log B>` — totals per verdict, every case whose verdict differs, and whether the not-passed sets are identical. CO-10 used it on 6.6.159 against 6.6.160-rc2 |
| **Keep an outside reviewer's text in `reviews/` without its tooling marks or mail addresses** | `python3 -I scripts/review-text-clean.py <in.md> <out.md> [<header.md>]`. It removes citation markers (including the private-use-character form), `utm_source` parameters, favicon lines with their site labels and `&#x20;`, and replaces links that carry a mail address. It prints a count per kind, writes the header first, and refuses to overwrite. Diff the result against the input before committing |
| **Everything about one possible contribution** (findings, experiments, log, references, drafts) | `contributions/<CO-nn>-<slug>/`: `README.md` (state, next step, who decides), `log.md` (append-only), `refs.md`, `experiments/`; the index is `contributions/README.md`. Raw recordings stay in the git-ignored archive and are named there by path |
| **Is a watched patch still `new`, or applied?** | `python3 -I scripts/patchwork-state.py ID [ID…]` — one line per patch: state, date posted, submitter, comment count (bots included), the commit patchwork recorded when it was applied, subject; raw JSON in `tmp/patchwork/patch-<id>.json`, comments included. Replaces the by-hand "still `new`, no reply" round (A1 and A2 found `accepted` this way, 2026-10-20). A patch's identity with what was sent: `git format-patch -1 <commit> -o <dir>`, then `git patch-id --stable < <file>` on both |
| **Run the BlueZ CI bot's checks here, before sending, and tell our findings from upstream's** | `scripts/ci-local.sh [--fetch] <patch>…` — the bot's own recipes (read from `bluez/action-ci`, pinned in `results/ci-local-2026-10-10.md` §T1): pre-ci_am, CheckPatch, GitLint (the bot's gitlint file, title limit 80, not BlueZ's `.gitlint`), BuildEll, BluezMake, bluezmakeextell, CheckSmatch, IncrementalBuild, ScanBuild; each build check runs on master and on master plus the series and every finding comes back **PASS / NEW / PRE-EXISTING / FIXED** (line numbers ignored in the comparison, so a moved warning is not a new one); exit 1 only on NEW. `--functional --kernel-image <bzImage>` adds TestFunctional (VMs; TCG without `/dev/kvm`). `--kernel` for a kernel patch: pre-ci_am against bluetooth-next or, for an `[x.y.y]` backport, against the newest tag of that line with the bluetooth-next result reported as EXPECTED; CheckPatch, VerifyFixes (`--stable-full` for a backport's ancestry), VerifySignedoff, GitLint, SubjectPrefix; `--build` adds BuildKernel, W=1, C=1. The base side is cached per master commit under `tmp/ci-local/base-cache/`. Third-party trees and tools under `cache/` (bluez, ell, smatch, sparse, action-ci, checkpatch, bluetooth-next-full); the results file says how each was fetched |
| Prove `ci-local.sh` can see a defect (the positive controls) | `scripts/ci-local-controls.sh` — writes two scratch patches from master (a checkpatch ERROR; a used VLA) and requires CheckPatch NEW and CheckSmatch NEW with `btdev.c:479` still PRE-EXISTING; run it after changing the script. Once A2 (`emulator: Avoid variable length array in send_cmd`, sent 2026-10-18) is applied, master has no `btdev.c:479` warning and control 2 must name another pre-existing one |
| Keep a run's readable output in the repository | `scripts/ci-local-publish.sh <run-dir> <dest>` — copies summaries, classifications, findings and failed-step logs from `tmp/` into a tracked directory with every address but the author's and the lists' elided (`results/ci-local-2026-10-10/` is one) |
| **Does a BlueZ patch change any emulator-tester verdict?** (the kernel bot's TestRunner, locally) | `scripts/bluez-tester-compare.sh --kernel <bzImage> [--testers L] [--runs N] <patch>…` — ASan build as the bot's TestRunnerSetup, `tools/test-runner` in QEMU on master and on master plus the patches, verdicts compared **by case name**; `--runs N` shows flakiness. The bzImage: bluetooth-next with BlueZ's `doc/tester.config` (`cache/bluetooth-next/arch/x86/boot/bzImage`, built 2026-10-10 in the build container and not kept on this machine; the 2026-10-18 re-test used `tmp/mesh-tester-ci/bzImage-val-btnext-control`, of 2026-10-05) |
| **Is a functional test flaky, and does our series change its rate?** | `scripts/functional-repeat.sh --kernel <bzImage> -k <test> --runs N [<patch>…]` — `test/test-functional` (pytest-bluezenv, the harness venv in `cache/bluezenv-venv`, which existed in the build container only) N times on master and N times with the patches, "K failures in N runs" per side. **Untested**: needs a host kernel with the `AF_ALG` interface (the host-side `btvirt` creates no LE-capable controller without it) and `/dev/kvm` for the bot's timings; the build container's kernel had neither, the harness never got past VM setup there, and the script has not completed one run (`results/ci-local-2026-10-10.md`, §T3 and "State at hand-off") |
| **How does BlueZ actually treat bot failures?** (accepted series' check states, respins, commenters) | `scripts/bluez-accepted-survey.py [PAGES]` → cached under `tmp/patchwork/survey/`; then `scripts/bluez-human-ci-mentions.py` for what humans said about the CI; `scripts/git-log-tab-count.sh <tree> [N] [--list]` for tabs / long lines that landed in the tree |
| **How does the kernel Bluetooth tree treat bot failures, and what do maintainers say?** | `scripts/kernel-bt-survey.py [PAGES]` — kernel series on patchwork: states, check states, commenters, aggregates, every human rule-related comment quoted |
| Lint a patch's commit message the way the BlueZ bot does | `scripts/gitlint-check.sh <bluez-tree> <patch>…` — gitlint in a `cache/` venv, BlueZ's `.gitlint`; reproduces the bot's B3 count on v1 |
| Derive the BlueZ v2 patches from v1 (tabs → spaces, two wrapped lines, changelog) | `scripts/build-v2.sh` → `patches/bluez/v2/`; then `BT_PATCH_DIR=patches/bluez/v2` in front of `checkpatch-check.sh`, `git-am-check.sh`, `scripts/build-mails.sh` |
| **Before mailing any patch: is it already upstream, and does it apply to today's master?** | `scripts/pre-send-check.sh <tree> <patch>…` — fetches `origin`, greps the subject in the log (a folded `Subject:` is unfolded), apply-checks the files **in the order given, as a series** against `origin/master`; says `OK to send` or `DO NOT SEND`. An applicability check only — lint and tests are separate. Written after both BlueZ v2 mails went out 6.5 h after v1 had been applied; on 2026-10-07 the maintainer applied the a2dp v2 on top of its v1 anyway, which is why a lint-only respin is never sent |
| Is a used app password really revoked? | `BT_SMTP_PASS='…' scripts/smtp-login-check.sh 587 tls` — login only, sends nothing; `REVOKED 535` / `ALIVE` / `INCONCLUSIVE` (a dropped connection is never read as revoked). Without arguments it uses the config's 465, where Gmail closed every check mid-AUTH on 2026-10-08; 587 answered. On 2026-10-18 it was the other way round: 587 timed out from this machine and 465 answered a clean 535, so use whichever port connects; only a 535 or a 235 is a verdict |
| Read a saved Gmail message (HTML) as greppable text | `scripts/mail-html-to-text.sh <saved.html>` → `tmp/<name>.txt` — how the bot's backtraces were read |
| **Why is CI red?** | `devtools/ci --failed [sha]` — prints the failing invariants and any stale coverage exclusion with the lines it hid; a red `--wait` does this automatically |
| Did the BlueZ patch guards fire? | `tools/bt-guards` |
| What did the **kernel** say on the management channel in a window of a capture? | `tools/bt-ctrl-window <btsnoop> <from> <to> [--hci]` — decodes the records `btmon` prints as `Control Event: 0xffff`, drops every address-bearing line (`EX-044`) |
| Publish-safety scan (MACs, BSSIDs, emails) | `devtools/repo-scan` |
| Commit ids the documents place on `main` are on main (run by `repo-validate`) | `devtools/doc-main-hashes` |
| **Which review findings are still open, across every register?** | `devtools/review-open` (`--all`, `--counts`) — reads the status column of `reviews/README.md`; the gate before anything is submitted |
| Compile-test a kernel patch against the running kernel (no tree needed) | `scripts/build-bluetooth-module.sh [patch]` — `net/bluetooth` from `cache/linux` (or `BT_KSRC=<checkout>`) against `/lib/modules/$(uname -r)/build`; builds only, never installs |
| ~~Run a kernel Bluetooth patch on this machine by a live module swap~~ **Retired; never run `load` or `restore`.** | `scripts/runtime-mgmt-test.sh` is kept for the record of 2026-09-23 only. Its first live `btusb` re-probe wedged a healthy controller (`EX-046`), and BRIEF §0 forbids any live unload, reload or swap. A self-built module goes in front of stock through `updates/` and a cold boot: `scripts/module-updates.sh` (below). The patch it was written for, BT-8's `86ef0f58bdec`, is in mainline |
| **Kernel submission checklist on the patch commit** (checkpatch `--strict` with Fixes resolved, `W=1 -Werror`, sparse new-vs-base) | `BT_SPARSE=cache/sparse/sparse scripts/kernel-preflight.sh cache/full-bt-next` — HEAD must be the patch commit (`git am` it first). ⚠️ Ubuntu's sparse 0.6.4 is too old for 7.x: the kernel silently skips `C=1`; the script refuses without a `CHECK … mgmt.c` line. Current sparse is built in `cache/sparse` |
| **Regenerate the kernel mail on a tree's tip** (new base, optionally a new message) | `scripts/build-bluetooth-fulltree.sh <ref> <name> <patch>` to prepare `cache/<name>`, then `scripts/kernel-regenerate.sh cache/<name> <patch> [<message-file>]` — `git am` + amend + `format-patch --base`; fails unless the patch-id is unchanged; leaves HEAD at the patch commit for `kernel-preflight.sh`; output in `tmp/kernel-regenerated/` |
| **Ubuntu's own Bluetooth source for a new kernel release** | `scripts/prepare-ubuntu-ksrc.sh <package-version>` (e.g. `7.0.0-34.34~24.04.1`) → `cache/ubuntu-<abi>`: sparse worktree at `v7.0` + the `linux-hwe-7.0` diff for the Bluetooth paths; refuses a diff that does not match its `.dsc` SHA-256 (the `.dsc` signature is not checked). Fetch the `.dsc`/`.diff.gz` first from `archive.ubuntu.com/ubuntu/pool/main/l/linux-hwe-7.0/` into `cache/ubuntu-src/` |
| **Build a diagnostic `btusb.ko` for the running kernel** (or, with `--krel <release>`, for an installed kernel not yet booted) | `scripts/build-btusb-module.sh --ksrc cache/ubuntu-<abi> [--krel <release>] [<patch>]` → `tmp/btusb-build/` (wiped each run: copy a build you keep): compiles btusb.c alone against `/lib/modules/<release>/build`, prints version/srcversion/vermagic/sha256. ⚠️ Not bit-identical to stock even unpatched (four helpers inlined differently, same source and headers) — compare behaviour, not bytes |
| **Does a btusb module (stock, new kernel, or self-built) carry the QCA9377 entry?** | `scripts/btusb-has-device.py <btusb.ko[.zst]> [vid pid]` — searches the binary for the `USB_DEVICE()` table bytes (default 13d3:3503); `FOUND`/`ABSENT`, exit 0/1. `modules.alias` cannot answer this: the quirks table is not exported. Control: `0cf3 e300` is in stock |
| **Copy a tree into the project (a worktree, a private branch's folder)** | `scripts/copy-tree.sh <src> <dst>` — `cp -a`; the destination must be inside the project and must not exist (never overwrites an earlier state); the source is in the project or `/usr`. Replaces `cp -r`, which always asks for approval |
| **Stop a QEMU guest, build or test run this project started** | `scripts/stop-own-process.sh <pid>...` — TERM only if the command line names the project directory; refuses bluetoothd, PipeWire, WirePlumber, obexd, btmon and anything else |
| **Put a self-built `bluetooth.ko` or `btusb.ko` in front of stock for the next boot** | `scripts/module-updates.sh [--krel <release>] [--module bluetooth\|btusb] status\|install <ko>\|remove` (`--krel`: an installed kernel that is not running) — `updates/` + `depmod`, takes effect at the next **cold** boot; never loads anything live (`EX-046`) |
| **Every SCO link of a boot and how its first command fared** (the E1 count per headset) | `scripts/sco-ledger.sh [<boot index or id>]` — per link: headset name (bluetoothd's store; never the address), air mode, alt-1 27-byte buffers, seconds streamed, `hangup-ok <ms>` / `TIMEOUT <opcode>` / `open`; totals. Positive control: the stock EX-053 boot reads `TIMEOUT 0x0406` after 7.33 s, 2432 buffers |
| **Does a mainline commit cherry-pick AND build on each stable line?** (the check a backport request rests on: `git cherry-pick` is what the stable pickup is — not `patch --dry-run`, not `patch -p1` with fuzz) | `scripts/build-btusb-stable-matrix.sh <commit> [<branch>…]` — fetches `stable`, resets each full worktree (`cache/stable-<ver>/`) to the fresh tip, `make M=drivers/bluetooth` unpatched (control) then `git cherry-pick --no-commit <commit>` and the build again, `-Werror` where the tree takes it; one row per line (tip, OK/CONFLICT, entry present, both builds); logs `tmp/btusb-matrix/`. `EX-059` is one run. ~1.5 GB per line |
| **Does a patch SERIES apply cumulatively to each stable branch?** (dry run; a later patch may need context an earlier one added) | `scripts/series-backport-check.sh <branch>[,<branch>…] <patch>…` — files copied per branch under `tmp/series-backport-check/`, patches applied in order with `patch(1)`; APPLIES (offset/fuzz) or FAILS at patch N. A text check: the proof for a request is the cherry-pick/build matrix |
| **Is the cherry-pick exhibit still current?** (the same-minute check before a stable request; replaces `backport-check.sh` as the authority) | `scripts/stable-tips-check.sh <exhibit.md> <stable-branch>…` — fetches `stable`, compares each requested line's tip with the tip the exhibit recorded; `unchanged` → the exhibit stands, `MOVED` → rerun `build-btusb-stable-matrix.sh` for that line |
| **A mail's mechanical form before sending** (72 columns, ASCII, headers, no trailing whitespace) | `scripts/mail-lint.sh <mail.eml>` — the hanging line of draft v3 is why |
| **Current recipients for a kernel patch, from the kernel's own script** | `scripts/get-maintainers.sh <full-tree> <patch>` (`get_maintainer.pl` must run inside a tree) |
| **Is a mainline commit in, or does it apply to, each stable branch?** (backport requests) | `scripts/backport-check.sh <commit> [<stable-branch>…]` — PRESENT (same subject there) / APPLIES (offset, fuzz) / FAILS per branch; default = the lines live on kernel.org on 2026-10-02 (7.2, 6.18, 6.12, 6.6, 6.1, 5.15, 5.10 — read `https://www.kernel.org/releases.json` before a request, 7.1.y/7.0.y went EOL), dry run on file copies in `tmp/backport-check/`. `git -C cache/linux fetch stable` first |
| **What was the desktop's Bluetooth audio policy at any moment?** (profile vs routes, defaults, volumes/mute, which stream records which source, which stream plays to which sink — U1–U8) | `scripts/bt-audio-policy.py --user <desktop-user> [--once]` — follows `pw-dump --monitor`, one line per changed fact, `MATCH`/`MISMATCH` per device; since 09-29 also `playback[app]` → sink and `playback-node[app]` (the sound's name and role), so a one-second test sound is on record. Started as a **transient** unit, so a reboot ends it (inactive since the 2026-10-11 reboot; restarting it is the operator's decision): `systemd-run --unit=bt-audio-policy --property=Restart=always --property=RestartSec=10 scripts/bt-audio-policy.py --user i`; read with `journalctl -u bt-audio-policy`. Listens only; values use node descriptions, not addresses |
| **Prove a fix while a trial is open** (the suite refuses then) | `scripts/prove-exhibit-boots.sh` (an exhibit's provenance names the evidence boots apart from the capture boot), `scripts/prove-trial-closer.sh` (unclosed directory set aside; slow journal costs counts, not the row), `scripts/prove-trial-nomatch.sh` (a `--grep` read that matched nothing exits 1 and is a clean window, not an unreadable journal), `scripts/prove-trial-build-label.sh [bt-trial]` (E1 labelled from the module version), `scripts/prove-audio-policy-metadata.py [recorder]` (partial pw-dump metadata kept, null removes) — the same assertions the suite carries, runnable alone; earlier siblings `prove-held-branch-guard.sh`, `prove-ci-*.sh`, `prove-dr-*.sh` |
| **The publishing scan refuses a results file for "real MAC" that are clock ranges** (a start and an end time joined by a hyphen read as six two-digit groups) | `scripts/fix-time-ranges.py <file>...` — rewrites `HH:MM:SS-HH:MM:SS` as `HH:MM:SS to HH:MM:SS`, prints the count per file; the times are unchanged |
| **Is a patch queued for stable on each line?** | `scripts/stable-queue-check.sh <patch-file-stem> <version>...` — reads `queue-<v>/` of the public stable-queue tree; QUEUED or not, per line (`EX-061`). After a release the patch moves to `releases/<v>.<n>/` |
| **Is a patch in the current stable release candidate?** (between QUEUED and released) | `scripts/stable-rc-check.sh <subject> <version>...` — fetches `linux-<v>.y` of the public linux-stable-rc tree into `FETCH_HEAD` only, and looks for the subject between the released tip and the rc tip; `IN RC <hash>` or `not in rc`, with the rc tip's subject (a release subject means no rc is open). Each line is one large fetch: minutes per line. From a worktree, set `LINUX_TREE` to the main checkout's `cache/linux` |
| **Read an HFP codec switch's decisive packets** (old link's Disconnection Complete vs the headset's `AT+BCS=` reply vs `Setup Synchronous Connection`) | `scripts/sco-switch-windows.sh <capture.btsnoop> "<from>" "<to>" [...]` — several windows in one run, fixed pattern; `EX-060` |
| **Retire a block of text into history without retyping it** | `scripts/move-lines.sh <src> <from> <to> <dst> "<heading>"` — moves an inclusive line range verbatim to the end of another file under a heading and deletes it from the source (BRIEF → HISTORY, 2026-10-03) |
| **Replace BRIEF's hand-off block, keeping the old one** | `scripts/brief-handoff-to-history.py <date> <placeholder>` — finds the `> **HAND-OFF` block by its marker (no line numbers to get wrong), appends it verbatim to `HISTORY.md` under "BRIEF hand-off block as it stood on `<date>`", and leaves `<placeholder>` in BRIEF for the fresh block (2026-10-08) |
| **Keep the open trial's record before a shutdown can lose it** (the installed closer, before `main`'s tools are deployed) | `scripts/trial-snapshot.sh` → `<trial dir>/snapshot-<UTC stamp>/`: `/run/bt-trial/current` verbatim; the row `main`'s `bt-trial autostop` computes now, run read-only in a sandbox under `tmp/` (own state copy, scratch results file, 600 s budget, no capture directories, no `/usr/local/bin` on PATH so no `bt-state`/`bt-mark`/`bt-incident`); `boot-bt-summary.sh` of the boot; the full-width SCO decode; `SHA256SUMS`. The trial stays open and `results.tsv` is not touched. First run 2026-10-18 on E3 #1 |
| **Close the open trial by hand, passively, before a shutdown can lose it** (and open the next) | `scripts/trial-close-now.sh [--reopen]` — `main`'s `tools/bt-trial autostop` from the checkout, nothing installed: passive (no command to the controller), the row first, 600 s journal budget, `main`'s probe-free `bt-state`/`bt-mark` first on PATH (the installed `bt-mark` sends Read Local Name), the closer's own decode skipped and `sco-params.txt` written by `trial-sco-decode.py`; `--reopen` runs `autostart <build>` and a step line saying the trial is not boot-aligned. Its `bluetoothctl` call can crash the capture's `btmon` (BT-4, ~1 s of trace). First run 2026-10-18 17:03 (E3 #1) |
| **A trial window's SCO requests at full width** (what `sco-params.txt` should hold) | `python3 -I scripts/trial-sco-decode.py <start-epoch> [<end-epoch>]` — the kernel's `opcode 0x0428`/`0x043d` setups in the window; per setup, per capture directory, decodes only the first file last written after it, with `btmon -T --columns=200 -r` (`COLUMNS` is ignored and the header names come out shortened); keeps setups, their Command Status and Synchronous Connect Complete; addresses as `<addr>`; a summary matches every kernel setup against each path |
| **One boot's Bluetooth summary for an exhibit** (build loaded, firmware lines, error-level hci0 lines, ledger with totals) | `scripts/boot-bt-summary.sh [<boot>]` — `EX-057` is one; `scripts/sco-ledger-boots.sh <boot>…` is the ledger over several boots with totals and per-headset counts (`EX-058`) |
| **How long does a journal query take on this boot?** (sizing a read that must finish before a deadline) | `scripts/journal-scan-time.sh <journalctl args…>` → lines and seconds. 2026-09-29, the 24 h E1 boot: `-k -b -1 --grep=<union>` **180 s** (filtering removes formatting, never traversal); `-k -b -1 -p err --grep=tx.timeout` **0.0 s** (the priority index). That is why `bt-trial`'s closer takes its verdict from `-p err` and bounds the rest (`BT_TRIAL_SCAN_BUDGET`, default 20 s) |
| **What did the controller advertise at each power-up?** | `scripts/supported-commands-survey.sh [capture-dir]` → `tmp/supported-commands-survey.tsv`: every `Read Local Supported Commands` reply in the retained captures, with entry count and whether Enhanced Setup/Accept Synchronous Connection are listed |
| **What went over the air in one minute** (an HFP codec switch, a SCO setup, a failure window) | `scripts/capture-window.sh <capture.btsnoop> "<from>" "<to>" ['<ere>']` — btmon's decode cut to the window, optionally only the packets matching the pattern; `'RFCOMM\|[+]BCS\|Synchronous\|Air mode\|Disconnect'` reads a codec switch (U7 was found this way, 2026-09-29). A bare `SCO` matches every SCO Data packet — 940 KB for one minute |
| **How each discovery cycle ended** (Inquiry Complete vs the LE scan-off and its Command Complete; whether `Discovering: Disabled` followed; refused starts; suspends) | `scripts/discovery-stop-race.py <trace.btsnoop>…` (files in time order) — BT-9, `EX-062`. btmon also shortens the `Command`/`Event` word itself (`< HCI Comman..`); the first version matched the full word and lost about 170 cycles' packets |
| **Every management reply in the captures** (command, Complete vs Status, status byte, per-file totals) | `scripts/mgmt-replies.sh <capture.btsnoop>…` — `BT_MGMT_KIND=STATUS`, `BT_MGMT_ONLY=<regex>`. Reads btmon's decoded form AND the undecoded `@ Control Event` records it prints in rotated capture files (the first version read those as "no replies"). Cross-check `capture/` against `trace/` — two independent recorders |
| **Put a self-built `bluetooth.ko` in front of the stock one for the next boot, or remove it** | `scripts/module-updates.sh status \| install <module.ko> \| remove` — checks CRCs against every dependant first, `depmod`, reports whether the initramfs matters; never loads anything live (`EX-046`) |
| Before replacing a module via `updates/`: will every installed dependant accept it? | `scripts/check-modversions.sh <Module.symvers> <module.ko[.zst]>…` — compares expected vs exported symbol CRCs |
| Change a format-patch's message without touching its diff | `scripts/patch-replace-message.sh <patch> <msgfile>` — refuses a file with no `---` or no diff |
| **Does a kernel patch build at another tree's tip — the real check** | `scripts/build-bluetooth-fulltree.sh <ref> <name> <patch>` — full worktree under `cache/<name>` (blobs on demand), `defconfig` + BT as module, `modules_prepare`, `make M=net/bluetooth` unpatched then patched with `-Werror`; needs `bison flex libelf-dev` (installed 2026-09-22). Worktrees `cache/full-bt-next`, `cache/full-6.1.y` exist; ~5 min each after the first checkout |
| Does a one-file kernel patch compile at **another** tree's tip (quick, no full tree) | `scripts/compile-mgmt-at.sh <sparse-worktree> <patch>` — that tree's `include/` first, `-Werror`, unpatched then patched. Whole-module builds across kernel versions need a full tree with `modules_prepare` (packages this host lacks); worktrees under `cache/linux-bt-next`, `cache/linux-6.1.y`, `cache/linux-6.12.y` |
| How do the branches diverge? | `devtools/branch-status` (`--unique`, `--files`) |
| **What exists only on this disk?** (every tree: uncommitted, untracked, commits on no remote) | `scripts/unpushed-survey.py <tree or parent dir>…` — e.g. the project and `cache/` (each child taken). The `cache/ubuntu-*` "modified" counts are Ubuntu's diff, reproducible |
| **Save the local work inside upstream checkouts** (our commits in `cache/` kernel and BlueZ trees, which no remote holds) | `scripts/export-local-work.py <out-dir> <tree>…` — format-patch of commits on no remote, `uncommitted.diff`, untracked files up to 1 MB, `BASE.txt` with how to re-apply; refuses an existing directory. Output goes to a branch on the private remote, one dated directory per export |
| Coverage / comprehensiveness | `devtools/coverage` (bash lines), `devtools/awk-coverage` (awk statements), `devtools/py-coverage` (Python lines), `devtools/test-comprehension` (modes, refusals, seams, branches per unit); each takes `--min N`, and CI holds 80 / 95 / 80 / 75 |
| Run the suite, or one block of it | `tests/run-tests`, `tests/run-tests --section "<text from a heading>"`; it refuses while a trial is open, and refuses to run inside a run of itself |
| **Does any test reach the real machine?** (a call, a read, a write, an answer the machine gave) | `devtools/sandbox` — the suite in a decoy world whose every answer is marked; four detectors must stay silent. `--self-test` plants leaks and proves each one is caught (tests/README.md, rule 5) |
| **Does any test touch the machine without the machine answering?** (an existence check, a read of an absent file, a lookup no test names) | `devtools/access-audit` — the suite under `strace`, every file access classified; fails on anything outside `tests/access-allowlist`. `--self-test` plants each kind of access and requires each caught (tests/README.md, rule 8) |
| **Would the suite notice if this decision were wrong?** | `devtools/mutate <file> [--lines A-B]` — each mutant from `devtools/mutants` (a flipped comparison, `&&`↔`\|\|`, a dropped `!`) applied alone in its own namespace, the whole suite run on it; a survivor is a missing test or an equivalent change. `--self-test` checks the harness |
| Do the fixtures still match real journalctl? | `devtools/journal-contract` |

### Deploying to the affected machine

| what | command |
|---|---|
| Prove the BlueZ patches apply the way a maintainer applies them (`git am` alone/together/either order, BlueZ format rules) | `patches/bluez/git-am-check.sh <bluez-checkout> [<commit>]` |
| **What is installed now, file by file, against the commit it came from** (read-only; before a deploy) | `python3 -I scripts/installed-vs-commit.py <checkout> <installed-commit> [<candidate>]` — reads `<installed-commit>:install.sh`, hashes every destination as git does: `identical` / `DIFFERS` / `missing` / `unreadable`; with a candidate, whether a deploy of it changes the file. 2026-10-18 on the laptop with `cccf0fe main`: 67 identical, the modprobe file `missing` because `bt-mode experiment` moved it aside as `.disabled` (identical too), 17 that a deploy changes |
| Deploy files, **arm nothing** — the whole set, never `bt-trial` alone (its library and `bt-mark` must match it; STATUS) | `sudo ./install.sh --tools-only`, then `sudo systemctl daemon-reload`, `sudo tools/bt-verify-install`, `bt-mode status` |
| Deploy and arm everything | `sudo ./install.sh --apply` |
| **Rehearse the investigation machine's deploy** before doing it: its installed tree, a trial open, `--tools-only` over it, `daemon-reload`, the shutdown's close, uninstall | `tests/system-upgrade <old-tree> [mitigation\|experiment]`, gated like the round trip; CI runs it over `cccf0fe` (the 2026-09-18 tools) in both modes. Clean-machine install and removal: `tests/system-roundtrip` (tests/README.md, "The system tests") |

⚠️ Use `--tools-only` on the investigation machine. `--apply` enables
`bt-hang-watchdog`, whose USB reset has three controlled demonstrations of driving
an already-wedged controller off the USB bus until power is removed.

### The other shipped tools

Installed by `install.sh` or run from the checkout, with no question above that names
them. Each line is the tool's own header; read the file before using it on the laptop.

| tool | what it answers |
|---|---|
| `bin/bt-capture` | decode-free HCI capture that survives `btmon` crashing (a daemon, `bt-capture.service`) |
| `bin/bt-dyndbg` | turn on the kernel's built-in Bluetooth debug statements (`bt-dyndbg.service`) |
| `bin/bt-evidence` | record a reproduction session as durable, sanitised evidence |
| `bin/bt-health-snapshot` | append one row of Bluetooth health metrics (timer and event units) |
| `bin/bt-usbmon` | capture the USB transport under the Bluetooth controller (a daemon) |
| `tools/bt-actions` | reconstruct what actually happened, from the logs rather than from memory |
| `tools/bt-boot-provenance` | how did the machine get into each boot |
| `tools/bt-boot-stats` | one row per boot: did the controller misbehave, and did it hang? |
| `tools/bt-capdiff` | do the two independent HCI capture paths agree? |
| `tools/bt-context` | what is next to the failures in the log, not only the failures |
| `tools/bt-diagnose` | has this machine recorded the HCI command-timeout phenotype? |
| `tools/bt-env-history` | which workarounds were active during which boot? |
| `tools/bt-health-report.sh` | are the mitigations working? (installed as `bt-health-report`) |
| `tools/bt-interval` | seconds between two log timestamps, with the shipped arithmetic |
| `tools/bt-logvolume` | what is filling the kernel log, and how fast? |
| `tools/bt-mode` | switch between daily-use mitigation and a clean experiment; `status` only reads. It writes live, so check `bt-window` first (BRIEF §0) |
| `tools/bt-phase` | did failures cluster near the liveness probe, or only look that way? |
| `tools/bt-timeline.sh` | every Bluetooth-relevant log stream merged into one chronology (installed as `bt-timeline`) |
| `tools/bt-trial-audit` | recompute every gating field in `results.tsv` from the journal |
| `tools/bt-verify-install` | is what is running the same as what is committed? Reads only; run it after a deploy |
| `tools/bt-verify-kernel-mechanism` | which reset mechanism does this kernel's btusb use? |
| `tools/verify-restored.sh` | is this machine back to its pre-investigation state? |

---

## Writing commands

⚠️ **Let journald do the filtering, or the scan is both too slow AND too narrow.**
`journalctl --since … | grep X` over this machine's journal walks ~19 days of
dynamic-debug output and does **not finish in ten minutes**. The same question
with `journalctl _COMM=bluetoothd --since … | grep X` answers in **thirty
seconds**, because journald selects on the indexed field instead of streaming
every record. On 2026-09-13 the slow form was abandoned and replaced by a grep
over one boot — which reported "the patch guard never fired" when it had fired
four times (`EX-041`). The too-slow scan and the false conclusion were the same
mistake.

**A repeated question becomes a file, not a pipeline.** A file under `tools/`,
`devtools/` or `scripts/` is reviewed, versioned and re-runnable, and an exhibit
can cite it; a hand-typed pipeline is none of these. Of the commands typed on this
project up to 2026-09-13, two thirds were compound shell, and 226 asked one
question that `bt-fault-window` now answers in one call. `scripts/` (added
2026-09-19, see its README) is for helpers and proofs that are not yet tools;
their outputs go to `tmp/` (ignored) and third-party sources to `cache/`
(ignored), never to a system temporary directory, which vanishes with a reboot.

Keep commands simple:

- one command per call; no `&&`, `;`, `$(...)`, loops, or variable assignment
- need several steps? put them in a script and invoke it by path
- **no redirects and no trailing `| tail -N`** — if output needs trimming, the
  script should trim it, and print everything when something failed.
- ⚠️ **check whether the tool already does the step you are prefixing.**
  `git add -A; devtools/repo-save …` was typed for weeks; `repo-save` stages
  first thing on its own.
- **never** `git commit -m "<long message>"` — write the message to a file, then
  `devtools/save <file>`
- use `git -C <dir> …`, never `cd <dir> && git …`

## Communication

`comms/` is the written channel between maintainers — see
[`comms/README.md`](../comms/README.md). Reply with a **new file**, never by
editing someone else's: `comms/<UTC>-from-<sender>-to-<recipient>.md`.
