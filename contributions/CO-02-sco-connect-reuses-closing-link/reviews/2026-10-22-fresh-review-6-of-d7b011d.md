# CO-02 — from-scratch review of `d7b011d` by reviewer 6, with their follow-up comments

*Received 2026-10-22, after v4 was published; it reviews v3's mails. Kept as received, except for
the reviewers' tooling marks, which `scripts/review-text-clean.py` removes, and one quoted
trailer value, replaced by "with an `Assisted-by:` trailer". What each point led to: `../log.md`,
entry "reviewer 6's from-scratch review; v5".*

---

---

## Reviewer 6

# CO-02 review at `d7b011d` — kernel series "Bluetooth: hci_conn: fix SCO connection reuse" and "[PATCH BlueZ] tools/sco-tester: Add SCO reconnect tests"

Date: 2026-10-22. Written from the mails in `patch/v3/send/` and the code, before reading `reviews/` or `log.md`; the earlier reviews were opened afterwards only to see what they had already covered.

## Verdict

The series is real, small, correct as far as I can trace it, and well written. All three bugs reproduce by reading the code at the base; the fixes are the minimal ones; the Fixes: commits are the right ones; checkpatch is clean; the patches apply with `git am` on bluetooth-next `27731ba09195` (final tree `f5424dd92043`, as the evidence says) and also on torvalds master of today. The BlueZ test is sound: it cannot pass on the broken kernel and it cannot fail on the fixed one in any sequence I could construct. Nothing here would make a maintainer do work you could have done.

Three things I would settle before sending, in this order:

1. **The written rule on tool-generated content.** `Documentation/process/generated-content.rst` (in tree) says contributors must be transparent in changelogs and cover letters when a meaningful part of the content was produced by a tool, and that maintainers may reject undisclosed tool-made work without review. The subsystem practice is the `Assisted-by:` trailer: 3,407 commits in mainline since 2026-01-01 carry one, 112 of them `Bluetooth:` commits, including Luiz's own. BlueZ's `doc/coding-assistants.rst` asks for `Assisted-by: AGENT:MODEL` too. Whether that applies to these mails depends on how the code and the text were produced, which only you know. This is the only place where the package can be out of step with a written rule, so decide it consciously rather than by default.
2. **One honest sentence the mails lack.** A connect() that arrives after close() but before the disconnect worker has *started* still cancels the worker and keeps the live link, with the old air mode and no new Setup. The series does not change that, and the cover letter's "the series makes connect() report what happens" is not true for that case. Say so in one sentence (patch 3 or the cover), or close it (see §2).
3. **Run the series on the laptop once** (Ubuntu 7.0.0-38, the patches apply there) with the real headset and PipeWire, and say in the cover whether the real codec switch ends in `ECONNABORTED` as predicted. The evidence file says "no hardware was used". The maintainer cannot tell that from the cover letter, and the bug was found on hardware.

Everything else below is smaller.

## What was checked

- `git am` of the three patches onto bluetooth-next `27731ba09195` (GitHub mirror `bluez/bluetooth-next`; the mirror head is the base plus five CI-workflow commits) and onto torvalds master `a1c2b1da93f5` (2026-10-22). Both clean. Final tree id `f5424dd92043` matches the evidence.
- `scripts/checkpatch.pl --strict` on all four kernel mails: 0 errors, 0 warnings, 0 checks (the only output on my shallow clone was "unknown commit id", which is the clone, not the patches). `get_maintainer.pl`: Marcel, Luiz, linux-bluetooth, linux-kernel.
- Every function the messages name, read at the base: `hci_connect_sco`, `hci_connect_acl`, `hci_conn_link/unlink`, `hci_conn_hold/drop`, `hci_conn_timeout`, `hci_abort_conn`, `hci_cancel_connect_sync`, `hci_cmd_sync_run_once`, `hci_conn_del`, `hci_conn_cleanup_child`, `hci_conn_set_handle`, `hci_proto_disconn_ind`, `l2cap_disconn_ind`, `hci_conn_request_evt`, `hci_sync_conn_complete_evt`, and in `sco.c` `sco_connect`, `sco_conn_add`, `sco_chan_add`, `__sco_chan_add`, `sco_chan_del`, `__sco_sock_close`, `sco_conn_del`, `sco_conn_ready`, `sco_connect_cfm`, `sco_disconn_cfm`; plus `__sco_sock_close` and `sco_chan_add` at `e6720779ae61^` for the "before the kref" claim.
- The five commits the messages cite exist with the quoted titles and authors: `06149746e720` (2023-04), `e6720779ae61` (2024-10), `8a5b0135d4a5` (2026-03), `e06d549fcd4a` (2026-09-15), `816fb1590a4c` (2026-09-26).
- BlueZ: the test applied with `git am` on master `7bc9684dc9e4`; `tools/sco-tester.c` compiles (`gcc -fsyntax-only -Wall -Wextra -Werror` with glib); checkpatch with BlueZ CI's ignore list is clean; `btdev_send_event`, `vhci_get_btdev`, `hciemu_add_central_post_command_hook` and `HCIEMU_HOOK_POST_EVT` exist on master and `run_hooks()` in `emulator/btdev.c` confirms that a POST_EVT hook returning false drops the event.
- PipeWire master `spa/plugins/bluez5/backend-native.c`: `sco_do_connect()` retries `connect()` at once on `ECONNABORTED`, twice, with no delay — the cover letter's claim is accurate. On `AT+BCS=` the transport is recreated ("previous connection may now be invalid"), which frees the old transport and its socket; the new connect comes later from the acquire path.
- The linux-bluetooth list (spinics mirror; lore and patchwork are not reachable from here): see §6.
- In-tree process docs: `submitting-patches.rst`, `stable-kernel-rules.rst`, `generated-content.rst`, `coding-assistants.rst`; BlueZ `HACKING`, `doc/coding-style.rst`, `doc/maintainer-guidelines.rst`, `doc/coding-assistants.rst`, `.gitlint`.

