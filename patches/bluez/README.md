# BlueZ patches — two NULL dereferences, ready to send

Two crashes recorded as `EX-032` on this machine, resolved to source in
[`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`](../../reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md)
and fixed here.

| patch | file | defect |
|---|---|---|
| `0001` | `src/adapter.c` | `start_discovery_complete()` dereferences the mgmt reply above its own length check |
| `0002` | `profiles/audio/a2dp.c` | `transport_cb()` passes `setup->stream` unchecked into a function that dereferences it |

**Why these two are worth sending, when the rest of this investigation is not
ready.** They carry none of the contested material. No hardware, no reproducer,
no argument about whether the controller wedge causes the daemon crash or the
crash is a symptom of it. `0001` in particular is an ordering bug a reader can
confirm in half a minute: the reply is dereferenced above the function's own
length check, so a callback delivered without parameters faults.

## Environment and runtime evidence — read this first

| | |
|---|---|
| machine | AMD Renoir/Cezanne laptop, Ubuntu 24.04 LTS, `bluez 5.72-0ubuntu5.5` |
| controller | Qualcomm Atheros QCA9377 (ROME), USB `13d3:3503`, `btusb` |
| crashes | `EX-032`: `segfault at 0` (08-14) and `segfault at 10` (08-18, seen three times) |
| resolved from | the stripped distro binary — `.eh_frame` boundaries + PLT call fingerprints against a different build — with the falsifier stated first and matched byte for byte against a retained core ([`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`](../../reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md)) |
| runtime | the patched daemon is a rebuild of **`5.72-0ubuntu5.5`** (the machine's own source + 31 Ubuntu patches), running since 2026-08-25. The 5.87 and master checks below are apply/compile checks, not the running build |
| upstream | both defects present in BlueZ master `c73fa2f9a`; both patches `git am` clean there |

**Runtime — the two patches stand differently, and the submission should say so.**
Neither NULL condition can be triggered on demand; both were first seen as crashes
in the wild. But the patched daemon has run on the affected machine since
2026-08-25, and both guards log before they bail, so a firing is positive evidence
of a crash prevented rather than merely absent (`EX-041`, `tools/bt-guards`):

- **`0002` fired four times** — 08-26, and three times on 09-02, across two daemon
  lifetimes and three distinct `setup` pointers. Each is `transport_cb()` reaching
  the accept with a live setup whose stream was NULL. Unpatched, each is the
  dereference the coredump matched. **Watched preventing it, four times.**
- **`0001`'s guard has not fired.** Its *premise* — a Command Status with status
  `0x00` answering a Start Discovery, so the callback gets `length 0, param NULL` —
  was logged **five times with clients present** (four on 08-14 in the daemon that
  then crashed, once on 09-08); the pre-existing check below the branch caught each.
  The 08-14 crash is the sixth, **reconstructed line by line from the archived
  daemon log** (`EX-041` correction of 09-18): last client removed 21:03:16, Start
  Discovery sent 21:03:24.943, Command Status `0x00` at 21:03:26.994, callback with
  the list empty, `segfault at 0`. The coredump analysis and the log agree.

⚠️ A third `bluetoothd` crash on the patched binary (09-08, a bad `free()` under
`g_main_loop_run`) is at neither patched site, occurred in a process that never
took either guard path, and is **not** part of this submission.

⚠️ **`0002` treats the symptom.** It stops the crash without explaining why
`setup->stream` is cleared while the setup is still on the `setups` list.

That caveat used to be spelled out in the commit message and was dropped when
the message was shortened for submission, on the reviewer's advice to carry the
evidence that justifies the change rather than the route to it. It is recorded
here instead, because it is true and a maintainer may ask: the guard is correct
and local, and the underlying teardown ordering is not explained by it.

## What has been verified

| check | result |
|---|---|
| applies to pristine 5.87 with `git apply --check` | ✅ both, clean |
| applies with `patch -p1` | ✅ both, clean |
| `src/adapter.c` and `profiles/audio/a2dp.c` compile | ✅ both objects build |
| compiler warnings introduced | ✅ none |
| defects still present in current upstream 5.87 | ✅ both, unchanged since 5.72 |
| `checkpatch` under BlueZ's own `.checkpatch.conf` (`patches/bluez/checkpatch-check.sh <tree>`, 2026-09-18) | ✅ 0 errors each; 1 warning each, the quoted `segfault` line (`HACKING` §5 exempts quoted output) |
| `git am` at master `c73fa2f9a`, each alone and both in either order (`patches/bluez/git-am-check.sh`) | ✅ 6/6, re-run after the 09-18 message changes |
| defects still present at master `2401054` (2026-09-17) | ✅ both — the first third-party reviewer's check, not re-run here (no network) |
| defects still present at master `ebbb4ee3` (2026-09-18) | ✅ both — the second independent reviewer's check (`reviews/2026-09-19T1700Z-…`) |
| three independent reviews (2026-09-18, 2026-09-19 ×2), the later two formed before reading the first | ✅ accept both, submit independently; message-only changes from them (a label, a provenance sentence, one sentence on `confirm_cb()`), all applied; no code change from any |

Built against BlueZ 5.87 configured with
`--disable-systemd --disable-obex --disable-cups --disable-manpages
--disable-testing --disable-tools --disable-monitor --disable-client`.

### The crash site survived falsification

The identification was made **without symbols** — `.eh_frame` function boundaries
and PLT call fingerprints matched against a *different* build. That method could
easily have produced a confident wrong answer, so it was published with a
prediction attached: `%r13` holds NULL, and the faulting instruction is
`mov 0x10(%r13),%rdi`.

Checked against a retained core on the investigation machine:

```
r13   0x0
rip   0x635d944b47e5
=> 0x635d944b47e5:  mov 0x10(%r13),%rdi
```

Byte for byte as predicted. The kernel's `segfault at 10` is the `0x10`
displacement off a NULL base, not an address in its own right.

**Worth citing in the submission** — a maintainer will reasonably ask how a crash
site was located in a stripped binary whose debug symbols were never published.

## Upstream status — checked three times, independently, and both are still needed

Verified on 2026-09-16 against the unshallowed tree at `c73fa2f9a` in a throwaway
worktree, each patch **alone** and both **together in either order** — the
`git am` path is the real submission path, and a stray `---` in a message body
silently truncates everything after it:

```console
$ patches/bluez/git-am-check.sh /path/to/bluez c73fa2f9a   # tracked; a throwaway worktree
  PASS  0001 alone — git am clean, 1 commit(s) on top of c73fa2f9a
         adapter: Fix crash on short start discovery reply
  PASS  0002 alone — git am clean, 1 commit(s) on top of c73fa2f9a
         a2dp: Fix crash on NULL stream in transport_cb
  PASS  0001 then 0002 — git am clean, 2 commit(s) on top of c73fa2f9a
  PASS  0002 then 0001 (order-independent) — git am clean, 2 commit(s)
  PASS  no Signed-off-by in either patch
  PASS  subject 49 chars · subject 46 chars · no body line over 72
```

Both defects present at `c73fa2f9a`, both patches `git am` clean **against real
master**, not just the 5.87 tarball. An earlier check used a `--depth 50` clone;
that cannot see a 2020 commit and answers `unknown revision`, so the tree was
unshallowed before any history question was asked of it.

Master was also checked independently from the investigation machine at
**`5.87-78-gc73fa2f`**:

- `start_discovery_complete()` still does `cp.type = rp->type;` **above** the
  `length < sizeof(*rp)` check;
- `transport_cb()` still passes `setup->stream` unchecked, **and the callee does
  not guard it either**.

Helpful context for the submission: `src/adapter.c`'s recent history carries
accepted crash fixes of the same shape — *"Fix crash on UUID discovery filter
match"*, *"Fix crash on dev_disconnected"*. NULL-deref fixes land in this file.

### Prior art — settled, no longer a caveat

| query | results | reporting these defects |
|---|---|---|
| `start_discovery_complete` | ~300 hits, 207 distinct subjects | **none** — the only NULL-deref threads are kernel-side `hdev->discovery.uuids` patches, a different layer and pointer |
| `avdtp_stream_set_transport` | 32 hits | **none** reporting this call path |

**The nearest prior work, verified here against full history** rather than taken
on trust:

```console
$ git log -1 --stat 90a600895
Luiz Augusto von Dentz   2020-09-22
avdtp: Handle case where remote send L2CAP connect ahead of Open
 profiles/audio/avdtp.c | 75 ++++++---     <- ONE FILE
```

It is the *same* code path, not merely a similar one: that commit introduced
`stream_set_pending_open()`, which is the function `avdtp_stream_set_transport()`
calls. It added no NULL guard on `stream`, and at master `transport_cb()` in
`a2dp.c:2680` still hands `setup->stream` over unchecked.

So the maintainer has already revisited **this code path** — and the gap patch
`0002` closes is one that work left open.

⚠️ Not the same *scenario*, and the patch is careful about this. `90a600895`
handles a transport arriving **before Open**; `125a2e237e7c` handles the
**`setup` disappearing** while an asynchronous accept is pending. Neither is the
NULL-stream teardown race observed here. What they establish is that both the
caller and the callee on this path have been hardened before, and that neither
ruled out a NULL `stream` at the hand-over.

⚠️ *Checking this needs the full history.* A `--depth 50` clone cannot see a 2020
commit and answers `unknown revision` — which reads like "no such commit" rather
than "not in my clone". Unshallowed to 29242 commits before checking.

## How to send

BlueZ takes patches by mail on `linux-bluetooth@vger.kernel.org`. The files are in
`git format-patch` shape and can go straight to `git send-email`, or be applied to
a checkout with `git am` and resent from there:

```console
$ git send-email --to=linux-bluetooth@vger.kernel.org 0001-adapter-*.patch
$ git send-email --to=linux-bluetooth@vger.kernel.org 0002-a2dp-*.patch
```

⚠️ **Send them as two separate invocations, not as a range.** They are
deliberately two standalone `[PATCH BlueZ]` mails — one is adapter/mgmt
discovery handling, the other A2DP asynchronous transport lifetime, and neither
depends on the other. Passing a revision range instead —

```console
$ git send-email --to=… HEAD~2..HEAD      # DON'T
```

— makes `send-email` apply `format-patch` semantics to the range, and
`format-patch` numbers subjects `[PATCH 1/2]` and `[PATCH 2/2]` whenever it
generates more than one patch. That would present them as a series and couple
their review, which is the opposite of the intent. If a series is ever wanted,
add a `0/2` cover letter rather than letting the numbering appear by accident.

To apply to a checkout instead of mailing, `git am 0001-*.patch 0002-*.patch`
works fine — the caution is only about sending.

### The note below the `---` line

A maintainer who asks "where did this come from, and has the guard ever
fired?" gets no answer from the commit message, correctly — BlueZ's `HACKING`
wants the message to carry the change and its evidence, not the route. The
place for the route is the mail body **below the `---` separator**, which
`git am` discards and which no convention governs
(front-door review 2026-09-17T2251Z, `FD-12`). The text for each mail is in
[`mail-notes/`](mail-notes/) — `0001.txt`, `0002.txt` — and goes in with:

```console
$ git send-email --annotate --to=linux-bluetooth@vger.kernel.org 0001-adapter-*.patch
# in the editor: paste mail-notes/0001.txt directly under the `---` line, above the diffstat
```

Never above the `---`, never as a trailer, never as a `Fixes:` URL — a project link
in a `Fixes:`-shaped position reads as a bug tracker.

## Conventions — measured from BlueZ's tree, not assumed

Read on 2026-09-16 from `HACKING` at `c73fa2f9a` and from the last 300 commits.

- ⚠️ **No `Signed-off-by`.** `HACKING`: *"Do not add Signed-off-by lines in your
  commit messages. BlueZ does not use them, so including them is actually an
  error."* 4 of the last 300 commits carry one; BlueZ's own `.checkpatch.conf`
  ignores `MISSING_SIGN_OFF`. Both patches carried one until 2026-09-16 and
  would have been rejected for it. Removed. (An earlier revision of this file
  said the sender must put their own there — true of the kernel, wrong here.)
- **50/72.** Header ≤ 50 characters, body wrapped at 72, quoted tool output
  exempt. Both subjects were 55; now 49 and 46. `checkpatch --max-line-length=80`
  is looser than BlueZ's own rule and is not the bar.
- **`[PATCH BlueZ]` prefix**, one mail per top-level directory, bug fixes first —
  all already the case.
- **`Fixes:` is used** — 14 of the last 300 — most often as a GitHub issue URL,
  with the `hash ("subject")` form as a used minority in 9-, 12- and 13-character
  hashes. `0001`'s `Fixes: 3597d1377723 (…)` resolves in the tree and is house
  style. `0002` carries **none on purpose**: `git log -S` on the unchecked call
  finds only a 2015 refactor (`fe9ba4ff0`), which is where the text last moved,
  not where the NULL became possible; naming it would mislead. The two prior
  hardenings of the same path are cited in prose instead.
- **A GitHub issue is what maintainers most often link.** The tree's `Fixes:`
  history is dominated by `github.com/bluez/bluez/issues/N`. Filing one before
  sending is the operator's call; if filed, it belongs in `0002`'s message as
  `Fixes: <url>`.
- **`checkpatch` under BlueZ's `.checkpatch.conf`: 0 errors** — now a tracked
  command, `patches/bluez/checkpatch-check.sh <bluez-tree>`, which runs from inside
  the tree so the config is actually read. ⚠️ Its first run on 09-18 found an
  **error the earlier hand-run had not**: `0002` cited prior commits as bare
  `hash ("title")` and checkpatch's `GIT_COMMIT_ID` wants `commit <12+ hex> ("title")`.
  BlueZ's last 300 commits show no house form either way (one bare citation, no
  `commit …` form), so the form checkpatch accepts is used: `commit 125a2e237e7c (…)`,
  `commit 90a600895d80 (…)`, wrapped at 72 with the closing `")` on the next line,
  which checkpatch joins. The remaining warning per patch is the quoted `segfault`
  line, exempt under `HACKING` §5.

