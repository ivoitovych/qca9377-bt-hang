# CO-35 — the send package: a stable request for 7.2.y (for review before sending)

**One mail, not sent.** A request under `Documentation/process/stable-kernel-rules.rst`, option 2:
a mail to the stable team naming two mainline commits, the tree, and why. Plain text, 7-bit
ASCII, body lines within 72 columns, no patch attached. The draft is
[`request-v1.txt`](request-v1.txt) (headers below; the sendable `.eml` is built on the day, as for
the request of 2026-10-02, `patches/diag/stable-request-dc16388d45ec.md`).

- **To:** stable@vger.kernel.org
- **Cc:** the commits' author (Pauli Virtanen), the Bluetooth maintainers (Marcel Holtmann, Luiz
  Augusto von Dentz), linux-bluetooth@vger.kernel.org — from the commits and
  `scripts/get-maintainers.sh` on the day.
- **Subject:** `Please backport 608e0b7a675b and 32d86e048d8e (Bluetooth: L2CAP) to 7.2.y`

## Why only 7.2.y
The pair cherry-picks onto 7.2.13 and builds, and there it turns the hang into a pass. On 6.18.59
it applies but does not build (the helpers use lock annotations 6.18 lacks); 6.12.y and 6.6.y also
need a reworked hunk. Those lines would be a separate request with backports, if wanted.

## Evidence (`../experiments/results-2026-10-28.md`)
- The case: BlueZ l2cap-tester "L2CAP Ext-Flowctl Server - Accept 2 Close 1" (added by Pauli
  Virtanen in BlueZ `e9b6ee380`, "This triggers deadlock on some kernel versions") hangs on 7.2.12
  and 7.2.13 (no Bluetooth change between them), 6.18.58, 6.12.114, 6.6.160.
- A bisect of bluetooth-next between v7.2 and `47d4d9f67e92` (with an unrelated, newer hang on the
  same case taken out) ends at `32d86e048d8e`; it needs its helpers from `608e0b7a675b`.
- 7.2.13 + the two: the case passes (0.009 s); the full l2cap-tester 111 of 111; kernel log clean
  (QEMU/KVM, 4 vCPUs, BlueZ's `doc/tester.config`).
- Neither commit carries `Cc: stable`; neither is in the stable queue (checked 2026-10-28).

## Questions for reviewers
1. Is a request for two commits, one being preparatory, acceptable in this form, or should it be a
   backport patch series instead?
2. Is limiting it to 7.2.y right, with the older lines left for later?
3. Is anything in the wording more than the stable team needs?
