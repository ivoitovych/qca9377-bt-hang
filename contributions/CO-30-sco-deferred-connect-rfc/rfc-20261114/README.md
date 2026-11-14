# CO-30: deferred SCO connect, RFC package on top of CO-02 v2

Not sent. No Signed-off-by (the operator adds his own). Base: CO-02 v2 (`../co02-v2/kernel/`, branch
`co02-v2-final` in `$W/linux-bn`) on bluetooth-next `da3cc02587c6`; the RFC is branch `co30-rfc`, one
commit on top of it.

## Contents

- `kernel/0001-Bluetooth-SCO-defer-a-connect-until-the-link-being-a.patch`: `[RFC PATCH]`, 113 lines
  in `net/bluetooth/sco.c`. Code unchanged from the 10-21 prototype
  (`contributions/CO-02-.../patch/kernel-rfc-defer/`): it applies with `git am --3way` to the v2 series
  without change, builds without warnings, tree identical to the image that was tested. Message
  without Signed-off-by and with a notes block (below `---`) that states what was and was not
  tested, including the limit below. `KERNEL-V2-LINK` in the notes is filled at send time.
- `bluez-research/`: two research-only sco-tester commits (NOT for submission) on top of the CO-02 v2
  BlueZ tests, BlueZ `20ffd285b58f`: the PipeWire-style retry case, and ten "close then connect with
  BT_VOICE_TRANSPARENT" cases. If the maintainers want the retry test upstream, the first one is the
  candidate; the second is a measurement.
- `results/`: summaries (`sco-tester-retry.txt`, `close-then-connect.txt`, `kernel-report-scan.txt`).
  Raw logs: `$W/logs/run-co30-*.log`, `run-co30close2-*.log` (hashes in `../co02-v2/logs/SHA256SUMS`
  after `scripts/finalize.sh`).

## Results (QEMU/KVM, 4 CPUs, KASAN and lockdep, 256 MB guest; `p123` = CO-02 v2 alone, `rfc` = v2 + RFC)

| Test | p123 | rfc |
|---|---|---|
| sco-tester, 36 cases (35 + the retry case), 3 runs each | 35 pass; only the retry case fails (3 of 3) | 36 pass, 3 of 3 |
| "RESEARCH Reconnect During Disconnect Retry": PipeWire 1.0.5's `sco_do_connect()`: connect(); on ECONNABORTED a new socket and connect() again, at most twice, while the old link's Disconnection Complete is held | `Second connect() returned -1 (Software caused connection abort)` three times in a row, "Still ECONNABORTED after 2 retries" | first connect() returns EINPROGRESS, the second socket gets its own link (setups 2, completes 2) after the held event is released |
| the series' own cases ("Reconnect During Disconnect", "Connect Twice", both "Other Voice" cases, "Reconnect After") | pass | pass |
| guest logs | clean | clean (`kernel-report-scan.py` exit 0) |

## The question about patch 3's ECONNABORTED before `hci_conn_timeout()` has run (answered, measured)

Case: a socket is closed and another connects at once with other voice parameters, before the old link's
disconnect work has run. Patch 3 refuses it with -ECONNABORTED (before, or equivalently after the work
ran but before the abort executes). Does the deferral help?

Measured, 10 cases per guest, 3 guests per kernel (`results/close-then-connect.txt`):

| | refused at once by connect() | second socket gets a link of its own | second socket fails later (poll error, ECONNABORTED) |
|---|---|---|---|
| v2 alone (p123) | 30 of 30 | 0 | 0 |
| v2 + RFC | 0 | **27 of 30** | **3 of 30** |

So the deferral covers most of this case, not all. Reading of the 3: the deferred connect runs from
the cmd_sync queue ahead of the old link's abort (the abort is queued only when the disconnect work
runs, which had not happened when the connect was deferred), calls `hci_connect_sco()` again, meets the
guard or the `abort_reason` check once more, and, as a deferred connect never defers a second time,
fails the socket with ECONNABORTED (log: "The second socket failed: condition 0x1c, Software caused
connection abort", only one setup in the run). [inference from the code and the log; the order in the
queue was not traced]. This matches the 11-01 research note that the RFC "does not cover a reuse before
`hci_conn_timeout()` starts" in part. The notes of the RFC mail say it (measured numbers).
A possible refinement, not written or tested: let a deferred connect that is refused with ECONNABORTED
requeue itself once behind the abort that is by then queued. It adds a retry loop to an RFC whose first
question is whether deferral is wanted at all, so I left it out.

## Checks

- Bot checks (patched side only, with a local Signed-off-by on the mails): `scripts/bot-rfc.sh`,
  output `project/tmp/bot-rfc/` and `bot/` after finalize; see `CHECKS-CO30.md`.
- Not done: hardware (laptop not used), PipeWire itself, blocking sockets, stable lines (the RFC is
  not for stable).

## Decisions for the operator

1. Whether to post the RFC at all, and when: after the v2 series has a reply (the RFC says it builds on
   it). The 11-01 recommendation (wait) still holds; nothing new upstream.
2. Whether to send the retry test with it (research patch 1) as a BlueZ patch.
3. Whether to add the requeue refinement before posting (closes the 3 of 30), at the cost of more code.
4. The RFC changes `connect()` for SCO sockets from -ECONNABORTED to -EINPROGRESS/wait in this window;
   PipeWire 1.0.5 copes (the test), other applications are untested.