The subjects changed with the rewrite, so the files were renamed to what
`git format-patch` would produce; nothing in the repository referenced the old
names.

## Notes from the route — history a maintainer does not need

⚠️ **The event IS determined; the kernel's reason for sending it is not.** This
section has flipped twice, so the evidence is spelled out. An early revision
named a successful Command Status as the event received; a 09-16 revision
retracted that as a claim from source reading, because Command Complete passes a
real pointer even at `length == 0` (`mgmt.c:408`) and `request_complete()` falls
back to matching on **index alone** when opcode+index finds nothing
(`mgmt.c:312`), so a mismatched completion could also reach the callback.

On 2026-09-18 a third-party review, reading our own exhibit, noticed that the
opcode we had labelled `START_SERVICE_DISCOVERY` (`0x003A`) was `0x0023`, Start
Discovery itself — and re-reading the archived 08-14 daemon log settled the
event outright (`EX-041`, correction block):

```
21:03:16.750  discovery_remove() owner :1.125            ← last client gone
21:03:24.943  send_request() [0x0000] command 0x0023      ← Start Discovery sent
21:03:26.994  can_read_data() [0x0000] command 0x23 status: 0x00
21:03:26.994  start_discovery_complete() status 0x00
21:03:26      kernel: bluetoothd[2821]: segfault at 0 …
```

