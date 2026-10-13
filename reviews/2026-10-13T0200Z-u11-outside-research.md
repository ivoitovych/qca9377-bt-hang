# U11 outside research: claim check

The research is in `2026-10-13T0200Z-u11-outside-research-text.md`. It was relayed by the
operator. This file checks its claims against the local source trees, this machine's logs, and
(section C) the public pages it cites. Labels: [source], [log], [inference], [operator].

## A. Claims about code: checked against local trees

Trees: `cache/wireplumber-upstream` (tag `0.4.17` and `master` at `251d742`),
`cache/pipewire-upstream` (`master`), `cache/bluez-upstream` (`master`).

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| A1 | 0.4.17 gives history positions 300,000 (laptop, position 1) and 260,000 (Shure, position 3); a new device gets no bonus | **confirmed** | `git -C cache/wireplumber-upstream show 0.4.17:modules/module-default-nodes.c`, `find_best_media_class_node()`: `prio += (N_PREV_CONFIGS - i) * 20000`, `N_PREV_CONFIGS 16`; no arrival term. Positions from the U11 entry in `docs/issues.md` |
| A2 | The reviewer's illustrated stack "1 MOMENTUM 4, 2 laptop, 3 Shure" | **simplified** | The state file has `.0` MOMENTUM 4, `.1` laptop, `.2` another Bluetooth output, `.3` Shure. The ranking conclusion is unchanged |
| A3 | WirePlumber 0.5 docs say saved selections outrank `priority.session` | **confirmed** | `docs/rst/daemon/configuration/priorities.rst:12–22` ("outranks every `priority.session` value"; `wpctl clear-default`; `node.restore-default-targets`) |
| A4 | 0.5 ranks history by position only, without `priority.session` | **confirmed, and it is new** | `481ecff`, Julian Bouzas, 2026-09-21, "default-nodes: Rank stored nodes by stack position only", "See #1005". It is after 0.5.17, so it is not in a release yet. Already in `2026-09-27-research-pipewire-wireplumber.md` (U3) |
| A5 | `module-switch-on-connect`: skips internal devices, `hdmi` blocklist by default, ignores virtual nodes, acts only after the initial scan | **confirmed, one detail** | `pulse-module-switch-on-connect.c:116–133`, `started` flag at 167–183. Detail: an internal PCI/ISA device is skipped *unless it is an HDMI sink* (line 119–120); the default blocklist `hdmi` then catches those by node name |
| A6 | `only_from_unavailable` is accepted but not implemented, with a warning | **confirmed** | line 32 `MODULE_ARG_ENOTIMPL`; 135–137 `/* XXX: not implemented */`; 291 `pw_log_warn("only_from_unavailable is not implemented")` |
| A7 | The module writes `default.configured.audio.sink`/`.source`, so its choices enter WirePlumber's history | **confirmed** | module lines 154–158 write `METADATA_CONFIG_DEFAULT_SINK`/`_SOURCE`. In 0.4.17 a change of that key calls `update_prev_config_values()` (`on_metadata_changed()`), which moves the node to stack position 0. So with the module on, the most recently *connected* device would also become the top of the history [source + inference] |
| A8 | It switches inputs as well as outputs | **confirmed** | line 91: sinks and sources; 156: sink or source key |
| A9 | BlueZ `plugins/policy.c` reconnects only after link timeout or local-host suspend | **confirmed** | `disconnect_cb()` lines 919–922. A headset switched off cleanly does not trigger a host-side reconnect; it has to connect back itself [source]. Whether that matters for the operator's reconnect observation is untested |

### A fact the research did not have, which sharpens its own model

The research's central distinction is "a deliberate choice" versus "a temporary fallback". In
0.4.17 these are **already separate**:
- The history stack changes only when a client writes `default.configured.audio.*`
  (`on_metadata_changed()` → `update_prev_config_values()`).
- WirePlumber's own fallback pick writes `default.audio.sink` (`reevaluate_default_node()`,
  `DEFAULT_KEY`), which does not touch the stack.
- [log] The state file was last written 10-11 16:31:07, i.e. the fallback to the laptop at
  01:01:00 on 10-13 was **not** recorded as a choice. The configured value stayed the MOMENTUM 4.

So in U11 the laptop did not outrank the Shure because a fallback was saved. It outranked it
because **some earlier explicit write** of `default.configured.audio.sink` (GNOME Settings,
`wpctl set-default`, or any other client) put the laptop above the Shure. The research's
proposed rule ("fallback must not become the preference") already holds. The rule U11 actually
needs is different: **"a device that has just connected should outrank older history entries
when the configured device is absent"**. That is the "new device" signal the stack lacks.

## B. This machine: what changed since the U11 entry

- [log] `journalctl _UID=1000 -b 0 -g SET_DEFAULT_SINK`:
  - `2026-10-11T16:31:06+02:00 … [GNOME Settings] SET_DEFAULT_SINK tag:29 name:bluez_output.<MOMENTUM 4>.1`
  - `2026-10-13T01:11:04+02:00 … [GNOME Settings] SET_DEFAULT_SINK tag:30 name:bluez_output.<AONIC 50>.1`

  The second line is new since the U11 entry: at 01:11:04 the Shure was chosen in GNOME
  Settings. That puts it at the top of the stack, so the next MOMENTUM 4 to Shure change will
  look different. Any reproduction must record the stack before each step.
