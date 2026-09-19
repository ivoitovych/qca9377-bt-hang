# Second independent review of the two BlueZ patches — 2026-09-19T17:00Z

**Source.** A second independent reviewer, working from
`docs/review-task-bluez-patches.md`, the repository at `f0689217`, and BlueZ master
`ebbb4ee31ad7011cead3d6394c68d10076ab55fc` (2026-09-18). The review is reproduced verbatim
in §"The review" below. Its two `https://reference-url-citation.invalid/…` links are the
reviewer's tool's placeholders and carry no content; they are kept rather than edited out.
The reviewer states the conclusions were formed before the first review
(`2026-09-18T0700Z-third-party-bluez-patch-review.md`) was read.

**Verdict as given.** No blocker. One SHOULD FIX, message only, in `0001`. `0002` ready as
written. Both defects present at `ebbb4ee3`. Keep the patches independent. "After the
`0001` wording correction, I see no remaining issue that should delay submission."

**What this side did with it** is in §"Verification": the one finding is confirmed against
the session files and fixed in the patch and the mail note; the format checks were re-run on
the changed patch; the reviewer's disagreement with the first review is the same one our
verification recorded. Register: `reviews/README.md` §TP2.

## Verification

### TP2-01 — the segfault line is not in the daemon log: confirmed, fixed

```console
$ grep -c segfault evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log
0
$ grep -c 'segfault at 0' evidence/sessions/20260814-212211-trial-stock-2-hang/kernel.log \
                          evidence/sessions/20260814-212211-trial-stock-2-hang/timeline.txt
…/kernel.log:1
…/timeline.txt:1
$ grep -n 'SEGV\|core-dump' evidence/sessions/20260814-212211-trial-stock-2-hang/bluetoothd.log | head -2
4814:Aug 14 21:03:27.924137 n systemd[1]: bluetooth.service: Main process exited, code=dumped, status=11/SEGV
4815:Aug 14 21:03:27.924283 n systemd[1]: bluetooth.service: Failed with result 'core-dump'.
```

Exactly as the reviewer said: the daemon log ends its own record with the callback entry at
21:03:26.994484 and then systemd's notice; the kernel's `segfault at 0` at 21:03:26.995487 is
in `kernel.log` (and the merged `timeline.txt`). The patch message now reads "The archived
session logs show exactly that sequence: the daemon's debug log … ends with the Command
Status delivery and the callback entry …; the contemporaneous kernel log records the
resulting fault", and the quoted block labels its lines `bluetoothd:` and `kernel:`.
`mail-notes/0001.txt` says "the archived session record (daemon debug log and the kernel log
beside it)". Re-verified after the change:

```console
$ patches/bluez/git-am-check.sh /var/cache/bt-investigation/bluez c73fa2f9a | tail -3
  PASS  no Signed-off-by in either patch
  PASS  subject 49 chars · subject 46 chars · no body line over 72

all 6 checks passed
$ patches/bluez/checkpatch-check.sh /var/cache/bt-investigation/bluez | grep 'error(s)'
   0001-adapter-Fix-crash-on-short-start-discovery-reply.patch: 0 error(s), 1 warning(s), 0 check(s)
   0002-a2dp-Fix-crash-on-NULL-stream-in-transport_cb.patch: 0 error(s), 1 warning(s), 0 check(s)
```

### TP2-02 … TP2-05 — agreement with the record: no action

The reviewer's readings of `0001`'s ordering bug, its `Fixes:` target, the residual, and of
`0002`'s invariant, its use of `drop:`, and its deliberate lack of a `Fixes:` tag match what
`patches/bluez/README.md` says and what the first review found. Nothing to change.

### TP2-06 — regression tests: refined, still open

The reviewer names the concrete seam the first review did not: `unit/test-mgmt.c`'s
`SOCK_SEQPACKET` socketpair can feed a successful `MGMT_EV_CMD_STATUS` and assert the
callback contract (`status 0, length 0, param NULL`); the fixed callbacks themselves are
static and need a seam or refactor the reviewer would not add to a crash fix. Recorded as
the follow-up shape; not a prerequisite. Matches TP-06's disposition.

