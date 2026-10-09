# Review request: BlueZ shared/mgmt leak fix, recheck after the second round (2026-10-07)

Nothing has been sent. The series goes to linux-bluetooth only after review and the operator's
word. This follows the request of 2026-10-07
(`REVIEW-REQUEST-bluez-shared-mgmt-leak-2026-10-07.md`); what the second round found and what
was done is in
[`review-response-2-bluez-shared-mgmt-2026-10-07.md`](review-response-2-bluez-shared-mgmt-2026-10-07.md).

## What to review

The two patches, exactly as they would be sent:

1. [`0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch`](../../patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch):
   `src/shared/mgmt.c`, +17/−7.
2. [`0002-unit-test-mgmt-Test-unregistering-from-callbacks.patch`](../../patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/0002-unit-test-mgmt-Test-unregistering-from-callbacks.patch):
   `unit/test-mgmt.c`, +215.

Base: BlueZ master `d84171e6cd68a5ab95d0f3a384279c36bd108a13` (`base-commit:`).
Source at the base: <https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/?id=d84171e6cd68a5ab95d0f3a384279c36bd108a13>

## What changed since the previous request

* Rebased on `d84171e6c` (no change to `mgmt.c`, `queue.c` or `test-mgmt.c` upstream).
* Fix: code unchanged. The message now states the two return-value cases separately
  (repeat unregister already failed; an id marked by `_all()`/`_index()` now fails too, as
  before `872729a91632`) and replaces the tester paragraph with one sentence, which now names
  userchan-tester as well.
* Tests: destruction is checked in an idle callback before teardown, and callbacks still
  dispatching check that nothing has been destroyed yet. `g_assert_cmpint()` replaces
  `g_assert_true()`/`g_assert_false()` (GLib 2.36 minimum). Subject shortened.
* Evidence: the testers were rerun with full allocation stacks. The leaked objects are now
  attributed to `mgmt_register()` directly, not inferred from their size.

## Questions for the reviewer

1. Is the new return-value paragraph accurate and clear?
2. Is the one-sentence tester paragraph right, or should it go?
3. Do the revised tests check destruction timing as the test message claims?
4. Anything that still stands between this series and sending it?

## Constraints for the reviewer

* Do not send anything, comment anywhere, or change files; report findings only.
* Mark each finding as verified (with the command or source line), inferred, or not checked.