## 1. Correctness of the kernel series

### Patch 1 — hold a reused SCO connection for its caller

Traced at the base. Link up, socket A holds the SCO (`__sco_chan_add` → `hci_conn_hold`, refcnt 1). Socket B connects: `hci_connect_acl()` takes a hold on the ACL; lookup finds the SCO; `hci_conn_link()` returns the existing `conn->link` and takes nothing; `sco_connect()` → `sco_chan_add()` fails `-EBUSY` (`conn->sk` set) → `hci_conn_drop(hcon)` → SCO refcnt 0 → `disc_work` queued with timeo 0 → `hci_conn_timeout()` → `hci_abort_conn()`. Socket A's link is disconnected. The ACL hold from `hci_connect_acl()` is never dropped on that path, so the ACL also never idles out. Both are real; the patch fixes both; the message describes both (the ACL part only implicitly — "drop the ACL reference, which the existing link already owns" — which is fine).

After the patch the refcount accounting on every path of `hci_connect_sco()` balances: new link → hold from `hci_conn_link()` passed to the caller; existing link → explicit hold, ACL hold returned; link failure → both dropped. `hci_conn_unlink()` does not drop the child, so there is no double drop later. Same shape as `e06d549fcd4a` for CIS; the precedent was applied by Luiz three weeks before the base, so the pattern is fresh in his mind.

Stable subtlety (not a defect, worth knowing if the stable team asks): on 6.6.y/6.12.y `sco_connect()` only drops the caller's reference on failure paths and otherwise consumes it in `sco_conn_add()` for a new `sco_conn`. Patch 1's extra hold on the reuse path is therefore balanced there only because the reuse path can never succeed before the kref change (the closed socket stays attached in `BT_DISCONN`, so `sco_chan_add()` always answers `EBUSY`). Your 6.6.160 and 6.12.114 runs show exactly that (only Connect Twice changes). No action needed.

### Patch 2 — don't reuse an aborting SCO connection

Traced. After close(), `sco_chan_del()` drops the socket's hold, `disc_work` runs, `hci_abort_conn()` sets `abort_reason` and queues the Disconnect; the SCO stays `BT_CONNECTED`; `hcon->sco_data` stays set, `conn->sk` is NULL. Socket B's connect finds the SCO, links (or, with patch 1, holds), skips setup because state is `BT_CONNECTED`, `sco_chan_add()` succeeds, `sk_state = BT_CONNECTED`, connect() returns 0; the Disconnection Complete then runs `sco_conn_del(hcon, bt_to_errno(0x16))` = `ECONNABORTED` on socket B. Confirmed. The pre-kref claim is also right: at `e6720779ae61^`, `__sco_sock_close()` left the socket attached in `BT_DISCONN` with `conn->hcon = NULL`, so `sco_chan_add()` answered `EBUSY`.

`abort_reason` is written only by `hci_abort_conn()` and never cleared, and `hci_conn_set_handle()` already refuses to give a handle to a connection with `abort_reason` set, so "has `abort_reason`" is a sound definition of "on its way out". The check sits before the link/hold step, so a refused connect leaks nothing: only the ACL hold from `hci_connect_acl()` is returned. `-ECONNABORTED` is the error the socket would otherwise get later; defensible. Luiz may still ask "why not `-EBUSY`, which older kernels gave?" — the answer in the message (same error, earlier) is good; keep it.

