# Source review — follow-up comments, 2026-09-26

*(The reviewer's follow-up, received after they read `main` and the stored report. **Condensed**
here — the table and conclusions are kept, some sentences are shortened, and inline
source-citation markers from the reviewer's tooling are removed. No finding was added or
changed.)*

The reviewer checked the maintainer's comments against current `main` (`BRIEF.md` blob
`ca8d6aba…`, `docs/issues.md` blob `24ca666…`) and the stored report (blob `fd758011…`).

| Defect | Current status as the reviewer sees it | Contribution opportunity |
|---|---|---|
| **1. BlueZ Start Discovery NULL/short reply crash** | **Done.** Upstream as `a734b06059cb…`. | Contribution already made. |
| **2. BlueZ A2DP `transport_cb()` NULL stream** | **Done.** Upstream as `0bed9886cff3…`; the local guard firing four times is unusually strong runtime validation. | Contribution already made. |
| **3. Kernel MGMT wrong status when pending commands are flushed** | **Submitted, apparently still pending.** The Sept 24 posting is in the archive; no later applied/review response surfaced. | Wait for review rather than resend. |
| **4. `13d3:3503` missing QCA ROME classification** | **Already fixed upstream by someone else** in `dc16388d45ec`, which names this exact USB ID and the `0x2005` BLE-scan failure. | Not a new mainline patch; hardware validation and possibly a **stable/backport contribution**. The foundation for the BT-1 experiment. |
| **5. BT-1 fatal WBS/alt-1 controller wedge** | **The major unsolved defect and the best chance for another substantive kernel contribution.** Generic `9+9+9` framing is not wrong; the alt-3 flag alone is a no-op with SCO MTU 50. QCA setup remains the best first intervention, but the setup-command distinction changes how to interpret it. | **Highest priority.** Several plausible upstream patches depending on controlled results. |
| **6. Healthy `btusb` reload kills controller** | Strongly suggestive of missing QCA pre-HCI setup, **not proven** — "plausibly cured by `dc163…`", not "probably". | See whether a cold-boot current-QCA build changes it; never reproduce via live rebind. If current upstream still cannot survive a warm reprobe, it is a clean separate kernel defect. |
| **7. BT-2 `0x2005` every 16 s** | "Nobody has written it" is obsolete: `dc16388d45ec` effectively *is* an upstream fix/report for the same ID and symptom. The exact 16.0 s cadence remains unexplained. | Test with QCA ROME handling. Disappears → stable/backport evidence. Persists on current upstream → a second bug worth patching. |
| **8. BT-4 `btmon` abort** | Quite possibly **already fixed upstream** by BlueZ `2908491c…` (a `monitor/packet.c` stack-buffer overflow when terminal width exceeds 255). Not yet proven the same defect. | Cheap test: current `btmon`, or 5.72 plus that patch, on the deterministic `hciconfig hci0 name/version` reproducer. Still crashes → BlueZ contribution; fixed → distro backport. |
| **9. Third `bluetoothd` bad `free()`** | **Completely open and separate.** | Needs the next core with symbols, or ASan allocation/free provenance, before any code. |
| **BT-6 unknown ACL handle** | One occurrence; an observation, not a demonstrated defect. | Keep detection; no patch effort yet. |
| **Shure `%QAC` / `BTRH?` SLC** | Separate PipeWire/HFP problem; not BT-1. | Lower-priority possible PipeWire contribution. |

**The setup-command correlation.** `main` now records that EX-031 was not CVSD: transparent
WBS, alt 1, `len 27 mtu 9`, survived ~17 min, set up by **Enhanced `0x043D`**; all twelve
fatal cases used legacy **`0x0428`**. QCA's upstream setup deliberately sets
`HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN` (introduced 2022 because SCO/mSBC was reported
not to work with Enhanced Setup on some QCA controllers), and current `btusb_setup_qca()`
still sets it. An inversion: upstream experience says QCA + Enhanced → broken mSBC, so force
legacy; this QCA9377's one long Enhanced session survived and all twelve legacy sessions
died. One uncontrolled survival cannot beat the reason for the quirk — but it is the kind of
hardware-specific evidence that can lead to a follow-up patch if a controlled experiment
confirms it.

**A retraction in the stored report.** Candidate (b) said disabling WBS would return to a
"CVSD/control condition that has survived in the repository". That depended on the old EX-031
classification and is **retracted**. WBS suppression remains a good discriminator, but no
recorded CVSD control proves survival beforehand.

**Refined ladder for BT-1.**

1. **QCA setup, automatic timeout reset disabled**, cold-booted through `updates/`, keeping the
   fatal conditions intact: legacy `0x0428`, WBS, alt 1, `27 → 9+9+9`. Survival → the evidence
   for missing QCA setup becomes extremely strong.
2. If it still dies, **do not jump to WBS-off yet.** First extract, from old captures, what the
   controller advertised in `Read Local Supported Commands` on the EX-031 boot versus the fatal
   boots. If it advertises Enhanced, a second diagnostic build keeps QCA setup but does not set
   `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN` for this controller/version: `QCA setup +
   0x0428 + alt 1` versus `QCA setup + 0x043D + alt 1`. Repeated legacy deaths and Enhanced
   survivals on otherwise identical boots could become a real kernel contribution — narrowing
   the quirk for this ROM/ID, not removing it globally.
3. `dc16388d45ec` gives this device ROME setup **and** advertises WBS. If BT-1 reproduces on
   top of that treatment, upstream enables a capability that reliably wedges the hardware; a
   narrowly evidenced follow-up (drop WBS for this ID, change the setup-command quirk for this
   ROME revision, or similar) becomes defensible.

**Focus.** Concentrate on BT-1 rather than scatter across all nine; in parallel, BT-4 is a
cheap "already fixed?" check, and the third bad free should be instrumented so its next
occurrence yields a patchable stack. Do not file BT-2 as a fresh bug: test the fix first; if
the exact 16 s desync survives current QCA handling, that is something new.

The fault boundary is now **QCA initialization × synchronous-setup opcode × WBS/alt 1** —
narrow enough that a few cold-boot experiments could plausibly end in another upstream patch.
