# Third independent review of the two BlueZ patches — 2026-09-19T19:00Z

**Source.** A third independent reviewer (the document titles itself "second"; it is the
third reading this repository has received, hence the filename), working from
`docs/review-task-bluez-patches.md`, the repository at `f0689217`, and BlueZ at
`c73fa2f9a` and master `ebbb4ee31ad7011cead3d6394c68d10076ab55fc` (2026-09-18). The reviewer
states their own nine-item review list and that the reading was written before opening the
first review. Reproduced verbatim in §"The review".

**Verdict as given.** Submit both as two separate `[PATCH BlueZ]` mails, without code
changes. No blockers, no should-fix, a few nits and notes.

**What this side did with it** is in §"Verification". Register: `reviews/README.md` §TP3.

## Verification

### TP3-02 — a divergence between reviewers, recorded

This reviewer read the patch at `f068921`, whose `0001` message still said the daemon log
"ends with" a sequence whose last line is the kernel's `segfault at 0`. F3 says every
factual sentence follows from the quoted log — and the reviewer opened `kernel.log` and
quoted the segfault line from there. The second reviewer (`2026-09-19T1700Z`) read the same
sentence as a provenance error and asked for it to be fixed; it was, an hour before this
review arrived. Two careful readers, one sentence, opposite calls: one took "the log ends
with" as shorthand for the session record, the other as a claim about one file. The fix
stands; it costs nothing and removes the ambiguity that produced the split.

### TP3-03 — the 75-character `Fixes:` trailer: kept

```console
$ awk 'length > 72 && !/^  / && !/^[-+ @]/' patches/bluez/0001-adapter-Fix-crash-on-short-start-discovery-reply.patch
Fixes: 3597d1377723 ("adapter: Fix not waiting for start discovery result")
```

The only unquoted line over 72. `git-am-check.sh` exempts known trailer names on purpose
(review-branch maintainer, 2026-09-18); BlueZ's checkpatch under its own `.checkpatch.conf`
does not flag it. The reviewer would not wrap it; neither would we.

### TP3-05 — `confirm_cb()` already checks the stream before the accept: confirmed, adopted

```console
$ grep -n -A40 '^static void confirm_cb' /var/cache/bt-investigation/bluez/profiles/audio/a2dp.c | grep -E 'setup->stream|bt_io_accept'
2726-		if (!setup || !setup->stream)
2729-		if (setup->io || avdtp_stream_get_transport(setup->stream,
```

At `c73fa2f9a`, `confirm_cb()` refuses to start the accept when `setup->stream` is NULL
(line 2726); nothing re-checks it when the accept completes. That is the cleanest statement
of what `0002` is — the second half of a check the file already performs — and one sentence
in `0002`'s message now says so. Re-verified after the change: `git-am-check.sh` 6/6,
`checkpatch-check.sh` 0 errors (results in the commit that carries this file).

### TP3-06 — two failed completions through the no-clients branch: confirmed

```console
$ grep -n '\[2821\]' evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log | grep -E '21:03:(1[6-9]|2[0-6])' | grep -E 'complete: 0x05|discovery_remove|status 0x'
4802:Aug 14 21:03:16.750764 … command 0x0023 complete: 0x05
4803:Aug 14 21:03:16.750793 … start_discovery_complete() status 0x05
4804:Aug 14 21:03:16.750850 … discovery_remove() owner :1.125
4806:Aug 14 21:03:20.846475 … command 0x0023 complete: 0x05
4807:Aug 14 21:03:20.846494 … start_discovery_complete() status 0x05
4809:Aug 14 21:03:24.942876 … command 0x0023 complete: 0x05
4810:Aug 14 21:03:24.942908 … start_discovery_complete() status 0x05
4813:Aug 14 21:03:26.994484 … start_discovery_complete() status 0x00
```

After the client left at 21:03:16.750, two completions with status `0x05`
(`MGMT_STATUS_AUTH_FAILED`) entered `start_discovery_complete()` with the list empty and
returned at `status != MGMT_STATUS_SUCCESS` — the branch was live and harmless until the one
completion that reported success with no parameters. Recorded here as the reviewer suggests;
not added to the message.

### TP3-07 — the task document's path: fixed

`docs/review-task-bluez-patches.md` named `mail-notes/0001.txt` without the
`patches/bluez/` prefix; that path does not exist at the repository root. Corrected.