### Patch 3 — wait for a running SCO disconnect before reuse

Traced. `hci_conn_hold()` does `cancel_delayed_work()`, which does not wait for a running `hci_conn_timeout()`; that worker reads `refcnt` without the lock and then calls `hci_abort_conn()`. A connect that lands between the read and `abort_reason` being set passes patch 2's check and takes over a connection that is aborted an instant later. `cancel_delayed_work_sync()` after the hold, then re-check, is the right order: a worker not yet started was cancelled by the hold; a worker past its read is waited for and has set `abort_reason` when the wait returns. On refusal `hci_conn_drop(sco)` re-queues `disc_work`, which finds `abort_reason` set and does nothing — harmless.

The deadlock question, which is the question a maintainer will ask: `hci_connect_sco()` runs under `hdev->lock` (`sco_connect()` takes it; it is the only caller). For a SCO connection `hci_conn_timeout()` takes: `hci_proto_disconn_ind()` → constant for non-ACL/LE; `hci_abort_conn()` → `hci_cancel_connect_sync()` returns `-ENOENT` for SCO (the switch has no SCO case) → `hci_cmd_sync_run_once()` → `hci_cmd_sync_run()` → not on `cmd_sync_work`, so `hci_cmd_sync_submit()`, which takes `cmd_sync_work_lock` and `unregister_lock` only. No `hdev->lock`. For ACL/LE the same worker takes `cmd_sync_work_lock` only. And `hci_conn_del()` already does `disable_delayed_work_sync(&conn->disc_work)` under `hdev->lock` (its callers hold it), so lockdep already knows this ordering; your lockdep-enabled runs confirm. The message says all this in four lines; good. The in-code comment repeats the key fact ("It does not take hdev->lock"), which is what a future reader needs.

`cancel_delayed_work_sync()` on a never-queued work (the brand-new connection path) is a no-op; fine.

### What the three patches do not cover (the point for §2)

Between `hci_conn_drop()` queuing `disc_work` (close) and the worker starting, a connect() that finds the SCO sees no `abort_reason`, `hci_conn_hold()` cancels the pending work, `cancel_delayed_work_sync()` has nothing to wait for, and the new socket keeps the live link: `sco->setting`/`codec` are overwritten but no Setup Synchronous Connection is sent, so the air mode stays what it was. Before `e6720779ae61` this was `EBUSY`. The window is "until the ordered high-priority kworker runs", i.e. tens of microseconds on an idle SMP box, longer under load or on UP without preemption. PipeWire's close-to-connect gap (transport recreate on `AT+BCS=`, then a later acquire) is longer than that, so it probably never hits it; the *Disconnect-sent-but-not-complete* window of several milliseconds is what it hits, and that one the series closes.

Two options:
- Disclose: one sentence in patch 3's message or the cover. ("A connect() that arrives before the disconnect work has started at all still cancels it and keeps the live link, as before this series; that is outside this patch.")
- Close it as well, cheaply: extend patch 2's condition to `sco->abort_reason || delayed_work_pending(&sco->disc_work)`. The PENDING bit is set by `queue_delayed_work()` and cleared only when the worker starts, so this catches the queued-not-started case; patch 3 catches started-not-aborted; `abort_reason` catches aborted. `delayed_work_pending()` has in-subsystem precedent (`l2cap_core.c:303`). Residual window: the few instructions in `hci_conn_drop()` between `atomic_dec_and_test()` and `queue_delayed_work()`, which no lock in that path can remove.

I would disclose regardless and leave the hardening for a follow-up unless you want to retest: adding it now means the During test and the parked-race experiment need rerunning, and it invites the question "then why is patch 3 needed?" (answer: the worker may already be running). Note that an earlier reviewer of yours judged this window not worth a sentence in the mail; I disagree, because the cover letter states a general claim that it contradicts, and Pauli, who knows the codec-switch timing, is on copy.

### Other paths through `hci_connect_sco()` after the series

- Incoming SCO request accepted, `BT_CONNECT`, no holder yet (`hci_conn_request_evt` holds nothing for SCO), outgoing connect() to the same device before Synchronous Connection Complete: no `abort_reason`, no link → `hci_conn_link()` holds; state `BT_CONNECT` → no setup; socket attaches and is completed by `sco_conn_ready()`. Unchanged by the series, sensible, and it is why a "refuse when refcnt == 0" alternative (which I considered as a one-patch replacement for 2+3) would be wrong: it would refuse this legitimate cross-over.
- `BT_CONNECT2` (deferred accept): same as above.
- Type mismatch (`SCO_LINK` conn left after an eSCO fallback, lookup by `ESCO_LINK`): a second conn is created for the same address. Pre-existing, out of scope; do not mention.
- `hci_connect_acl()` error path (`hci_conn_del(acl)` when `hci_connect_acl_sync()` fails) is before any of the new code; untouched.
- ACL in `BT_CONNECT` (ACL still being created) with an aborting SCO found: patch 2 drops the ACL hold → ACL refcnt 0 → `disc_work` with timeo 0 → the fresh ACL connect is aborted. That is what the `-ENOLINK` path has always done; consistent.

