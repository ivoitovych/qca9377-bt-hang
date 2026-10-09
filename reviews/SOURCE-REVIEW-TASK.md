# Source review task — Bluetooth defects on a QCA9377 (`13d3:3503`) laptop

*(The brief as given on 2026-09-26, when it was kept private until the fixes it led to were
sent; ported to `main` on 2026-10-09.)*

## What is asked

A **source-code review** of the Linux Bluetooth stack (and, for three items, BlueZ), aimed at
the defects this project has observed on one laptop over six weeks. The observations are
solid and re-runnable; what is missing for most of them is the **mechanism** — which line of
code, or which host behaviour, produces the failure. The aim is to turn observations into
patches that go upstream.

Please read the code, not only this brief. For each defect: what in the source explains the
observation, what does not, what a fix would look like, and what experiment on the machine
would confirm or refute your reading. **Findings that contradict this brief are as welcome as
ones that support it.** "I looked at X and it cannot be the cause" is a result.

You are free to go anywhere the code leads — USB core, the host controller driver, the QCA
firmware loader, `hci_sync`, BlueZ, PipeWire's HFP backend. The list below is where we know
to look; the defects we have not found are the ones you may see.

## The machine and the evidence

- Laptop: AMD Renoir, xHCI; Bluetooth on USB bus 3 port 3, **full speed (12 Mb/s)**.
- Controller: Qualcomm QCA9377 "ROME", `13d3:3503` (IMC Networks). Interface 1 has
  isochronous alternate settings **1–5 and no 6**.
- Kernels observed: Ubuntu `-29`, `-30`, `7.0.0-31`, `7.0.0-34` (v7.0 base + Ubuntu delta).
- BlueZ 5.72 (Ubuntu, with two local patches since merged upstream); PipeWire/WirePlumber 1.0.5.
- Headsets: three models from three vendors (Shure AONIC 50 is the newest).
- Public evidence repository: <https://github.com/ivoitovych/qca9377-bt-hang>. Start with
  `BRIEF.md` (current state, **including retracted claims — do not re-assert those**), then
  `docs/issues.md` (the defect register, `BT-1`…`BT-7`), then `evidence/exhibits/` — every
  exhibit carries the exact command that produced its output.
- Source trees to read against: `bluetooth` and `bluetooth-next` (git.kernel.org,
  `bluetooth/bluetooth.git`, `bluetooth/bluetooth-next.git`), mainline, and BlueZ master.

## The defects, in priority order

### 1. `BT-1` — the controller wedges on the alternate-setting-1 SCO path (the main one)

**Observed, 12 times** (`EX-033`, `036`, `037`, `038`, `040`, `042`, `043`, `045`, `047`,
`051`, `052`, `053`), on four kernels, three headsets, both power configurations:

1. The headset's HFP negotiates **transparent (mSBC) SCO**. `btusb` gets
   `HCI_NOTIFY_ENABLE_SCO_TRANSP` (`evt 5`), logs `Looking for Alt no :6` then `:3`, finds
   neither usable, and selects **alt 1**: a 9-byte isochronous endpoint. Each 27-byte SCO
   buffer goes out as three 9-byte packets (`len 27 mtu 9`).
2. The stream runs — up to 9.65 s (`EX-043`) and 7.3 s (`EX-053`) with **no HCI command in
   flight and no error**.
3. **The first HCI command issued after that gets no response.** Usually `0x0406 Disconnect`
   (reason `0x13`, the headset hanging up); once `0x0c1a Write Scan Enable` (`EX-051`). It
   times out after `HCI_CMD_TIMEOUT`.
4. From then on the controller answers **nothing**, including USB **control** transfers
   (`GET_DESCRIPTOR` → `-110`; `usb_set_interface` → "setting interface failed (110)" in
   `EX-052`). It stays enumerated. Only **removing power** recovers it; `HCI_Reset`, a warm
   reboot, a `btusb` rebind, an rfkill cycle (`EX-048`) all fail or make it worse.
5. **Survival control:** ⚠️ *corrected 2026-09-26* — `EX-031` is **not** a CVSD control, as
   this brief first said: it is a **transparent (wideband) link on alt 1** (`evt 5`,
   `len 27 mtu 9`) that ran ~17 min and survived — set up by **Enhanced** `0x043D`, while
   every death used legacy `0x0428`. One recorded survival on 09-01 carried only 8 alt-1 buffers — the
   peripheral's choice, not an intervention; there is no controlled comparison yet.

**Not established:** whether the command *causes* the wedge or *discovers* a controller the
alt-1 stream already wedged (`DR-03` in the repository).

**Where to look, and what we already see:**

- `drivers/bluetooth/btusb.c`, `btusb_work()` (bluetooth tree ~2464–2525): the alt choice
  for `HCI_NOTIFY_ENABLE_SCO_TRANSP` is alt 6 if present; else alt 3 if `sco_mtu >= 72` and
  `BTUSB_USE_ALT3_FOR_WBS` (set today only for Realtek, ~4462); else **alt 1**. The comment
  says alt 1 "appears to work for all adapters that do not have alt 6, and which work with
  WBS at all". It came in with `517b693351a2` ("Bluetooth: btusb: Always fallback to alt 1
  for WBS", 2020, v5.12).