### TP3-01, TP3-08, TP3-09 — recorded

Both defects at `ebbb4ee3` with the reviewer's dry-run offsets (18 / 22): the reviewer's
observation, not re-run here. No cheap `unit/` hook: agrees with the second review's
TP2-06. The index-fallback disagreement with the first review: the same one our
verification and the second review recorded, from the same log line (`Unable to find
request` absent).

## The review

Reproduced verbatim from the file the operator uploaded on 2026-09-19.

---

# Second independent review of two BlueZ patches

**Date:** 2026-09-19  
**Reviewer:** external reading requested by `docs/review-task-bluez-patches.md`  
**Repository read:** https://github.com/ivoitovych/qca9377-bt-hang `main` at `f0689217ecdf70f520c4c0e35dcf2115c4e13097`  
**BlueZ read:** master `c73fa2f9a` (the commit the patches last claim) and current master `ebbb4ee31ad7011cead3d6394c68d10076ab55fc` (committed 2026-09-18). The `start_discovery_complete()` body is identical at those two commits. `transport_cb()` has moved but the unguarded call is unchanged.

This reading was written before opening `reviews/2026-09-18T0700Z-third-party-bluez-patch-review.md`. Comparison with that review is in a separate section at the end and is left unresolved.

## What I used as a review list

Not the project's section 4. The list I would use for a patch arriving on `linux-bluetooth`:

1. Is the defect still in current master, in the form the message describes?
2. Does the diff close that defect and only that defect?
3. Can I construct a valid input whose handling changes? (negative result required)
4. Do the commit message's factual sentences follow from the cited code and from the log/disassembly they quote?
5. Residual behaviour after the guard — is the trade acceptable?
6. `Fixes:` / prior-art citations — do they name the change that introduced the hole, or something that merely moved text?
7. Format against BlueZ `HACKING` as published at current master, not against kernel habits.
8. Tests: is there a cheap way to drive the guarded state from `unit/`?
9. Does anything in the mail claim these patches fix the controller hang?

## Verdict

Submit both, as two separate `[PATCH BlueZ]` mails, without code changes.

No blockers. No should-fix items. A few nits and notes.

Both defects are present at BlueZ master `ebbb4ee31` (2026-09-18). Dry-run `patch -p1` of `0001` against current `src/adapter.c` succeeded at offset 18; of `0002` against current `profiles/audio/a2dp.c` succeeded at offset 22. The constructs the messages describe have not been fixed in the day since `c73fa2f9a`.

---

## Patch 0001 — adapter: Fix crash on short start discovery reply

### F1. The defect is real and the diff is the right local fix
**Grade:** note (accept)  
**Checked at:** BlueZ `c73fa2f9a` and `ebbb4ee31`, `src/adapter.c` `start_discovery_complete()`; `lib/bluetooth/mgmt.h`; `src/shared/mgmt.c` `can_read_data` / `request_complete`.

`start_discovery_complete()` assigns `const struct mgmt_cp_start_discovery *rp = param` and, when `!adapter->discovery_list` and `status == MGMT_STATUS_SUCCESS`, does `cp.type = rp->type` before the function's own `length < sizeof(*rp)` check. `struct mgmt_cp_start_discovery` is a single `uint8_t`. `sizeof(*rp)` is 1.

On the Command Status path, current `src/shared/mgmt.c` does:

```c
DBG(mgmt, "[0x%04x] command 0x%02x status: 0x%02x", ...);
request_complete(mgmt, cs->status, opcode, index, 0, NULL);
```

Command Complete logs `command 0x%04x complete:` and passes a pointer into the receive buffer. Absence of a `complete:` line is not absence of a completion; the two branches print different strings. The quoted `command 0x23 status: 0x00` can only come from `MGMT_EV_CMD_STATUS`.

The added check is inside the no-clients branch, after the existing `status != SUCCESS` return and before `rp->type`. That is the only path that was missing the check. The pre-existing check below the branch is left alone.

**Would change my mind:** a current-master change that moves the length check above the branch, or a showing that `param` is never NULL when `status == SUCCESS`.

### F2. Negative result — no valid reply is rejected
**Grade:** note  
**Checked at:** `mgmt.h` (`struct mgmt_cp_start_discovery`), mgmt protocol (Start Discovery return parameter is one Address_Type octet), the same callback also serving `MGMT_OP_START_SERVICE_DISCOVERY` (also one octet back).

