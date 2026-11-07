# CO-02 send drafts

**State:** drafts, 2026-10-21. Nothing is sent without the operator's word.

| file | what | to |
|---|---|---|
| `kernel-cover-letter.txt` | the cover letter of the two-patch kernel series, **final patches in `../patch/kernel-final/`** (2026-10-22: shorter subjects for the bot's 80-column GitLint; patch 2's `Fixes:` corrected to `8a5b0135d4a5`; code identical to the tested series: same tree `5cb23798…`, same patch-ids `20f80382…`, `106cab62…`; checkpatch `--strict` 0/0/0 run inside the tree). `../patch/kernel/` is the tested draft with the old messages, superseded | To: Marcel Holtmann, Luiz Augusto von Dentz; Cc: linux-bluetooth, linux-kernel (`get_maintainer.pl`); optional Cc Pauli Virtanen |
| `../patch/bluez/0001-tools-sco-tester-Add-reconnect-tests.patch` | the BlueZ test case, its own mail, no cover letter; send with `--subject-prefix="PATCH BlueZ"` | linux-bluetooth |
| `../patch/kernel-rfc-defer/` | the deferral, **not sent now**: offered in the cover letter as an RFC if the maintainers prefer it | — |

**Placeholders:** none left. Base bluetooth-next `27731ba09195` (unmoved at the 2026-10-22
check; re-check just before sending). Still to do before a send: an outside review of the
package, the operator's three decisions below, and the send itself from the operator's word.

**Open for the operator:**
1. Send the kernel series and the BlueZ test together (recommended), or the kernel series first.
2. Whether to Cc Hitalo Souza, whose pending SCO series touches neighbouring code (the cover
   letter mentions it).
3. The deferral question in the cover letter: keep it (recommended: it is the part that fixes
   U7 for PipeWire users) or leave it for a later mail.

**Why the mail says what it says** (kept here, not in the mail):
- PipeWire is named because it is the user-visible trigger the maintainers can reproduce; the
  capture evidence (`EX-060`) stays in the project.
- The BlueZ test is named by subject so the two mails can be found together; it fails on
  kernels without patch 1, which the BlueZ CI will show until the kernel patch lands, as with
  the BT-9 cases.
- Test counts, CPU variants and the worker's process are left out (zero-noise rule); they are in
  `../experiments/results-2026-10-21.md`.
