# CO-02 v2: decisions left to the operator

Nothing here is sent. The mails are in `kernel/` (cover plus 3 patches) and `bluez/` (cover plus 2
patches); no `Signed-off-by` on any patch (add your own when sending); `git send-email` is yours.
Evidence and commands are in `CHECKS.md`.

## 1. Shape of the posting

- **Kernel: 3 patches (what is prepared), or 2.** Patch 3 (parameter guard) is separable: drop it
  and the BlueZ patch 2 and the series is "hold fix + folded abort fix" only. The notes in
  `contributions/review-2026-11-02/followups.md` (D2: "then the guard goes out with v2") support
  sending it, so it is in. Without it, "Connect Twice Other Voice Setting" and "... Retry" fail
  (measured: 33 of 35 sco-tester cases).
- **Label mix-up in the task brief:** the brief calls D1 "-EBUSY on a live link" and D2 "in-flight
  test". In `followups.md` D1 is "when to post v2 and its label (v2)" and D2 is the mismatch
  patch (-EBUSY split, F-19; in-flight test, F-80). Both were done as D2/F-19/F-80 describe.
- **What changed from the 11-02 mismatch patch (`patch/mismatch-20261102/`) and why:**
  - -EBUSY for a connection a socket still holds, -ECONNABORTED only when nothing holds it (F-19,
    R2 and R6 agreed); the old patch gave -ECONNABORTED for both.
  - It no longer needs `BT_CONNECTED`: it also covers a setup still in flight and a connection a
    socket holds while its ACL link is still coming up, which is the F-80 case (measured, see
    CHECKS.md: with patches 1 and 2 alone the first socket's setup carries the second socket's
    voice setting, in both the ACL-pending case and the retried-setup case).
  - Compares `setting`, `codec.id`, `codec.data_path` instead of `memcmp` of the struct (F-20); the
    check is an `else if` next to the `abort_reason` check (F-21).
  - A connection with no holder in `BT_OPEN`/`BT_CLOSED` is still set up with the new parameters
    (nothing was sent yet).
- **Left out on purpose:** F-22 (compare the negotiated Air_Mode for a link the remote device set
  up; needs CO-21's stored air mode) and F-23 (the general overwrite audit). A link the remote
  device set up has no stored parameters, so with no holder it is refused once (-ECONNABORTED),
  then a retry gets a fresh link. The message says so. Your call whether that is acceptable.
- **Stable tags:** patch 1 `Cc: stable # 6.6.x` (unchanged); patch 2 `Cc: stable`, `Fixes:
  e6720779ae61` (the fold carries the old patch 3's race fix, so stable never gets the race open);
  patch 3 has **no** `Cc: stable` (it adds a refusal for remote-set-up links; add it if you want
  it). Textual check: all three apply (offsets only) to the 6.6.y, 6.12.y, 6.18.y and 7.2.y heads
  in `cache/`; that is not a statement about which Fixes: commits those trees contain.
- **BlueZ: 2 patches with a cover letter, or one patch.** Patch 1 is the v1 test ported to the
  mainloop tester (same 3 cases); patch 2 adds the two cases for kernel patch 3. If you send only
  kernel patches 1 and 2, send only BlueZ patch 1. Order: kernel first, then BlueZ with the kernel
  cover's lore link.
- **Placeholders to fill at send time:** `KERNEL-V2-LINK` in the BlueZ cover letter and in the
  notes of BlueZ patch 1 (the lore URL of the kernel cover, which exists only after the send).

- **Subject of BlueZ patch 2** is "tools/sco-tester: Add connect twice with other voice tests": the
  bot's GitLint rejected a longer title (85 > 80 with the `[BlueZ,v2,2/2]` prefix). BlueZ
  CheckPatch/GitLint/BuildEll/BluezMake/IncrementalBuild pass on the final mails; CheckSmatch gives
  the same header note as v1 (`CHECKS.md` section 6).
- **Kernel mails carry no Signed-off-by**, so the bot's CheckPatch/GitLint/VerifySignedoff fail on
  exactly that; with a Signed-off-by added locally all three pass. VerifyFixes fails for patch 3 only
  because my bot clone had history since 2023; the Fixes target exists (2013) and is an ancestor.

## 2. Statements in the kernel cover to check yourself

- The hardware paragraph is v1's, shortened (F-18). It says patch 3 was not run on the laptop;
  nothing new was run there. v1 of patches 1 and 2 ran there; the fold (v2 patch 2) is the same
  code plus one `READ_ONCE()`.
- The l2cap-tester sentence (96 of 96 pass with 3 GB guests; 2 of 27 stalls at 256 MB, none
  without the series; see section 3). It is in the draft so a reviewer is not surprised; leave it
  out if you prefer, it is unexplained but not attributable to the series.
- The "RFC deferral prototype" sentence is from v1's cover.

## 3. Surprise worth knowing before the send

- **l2cap-tester stalled in 2 of the first 12 runs with the full series at 256 MB** (95 and 97
  cases passed; "L2CAP LE Server - Set HDT 2M"/"3M"; the guest then only printed btmon `Invalid
  index` lines until the 25 minute limit). **Followed up (task 2), full detail in `CHECKS.md`
  4a:** with the memory confound removed (3 GB guests, no OOM line) 32 runs each on base, 1+2
  and 1+2+3 all pass 144 of 144 (96 of 96); 15 more runs each on base and 1+2+3 at 256 MB all
  pass. Totals at 256 MB: 1+2+3 2 of 27 stalled, base 0 of 27, 1+2 0 of 6 (Fisher p = 0.49: not
  separable). The earlier "btmon not OOM-killed" correlation is refuted as a cause. `hci_connect_sco()`
  is only reachable from a SCO socket connect() and the l2cap-tester opens none, so patch 3 cannot
  run there; the stalls are unexplained and not attributable to the series. Logs of the two stalls:
  `logs/run-l2cap-p123-1.log`, `logs/run-l2cap-p123-3.log`.

## 4. Upstream state (11-14)

See the report: no human reply on the thread, all four patches still `new`; one other open patch
touches the same function: Wentao Liang's "Bluetooth: delete the new SCO link if linking it fails"
(patchwork 14942649, 11-04). It conflicts textually with our patch 1 (hunk 2: the `hci_conn_link()`
failure path); whichever lands second needs a trivial rebase. A maintainer-side reply there
(Krzysztof Kozlowski) is critical of that author's process; none concerns our series.

## 5. checkpatch --strict

Run on the host on all five patches: nothing beyond the missing Signed-off-by (kernel) and
BlueZ style notes the BlueZ bot does not apply (`CHECKS.md` section 1).