`command 0x%02x status:` is printed **only** on the `MGMT_EV_CMD_STATUS` branch
(`complete:` on the other), the opcode matches the request sent 2.05 s earlier
(no fallback), and that branch passes `0, NULL`. So: Command Status, status
`0x00`, `length 0`, `param NULL`, list empty, `rp->type` — the `segfault at 0`.
The same delivery appears five more times in the logs with clients present.

Still open, and now the interesting question for a kernel reader: **why does the
kernel answer Start Discovery with a successful Command Status** rather than the
one-byte Command Complete it sent for the other 37 in that log? The five
with-clients instances came 12–14 ms after the send; the fatal one 2.05 s after,
while the controller was timing out HCI commands every 2 s. The commit message
states the observation and leaves the cause open. A `btmon` capture of the next
occurrence would show the management event as the kernel emitted it.

Residual behaviour after the guard, stated so a maintainer need not ask: if the
kernel *did* start discovery and the reply carried no `type`, the no-clients
branch can no longer send `MGMT_OP_STOP_DISCOVERY`, and discovery runs until
another stop path. Manufacturing a `type` would be worse; a daemon that is up
can be told to stop, one that has crashed cannot.

An earlier revision of this file said the list archives could not be searched
from either environment. **That was wrong, and it was wrong the same way twice**
— see the four failure modes in [`docs/source-access.md`](../../docs/source-access.md).
`lore.kernel.org` returns 403 to `curl` because of a user-agent block fronting a
JavaScript anti-bot page; a browser passes it in seconds. The operator opened it
himself and settled the question in under a minute.