- **When the laptop was put above the Shure cannot be dated from our logs.** This tests the
  research's "it worked months ago, then an explicit choice reordered the stack" hypothesis, and
  the test is inconclusive:
  - `scripts/journal-archive-grep.py "default\.configured\.audio\.sink|SET_DEFAULT_SINK" /root/bt-journal-archive/boot-*.export.zst`
    → `total: 0` over 60 archived boots.
  - That zero is not evidence. The drop-in that logs `SET_DEFAULT_SINK`
    (`~<user>/.config/systemd/user/pipewire-pulse.service.d/90-bt-ui-capture.conf`,
    `PIPEWIRE_DEBUG=mod.protocol-pulse*:3`) was staged 2026-10-05 02:37:18 and is read only
    when pipewire-pulse starts, i.e. first at the 10-11 reboot. Control: the last archived boot,
    `boot-c34cfa10` (ended 10-11), has 4,517 audio-stack lines (`bluez_output|spa\.bluez5|default-nodes|pw\.conf`,
    first at 10-06 20:23:51) but 0 `protocol-pulse` lines. The current boot has both choices above.
  - So the hypothesis is still possible but untested. The only dated record of the stack is the
    state file's contents, not its history.

## C. Claims about public pages

Full record, with quotes, URLs and dates: `2026-10-13T0200Z-u11-outside-research-web-sources.md`
(raw GitLab JSON stays in `tmp/u11-wp-*.json`; some of it carries a MAC copied from a public
issue, so it is not committed). Summary: 4 confirmed, 5 partly right, 2 not reachable or not
found, none wholly wrong.

| Claim | Verdict | Correction |
|---|---|---|
| WirePlumber GitHub #11 (2022) | confirmed | Closed "completed" 2022-11-16 with nothing fixed; the 0.4.12 quote is "only seems to work 1st time after restarting wireplumber" |
| r/archlinux, Feb 2021, PipeWire 0.3.21 | not found | Reddit is behind a login wall; three searches found no such thread |
| KDE plasma-devel, March 2018 | partly | One post by David Rosca quoting Nate Graham's checkbox text, not "KDE developers" as a group |
| PulseAudio docs, 11.0 notes | confirmed | Docs: switch-on-connect "not loaded by default, beacuse it's a bit too aggressive". 11.0 notes: most USB devices were prioritized only from 11.1 |
| KDE bug 392103 | partly | Edmundson closed it on 2018-03-20 before the 2019 reopen; final state **RESOLVED WONTFIX** (2025-08-02), not "fixed" |
| Debian #998073 | confirmed | Dates and quotes match; first filed against pipewire-pulse, moved to wireplumber 2022-05-30 |
| User reports (KDE Discuss, Manjaro, Reddit) | partly | KDE Discuss matches; the Manjaro 2024 thread is about a **wired** jack; the Reddit threads were not reachable |
| BlueZ #294 | partly | Closed "not planned" 2025-09-16; nobody mentions cost; the address that could leak is the laptop's; `ReconnectStartup` was never implemented |
| BlueZ PR #633 | confirmed | Closed unmerged by the test bot, pointing to the mailing list |
| Launchpad 2169383, pop-os 4102, BlueZ 2524, 2575 | confirmed | All exist; BlueZ 2524 was closed by its reporter 2026-10-07 without a fix |
| Plasma 5.17 "fixed" | partly | Not in the 5.17 announcement; it is a comment on KDE bug 399487. In the 2021 Manjaro thread the missing module was `module-gsettings` |

### What the research missed on the official tracker

The research reached only the GitHub mirror. The official WirePlumber tracker has the closest
record (GitLab API; quotes in the web-sources file):

- **#352** (2022, closed as intended): "Headphones are not switched to automatically unless
  they are set as the default/fallback sink". Maintainer gkiagia, 2022-11-23: "wireplumber
  prefers to stick to your selection rather than changing to something else", and "We have
  changed this behaviour back and forth in the past because some people want it this way and
  some others don't." This is the maintainers' stated position on exactly U11's question.
- **#1005** (closed 2026-09-23) and MR !902 (`481ecff`): after a disconnect, the most recent
  still-available entry in the stack wins. **#1036** (2026-10-09), Julian Bouzas: this is in
  `0.5.18`, and "When the current default goes away, it falls back to the most recent one in
  that list that's still available." So the newest release behaves as 0.4.17 did in U11.
- **#914** (open, `user-experience`, no maintainer comment): a selection made in a desktop panel
  "permanently overrides" priorities. The reporter suggests a GUI action that sets the current
  output without making it permanent.
- Complaints the other way: #83, #221, #463, #629, #840 (unwanted automatic switches).

## D. Disposition

- **Root cause of U11:** unchanged, and now also confirmed from the maintainers' side (#352,
  #1036).
- **The research's direction holds**, with three corrections:
  1. "Fallback must not become the preference" is already true (section A). The missing input is
     "this device was just connected".
  2. KDE 392103 ended WONTFIX, not fixed. Upstream's recorded reason is the one the research
     names (monitors, HDMI): new outputs that should not take over.
  3. Upstream has already "changed this behaviour back and forth" (#352). A proposal has to
     be opt-in, and has to say how it avoids the cases #83, #221, #463, #629 and #840
     complain about.
- **Who decides, unchanged:** `module-switch-on-connect` on this laptop, any proposal, and
  any reproduction run on the laptop are all the operator's word. The 01:11:04 choice has
  already changed the stack, so a reproduction starts by copying the state file.
- **Where it would go:** WirePlumber's tracker is on gitlab.freedesktop.org. The GitHub mirror
  is not watched (GitHub #11). #352 and #914 are the threads to read first; a new
  `type::suggestion-request` would cite them.
