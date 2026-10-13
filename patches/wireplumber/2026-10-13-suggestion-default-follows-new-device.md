# DRAFT: WirePlumber suggestion: optional "a newly connected device becomes the default"

Status: **draft, not posted.** Posting is the operator's own decision. Target:
https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/new, label `type::suggestion-request`.
Addresses are replaced by `<headset A>` (MOMENTUM 4) and `<headset B>` (Shure AONIC 50);
keep them that way when posting. Everything between the two
`8<` lines is the issue text.

Before posting:
- [ ] The operator has read it and agrees with every sentence, in particular the choice in
      "Open questions" 1 (a new connection also outranks the selected device).
- [ ] **Not ready to post (2026-10-13, outside review, two rounds).** Round 1 asked for the narrow
      variant only. Round 2 revised that: keep the broad variant and offer the maintainers both
      use cases as opt-in modes, default `off`: `off` (today's behaviour), `fallback-only` (a new
      device replaces an automatic fallback, never an available, explicitly selected device),
      `prefer-new` (a new device wins until the next manual selection). Names are illustrative.
      Before rewriting:
      - outputs only;
      - Bluetooth only;
      - define the event identity (device known, link up, usable sink, profile change) and the
        ordering against asynchronous selections;
      - reproduce the sequence on 0.5.18 (fetched 2026-10-13; it carries `481ecff`) in an
        isolated session;
      - first message: the behaviour contract and the use cases, not the hook design.
      The variant set is the operator's decision.
- [ ] Optional: reproduce on 0.5.18 in an isolated session (not on the laptop without
      the operator's word). The maintainers may ask for it; #1036 says 0.5.18 has the same
      fallback rule.
- [ ] Decide whether to offer a merge request (last line of the text).

8<----------------------------------------------------------------------------------------

**Title:** Optional setting: let a newly connected device become the default sink

### Summary

When a Bluetooth headset connects, it does not become the default sink if an older entry
in the `default-nodes` history ranks above it. The user has to open the sound settings and pick
it, every time the order of the history and the order of use disagree. I'd like to suggest an
**opt-in** setting under which a device that has just connected becomes the default, until the
user selects something else.

I know this has gone back and forth (#352), and that many people do not want new devices to
take over (#83, #221, #629). Hence opt-in, default off.

### What happens today

WirePlumber 0.4.17 (Ubuntu 24.04), PipeWire 1.0.5. History at the time (`default-nodes` state
file, sink keys, relevant entries):

```
default.configured.audio.sink=bluez_output.<headset A>.1
default.configured.audio.sink.0=bluez_output.<headset A>.1
default.configured.audio.sink.1=alsa_output.pci-0000_03_00.6.analog-stereo
default.configured.audio.sink.2=bluez_output.<another headset>.1
default.configured.audio.sink.3=bluez_output.<headset B>.1
```

1. Headset A is the selected default and plays.
2. Headset A is switched off. The default falls back to the laptop output (stack position 1).
   As expected.
3. Headset B is switched on and connects; its A2DP sink is created. **The default stays on the
   laptop**, because position 1 outranks position 3. Every new stream for the next five minutes
   goes to the laptop.

```
01:01:00.686778 wireplumber: ... default target picked: alsa_output.pci-0000_03_00.6.analog-stereo (52)
01:02:04.793905 wireplumber: Setting profile a2dp-sink on bluez_card.<headset B>
01:02:09.278445 wireplumber: ... default target picked: alsa_output.pci-0000_03_00.6.analog-stereo (52)
01:03:30.848569 wireplumber: ... default target picked: alsa_output.pci-0000_03_00.6.analog-stereo (52)
01:06:58.002247 wireplumber: ... default target picked: alsa_output.pci-0000_03_00.6.analog-stereo (52)
```

Nobody selected anything in that window. The laptop's place above headset B comes from an
earlier selection. Connecting headset B is not a selection, so the history does not change.
This is all as designed (`7a1b48b7`). In master, `state-default-nodes.lua` ranks the stack by
position only (`481ecffb`, #1005), and as #1036 says, 0.5.18 falls back "to the most recent one
in that list that's still available". So I expect the same result there.

On a shared laptop with several headsets, the people using it think "I turned my headphones on,
so the sound should be there". The history answers a different question: which of the
remaining devices was chosen most recently.

### Why not `module-switch-on-connect`

It does the switching, but it writes `default.configured.audio.sink`/`.source` for every new
device, so each connection is recorded as a user selection and reorders the history.
`only_from_unavailable` is not implemented. It also switches inputs together with outputs, and
it lives in the pulse layer rather than in the policy.

### Proposal

Two settings, both default `false`:

- `node.default-follows-new-device.audio.sink`
- `node.default-follows-new-device.audio.source`

(Names are placeholders.)

Rule: **the most recent intent wins.** An intent is either
- an explicit selection: a change of `default.configured.<type>`, as today; or
- an eligible device connecting.

While the most recent intent is a connection, and that device's node is available, that node
is the default. Once the user selects something afterwards, the selection wins again, as today.

Details:
- **Eligible:** devices added after WirePlumber's initial enumeration. Devices present at
  startup do not count, so the boot order cannot decide. By default only `device.api = bluez5`
  devices are eligible; standard match rules can widen or narrow that (USB headsets, docks).
  HDMI and DisplayPort nodes are never eligible by default.
- **A device, not a node:** a profile switch (A2DP ↔ HFP) re-creates nodes but does not re-add
  the device, so it does not count as a new connection. A drop and reconnect of the same device
  stays the same intent.
- **No writes to the history:** `default.configured.*` and the state file are untouched, so
  turning the setting off restores today's behaviour exactly. The state is in memory only.
- **Streams:** unchanged. Whether running streams move is still decided by
  `linking.follow-default-target` and the stream's own target.

Implementation sketch: a hook `default-nodes/find-connected-default-node` in the
`select-default-node` chain, after `find-selected-default-node`. When the latest intent is a
connection, it sets that node with a priority above the configured node's `30000 + priority`.
The intent order would come from a `device-added` hook (connections) and the existing
`default.configured.*` metadata change (selections).

### Open questions

1. Should a new connection also outrank the **selected** default while that device is still
   present (my proposal), or only when the selected default is absent? The narrower variant is
   enough for the case above. The broader one matches what users of a shared machine expect
   when they turn on their headphones.
2. One setting with a list of node types, or two booleans?

I can prepare a merge request if the approach is acceptable.

8<----------------------------------------------------------------------------------------

## Sources for the operator (not part of the issue)

- Log lines: `journalctl _UID=1000 --since "2026-10-13 00:53:40" --until "2026-10-13 01:07:00" -o short-iso-precise -g "Setting profile|default target picked"`,
  addresses replaced with `<headset A>` and `<headset B>`.
- History: `default-nodes` state file as recorded in the U11 entry (`docs/issues.md`). Since
  01:11:04 it reads differently: headset B was selected then, so it is now position 0.
- Hook names and priorities: `src/scripts/default-nodes/README.rst`,
  `find-selected-default-node.lua:55` (`30000 + priority`), local WirePlumber tree at `251d742`.
- `module-switch-on-connect`: PipeWire master `pulse-module-switch-on-connect.c:32`, 135–137,
  154–158.
- #352, #914, #1005, #1036, #83, #221, #629: `reviews/2026-10-13T0200Z-u11-outside-research-web-sources.md`.
