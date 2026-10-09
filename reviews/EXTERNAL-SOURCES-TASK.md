# External-sources review task — the open defects of the QCA9377 (`13d3:3503`) project

*(The brief as given on 2026-09-29, when it was kept private until the reports and patches
it led to were sent; ported to `main` on 2026-10-09.)*

## What is asked

The first review (2026-09-26) read the **source code** behind our defects. This one asks
for the **world outside the code**: for each open item below, find what other people have
already seen, said, reported, fixed or refused, and tell us how our observation fits.

For every item we want to know:

1. **Has it been reported before?** Bug trackers (kernel bugzilla, Launchpad, Fedora and
   Arch bug trackers and forums, freedesktop GitLab for PipeWire and WirePlumber, GNOME
   GitLab, the BlueZ GitHub issues), mailing lists (`linux-bluetooth`, `stable`, the
   PipeWire and WirePlumber lists), vendor material (Qualcomm/Atheros firmware notes,
   `linux-firmware` commit messages for `qca/`), distribution changelogs.
2. **Is it fixed, worked around, or declared "by design" somewhere?** In which release,
   by which commit, with what reasoning. Quote the source and give the link.
3. **Does the outside record contradict our reading?** That is the most valuable answer.
   "Three reports say this headset does X on every controller" changes what we would send.
4. **What is the right venue and form** for what remains: a stable backport request, a
   bug, a patch, a comment on an existing issue — and what evidence that venue expects.

Please give links and dates, and mark each claim as **quoted** (you saw it), **inferred**
(your reasoning) or **not found** (you searched; say where). "Not found" after a named
search is a result. Please do not open, comment on or edit any upstream issue yourself.

## The machine and the evidence

- Laptop: AMD Renoir, xHCI; Bluetooth on USB bus 3 port 3, full speed (12 Mb/s).
- Controller: Qualcomm QCA9377 "ROME", `13d3:3503` (IMC Networks). Interface 1 has
  isochronous alternate settings 1–5 and no 6. ROM firmware `0x302`, patch build `0x111`
  as the stock kernel leaves it; patch build `0x3e8` plus NVM once the QCA setup runs.
- Kernels: Ubuntu HWE `7.0.0-29` … `7.0.0-34` (v7.0 base). BlueZ 5.72. PipeWire 1.0.5,
  WirePlumber 0.4.17, GNOME Settings 46.7 (Ubuntu 24.04).
- Headsets: three models from three vendors (Sennheiser MOMENTUM 4, Shure AONIC 50, one
  more); the SCO evidence below is from the MOMENTUM 4 unless stated.
- Public evidence repository: <https://github.com/ivoitovych/qca9377-bt-hang>. Start with
  `BRIEF.md` (current state, **including retracted claims — do not re-assert those**), then
  `docs/issues.md` (the register: `BT-1`…`BT-7`, `U1`…`U6`), then `evidence/exhibits/`.
  Every exhibit carries the command that produced it.
- Two source-research notes of ours are attached with this brief: `pipewire-wireplumber.md`
  and `gnome-settings.md` (2026-09-27). They already name the upstream commits and
  tracker items we found for `U1`–`U6`; please start from them rather than repeat them,
  and tell us what they missed or got wrong.

## The items, in priority order

### 1. `BT-1`/`BT-2`/`BT-3` — the missing `btusb` table entry, and its stable backport

**What we know.** With no entry in `btusb`'s table, the controller runs on ROM firmware.
On that firmware, the first HCI command after a transparent (mSBC) SCO stream on USB alt 1
gets no answer and the controller is dead until power is removed: **12 of 12** such
streams, four kernels, three headsets (`EX-033`…`EX-053`). Upstream commit `dc16388d45ec`
("Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table", mainline v7.3-rc1, no
`Cc: stable`) adds the entry. A diagnostic build of ours that runs only the QCA firmware
setup part of it: **37 SCO links, 37 hang-ups answered, 0 timeouts**, streams up to 85
minutes (`EX-055`, `EX-056`, `scripts/sco-ledger.sh`). The upstream commit's own reason
is the `0x2005` LE error (`BT-2`): 0 on our firmware-loaded boots too.