The new predicate is `length < sizeof(*rp)` with `sizeof(*rp) == 1`. A spec-compliant Command Complete carries that byte and has `length >= 1`. I tried to construct a valid successful Start Discovery / Start Service Discovery reply that this check would now drop, and could not.

A Command Complete with `length == 0` is not a valid reply for this opcode; if one arrived with a non-NULL `param` (Complete path points into the buffer even at length 0) the new check would still refuse to read it, which is right.

**Would change my mind:** a documented successful completion whose return parameter is empty.

### F3. Every factual sentence in the message follows from the quoted log and from `mgmt.c`
**Grade:** note (message is clean after the 09-18 label correction)  
**Checked at:** `evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log` and that session's `kernel.log`; `src/shared/mgmt.c` at current master; `lib/bluetooth/mgmt.h` (`MGMT_OP_START_DISCOVERY` is `0x0023`, `MGMT_OP_START_SERVICE_DISCOVERY` is `0x003A`).

From the archived daemon log, PID 2821:

```
21:03:16.750850  adapter.c:discovery_remove() owner :1.125
21:03:24.943018  mgmt.c:send_request() [0x0000] command 0x0023
21:03:26.994468  mgmt.c:can_read_data() [0x0000] command 0x23 status: 0x00
21:03:26.994484  adapter.c:start_discovery_complete() status 0x00
```

From that session's `kernel.log` (not `timeline.txt`; I opened `kernel.log`):

```
21:03:26.995487  kernel: bluetoothd[2821]: segfault at 0 ip 00005d6eb1ad1986
                     sp 00007ffef8e784b0 error 4 in bluetoothd[a6986,5d6eb1a50000+f3000]
```

The addresses and the `a6986` file offset in the message match this line. The message elides the trailing `likely on CPU 8 (core 4, socket 0)` and the syslog prefix; that is ordinary quotation, not a change of meaning. Callback to fault is about 1 ms.

Counts in the same `bluetoothd.log`:

- `command 0x23 status: 0x00` — 5 (20:31:22, :23, :26, :37, and 21:03:26)
- of those, `Wrong size of start discovery return parameters` immediately after — 4 (the 20:31 four)
- `command 0x0023 complete` — 37
- `Unable to find request` — I did not grep this until after forming the view; having now done so, it is 0 in this log. The Status events match a `send_request … command 0x0023` immediately before them. The index-only fallback in `request_complete()` was not taken for these deliveries.

`21:03:26.994 − 21:03:24.943 = 2.051 s`. `21:03:26.994 − 21:03:16.750 ≈ 10.24 s`. The message's "2.05 s earlier" and "ten seconds after its last discovery client had gone" follow.

Between the last client leaving and the fault, two more Start Discovery completions arrived as `command 0x0023 complete: 0x05` (`MGMT_STATUS_AUTH_FAILED`). Those take the no-clients `status != SUCCESS` return and do not dereference `rp`. The next completion is the Status/success/NULL one. That is consistent with the no-clients branch being live before the crash, and it is not claimed in the message; I record it as extra support, not as a missing sentence.

The message does not claim that current Linux normally emits a successful parameterless Command Status for Start Discovery. It says the delivery was observed and that why the kernel sent it is not established. That matches what I can support from userspace source plus this log. I did not open `net/bluetooth/mgmt.c` beyond search snippets; a kernel reader can take that question separately.

I did not re-run the stripped-binary recovery in `reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`. The quoted load `movzbl 0x0(%r13)` is the load the source says that branch performs, and the kernel line's `segfault at 0` / `a6986` match the quote. That is as far as I take the disassembly.

**Would change my mind:** a showing that `command 0x%02x status:` can be printed from the Complete path; or that `discovery_list` was non-empty at 21:03:26.994 (the 20:31 four printed `Wrong size…`, which on unpatched 5.72 is only reachable when the list is non-empty; the fatal fifth did not).

### F4. Residual: not sending Stop Discovery after the guard
**Grade:** note — I would make the same trade  
**Checked at:** the no-clients branch; `start_discovery_timeout()`'s use of `adapter->discovery_type` when stopping an already-running discovery; `struct mgmt_cp_stop_discovery`.

After the guard returns, the branch has no `type` and does not send `MGMT_OP_STOP_DISCOVERY`. If the kernel actually started discovery, it can keep running until some other stop path.

