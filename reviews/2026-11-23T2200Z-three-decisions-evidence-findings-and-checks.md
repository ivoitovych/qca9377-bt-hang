# Evidence for three open decisions (2026-11-23 night): five outside answers, checked

**The question.** The operator asked the reviewers for precedent evidence, not votes, on three decisions:
1. CO-44's trailer;
2. `Cc: stable` on CO-43 1/3, and a path note given the `btusb_main.c`/`btusb.c` split;
3. CO-26 variant A (`Fixes:`) or B (none).

All five answered (reviewers 1, 2, 3, 6 and 7). The full texts are kept privately; findings only here. Every
precedent below that decides something was checked in the kernel tree:
`tmp/kernel-queue-20261123/check-precedents.sh` and `check-precedents-2.sh`, plus the GitLab API for
linux-firmware.

## Checked precedents

| precedent | what it shows | check |
|---|---|---|
| `df5e35f1663a` (btusb, `btusb_main.c`, `Cc: stable`) → 6.18.y `b415ba15d072` | a post-split btusb fix taken into 6.18's `btusb.c`, with "[ sashal: Adapted the patch to the Bluetooth USB driver's original source filename. ]" | confirmed |
| 7.3.y `10ed5a995f9f` ("btusb: Build the driver from multiple source files"), then `7c63ce91cead` (the copy of `df5e35f1663a`) | for 7.3 the stable team took the split itself as a dependency (`Stable-dep-of: df5e35f1663a`, reviewer 3), then the fix. Reviewers 2 and 3 cite FAILED-to-apply mails for 7.3 and 6.18 before that (lore, not read here) | the two commits confirmed in 7.3.y |
| `fa96916cfd05` (btusb, `btusb_main.c`, `Fixes:` only) | in `btusb.c` on 6.18.y, 6.12.y, 6.6.y and 6.1.y | confirmed |
| `c93922dd316b` (btusb runtime-PM leak, `Fixes:` only) → 6.18.y `8b28ff3728e4` | a `Fixes:`-only btusb leak fix reaching stable | confirmed |
| `59b047bc9808` (MGMT/SMP address type, `Cc: stable`) → upstream revert `532f8bcd1c2c` (Luiz Augusto von Dentz, `Cc: stable`) → reverts on 6.6.y `c4252955e1fb` and 6.1.y `547017ba86aa` | an MGMT semantic correction reverted from stable after it broke bluetoothd's Load Long Term Keys | confirmed |
| `86ef0f58bdec` (our MGMT status fix, `Fixes:` + `Cc: stable`) | a numeric MGMT status correction with a crash behind it, taken to stable without trouble | confirmed (released, STATUS) |
| `7eac80614300` (MGMT RFKILLED mapping, `Fixes:` only) | CO-44's nearest precedent, in no stable line | confirmed earlier (S-9) |
| `0eaf7c7e85da` (errno fix, `Fixes:`), `a3d984253d23` (errno fix, no `Fixes:`) | internal errno fixes are accepted both ways | confirmed |
| 6.18.y `42a44fe738f6` and `eff110e062a5`: reverts of the ASUS USB-BT540 and BT600 ID backports (reviewer 6) | a device-ID backport reverted because the ID makes the vendor driver need a firmware file older distributions lack (`rtl_bt/rtl8761cu_fw.bin`, in linux-firmware since 20251111; Debian trixie broke) | confirmed (revert message) |
| `S-4`'s earlier reading (the bracketed form marks the stable team's own pick) | wrong: `b415ba15d072` has the bracketed form and came from `Cc: stable` (reviewer 7) | corrected in the register (`ce64414`) |

Reviewer 1's two examples did not hold:
- `eedc6867ebad` changed `btusb.c` before the split, so it says nothing about renames.
- `4ef36a52b0e4` exists, but it carries no stable tag line, and the route claimed for it was not confirmed.

## Positions after the evidence

| decision | 1 | 2 | 3 | 6 | 7 |
|---|---|---|---|---|---|
| CO-44 | `Fixes:` only | `Fixes:` only | `Fixes:` only (changed back) | **`Cc: stable`** (changed) | `Fixes:` only (changed back) |
| CO-43 1/3 | `Cc: stable`, no note | `Cc: stable`, note below `---` | `Cc: stable`, no note on the tag; a factual sentence below `---` optional | `Cc: stable` with a short path note | `Cc: stable`, one sentence below `---` |
| CO-26 | A | A | A (65–70 %) | A (high) | A |

**Reviewer 6's measured record, from git only:**
- **Leak fixes in Bluetooth drivers since 2022:** all 5 with both tags reached stable, 10 of the 12 with `Fixes:` only, and 0 of the 2 with neither.
- **Applied against posted, for 96 outside patches:** the maintainer added `Fixes:` twice and never removed it. He never added or removed `Cc: stable`.
- **Error-path fixes since 2025:** 17 with `Fixes:` only, 4 with both tags, 10 with neither.

## Outcome

- **CO-44: keep it as packaged, `Fixes:` only, by 4 of 5.**
  - For: the same-function precedent `7eac80614300` stayed mainline-only.
  - For: the revert `532f8bcd1c2c` shows why MGMT semantic changes are kept out of stable without a strong case.
  - Against (reviewer 6): our own `86ef0f58bdec` went to stable with its tag, cleanly.
  - `noautosel`: no reviewer supports it.
- **CO-43 1/3: `Cc: stable`, by 5 of 5,** conditional on the seven-line runs.
  - The precedents show the stable team taking post-split btusb fixes into `btusb.c`, by hand or by taking the
    split as a dependency.
  - The clean real cherry-pick on all seven tips puts 1/3 in the easy case.
  - A note on the `Cc:` line has no measured effect, and `# needs adjustments` would be false.
  - Most favour a short factual sentence below `---` instead.
- **CO-26: variant A, by 5 of 5,** with mixed precedent. The case rests on what `Fixes:` means, and on CO-26
  also stopping an invalid scheduling call, not on a Bluetooth convention.
- **CO-22, from reviewer 6's find: one sentence added to the mail.** The two ASUS IDs make btusb load
  `qca/rampatch_usb_00000302.bin` and `qca/nvm_usb_00000302.bin` (d54601f21faf's own log). linux-firmware has
  shipped both since 2015-07-14 (`23d13405`, "qca: add BT firmware files to support QCA ROME chips"; GitLab API,
  `repository/commits?path=…`). So older distributions have them, unlike the reverted Realtek case.