**Questions.**
- Other reports of this device (`13d3:3503`, "QCA9377", "IMC Networks", "ROME") hanging on
  calls, dying after HFP, or needing a power cycle: Launchpad (Ubuntu `linux`, `bluez`),
  kernel bugzilla, Arch/Fedora/Manjaro forums, Reddit, GitHub issues. Since when, which
  kernels, which laptops (ours is an ASUS-class Renoir; the vendor ID is IMC Networks).
- The history of this ID upstream: was `13d3:3503` ever proposed before 2026 and refused
  or dropped? Its neighbours `3491/3496/3501` have entries; `3502/3503/3504` did not. Any
  list thread explaining the gap.
- Has anyone already asked `stable@` for `dc16388d45ec`? Any distribution carrying it
  (Ubuntu, Fedora, openSUSE, Arch patches)?
- `linux-firmware`: the `qca/rampatch_usb_00000302.bin` / `nvm_usb_00000302.bin` history —
  what the vendor said each version fixes; anything about SCO/WBS/USB isochronous.
- The `517b693351a2` alt-1 fallback ("Always fallback to alt 1 for WBS", 2020): any reports
  of alt-1 WBS failing on other adapters without alt 6, and how they were resolved (a
  `BTUSB_USE_ALT3_FOR_WBS` entry? a firmware fix?).

**What we intend:** a stable backport request naming `dc16388d45ec`, once the exact upstream
entry (not only our diagnostic build) has run one more boot here. Tell us if the outside
record makes that the wrong move.

### 2. `BT-4` — `btmon` aborts during capture (BlueZ 5.72)

**What we know.** A raw-HCI command/response exchange (`hciconfig hci0 name`) aborts an
active `btmon` capture, every time (`EX-011`). Up to 85 aborts per boot here because our
own health probe fires the trigger on a timer. Our first check of BlueZ master was not
completed; commit `2908491c` in `monitor/` is a candidate fix we have not read.

**Questions.** Is it fixed in BlueZ master or any release after 5.72, by which commit; any
bug or list thread describing the same abort (search: "btmon" + "abort", "assert",
"double free", "core dumped", "hciconfig"); whether Ubuntu 24.04 carries a fix. If it is
not fixed, the right form is a patch to `linux-bluetooth`; say what a reproducer there
would need.

### 3. A third `bluetoothd` crash — bad `free()` under `g_main_loop_run` (2026-09-08)

At neither of the two sites fixed upstream in September (`a734b06059cb`, `0bed9886cff3`,
both ours). One occurrence, core retained, mechanism unknown. **Questions:** any BlueZ
report of a `free()` abort in `bluetoothd` 5.72–5.8x with a Bluetooth audio device
(search "bluetoothd" + "free(): invalid pointer" / "double free" / "SIGABRT"), and whether
a later release names a fix that fits.

### 4. `U3` — the handsfree headset's microphone does not become the default input

**What we know** (`pipewire-wireplumber.md`, §U3): WirePlumber's configured default wins
over `priority.session` by design (0.4.17 and master); wireplumber#914 (open) is the closest
discussion; `module-switch-on-connect` exists on the PipeWire side; GNOME
gnome-control-center#3800 (open) is about Settings rewriting the configured default.