Manufacturing a type is worse than leaving discovery on. Crashing the daemon is worse than leaving discovery on. I agree with the README's trade for this patch.

A slightly stronger local alternative exists and I would not put it in this patch: the type was known when the command was sent (`cp.type = new_type` in `start_discovery_timeout()`). Storing that pending type on the adapter would let the no-clients branch stop without trusting the reply. That is a small design change, not a crash fix, and it would touch more than this branch.

**Would change my mind:** evidence that this machine (or common kernels) actually starts discovery on a Status/success with no payload, *and* that no later stop path runs, so an orphan scan is the common outcome rather than a theoretical one. A `btmon` capture of the next occurrence would settle the kernel half.

### F5. `Fixes: 3597d1377723` is the right tag
**Grade:** note  
**Checked at:** GitHub copy of `3597d1377723705e3fa6736610fcdb64ee6f2ce1` (2017-09-18, Luiz Augusto von Dentz, "adapter: Fix not waiting for start discovery result").

That commit introduced the "clients gone while start was pending, so send Stop Discovery from `rp->type`" branch next to the pre-existing length check. Naming it is house style and names the change that created the ordering hole.

I did not finish a full `git log -L` of the function (the sparse clone spent the window packing). By 2020-06-11 (`227cfdf8e0` / `0ce535ecb2`) the test was already `if (!adapter->discovery_list)` rather than `client = discovery_list->data; if (!client)`. The 2017 form loaded `discovery_list->data` first; an empty list would have faulted there rather than on `rp->type`. The reachable crash on today's tree is the length-check ordering that 3597 put in place, after a later commit made the empty-list test safe. I still think `Fixes: 3597d1377723` is the honest tag: it is where the unsafe use of `rp` in that branch was born. I would not retarget it without a commit that clearly *introduced* the `!discovery_list` form *and* the deref.

**Would change my mind:** a later commit whose message or diff is "use `rp->type` when the list is empty" as a new feature rather than a rename/refactor of 3597's branch.

### F6. Format nits on 0001
**Grade:** nit  

- Subject is 49 characters. No `Signed-off-by`. `[PATCH BlueZ]`. Body wrapped; quoted kernel/disassembly lines over 72 are what `HACKING` §5 exempts.
- The `Fixes:` trailer is 75 characters. BlueZ `HACKING` wants 72 except quoted tool output. Kernel-style `Fixes:` lines are often left long; the project's `checkpatch` run reportedly did not flag it. I would not wrap it.
- The new diagnostic string is a copy of the existing one. That is why EX-041 has to distinguish the two sites by whether the list was empty. A distinct string would make field logs cheaper to read. I would not delay the mail for it.

---

## Patch 0002 — a2dp: Fix crash on NULL stream in transport_cb

### F7. The defect is real and the diff is the right local fix
**Grade:** note (accept)  
**Checked at:** BlueZ `c73fa2f9a` `transport_cb` at `profiles/audio/a2dp.c:2651` and current master at `:2673`; `avdtp_stream_set_transport()` at current `avdtp.c:3272`; the `setup->stream = NULL` assignments in `a2dp.c` (at least `:966`, `:978`, `:1163`, `:1172`, `:1323`, `:1404`, `:1491`, `:1642`, `:1752`).

`transport_cb()` confirms `g_slist_find(setups, setup)` and then passes `setup->stream` to `avdtp_stream_set_transport()`, which does `g_io_channel_unix_new(fd)` and then `stream != stream->session->pending_open`. No NULL check on `stream` in the callee.

Several paths NULL `setup->stream` while leaving the setup on `setups`. Independently, `confirm_cb()` already does `if (!setup || !setup->stream) goto drop;` *before* `bt_io_accept(io, transport_cb, setup, …)`. The stream is checked at accept-start and not at accept-complete. That is the window.

The new check sits after the `err` / `bt_io_get` failures and immediately before the AVDTP call, and takes the existing `drop:` path (`setup_unref` + `g_io_channel_shutdown`). I/O errors still report as I/O errors.

I did not re-run the core/`%r13 == NULL` / `mov 0x10(%r13),%rdi` check. `session` is at offset 0x10 of `struct avdtp_stream` in the 2026-08-23 write-up; that matches `segfault at 10`. The field evidence I can read is EX-041's four `has no stream` lines (two PIDs, three distinct `setup` pointers). I did not query the machine journal myself.