- `__fill_isoc_descriptor()` (~1827) vs `__fill_isoc_descriptor_msbc()` (~1784, alt 6
  only): the alt-1 path splits by `mtu` with no pacing; the alt-6 path deliberately paces at
  7.5 ms per the Core spec, Vol 4, Part B, Table 2.1. **Is the alt-1 packet rate and framing
  for mSBC within what that table allows for alt 1 at full speed?** What does the controller
  expect for transparent data on alt 1?
- `btusb_switch_alt_setting()` (~2405) and `__set_isoc_interface()` (~2362): URBs are killed
  and `usb_set_interface` is issued on every alt change. Any ordering hazard between the
  isochronous stream and the next HCI command on the bulk/interrupt endpoints? The command
  that dies travels on the control endpoint (HCI commands go by `usb_control_msg` class
  requests) — **does anything in the alt-1 stream's scheduling starve or collide with
  EP0 on a full-speed device behind xHCI?**
- `dc16388d45ec` (master, 2026-08-07) finally gave `13d3:3503` a table entry:
  `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`. That installs QCA firmware setup and a reset
  path we have never run, **and formally advertises wideband speech** — the mode that
  kills this part. How did transparent SCO get negotiated on our kernels, where the device
  had no table entry and so no `BTUSB_WIDEBAND_SPEECH`?
- `drivers/bluetooth/btqca.c`: what does the ROME setup change (firmware patch, NVM, SCO
  routing/`WBS` configuration)? Could the missing setup be the actual defect — i.e. this
  controller runs with ROM firmware that mishandles transparent SCO over USB?
- QCA's own out-of-tree / Android handling of WBS on ROME over USB, if you know it.

**What would help most:** a reasoned choice between candidate fixes, each small and
testable here with a self-built module loaded from `updates/` and a cold boot:

- (a) set `BTUSB_USE_ALT3_FOR_WBS` for this device (alt 3 needs `sco_mtu >= 72` — is that
  met?);
- (b) drop `BTUSB_WIDEBAND_SPEECH` for this device (no mSBC; CVSD only);
- (c) pacing or framing on the alt-1 transparent path, if the code shows it is wrong for
  all devices, not just this one;
- (d) the QCA ROME setup alone (`dc16388d45ec` minus its reset callback), to see whether
  firmware setup removes the fault.

### 2. `BT-2` — opening the GNOME Bluetooth panel starts `unexpected event for opcode 0x2005`

Within 0.06–10 s of opening the panel, `unexpected event for opcode 0x2005`
(`HCI_LE_Set_Random_Address`) appears and repeats at an **exact 16.0 s cadence** for as long
as the panel is open (runs of 228–2480; `EX-002`, `EX-003`). Not the cause of `BT-1`.
Reproducible in seconds. Where to look: `net/bluetooth/hci_event.c` (the message, ~4345 and
~4464), `hci_sync.c` (LE scan / random-address rotation during discovery). Why would the
controller answer `0x2005` twice, or late? Is 16 s a timer in the host?

### 3. Driver reload on a **healthy** controller is fatal (`EX-046`)

A `btusb` unbind/re-probe, no SCO involved: the first command of the re-probe, `HCI_Reset`
`0x0c03`, times out, and `hci0` comes up with an all-zero address, DOWN. Our reading: with
no table entry there is no firmware-setup path, so the re-probe talks to a controller left
in a state the generic path cannot handle. Please confirm or refute from `btusb_probe()` /
`btqca.c`, and say whether `dc16388d45ec` fixes it.

### 4. `BT-4` — `btmon` aborts repeatedly while capturing (BlueZ 5.72)

Up to 67 aborts in one boot; a liveness probe (`hciconfig … name`) deterministically aborts
an active capture (`EX-010`, `EX-011`). Where to look: BlueZ `monitor/` decoders. Is it
fixed in BlueZ master?

### 5. A third `bluetoothd` crash: a bad `free()` under `g_main_loop_run` (2026-09-08)

At neither of the two sites fixed upstream in September (`a734b06059cb`, `0bed9886cff3`);
cleared of being caused by those patches (`BRIEF.md` §6). Its cause is not investigated.

### 6. HFP service-level connection with the Shure AONIC 50 sometimes never completes

WirePlumber 1.0.5: `RFCOMM receive command before SLC completed: AT+%QAC=0`, then
`RFCOMM receive command but modem not available: AT+BTRH?`. On a later connection HFP came
up (and led to `EX-053`). A PipeWire issue, not kernel; worth a look only if cheap.

## Already fixed or sent (context, no review needed)

- BlueZ: two `bluetoothd` NULL dereferences — applied upstream 2026-09-21.
- Kernel: `Bluetooth: MGMT: Fix status of pending commands flushed on power off` — sent to
  `linux-bluetooth` on 2026-09-24.

## What we would like back

1. Per defect: the code path you believe explains it (file, function, line, tree and
   commit), how sure you are, and what would falsify it.
2. For `BT-1`: your ranking of candidate fixes (a)–(d) or better ones, and the single
   experiment you would run first.
3. Anything else the code shows that we have not listed.

Constraints: the machine is a family laptop — experiments are short, and a wedge costs the
household until the next power cycle. Do not propose unloading or rebinding `btusb` on the
live system (`EX-046`); module changes go in via `updates/` and a cold boot.
