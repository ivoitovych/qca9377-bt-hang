# CO-38 refreshed on bluetooth-next da3cc02587c6 (2026-11-14; nothing sent)

Copied from `/root/exp/agent-work/lane3-mgmt-20261114/CO-38/`; `CHECKS.md` has every command and
result. The send files are `patch/` (kernel) and `patch/bluez/` (the three BlueZ tests with their
cover letter), authored "Iaroslav Voitovych", **without Signed-off-by** (he adds it at send time).

- No equivalent fix posted or merged; the patch applies to bluetooth-next and bluetooth/master;
  its code is unchanged (only `base-commit`). The BlueZ series needed one context conflict
  resolved at the end of `mgmt-tester.c`; `git range-diff`: no content change.
- mgmt-tester "Add", 3 runs each: 119/128 → 120/128, the only change "Add Ext Advertising -
  Instance 2 listed alone" Failed → Passed (3 of 3), as on 11-02; mesh-tester 8/10 on both.
- The bot, kernel side: every check passes on both sides with identical tester results (the
  Signed-off-by checks only with a placeholder in a test copy). BlueZ side: TestFunctional failed
  2 of 3 on the patched side (two different BAP cases, "Failed to acquire") and passed 2 of 2 on
  base; the series touches only two tester sources, so it looks like a flake under load (20 to 30)
  but is **not shown** to be.

**Left in the work area:** kernel images and tester binaries; the bot's large harness and tester
logs (they print emulated controllers' addresses); intermediate patch copies; saved lore and
patchwork pages of other people's postings. One bot run on a placeholder-signed test copy
(`bot-co38-k-msg2`) is summarised in `CHECKS.md` and stays there too. `mk-kernel-patch.sh` and
`CHECKS.md` name the placeholder address as `example.com` (the run used `example.invalid`).