## 2. What the series does not fix, and whether the mails say so

Said: PipeWire's immediate retry (true in PipeWire master: `for (int retry = 2;;)` … `errno == ECONNABORTED && retry-- > 0` → `continue`, no sleep). Said: independence from Hitalo's series. Not said: the queued-not-started window above. Also not said, and I think should be: that the series was tested only in the emulator so far (see §10).

## 3. The commit messages, sentence by sentence

Every statement checks out against the code and history. Wording that could trip a tired reader:

- Patch 2, first sentence: "sets up a link only if that connection is BT_OPEN or BT_CLOSED". In patch 1 "link" means `struct hci_link`; here it means the SCO air link. Luiz will read "link" as `hci_link`. Say "sends a Setup Synchronous Connection only if …".
- Patch 2: "hci_abort_conn() only sets abort_reason" — it sets `abort_reason` and queues the Disconnect; what matters is that it does not change `state`. Suggest: "hci_abort_conn() sets abort_reason and queues the Disconnect but leaves the state alone, so the connection stays BT_CONNECTED until the Disconnection Complete event arrives."
- Patch 3, first paragraph is one 11-line sentence chain. Fine for Luiz; for the hangover reader, break after "…sets abort_reason." and start "A connect() that finds the connection in that window…".
- Patch 1: "A new connection gets the reference from hci_conn_link()." True, but "reference" and "hold" are both used; the code says `hci_conn_hold`, the CIS precedent says "hold". Pick "hold" throughout patch 1 (the title already does).
- Cover, paragraph 2: "Patch 1 first fixes the reference a reused connection comes with" — same word; "the hold a reused connection comes with".
- Cover, testing paragraph: add "with lockdep enabled" after "uniprocessor and SMP" — your kernels had `PROVE_LOCKING`/`DEBUG_ATOMIC_SLEEP` (log.md says so), and patch 3 is exactly the kind of change where a maintainer wants to see that word.
- Cover, stable paragraph: correct, but it duplicates what the trailers already encode, and stable works from trailers, not cover letters. Keep it if you like; three sentences would do: "Patch 1 applies alone on 6.6.y and 6.12.y, which have the 8a5b0135d4a5 backport and the reuse path but not e6720779ae61; patches 2 and 3 apply on top of it on 6.18.y and 7.2.y. 6.1.y has no reuse path, hence '# 6.6.x'."
- Cover, "and with headsets that answer AT+BCS quickly the new codec never gets a link": clear and the hook that makes a reader care. Keep.

## 4. Fixes: and stable tags

- Patch 1 `Fixes: 8a5b0135d4a5`: right — that is the commit whose new error-path `hci_conn_drop()` turns the missing hold into the disconnect of the live link. `06149746e720` is where the ACL hold leak began; a second `Fixes:` line would be legitimate but is not needed; the message cites it anyway.
- Patch 1 `Cc: stable@vger.kernel.org # 6.6.x`: the documented form (`stable-kernel-rules.rst`, "Point out kernel version prerequisites"), and correct: 6.1.y has the `8a5b0135d4a5` backport but no `hci_conn_link()`, so without the suffix stable would try and fail there. checkpatch accepts the form without angle brackets.
- Patches 2 and 3 `Fixes: e6720779ae61`, plain `Cc: stable`: right; stable derives 6.18.y and 7.2.y from the Fixes commit, and the series order makes patch 1 the context they need ("you do not have to list patch1 as prerequisite of patch2 if you have already marked patch1 for stable").
- Your stable matrix is better than what most series come with: not just "applies", but sco-tester run on each stable head, unpatched and patched. Say that in one clause of the cover ("and sco-tester gives the same results on those heads").

## 5. Written rules and conventions

