# Review request: BlueZ "shared/mgmt: Fix notify leak in mgmt_unregister()"

Prepared 2026-10-06. Nothing has been sent. The patch goes to linux-bluetooth only after this
review and the operator's word.

## What to review

The patch, exactly as it would be sent (identical to the file `git send-email` would use):
[`patches/mesh-tester/bluez-shared-mgmt-notify-leak.patch`](../../patches/mesh-tester/bluez-shared-mgmt-notify-leak.patch)

* One file, `src/shared/mgmt.c`, function `mgmt_unregister()`: +16 / −7.
* Base: BlueZ master `4dc15be8ee3f7422d447087f1893d215575cb2c8` (recorded as `base-commit:`).
  Still applies to current master `f8f352d13` (`scripts/pre-send-check.sh`, 2026-10-06:
  "applies to origin/master: yes").
* Source at the base, for reading around the change:
  <https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/src/shared/mgmt.c?id=4dc15be8ee3f7422d447087f1893d215575cb2c8>
  (`mgmt_unregister`, `mgmt_unregister_index`, `mgmt_unregister_all`, `process_notify`,
  `notify_handler`, `destroy_notify`).
* `Fixes:` names `872729a91632` ("shared/mgmt: Fix crash when removing index").

## What the patch claims

1. When `mgmt_unregister()` is called from inside a notification callback (`in_notify` set), the
   current code removes the entry from `notify_list` and only marks it `removed`;
   `process_notify()` later frees the removed entries it finds on `notify_list`, which no longer
   holds this one, so the entry is never freed.
2. Leaving the entry on the list while notifying (as `mgmt_unregister_index()` and
   `mgmt_unregister_all()` already do) lets `process_notify()` free it.
3. Measured with BlueZ's own testers (built `./bootstrap-configure --disable-lsan`, run with
   `test-runner`): mgmt-tester ends with "Direct leak of 9080 byte(s) in 227 object(s)"
   through `util_malloc()`, 40 bytes each (`struct mgmt_notify`); mesh-tester with 120 bytes in 3
   such objects. With the patch neither is reported.

## The evidence

Private validation record,
[`docs/mesh-tester-ci/validation-2026-10-05.md`](validation-2026-10-05.md), sections:

* **B1** — the standalone branch and the exact commit tested;
* **B2** — prior art searched (no competing fix found);
* **B3** — the leak before and after, and ordinary behaviour: mgmt-tester 503/503 and
  mesh-tester 8/10 (the same two "Send cancel" timeouts) before and after, identical per case;
* **B4** — lint (checkpatch, gitlint);
* **B5** — the exported patch.

Raw logs are local to the operator's machine (`tmp/mesh-tester-ci/logs/`), with SHA256SUMS;
quoted lines in the record are copied from them.

## Questions for the reviewer

1. **Correctness.** Is the analysis of the leak right? Read `process_notify()` and the
   `in_notify` / `need_notify_cleanup` / `removed` handling: does the unpatched path really lose
   the entry, and does the patched path free it exactly once, in every order of calls?
2. **Re-entrancy.** Can a callback unregister the entry that is currently being notified, or
   another entry, or call `mgmt_unregister()` twice for the same id while notifying? Does the
   patch behave in each case (no double free, no use after free, no missed notification for
   entries still registered)?
3. **Consistency.** Does the patched `mgmt_unregister()` now match how `mgmt_unregister_index()`
   and `mgmt_unregister_all()` defer removal? Any path still inconsistent?
4. **`Fixes:` tag.** Is `872729a91632` the commit that introduced the leak? (Read its diff.)
5. **Commit message.** Is it accurate, sufficient and free of noise for BlueZ's list? Is the
   measurement paragraph the right amount of evidence? Subject line style (`shared/mgmt:`)?
6. **Anything missing** a BlueZ maintainer would ask for (a tester case, `Cc`, version prefix)?

## Out of scope

* The kernel mesh work, and the Tested-by already sent for the kernel patch.
* Trailers other than those present: they are the author's decision.

## Constraints for the reviewer

* Do not send anything, comment anywhere, or change files; report findings only.
* Mark each finding as verified (with the command or source line), inferred, or not checked.
