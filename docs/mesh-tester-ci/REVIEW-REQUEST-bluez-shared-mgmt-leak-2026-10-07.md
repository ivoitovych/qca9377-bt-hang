# Review request: BlueZ shared/mgmt leak fix with unit tests (2026-10-07)

Nothing has been sent. The series goes to linux-bluetooth only after review and the operator's
word. This replaces the request of 2026-10-06 (`REVIEW-REQUEST-bluez-shared-mgmt-leak-2026-10-06.md`),
whose review led to the changes listed in
[`review-response-bluez-shared-mgmt-2026-10-07.md`](review-response-bluez-shared-mgmt-2026-10-07.md).

## What to review

The two patches, exactly as they would be sent:

1. [`0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch`](../../patches/mesh-tester/bluez-shared-mgmt-notify-leak-2026-10-07/0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch):
   `src/shared/mgmt.c`, +17/−7.
2. [`0002-unit-test-mgmt-Add-tests-for-mgmt_unregister-from-ca.patch`](../../patches/mesh-tester/bluez-shared-mgmt-notify-leak-2026-10-07/0002-unit-test-mgmt-Add-tests-for-mgmt_unregister-from-ca.patch):
   `unit/test-mgmt.c`, +191.

Base: BlueZ master `4dc15be8ee3f7422d447087f1893d215575cb2c8` (`base-commit:`); both apply to
current master `f8f352d13` (`scripts/pre-send-check.sh`, 2026-10-07: `OK to send`).
Source at the base: <https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/?id=4dc15be8ee3f7422d447087f1893d215575cb2c8>
(`src/shared/mgmt.c`, `src/shared/queue.c`, `unit/test-mgmt.c`).

## What changed since the 2026-10-06 request

* The fix rejects an entry already marked removed while notifying, so a repeated
  `mgmt_unregister()` of the same id still returns `false`.
* The comment follows BlueZ coding style M2.
* The message no longer names `struct mgmt_notify` as the leaked type; it gives the size.
* The message now also states the use-after-free in `queue_foreach()` when a callback
  unregisters the next entry (measured with the new unit test under ASan).
* A second patch adds four `unit/test-mgmt` cases.

## The evidence

`review-response-bluez-shared-mgmt-2026-10-07.md`: per-case unit results on unpatched,
first-version and revised `mgmt.c`; the ASan report; `make check`; lint; mgmt-tester and
mesh-tester in QEMU before and after. Raw logs are on the operator's machine, listed in
`logs-bluez-2026-10-07-SHA256SUMS`.

## Questions for the reviewer

1. **Fix.** Is the `notify->removed` check right? Does any case now return a different
   value than before the fix, other than the leak no longer happening?
2. **Commit message.** Accurate and without noise? Is the use-after-free sentence correct and
   worth having? Is the tester paragraph still needed now that a unit test reproduces the leak?
3. **Tests.** Do the four cases test what they claim? Do they fail without the fix for the
   right reason (see the per-case table)? Are they in the style of `unit/test-mgmt.c`? Is
   anything too much for a maintainer, or missing?
4. **Series.** Fix first, test second, no cover letter: right for BlueZ?
5. **Anything else** a BlueZ maintainer would ask for.

## Out of scope

* The kernel mesh work.
* Trailers other than those present: they are the author's decision.
* `mgmt_unregister_index(MGMT_INDEX_NONE)` selecting differently inside and outside a
  notification: recorded for later, not part of this series.

## Constraints for the reviewer

* Do not send anything, comment anywhere, or change files; report findings only.
* Mark each finding as verified (with the command or source line), inferred, or not checked.