**Would change my mind:** a current-master NULL check in the callee that makes this caller crash impossible; or a showing that `setup->stream` cannot be NULL while the setup remains on `setups` and `bt_io_accept` is still pending.

### F8. Negative result — no valid attach is lost
**Grade:** note  
**Checked at:** `transport_cb` success path; `avdtp_stream_set_transport()` including the `90a600895d80` early-L2CAP handling; `confirm_cb`'s pre-accept stream check; `drop:`.

If `setup->stream` is NULL there is no stream to attach the accepted fd to. `90a600895d80` handles "transport before Open" only when it has a stream object (`stream_set_pending_open`, `stream->session`, `stream->lsep`). It does not give a place to park an fd for a stream that has already been cleared.

I tried to construct a case where the new check drops a transport that `avdtp_stream_set_transport()` would have accepted. I could not. The only concern would be a callback that expects to *replace* `setup->stream` before using it; nothing in `transport_cb` does that.

`drop:` was already reachable from `avdtp_stream_set_transport()` returning false and from the I/O error paths. The patch adds a jump to an exercised label. EX-041's later `g_main_loop_run` / bad-`free` crash is not this path; I did not re-investigate it beyond reading that clearance.

**Would change my mind:** a caller-visible protocol where a NULL `setup->stream` at accept-complete is supposed to create or reopen a stream from the new fd.

### F9. No `Fixes:` tag is the right call
**Grade:** note  
**Checked at:** GitHub copies of `125a2e237e7c`, `90a600895d80`, `fe9ba4ff0475`.

- `125a2e237e7c` (2017) — setup itself disappearing during `bt_io_accept`. Different object.
- `90a600895d80` (2020) — early L2CAP, callee only, still assumes non-NULL `stream`.
- `fe9ba4ff0` (2015) — `git log -S` on the unchecked call lands here because that is where the text last moved, not where a NULL stream became possible.

Putting `Fixes: fe9ba4ff0` on this patch would be a lie. Citing the two hardenings in prose is what I would do. A GitHub issue URL is optional and not required for the mail.

**Would change my mind:** a commit whose change is "transport_cb may see a live setup with a NULL stream" that we are actually repairing.

### F10. Format on 0002
**Grade:** nit  

Subject 46 characters, no `Signed-off-by`, `[PATCH BlueZ]`, `commit <12+ hex> ("title")` split at 72 the way checkpatch wants. The quoted segfault line is over 72 and exempt. Fine as submitted.

---

## Cross-cutting

### F11. Neither patch claims to fix the controller hang
**Grade:** note (clean)  
**Checked at:** both commit messages, `patches/bluez/README.md`, `mail-notes/0001.txt`, `mail-notes/0002.txt`.

The messages name the QCA9377 as the machine that crashed. They do not say the guard restores HCI. The README says the opposite. The notes below `---` are context and `git am` will drop them. I would leave them below `---`, not above.

### F12. No cheap `unit/` hook
**Grade:** note  
**Checked at:** `unit/` listing on current BlueZ master (`test-mgmt.c`, `test-avdtp.c`, no `test-adapter.c`, no A2DP setup/accept test).

I do not see a way to drive either callback into the guarded state from BlueZ's existing `unit/` tests without new stubs for `btd_adapter` / the A2DP setup list. `test-mgmt.c` could inject a Command Status with `length 0, param NULL`; that would test `mgmt.c`, not the adapter branch. Worth doing later. Not a reason to hold these mails.

A throwaway C harness that calls `start_discovery_complete(SUCCESS, 0, NULL, adapter)` with `discovery_list == NULL` would have been a crash before and a return after. Same idea for `transport_cb` with a listed setup and `stream == NULL`. I would accept the patches without that harness.

### F13. `HACKING` as I read it at current master
**Grade:** note  

Matches what the project measured: no `Signed-off-by`, 50/72, `[PATCH BlueZ]`, split by top-level directory, bug fixes first. I do not have a better read of current list habits than the tree. I am not aware of a recent list turn that would make either subject or the missing `Fixes:` on 0002 look odd.

`patches/bluez/git-am-check.sh` reports "no body line over 72". Quoted backtrace lines are over 72; they are exempt. Not a defect in the patches.

---

## Things read and found clean (silence is not a result)