**Questions.** Any decision on record — maintainer statements, closed-as-designed
issues, distribution defaults — for "selecting a handsfree device should select its
microphone". What KDE, Windows and Android do (a documented reference, not an opinion).
Whether the suggestion is better placed with WirePlumber (#914) or GNOME Settings, and
whether one already exists that we should comment on rather than open.

### 5. `U4` — the "Configuration" (codec) row disappears in GNOME Settings

**What we know** (`gnome-settings.md`, §1): the row's visibility is a snapshot taken when
the combo row's device object changes, and gvc updates the profile list silently; not fixed
through 51.0; gnome-control-center#1317 (open, 2021) is the nearest report.

**Questions.** Other reports of the missing profile/Configuration row with Bluetooth
handsfree (GNOME GitLab, Launchpad, distribution forums); whether #1317 is the right thread
to add to; any merge request in flight for gvc `set_profiles` notification.

### 6. `U6` — the input level meter stays dead after handsfree → A2DP

**What we know** (`gnome-settings.md`, §2): fixed for 47 by `bf6f7227`, `3aeb837c`,
`afec106a`, `a74bc5a8` (2024-03-07); Ubuntu 24.04 ships 46.7 with none of them;
libgnome-volume-control#48 (open) is the remaining upstream gap.

**Questions.** Whether Ubuntu has a Launchpad bug for the dead meter on 24.04 and whether
an SRU of those four commits was ever proposed or refused; the SRU policy fit (a
user-visible bug with an upstream fix in the next release).

### 7. `U2` — the headset microphone volume moves with no user action; "mute on"

**What we know** (`pipewire-wireplumber.md`, §U2): the volume ↔ `AT+VGM`/`+VGM` gain
coupling is deliberate; pipewire#678 (open since 2021) is the thread; a per-headset quirk
(`hw-volume-mic`) is the upstream remedy if the headset itself sends gain 0.

**Questions.** Reports of the Sennheiser MOMENTUM 4 (and the Shure AONIC 50) announcing
"mute on" or sending `AT+VGM=0` on Linux, macOS or Android; any existing quirk request for
these models in `bluez-hardware.conf`; how pipewire#678 was left.

### 8. The Shure AONIC 50's HFP service-level connection sometimes never completes

`RFCOMM receive command before SLC completed: AT+%QAC=0`, then `AT+BTRH?` "modem not
available" (PipeWire 1.0.5 native backend). **Questions:** what `AT+%QAC` is (a Qualcomm
aptX-voice/HFP vendor command?), whether PipeWire master handles it, and whether other
users see this headset's HFP fail on Linux.

### 9. The kernel CI bot's `mesh-tester` failure (context, and a possible contribution)

Every kernel patch on the `linux-bluetooth` patchwork since 2026-06-01 — ours included,
patch `14845586` — carries `TestRunner_mesh-tester: fail` ("Mesh - Send cancel - 1/2" timed
out); before 2026-05-15 the same check passed (`scripts/patchwork-checks.sh --rate`).
**Questions:** has anyone on the list or in `bluez/bluez` issues noted it; is there a
kernel or tester change between 2026-05-14 and 2026-06-01 that explains it (kernel
`71af682ba469` and `3c742feda8fc` touch mesh send-cancel later, in August and September, and
did not clear it); would a fix to `tools/mesh-tester.c` or the kernel be welcome.

## Already sent or fixed (context, no work needed)

- BlueZ: two `bluetoothd` NULL dereferences, applied upstream 2026-09-21.
- Kernel: `Bluetooth: MGMT: Fix status of pending commands flushed on power off`, sent
  2026-09-24, patchwork `14845586`, state *new*, no human reply yet.
- Withdrawn by us: `U5` (handsfree "picks the worst codec") — it picks the last-used codec
  per device, by design; `U1`'s generic "Headset Head Unit" entry is gone from PipeWire 1.2.

## What we would like back

1. Per item: the links, what they say (quoted), and your reading of how our observation
   relates — same defect, related, or contradicted.
2. Per item: the venue and form you would use, and what evidence it expects that we do
   not yet have.
3. Anything the outside record shows that we have not listed.

Constraints: the machine is a family laptop; experiments are short and a wedge costs the
household until the next power cycle. This task needs no experiment. Please do not post
anywhere on our behalf.
