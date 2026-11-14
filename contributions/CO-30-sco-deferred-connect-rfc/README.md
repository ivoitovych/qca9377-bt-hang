# CO-30 — defer a SCO connect until the aborting link is gone (RFC on top of CO-02 v2)

**What it is.** With CO-02 v2, a `connect()` that finds the peer's SCO link being torn down is
refused with -ECONNABORTED. PipeWire 1.0.5 retries at once with a new socket, which is refused
again while the old link's Disconnection Complete has not arrived, so the audio returns only after
WirePlumber's idle suspend (U17, CO-31). The RFC instead defers such a connect until the aborting
link is gone, so `connect()` returns -EINPROGRESS and the socket gets its own link.

**State (2026-11-14): RFC package, nothing sent** (`rfc-20261114/`; its `README.md` and
`CHECKS-CO30.md` have every command and result). The patch applies to CO-02 v2 with
`git am --3way` and its code is unchanged from the 11-01 prototype.

- **A PipeWire-style retry** (a research-only sco-tester case, `bluez-research/`, not for
  submission), 3 runs each: CO-02 v2 alone fails 3 of 3 (ECONNABORTED on every attempt), v2 + RFC
  passes 3 of 3; the other 35 sco-tester cases pass on both.
- **Close then connect with another voice setting** (patch 3's refusal), 30 connects per kernel:
  v2 alone refuses all 30 at once; v2 + RFC gives the second socket its own link 27 of 30 times and
  fails 3 later with ECONNABORTED. The reading (inferred, not traced): the deferred connect can run
  ahead of the old link's abort in the cmd_sync queue and is refused again, and a deferred connect
  does not defer twice.
- The bot's checks, patched side, with a local Signed-off-by: pass, but for one sparse note in a
  header the RFC does not touch (no base comparison: the base does not build `sco.c`). checkpatch
  `--strict` on the host: only the missing Signed-off-by.
- **Not run:** mgmt-tester, iso-tester, l2cap-tester on the RFC kernel; hardware; PipeWire itself.

**Decides:** the operator — whether to post it at all and when (after a reply to CO-02 v2, as the
11-01 recommendation said); whether the retry test goes with it; whether to add a requeue-once
refinement for the 3 of 30 first; whether the -ECONNABORTED → -EINPROGRESS change in that window
is acceptable for applications other than PipeWire.

Earlier work: `../research-2026-11-01/sco/`. Copied from `/root/exp/agent-work/lane2-sco-20261114/co30-rfc/`
(fetched third-party pages and the bot's large logs left there).