| Rule | Status |
|---|---|
| checkpatch `--strict` | clean ×4 (kernel), clean with BlueZ CI's ignore list (BlueZ; the only `--strict` CHECKs are parenthesis alignment, which BlueZ ignores by design) |
| Subject form `Bluetooth: hci_conn: …` | matches the tree; capitalisation after the prefix is mixed in the tree, lower-case is fine |
| `Fixes:` 12-char hash + quoted title | correct |
| Signed-off-by on kernel patches, none on BlueZ | correct both ways (`doc/maintainer-guidelines.rst` rule) |
| Cover letter for a 3-patch series, `base-commit:` | present, generated by format-patch |
| `--- ` section in the BlueZ mail for the dependency note and rebase offer | right place for it |
| BlueZ `.gitlint` title ≤ 72, body present | ok |
| GitLint body lines ≤ 80, no trailing whitespace (the CI runs it on kernel mails too) | no trailing whitespace anywhere; one 82-character `Fixes:` line in patch 1, which must not be wrapped (see §6, item 7) |
| No `Change-Id:`, no attachments, no HTML | correct |
| `get_maintainer.pl` lists `linux-kernel@vger.kernel.org` | you omit it; most Bluetooth core patches on the list do too (see §6); acceptable |
| Target tree marker `[PATCH bluetooth …]` | several recent fixes on the list use it (`[PATCH bluetooth v1] Bluetooth: hci_core: Initialize LTK…`); yours says `[PATCH 0/3]`. Optional, but it tells Luiz where you expect it to land; since the base is a merge of `bluetooth` into `bluetooth-next` it applies to either. Consider `[PATCH bluetooth 0/3]` — see §6 for what the list does |
| `generated-content.rst` / `coding-assistants.rst` / BlueZ `doc/coding-assistants.rst` | see Verdict item 1 |
| `coding-assistants.rst` item 8: say what could not be done (build, test, reproducer) | the cover says what was tested; it does not say the hardware case was not; add it |

## 6. The list's own practice (survey)

About 85 kernel-core threads on linux-bluetooth from early August to 22 October 2026 were read on the spinics mirror; ~45 had a human or bot reply. What that shows, and how the package measures against it:

**Who reviews.** Marcel did not reply to a single core patch in the period. Luiz applies everything (always to bluetooth-next master, then pull to net); Pauli Virtanen is the frequent detailed reviewer. Luiz's single most common reply is one line plus a link to **Sashiko**, an automated LLM review he runs on every patchset ("Sashiko flagged a problem: <link>"). Expect that reply; the authors who answer it point by point get applied, the ones who don't stall. Your `reviews/` folder is, in effect, a Sashiko run done early — good, but the maintainers' Sashiko will raise anything you left open, including the pending-work window in §1.

**Why patches get sent back, most to least frequent, and where this package stands:**

1. Sashiko found something → answer it. (n/a until sent.)
2. Fixing the symptom, or "there is a better way" — Luiz often answers with his own diff (skb_get over skb_clone, "remove le_conn_timeout entirely", "disable the work instead of a new workqueue"). Risk here is moderate: he may ask why patches 2 and 3 are not one, or why the check is not in `hci_conn_hold()` (answer: non-sleeping callers), or why SCO reuse of a `BT_CONNECTED` conn is allowed at all. Your messages pre-empt the first two; have the third ready (the incoming-connection cross-over in §1).
3. "Not tested" / "no new test cases, please add them to *-tester" — asked of Hitalo's SCO series explicitly, of Cen Zhang's 6LoWPAN series ("Something suggests none of this was tested"), and of Kyle Pepper's RPA patch ("needs to be confirmed with mgmt-tester"). You arrive with the tester cases and the counts. This is the strongest part of the package.
4. "The bug does not exist on current bluetooth-next / already fixed" (Pauli, twice, with "revalidate on current master"). You reproduce on the current base with run counts; covered.
5. Wrong base tree → CI "patch does not apply". Based on bluetooth-next master; covered.
6. Tester regressions in CI (iso-tester PAST, l2cap-tester Direct Advertising). You ran sco/iso/l2cap/mgmt; the CI also runs bnep, rfcomm, ioctl, mesh, smp, userchan, 6lowpan — none touch this code.
7. GitLint/CheckPatch hygiene: body lines > 80, trailing whitespace (even below `---`), `Reported-by:` without `Closes:`, missing `Bluetooth:` prefix. Your mails have no trailing whitespace and no `Change-Id:`. One note: patch 1's `Fixes:` line is 82 characters. Kernel rules say never wrap a `Fixes:` line and checkpatch exempts it, but BlueZ's gitlint (B1, 80) may flag it; if it does, ignore it, as Lee Jones did for a changelog line and was applied anyway.
8. Explanations too long / changelog in the body / "Assisted-by: some LLM?" (Pauli, on a v2 whose prose was long). Your messages are tight; the cover letter is the longest text (≈55 lines, within the 10–60 seen).
9. Resending without answering review. n/a.
10. Stable process: Greg's form letter when a not-yet-merged patch is mailed to stable@ — your `git send-email` copies stable@ from the trailers, which is the normal and accepted way (Chengfeng Ye, Aldo, Siwei Zhang all did it); do not send to stable@ separately. Reviewers asked to drop `Cc: stable` from a cleanup and from a fix that needed root plus `rmmod` to trigger; yours are user-triggerable from an unprivileged socket, so the tags are justified.