### TP2-07 — the first review's index-fallback lead

The reviewer independently reaches what §TP-04 of the first review's verification recorded:
request and reply both carry `0x0023`, the exact match succeeds, the fallback is not taken.
Two readers, two routes, one conclusion. The reviewer also states the remaining question the
way the patch now leaves it: *why* the kernel produced a successful Command Status is a
kernel-side matter and not this patch's business.

### TP2-08 — BlueZ master `ebbb4ee3`

One day newer than the first reviewer's `2401054`, two months newer than the local
`c73fa2f9a`; both constructs reported unchanged. Recorded in the README's verification table
as the reviewer's observation; not re-run locally.

## The review

Reproduced verbatim from the operator's paste of 2026-09-19.

---

Independent review of two BlueZ crash-fix patches

Review date: 2026-09-19

Project repository revision reviewed:
"f0689217ecdf70f520c4c0e35dcf2115c4e13097"
"project commit f0689217" (https://reference-url-citation.invalid/0)

BlueZ revision reviewed:
"ebbb4ee31ad7011cead3d6394c68d10076ab55fc" ("master", committed 2026-09-18)
"BlueZ commit ebbb4ee3" (https://reference-url-citation.invalid/1)

I formed the technical conclusions below before reading the previous third-party review. I read that review afterward and compare conclusions near the end.

Overall result

No blocker found.

One SHOULD FIX, message only: patch "0001" slightly conflates two evidence sources when it says that the daemon debug log contains the final kernel "segfault" line. The daemon log contains the management delivery and callback immediately before death; the "segfault at 0" line comes from the session timeline/kernel log. The combined session evidence fully supports the patch's causal reconstruction, but the provenance should be stated precisely.

With that wording corrected:

"0001": ready to submit.
"0002": ready to submit as written.

Both defects remain present in BlueZ "master" at "ebbb4ee31ad7011cead3d6394c68d10076ab55fc". In current "adapter.c", the no-clients branch still accesses "rp->type" before the existing reply-length validation. In current "a2dp.c", "transport_cb()" still passes "setup->stream" unchecked into "avdtp_stream_set_transport()", whose current implementation immediately accesses "stream->session".

The submitted changes are narrow crash hardening and do not claim to fix the QCA9377 controller wedge. That distinction is clear in the patches and supporting README.

Finding 1 — SHOULD FIX — "0001" slightly misattributes the final crash line to the daemon debug log

Checked: "0001", the archived "bluetoothd.log", "timeline.txt", EX-041, the crash-site reconstruction, and the current "src/shared/mgmt.c", at the project and BlueZ revisions above.

The patch currently says:

«"The daemon's debug log (bluez 5.72) ends with exactly that delivery…"»

and then presents a sequence whose final line is the kernel's "bluetoothd[2821]: segfault at 0 ...".

The technical sequence is correct, but those records come from two files.

The archived "bluetoothd.log" ends the daemon's useful record with:

"21:03:24.943018" — Start Discovery request "0x0023"
"21:03:26.994468" — "command 0x23 status: 0x00"
"21:03:26.994484" — "start_discovery_complete() status 0x00"

and then records systemd noticing that the process exited with SIGSEGV.

The actual kernel:

"bluetoothd[2821]: segfault at 0 ..."

line is in the session "timeline.txt", where it follows the two BLUED lines at 21:03:26.

This does not weaken the technical case. On the contrary, the two independent streams line up exactly: daemon records callback entry, kernel records the immediate fault, and the separately reconstructed instruction at the fault address is "rp->type". But BlueZ's own contribution guidance expects the commit message to carry the evidence accurately, so I would remove this small ambiguity before sending.

A minimal correction would be:

«"The archived session logs show exactly that sequence. The daemon debug log ends with the Command Status delivery and callback entry; the contemporaneous kernel log records the resulting fault:"»

The corresponding sentence in "mail-notes/0001.txt" should likewise say "the archived session record" or "the daemon log and session timeline", rather than attributing the complete sequence including the fault to the daemon log alone.

What would falsify this finding: showing that the reviewed "bluetoothd.log" itself contains the quoted kernel segfault record. The file at project commit "f0689217" does not; "timeline.txt" does.

Severity rationale: message/evidence provenance only. No code change is required and none of the substantive crash claims depends on the wording error.

Finding 2 — NOTE — "0001" fixes a real ordering bug and does not alter a valid reply path

Checked: patch "0001", current "src/adapter.c", current "src/shared/mgmt.c", and the documented management protocol.

The vulnerable ordering remains straightforward:

rp = param

if no discovery clients:
        if status != SUCCESS:
                return
        cp.type = rp->type       <-- use
        ...
        return

if length < sizeof(*rp):         <-- validation too late for branch above
        ...

Patch "0001" adds the same size requirement inside the exceptional no-clients branch, immediately before the first dereference.

Current BlueZ's shared mgmt code makes the observed callback shape possible: "MGMT_EV_CMD_STATUS" invokes "request_complete()" with the event status and explicitly supplies "length = 0" and "param = NULL".

The official BlueZ management protocol describes Start Discovery ("0x0023") as having a one-octet return parameter and normally generating Command Complete. Thus the observed successful zero-parameter Command Status is abnormal, but the callback must nevertheless survive it.

I tried to construct a valid Start Discovery result whose behavior would be changed by the new check and could not. For the no-client branch:

- failure status still returns before the new check;
- a valid one-byte-or-longer response proceeds exactly as before;
- only a successful response too short to contain "rp->type" takes the new return.

That is precisely the invalid state that cannot safely execute the old code.

What would falsify this finding: a valid management-protocol completion for this callback in which "length < sizeof(struct mgmt_cp_start_discovery)" but "rp->type" nevertheless has defined semantics that BlueZ is required to use. I found no such case.

Finding 3 — NOTE — "0001"'s residual "cannot send Stop Discovery" behavior is the right local failure mode

Checked: the current discovery code around "start_discovery_complete()", "trigger_start_discovery()", discovery state tracking, and the patch's README discussion.

When there are no clients and BlueZ receives a malformed successful completion with no returned type, the patch returns rather than issuing "MGMT_OP_STOP_DISCOVERY".

That leaves a residual possibility: if the controller actually started discovery despite returning an invalid response, the callback does not immediately stop it.

I do not see a safer local alternative.

The Stop Discovery request requires a discovery "type". That is precisely the byte that is missing. Manufacturing one from current adapter state or recomputing "get_scan_type()" would implicitly assume that present userspace state still describes the request that was sent seconds earlier. In this race, that is not a reliable assumption.

A larger redesign could retain the original requested type in callback-specific context and use it during malformed completion handling. That might eliminate the residual, but it would turn this six-line crash fix into a state/lifetime change with materially more surface area.

For this patch, discarding an unusable reply while keeping "bluetoothd" alive is the appropriate trade.

What would change my view: demonstration of an existing, authoritative value in the current callback state that is guaranteed to be the type of the exact pending request. In that case BlueZ could safely send Stop Discovery even when the response payload is absent.

Finding 4 — NOTE — "0001"'s "Fixes:" tag is precise

I independently checked upstream commit "3597d1377723705e3fa6736610fcdb64ee6f2ce1".

That commit introduced the asynchronous "clients disappeared while Start Discovery was pending" handling and placed:

cp.type = rp->type;

in that branch ahead of the reply-length validation.

So:

"Fixes: 3597d1377723 ("adapter: Fix not waiting for start discovery result")"

identifies the introducing change rather than merely a nearby refactor. I would keep it.

What would falsify this finding: older reachable BlueZ code containing the same unsafe no-client dereference before "3597d1377723", or evidence that "3597d1377723" merely moved existing faulty code. Its diff shows otherwise.

Finding 5 — NOTE — "0002" fixes the correct lifetime invariant at the correct point

Checked: patch "0002", current "profiles/audio/a2dp.c", current "profiles/audio/avdtp.c", all current visible assignments of "setup->stream = NULL", the retained-core reconstruction, and EX-041.

The existing first guard in "transport_cb()" establishes:

setup is still a member of setups

It does not establish:

setup->stream != NULL

Those are different lifetime invariants.

Current "a2dp.c" still has multiple paths that clear "setup->stream". "transport_cb()" subsequently calls:

avdtp_stream_set_transport(setup->stream, ...)

without rechecking it. Current "avdtp_stream_set_transport()" accesses "stream->session" immediately.

The retained-core evidence is unusually strong here: the faulting load is at offset "0x10" from a register whose retained value is zero, matching "struct avdtp_stream::session". The runtime guard subsequently fired four times with a valid "setup" and NULL "stream", demonstrating that this is not merely a theoretically constructible state.

The location of the new check is also good. It comes after the callback has handled an incoming "GError" and after "bt_io_get()" has been allowed to report its own error. Therefore the new lifecycle diagnostic does not mask a primary I/O failure.

I tried to construct a legitimate operation that is lost by the new branch and could not. Once this callback has a valid "setup" but no stream, there is no destination to which the accepted transport can be attached. The existing "drop:" path is therefore the conservative operation.

What would falsify this finding: evidence that "setup->stream == NULL" is an intentional recoverable state at this point and that existing BlueZ code subsequently reconstructs or selects the intended stream for this already accepted transport. I found no such mechanism.

Finding 6 — NOTE — using the existing "drop:" path in "0002" is preferable to inventing teardown

Checked: the success and error exits of current "transport_cb()" and the setup/channel ownership introduced by earlier lifetime hardening.

The patch does not add another cleanup implementation. It jumps to the callback's existing failure path:

setup_unref(setup);
g_io_channel_shutdown(io, TRUE, NULL);

That is consistent with the callback's existing handling of failed acceptance and failed "bt_io_get()".

A NULL check inside "avdtp_stream_set_transport()" could additionally be useful as defense in depth, but it should not replace the caller-side check. The caller knows why this particular NULL is interesting and can emit a useful lifecycle diagnostic. A lower-layer guard would merely convert the crash into a generic "FALSE", and it would need to be placed before even constructing the "GIOChannel".

What would change my view: proof that the existing "drop:" path itself is inappropriate for an already completed accept specifically when the AVDTP stream has disappeared. The current ownership code and the four observed guard firings provide no indication of that.

Finding 7 — NOTE — omitting "Fixes:" from "0002" is defensible

I checked the two historical commits cited in the message.

"125a2e237e7c..." hardened the same asynchronous accept window against the entire setup disappearing while "bt_io_accept()" was pending. It does not establish that this was the commit that first made "setup->stream" capable of disappearing independently.

"90a600895d80..." extended "avdtp_stream_set_transport()" to handle the transport arriving before Open. It assumes that the "stream" pointer itself is valid and therefore does not address this defect.

Neither is an honest "introduced the bug here" "Fixes:" target.

I therefore prefer the current prose references to a speculative "Fixes:" tag.

What would change my view: a history/bisection result identifying the exact commit that first created the reachable "setup alive / setup->stream NULL / accept callback pending" state. If such an introducing commit is found, adding a "Fixes:" tag would then be appropriate.

Regression tests

I looked specifically for a deterministic test path in current BlueZ.

There is a promising existing mechanism for the premise of "0001": "unit/test-mgmt.c" creates a "SOCK_SEQPACKET" socketpair and feeds synthetic management responses to "src/shared/mgmt.c". It should be straightforward to add a test that queues Start Discovery and returns a successful "MGMT_EV_CMD_STATUS", then asserts that its callback receives status success, "length == 0", and "param == NULL".

That test would lock down the mgmt-layer behavior but would not directly exercise the fixed branch, because "start_discovery_complete()" is static inside "src/adapter.c" and requires substantial adapter/D-Bus state. Direct coverage would require either a test seam around that callback or a small refactoring. I would not enlarge this crash fix solely to make the static callback convenient to unit-test.

The situation for "0002" is similar. BlueZ has "unit/test-avdtp.c", but the actual vulnerable callback is static in "profiles/audio/a2dp.c" and depends on an "a2dp_setup", pending asynchronous accept, and channel state. A deterministic test is possible, but it is not a small addition to the current unit harness.

Consequently, I regard dedicated regression tests as valuable follow-up work, not a prerequisite for these two minimal crash fixes. The field evidence for "0002" in particular is stronger than is usual for this class of guard.

I did not rerun the project's build, "git am", or checkpatch scripts; the task explicitly records those checks and says they need not be repeated. I did independently inspect both patch contexts against BlueZ "master" newer than the revision recorded by the task. The vulnerable constructs remain unchanged at "ebbb4ee31ad7".

Negative results / things checked and found sound

I found no valid reply whose handling "0001" changes. I found no evidence that the "0001" guard should fabricate a missing discovery type. I found no reason to move the check above the failure-status return. I found no problem with its "Fixes:" attribution.

For "0002", I found no legitimate operation available when the setup is valid but its stream is NULL, no reason to put the new check ahead of the existing I/O error handling, no teardown better than the existing "drop:" path for this minimal fix, and no historical commit I would confidently label as the introducing commit.

I also found no claim in either patch that it fixes the larger QCA9377 controller hang. Both messages correctly present the crashes as userspace failures encountered in that environment rather than the cause of the controller failure.

BlueZ's current "HACKING" rules continue to require 50/72 formatting, "[PATCH BlueZ]", and explicitly prohibit "Signed-off-by"; the project's stated format choices are therefore still appropriate.

Comparison with the first independent review

After reaching the conclusions above, I read "reviews/2026-09-18T0700Z-third-party-bluez-patch-review.md".

I agree with its central conclusions: both code defects are real, the two local fixes are appropriately narrow, "0002" has particularly strong runtime evidence, the patches are independent, and unit-level regression coverage would be useful.

I disagree with the original review's "strong additional lead" involving "request_complete()"'s index-only fallback. That hypothesis depended on the then-incorrect record labelling opcode "0x0023" as Start Service Discovery.

The corrected archived log shows:

send request: 0x0023
receive Command Status for: 0x0023

so opcode + index already match. Current "request_complete()" first searches by exactly opcode + index and resorts to its index-only fallback only if that search fails.

The original fallback hypothesis therefore does not explain this event. The repository's subsequent verification correctly records this correction. The unresolved question is simpler and narrower: why the kernel produced a successful Command Status for Start Discovery at all. Patch "0001" accurately leaves that unanswered.

That disagreement has no adverse effect on "0001"; the patch needs only the observed callback contract violation, not an explanation of why the kernel emitted it.

What remains unsettled

Neither patch requires access to the affected laptop to establish its correctness.

For "0001", the remaining machine/kernel question is why this controller/kernel path produced successful Start Discovery Command Status events rather than the documented one-byte Command Complete. Raw management capture plus the corresponding Linux kernel path would settle that. It belongs in a separate kernel-side investigation, not in this BlueZ crash fix.

For "0002", instrumentation could identify exactly which AVDTP error/teardown transition most commonly clears "setup->stream" while the transport accept remains outstanding. That would be useful architectural information, but again the NULL dereference and the correctness of the local guard do not depend on knowing it.

Final disposition

"0001-adapter-Fix-crash-on-short-start-discovery-reply.patch"
No code changes requested. Fix the evidence-source wording described in Finding 1, including the matching mail note. Then submit.

"0002-a2dp-Fix-crash-on-NULL-stream-in-transport_cb.patch"
No changes requested. Submit as written.

Series structure: keep them independent and mail them independently. They have separate causes, separate affected subsystems, separate historical context, and no dependency on one another.

After the "0001" wording correction, I see no remaining issue that should delay submission.
