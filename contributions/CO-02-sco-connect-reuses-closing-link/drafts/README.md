# CO-02 send drafts

**State:** drafts, 2026-10-21. Nothing is sent without the operator's word.

| file | what | to |
|---|---|---|
| `kernel-cover-letter.txt` | the cover letter of the two-patch kernel series (`../patch/kernel/`) | linux-bluetooth and the maintainers `get_maintainer.pl` names (the pre-send check fills them in) |
| `../patch/bluez/0001-tools-sco-tester-Add-reconnect-tests.patch` | the BlueZ test case, its own mail, no cover letter | linux-bluetooth |
| `../patch/kernel-rfc-defer/` | the deferral, **not sent now**: offered in the cover letter as an RFC if the maintainers prefer it | — |

**Placeholders still open:** `<TIP>` (the bluetooth-next commit the series is based on, after the
fresh-base check); the recipients.

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