**Conventions in applied patches, against yours.** Subject `Bluetooth: <area>: <summary>` with either capitalisation: match. `Fixes:` on every fix, `Cc: stable` on about half: match. `Assisted-by:` trailers appear on Luiz's and Pauli's own patches and draw no comment; reviewers ask for one when text looks tool-written, and the one cross-subsystem patch-bomb without disclosure drew "on the verge of hostile patch" from Krzysztof Kozlowski. Cover letters: used by some ≥3-patch series, skipped by others (Siwei's 6-patch v4 was applied without one): yours is fine. `linux-kernel@`: on the majority but omitted by several applied patches: fine. Below `---`: version changelog and test notes (tester names, pass counts, QEMU/KASAN/lockdep, base id) — exactly what your BlueZ mail does; the kernel cover does the same in its body. Target-tree marker `[PATCH bluetooth]`: used by some, not required; Mikhail Gavrilov *suggested* it for a stable-marked patch. Keep `[PATCH 0/3]` or add `bluetooth`; either is applied.

**Threads adjacent to yours:**
- Hitalo Souza, "Fix SCO setup failures after an abandoned setup", v3 pending. Luiz's reply on v2 is the one to read before sending: he asked whether it "couldn't be made more generically" — an aborted connection whose Complete still arrives "shall always result in HCI_OP_DISCONNECT" — and asked for tester cases. His series touches `hci_sco_setup()`, the mode-change path and `sco.c` state reset, not `hci_connect_sco()`; your "applies with or without it" claim is consistent with that, and Luiz asked him, as you already do, to send tester changes as a separate BlueZ patch. Hitalo's cover discloses AI assistance and carries `Assisted-by:` tags.
- Jeremy Dean Clifton, "hci_core: Fix queuing disc_work while workqueue is drained" (20 Oct, no maintainer reply yet): fixes syzbot's "WARNING in hci_connect_sco" (`hci_connect_sco` → `hci_conn_drop` → `queue_delayed_work` on a draining workqueue during HCIDEVDOWN). It changes `hci_conn_drop()` in `hci_core.h` to re-arm `disc_work` only when `HCI_CMD_DRAIN_WORKQUEUE` is clear; `hci_conn_hold()`, `hci_conn_timeout()` and `hci_conn.c` are untouched. No textual conflict, no semantic one: it gates the re-arm on device close, yours waits on the connect path with the device up. Because both sit on the same syzbot-visible path, one clause in the cover ("related, not overlapping: syzbot+5897b3c764f5989ea942, fix posted by Jeremy Dean Clifton") would spare a reviewer a moment of confusion. Hitalo's cover also mentions that before `a13f316e90fd` the next socket "reused the pending hci_conn" — same territory, different window.
- "[REGRESSION] v7.2: btusb SCO (HFP mic) broken on AMD Raven xHCI + Intel 9260" (Nahuel Clotet, Michal Pecio replying): currently treated as an xHCI isochronous regression, with net/bluetooth only floated as an alternative; nobody names `hci_connect_sco` or reuse. Do not cite it as support.
- Luiz, "[PATCH BlueZ v1 00/27] Run the testers under User Mode Linux with time travel" (posted today, v1, CI reply only): patch 24/27 **rewrites `tools/sco-tester.c`** onto a new `tools/tester-io.h` layer (`g_io_add_watch` → `tester_io_add_watch`, `g_source_remove` → `tester_remove_source`, `GIOChannel` → `struct tester_io`, GLib dropped, callback signatures changed). Your test is GLib-style, so a conflict is certain once that lands, not possible. Sending now against master with the rebase offer is still the right move: the `tester_io` API is not merged, so writing against it would be premature; just expect to do the rebase.
- Hitalo's companion test "tools/sco-tester: Add test closing the socket before the link is up" (with an `Assisted-by:` trailer) was pushed to BlueZ master on 2026-10-09 (814e3496a888); your patch already applies on top of it.
- Luiz's one substantive comment on Hitalo's v1 states his model plainly: any completion for a connection that was aborted "shall always result in HCI_OP_DISCONNECT so the handle don't stay active in the controller". That is the same premise as patch 2 ("`abort_reason` set means the connection is gone"), which is good news for your framing. Hitalo's v3 3/6 handles the event side of that (disconnect when `hci_conn_set_handle()` fails with `abort_reason` set); yours handles the connect side; they are complementary, not competing.
- Aldo's CIS hold patch (`e06d549fcd4a`): one version, no human comment, applied with its stable tag. His SCO serialise patch took four versions: Pauli found two UAFs in v2, Sashiko an early-return problem in v3. Expect more than one round even for a correct series; that is normal here, not a verdict.
- Two 2026 bug reports look like neighbours of your symptom and have no fix: Caleb White (Intel AX201/AX211, "SCO packet for unknown connection handle 257" on repeated HFP opens; Luiz: "looks like a firmware bug") and Алексей Воронов (Realtek 8761BU, mSBC, later HFP joins fail; asks whether `8a5b0135d4a5` covers his pattern, unanswered). Neither is obviously this bug, but Voronov's question is one your series partly answers; a CC to him costs nothing and may bring a Tested-by on different hardware.

## 7. The BlueZ test

Logic, checked path by path:

- **Reconnect After Disconnect**: first link up → close → Disconnection Complete (hook: `disc_released = true`, 100 ms) → second connect must return `EINPROGRESS` (sockets are `SOCK_NONBLOCK`), then a second Setup and a second Synchronous Connection Complete, after one Disconnect → 500 ms quiet → socket still connected and `disc_cmds == 1`. The handle is reused by the emulator, so the test counts commands and completions instead of comparing handles; the comment explains that. Correct on fixed and unfixed kernels (the bug is not in this path), so it is the control.
- **Reconnect During Disconnect**: Disconnect is processed by `btdev` (the emulator's link is gone), only the event to the host is held (hook returns false; `run_hooks()` → no `send_packet`). The second connect is made from a 0 ms timer. Accepted outcomes: `ECONNABORTED`/`EBUSY` now, then after the held event is delivered exactly 1 Setup/1 Complete/1 Disconnect; or `EINPROGRESS` and a second link after the first is gone. `ret >= 0` fails. On the fixed kernel `ret >= 0` is impossible here because the emulator has already processed the Disconnect, which means `hci_conn_timeout()` ran and `abort_reason` is set before the connect; so no false failure. On the broken kernel `ret == 0` is certain (traced in §1). Deterministic both ways. The re-sent event runs the hook again, which returns true because `disc_released` is set first; good.
- **Connect Twice**: second connect must be `EBUSY`; 500 ms quiet; first socket still connected and no Disconnect; then both closed; SCO Disconnection Complete with status 0 must precede the ACL's, and the ACL must go within 5 s. Unpatched: a Disconnect for the first link arrives during the quiet period → fail with the right message. Patched: SCO goes at once, ACL after its 2 s `disc_timeout` (out-going, not doubled) — inside the 5 s deadline and the 8 s test timeout. Also catches the ACL hold leak (without patch 1 the ACL would never go).

Style and maintainability:

- Mechanisms match the file: `hciemu_add_hook(POST_EVT)`, a central post-command hook (as `l2cap-tester`), `g_timeout_add`, `g_io_add_watch`, `tester_warn` before `tester_test_failed`, and `btdev_send_event` + `vhci_get_btdev` exactly as your merged mgmt-tester test uses them. `calloc` instead of `malloc` in the macro is a correct and welcome change (the new fields rely on zero init).
- Size: 534 lines for three tests, against 77 and 261 for Pauli's two recent sco-tester additions. Not out of range, but on the heavy side. If asked to shrink: `sock_poll()`/`sock_error()`/`sock_connected()`/`io_connected()` could fold into one helper; `revents > 0 &&` is redundant; `reconnect_connect2()` duplicates `connect_sco_sock()` because it needs `errno` — acceptable.
- Timing: four fixed delays (100/500/3000/5000 ms). The 500 ms "nothing more happens" checks are inherently timing-based; the file already has `g_usleep(500000)` in hooks, so it is within local custom, and Luiz's new UML time-travel series (see §6) virtualises these delays anyway.
- Teardown now removes the timer and the second watch and closes `sk2`; the first socket's `io_id` is cleared in the callback. Consistent with Pauli's "fix missing clear of io_id" commit.
- Subject prefix: both `sco-tester:` and `tools/sco-tester:` are in the file's history (Pauli's latest uses `tools/`). Fine.
- The During case accepting `EBUSY` is right and the `---` note explains why in one sentence.

## 8. Evidence against the claims in the mails

Every number in the cover's testing paragraph is in `results-2026-10-22-v3.md` (27/27 on UP, SMP 4, KCSAN SMP 4; 33/33 full sco-tester on UP and SMP; iso/l2cap/mgmt carried from v2 on the same tree id; the parked race, both link origins). Nothing is overstated. Two things are *understated*: lockdep was on and the cover does not say so; the stable heads were run, not only patched, and the cover does not say so. One thing is missing: no hardware run.

## 9. Recipients and form

- Kernel series: list + Marcel + Luiz + Cen Zhang (Fixes author) + Aldo (precedent and `816fb1590a4c`) + Hitalo (pending SCO series) + Pauli (PipeWire, `Suggested-by` on `816fb1590a4c`) + stable on 1–3 via trailers. Right and complete; `linux-kernel@` omitted as the list usually does.
- BlueZ test: list + Luiz. Add Pauli: he wrote most of `sco-tester.c` since 2025 and will be the one who reviews test semantics.
- Optional on the kernel series: Алексей Воронов (his unanswered September report asks exactly whether the `8a5b0135d4a5` family covers repeated HFP joins; see §6), and Jeremy Dean Clifton if you cite his pending `disc_work` patch.
- Order (kernel first, BlueZ the same day) is fine. Sending the BlueZ test first and waiting for it to land would let the kernel CI's tester run show the new cases passing on the patched kernel — a small plus, not worth a delay.
- Threading from the dry run is right; the author address is suppressed; nothing in the mails a maintainer would not want (no attachments, no HTML, no links to your repo — correct, the mails must stand alone).

## 10. Homework still open

1. Hardware run on the laptop (see Verdict item 3). Also: your Ubuntu 7.0.0-38 has the kref change but not `816fb1590a4c`, so it is also the one combination that exercises patch 1's hold against the *old* ownership model after the kref — worth a sentence in your notes, not in the mail.
2. Decide item 1 of the Verdict.
3. Add the disclosure sentence (§1, "What the three patches do not cover").
4. Cover: "with lockdep enabled"; "sco-tester gives the same results on the stable heads"; shorten the stable paragraph if you like.
5. Patch 2 wording ("link", "only sets"); patch 1 "reference"→"hold".
6. Optional: `[PATCH bluetooth 0/3]`; CC Pauli on the BlueZ mail; a `W=1` build of `net/bluetooth` with the series (two lines, no new warnings possible from this diff, but it is a thing people state).
7. Re-check both heads and patchwork 14908123 on the day, as your README says.
8. Have three answers ready, not in the mail: why patches 2 and 3 are separate (2 is the rule, 3 is the race against the rule's own check; squash if Luiz prefers); why the wait is not in `hci_conn_hold()` (callers that cannot sleep); why a `BT_CONNECTED` SCO conn is reusable at all (the incoming-request cross-over in §1, which must keep working).

Sources for §6 are the spinics mirror of linux-bluetooth (lore and patchwork were unreachable from the review environment); message numbers were followed thread by thread and should be re-verified on lore before you quote any of them in a mail.

## 11. The hangover test

Cover letter paragraph 1 passes it: who, what, when, why it matters, in five lines. Patch 1 passes once "reference"/"hold" is one word. Patch 2 passes after the two wording fixes. Patch 3 is the densest; it is also the one that will be read most carefully, so the three-sentence split above is worth doing. The BlueZ message is already the clearest text in the package.

---

## Reviewer 6, comments sent during the review

The second list reader finished after I'd sent the file and it corrected four things in the first version, so `CO-02-review-d7b011d.md` is re-sent with these fixes. The verdict and the three items to settle are unchanged; what changed:

* Luiz's UML series (posted today) does rewrite `sco-tester.c` — patch 24/27 moves it off GLib onto a new `tester_io` layer, so your GLib-style test will certainly need the rebase you offer, not maybe. Still send against master now; the new API isn't merged.
* Clifton's `disc_work` patch gates the re-arm in `hci_conn_drop()` on `HCI_CMD_DRAIN_WORKQUEUE` (not `HCI_UP` as I first wrote) and fixes syzbot's "WARNING in hci_connect_sco" — same path as yours, no overlap; one "related, not overlapping" clause in the cover would help.
* Luiz's stated model on Hitalo's series — any completion for an aborted connection "shall always result in HCI_OP_DISCONNECT" — is the same premise as your patch 2. That's the frame he'll bring; it favours you. Hitalo's companion sco-tester test is already in master and your patch applies on top of it.
* Aldo's CIS patch went in at v1 with no comment (I'd carried a wrong detail from the first reader); his SCO one took four rounds.

One addition: Алексей Воронов's unanswered September report (Realtek, mSBC, repeated HFP joins fail; asks whether the `8a5b0135d4a5` family covers it) is a cheap CC that could get you a Tested-by on different hardware.