- Diff of `0001` against `start_discovery_complete()` at `c73fa2f9a` and `ebbb4ee31`.
- Diff of `0002` against `transport_cb()` at `c73fa2f9a` and `ebbb4ee31`.
- `avdtp_stream_set_transport()` still has no NULL guard at `ebbb4ee31`.
- Command Status vs Command Complete log strings and callback arguments in `src/shared/mgmt.c`.
- `MGMT_OP_START_DISCOVERY == 0x0023`, `MGMT_EV_CMD_STATUS == 0x0002`.
- Archived 08-14 daemon log sequence and kernel segfault line, as quoted.
- Four `0002` guard strings in EX-041; the fifth EX-041 line is the *old* `Wrong size…` site (list non-empty), not `0001`'s new guard.
- Prior commits named in the messages resolve and say what the messages say they say.
- Mail notes live under `patches/bluez/mail-notes/`, not repo-root `mail-notes/` (the task doc's root path 404s). Content is route context, correctly placed below `---`.

## Not opened / not settled here

- `lore.kernel.org` (not searched). Status is "not fixed in master `ebbb4ee31`", not "never posted".
- The Ubuntu `5.72-0ubuntu5.5` binary and the retained core. Crash-site identification is taken from the 2026-08-23 note plus source/log consistency, not re-done.
- `evidence/sessions/20260814-212211-trial-stock-2-hang/timeline.txt` (kernel.log used instead).
- Live journal on the investigation machine. EX-041's four firings and the 09-08 `Wrong size…` line are taken as the project's record.
- Full `net/bluetooth/mgmt.c` Start Discovery implementation. I am not in a position to say whether a successful Command Status is a kernel bug.
- `reviews/2026-09-19T1500Z-r2-disposition.md` and the front-door review.

A machine-side item that would settle F4's optional follow-up: the next Status/success Start Discovery on `btmon`, to see whether the kernel actually started discovery.

---

## After forming the view: the 2026-09-18 third-party review

Read: `reviews/2026-09-18T0700Z-third-party-bluez-patch-review.md` (verbatim section), plus the project's verification preamble.

**Agree**

- Both patches should go up, independently.
- Both defects were still in master at the commit that reviewer used (`2401054`, 2026-09-17); they still are at `ebbb4ee31` a day later.
- `0001` is an ordering bug; duplicating the length check inside the branch is the conservative fix.
- Residual orphan discovery is acceptable; inventing a `type` is not.
- `0002` is the right caller-side check; `drop:` is the right exit; the 2017 setup-lifetime fix and the 2020 early-transport fix are different cases.
- No valid `0002` behaviour is lost.
- A callee `if (!stream) return FALSE;` is optional defense in depth and should not replace this patch.
- Neither mail is a hang fix.
- Deterministic harnesses are possible and not required to send.

**Disagree (left as disagreement)**

- The "strong additional lead" that `request_complete()`'s index-only fallback (`6efdbd8dbd16`) delivered a `0x0023` Status to a pending `0x003A` callback. On the archived 08-14 log every `command 0x23 status: 0x00` is preceded by `send_request … command 0x0023`, and the fallback's own `Unable to find request` line is absent. The current `0001` message no longer carries the wrong `START_SERVICE_DISCOVERY` label that lead was built on. I do not treat the fallback as part of the crash reconstruction. The fallback remains real code and a reasonable separate audit; it is not why these five Status lines landed in `start_discovery_complete()`.
- I would not add `if (!rp || length < sizeof(*rp))` to `0001`. `length == 0` already covers the Status path, and matching the existing check is enough.

**Add**

- `confirm_cb()` already refuses `bt_io_accept` when `!setup->stream`. That is independent evidence the tree knows the pointer is nullable at the start of the accept, and that `0002` is the missing end-of-accept half of a check the file already performs.
- Current master at this review is `ebbb4ee31` (2026-09-18), newer than the first reviewer's `2401054`. Still vulnerable; both hunks still apply, with line offset.
- Two non-success Start Discovery completions (`complete: 0x05`) ran through the no-clients branch in the 10 s window before the fatal Status. That is extra reconstruction support, not a message defect.
- `0001` identical diagnostic string: nit only.

---

## Disposition

| patch | code | message | send |
|---|---|---|---|
| `0001` | accept | accept | separate mail |
| `0002` | accept | accept | separate mail |
