# CO-23 event 1: the send package (for review before sending)

**Two mails, BlueZ, not sent.** The files to send, exactly as they stand, in this order:
1. [`0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch`](0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch)
   — BlueZ commit `069fcf2d5` on master `82667d713949`;
2. [`0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch`](0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch)
   — `b36937c74`.

Generated with `git -C /root/exp/agent-work/co23/bluez format-patch --subject-prefix="PATCH BlueZ"
-o <this dir> origin/master` (branch `co23-a2dp-reconfig-uaf` of that clone).

## What it fixes
`a2dp_reconfig()` (MediaEndpoint1.SetConfiguration on a remote endpoint) writes
`setup->reconfigure` into a freed `struct a2dp_setup` when the switch comes while a Close sent by
the laptop is still pending: `avdtp_abort()` cancels the Close, `close_cfm()` completes the request
and frees the setup, then `a2dp_reconfig()` stores into it (`a2dp.c:2173` at master). This is the
bluetoothd crash of 2026-09-08 10:23:43 on the laptop (`../investigation-2026-10-28.md` §1), whose
log shows the same sequence. Present since `5071fadb97b8` (BlueZ 5.51). Patch 1 holds a reference
across the calls and does not free or fail a request that the canceled Close already completed;
patch 2 is the regression test in BlueZ's functional suite. Why this fix and not the alternatives:
`../experiments/results-2026-10-29.md` §2.

## To whom
`linux-bluetooth@vger.kernel.org`, Cc Luiz Augusto von Dentz `<luiz.dentz@gmail.com>`: he applies
BlueZ patches, wrote `5071fadb97b8` and the functional A2DP tests (same address as the earlier BlueZ
sends, `CO-02 send-tools/send.sh`). No `Signed-off-by` (BlueZ maintainer guidelines, rule 2). No
cover letter: two patches, each message stands alone.

## What was run (`../experiments/results-2026-10-29.md`)
- **Reproduction under AddressSanitizer** in the CI bot's image and QEMU guests: master + the test
  → `heap-use-after-free … profiles/audio/a2dp.c:2173 in a2dp_reconfig` (WRITE of size 4, 80 bytes
  into the 112-byte setup); master + both patches → the A2DP functional cases 5/5 pass, no sanitizer
  report; the new case alone 5 of 5 runs pass. Both failure branches of the fix that a test can
  reach were exercised (the second `endpoint.config` takes the "still pending" one).
- **Unit tests** (`make check`, ASan/UBSan build) on master + test and master + both: 42 total, 41
  pass, 1 skip (`test-mesh-crypto`), 0 fail on both.
- **The CI bot's own checks** (`scripts/bot-ci-local.sh --space user`, run `tmp/co23/bot-ci-3`), on
  exactly these mails, base and base + series: **all PASS on both sides, exit 0** (CheckPatch,
  GitLint, BuildEll, BluezMake, MakeCheck, MakeDistcheck, CheckValgrind, CheckSmatch, bluezmakeextell,
  TestFunctional, IncrementalBuild, ScanBuild). TestFunctional 48 → 49 passed (the new case), 1
  skipped on both. An earlier run's CheckPatch warning (an 81-column comment) was fixed first.
- **checkpatch** is the bot's CheckPatch above (`/usr/bin/checkpatch.pl` in its image, its ignore
  list): 0 errors, 0 warnings on both mails.
- `scripts/pre-send-check.sh /root/exp/agent-work/co23/bluez <both>` on 2026-10-29: applies to
  master `82667d713`, not upstream, "OK to send". No competing patch or report on patchwork since
  2026-08-01 or in the lore archive since 2026-09-10.
- `black --check` (the bot image's) on the test file: unchanged.
- Not run: the path where the Abort cannot be sent after the Close was canceled (no ordinary test can
  make that send fail); covered by reading only.

## The send (only on the operator's word)
On the day: re-run `scripts/pre-send-check.sh` against a fresh master; if master moved, re-run
`format-patch`, compare with `scripts/patch-code-compare.py`, and rewrite `SHA256SUMS`. Then
[`send.sh`](send.sh) (never run by its author: `send-email`, a dry run included, stays with the
coordinator): without arguments it checks the mails against `SHA256SUMS` and runs
`git send-email --dry-run`, whose RCPT TO must be exactly the list and Luiz Augusto von Dentz;
`send.sh --send` is the real send (`--confirm=always`), with an app password used once and revoked
afterwards.

    To: linux-bluetooth@vger.kernel.org
    Cc: Luiz Augusto von Dentz <luiz.dentz@gmail.com>
    SHA256SUMS: 45dd0c86ae7a… (0001), 2ba2bf0c2966… (0002)

## Questions for reviewers
1. Is holding a reference plus the callback lookup the right shape, or would the maintainer rather
   see only the reference (smaller, leaves the failed-Abort-send ending) or the flag moved before the
   calls (smallest, same)? `results-2026-10-29.md` §2 says why neither was chosen.
2. Is stopping the peer's `bluetoothd` with `SIGSTOP` through `host.call()` acceptable in BlueZ's
   functional suite? No existing case does it; it is the only deterministic way found to keep a Close
   unanswered.
3. Subject, message, `Fixes:` form, and splitting the test into its own patch (as `ab5df7ba3` did).
