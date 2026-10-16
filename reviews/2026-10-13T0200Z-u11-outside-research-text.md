# U11 outside research, the text

Relayed by the operator on 2026-10-13 (about 02:00 UTC) as "input/research from Reviewer 2", in
two parts. Edited for publication only: page-scrape residue (site icons, citation counts) and
one non-text interface element were removed, and a few personal phrasings were made neutral.
The findings, sources and reasoning are unchanged. Parts of it answer things the operator
discussed with the reviewer directly (a professional setup versus an everyday one, a settings
checkbox, three headsets, a reconnect observation over repeated power cycles); those are
[operator] statements relayed, not checked here. The claim-by-claim check is
`2026-10-13T0200Z-u11-outside-research.md`.

---

Part 1:

# Investigation: Why Linux Bluetooth audio connects but does not become the active output

Research focus: PipeWire, WirePlumber, BlueZ, GNOME, historical design decisions, upstream discussions, and real user experiences — October 13, 2026

## 1. The first important discovery: this is an old, unresolved usability conflict

I found something particularly relevant: in November 2022, a user opened [WirePlumber issue #11](https://github.com/PipeWire/wireplumber/issues/11) describing almost exactly your situation:

> When i connect bluetooth headset to my laptop, i have to manualy switch to it.

The user wanted newly connected devices to become active automatically, with existing audio streams following.

The discussion is revealing. The reporter discovered the new history-based selection mechanism in WirePlumber 0.4.12 and initially believed it solved the problem. Shortly afterward, they reported that it only worked after restarting WirePlumber and then failed again.

The issue was closed without a demonstrated resolution of that behavior. Most subsequent discussion concerned moving reports to the project's official GitLab tracker.

This matters because the behavior you've experienced is neither a new technical limitation nor an expectation nobody has expressed before. Users have explicitly requested different behavior, including after the historical-default mechanism was introduced.

There is also an interesting historical contradiction.

In February 2021, a post about PipeWire 0.3.21 on r/archlinux celebrated the following improvements:

- Bluetooth headphones automatically becoming the default output upon connection.
- Existing audio streams moving to the newly connected headphones.
- Bluetooth volume being restored correctly.

That historical account shows that the behavior you expect was not some unimaginable feature. At least one earlier PipeWire configuration provided an experience users recognized and appreciated.

The investigation therefore needs to distinguish three questions:

1. Why did the policy evolve toward remembering previous selections?
2. Does that policy accurately represent user intent when devices appear and disappear?
3. Can we design something that preserves the advantages of remembered preferences without producing your current failure?

The third question is especially promising.

## 2. The historical explanation goes back further than WirePlumber

I found an especially useful source from 2018: a discussion on the KDE Plasma development mailing list about PulseAudio's `module-switch-on-connect` and `module-device-manager`.

This is the kind of discussion we were looking for: developers explicitly debating what users expect and why a seemingly obvious behavior was not made the default.

In the March 2018 discussion, KDE developers explained that the two approaches conflicted:

- `module-device-manager` remembers more detailed output preferences, including settings for different types of audio streams, but is limited when new devices appear.
- `module-switch-on-connect` handles newly connected devices naturally, but can override preferences without much discrimination.

The developers recognized both advantages but chose to retain the existing device-management approach as the default, leaving automatic switching as a user option.

This is direct evidence of a historical design trade-off, not just a hypothetical explanation.

Original discussion: [PulseAudio switch-on-connect and device-manager modules — KDE Plasma developers, March 2018](https://mail.kde.org/pipermail/plasma-devel/2018-March/083152.html)

The official PulseAudio documentation makes the reason even clearer: automatic switch-on-connect was not loaded by default because it could override a device that the user had deliberately selected. In other words, a new sound card appearing should not necessarily overturn an explicit choice.

PulseAudio

### An important 2017 precedent

PulseAudio 11.0 changed device priorities to favor USB and Bluetooth audio over internal sound cards, provided the user had not explicitly configured another default.

Its release notes explicitly describe the intended result: connecting a Bluetooth device should no longer require manually choosing it as the default output.

PulseAudio

That establishes a historical design principle:

Automatic selection of Bluetooth headphones over laptop speakers is desirable, but it must coexist with explicit user choices.

WirePlumber's 2022 implementation took the preservation of user history further.

I verified commit [7a1b48b7 — module-default-nodes: prioritize previous configured defaults](https://github.com/PipeWire/wireplumber/commit/7a1b48b741aa796c2e4168817045ba86f4d6711c), authored by Pauli Virtanen.

The commit explains its rationale: numerical device priorities can be difficult for users to configure and may not reflect their preferences. Consequently, previously configured devices should outrank automatic priorities.

That is a defensible solution to one problem, but it creates another: an old manual selection can continue determining fallback behavior long after the circumstances surrounding that selection have disappeared.

And that is exactly where your experience becomes interesting.

## 3. A particularly revealing KDE issue, including an explicit rejection

[KDE Bug 392103 — Enable switchOnConnect by default](https://bugs.kde.org/show_bug.cgi?id=392103) was opened on March 20, 2018, by Nate Graham.

His argument was very close to yours: not switching sound to a newly connected device confuses users and creates unnecessary friction.

Another KDE developer, David Edmundson, opposed treating switch-on-connect as an obviously superior default. His example was a monitor with built-in speakers: connecting that monitor did not mean he wanted to stop using his existing headphones.

The discussion continued over multiple years:

2018

Proposal rejected. The existing PulseAudio modules conflicted, and developers disagreed about the desirable default.

2019

Graham reopened the discussion after the Phonon configuration module was removed. One technical obstacle had disappeared, leaving the usability question.

2020

PulseAudio 14's HDMI exclusion was identified as progress toward safer automatic switching.

2024

Harald Sitter explicitly called for reinvestigation with PipeWire.

2025

Graham reported that PipeWire now worked as he expected, and accepted closing the old issue.

All of those steps are recorded in the issue's comments.

One conclusion needs careful handling: Graham's experience in 2025 is evidence that PipeWire can behave correctly in some configurations. It does not establish that WirePlumber handles your particular sequence of switching between two Bluetooth headsets correctly.

In fact, your October 13 logs demonstrate the opposite for your configuration.

This gives us a much stronger basis for a new upstream discussion: not automatic switching never works, but the current preference-history model can fail to recognize a deliberate change in the user's active listening device.

## 4. Debian Bug #998073: almost the same failure, and a fix that was never conclusively identified

This is probably the closest historical match I've found.

In October 2021, Vincent Lefèvre reported that WirePlumber failed to transfer audio from his Bluetooth speakers to his Bluetooth headphones when he connected them.

In October 2022, after WirePlumber's new history mechanism appeared, he tested again and described this sequence:

1. Select Bluetooth headphones manually.
2. Switch off the headphones; sound moves back to the speakers.
3. Switch the headphones on again.
4. Sound stays on the speakers instead of returning to the headphones.

That is substantially the same class of behavior as your U11 incident.

The maintainer initially treated WirePlumber 0.4.12 as a possible fix. Lefèvre reproduced the problem with that version and additionally encountered a VLC playback failure.

The eventual resolution is particularly interesting: in December 2023, the reporter said the problem had disappeared on a new laptop with WirePlumber 0.4.13. He could not establish whether the improvement came from the software version or a difference between machines.

The Debian maintainer explicitly stated that he could not find a relevant change in the 0.4.13 changelog. Nevertheless, the issue was ultimately closed in April 2024.

[Read Debian Bug #998073 and its correspondence](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=998073)

There is a useful lesson here: the bug tracker records a successful outcome on one system, but does not establish a general algorithmic solution to the reported problem.

Your trace now supplies a missing piece of evidence: a deterministic explanation of why an apparently successful Bluetooth connection did not lead to audio switching.

This is better than simply reopening a complaint about unreliable Bluetooth sound. We have an identified policy decision, a real sequence of events, and historical reports that can be compared against it.

## 5. What actual users appear to want

I found evidence for several competing preferences, not one universal expectation.

| User preference                                                | Examples from real discussions                                                                                                                                                          |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| New Bluetooth headphones should take over automatically        | Debian #998073 (2021–2023), [r/linux4noobs (2024)](https://www.reddit.com/r/linux4noobs/comments/1fx9rl0), [r/Fedora (2025)](https://www.reddit.com/r/Fedora/comments/1ifvfz3)          |
| A preferred dock or device should regain priority              | [KDE Discuss (February 2026)](https://discuss.kde.org/t/wireplumber-0-5-how-to-enforce-priority-based-auto-switching/44242) — saved selections defeat custom priorities                 |
| Newly detected outputs should not override a deliberate choice | [KDE #392103](https://bugs.kde.org/show_bug.cgi?id=392103) — the monitor-versus-headphone example                                                                                       |
| Automatic switching can be actively harmful                    | [Manjaro (2024)](https://forum.manjaro.org/t/automatic-switch-sink-and-microphone-pipewire/164270) — an unreliable headphone jack repeatedly sends sound to speakers                    |
| Connections and applications should not interrupt playback     | [r/pipewire (2025–2026)](https://www.reddit.com/r/pipewire/comments/1ozrflt/bluetooth_devices_come_and_go_trying_a_solution/) — Bluetooth changes disrupt applications and audio routes |

The most recent especially relevant reports include September 2026 discussions on r/pipewire and r/archlinux. A user complains that connecting Bluetooth earbuds leaves existing application audio on the previous device, even though newly started applications may behave differently. That is not identical to your case, but it illustrates the continuing confusion between default selection and application-stream routing.

This is qualitative evidence from self-selected reports, not a representative survey. I cannot claim that most Linux users prefer automatic takeover, or that the opposite group is larger.

What I can conclude is that both automatic takeover and preservation of deliberate choices are legitimate requirements, and users experience failures when software treats either rule as unconditional.

## 6. The real architectural problem: one 'default' is being asked to represent several different things

This is my interpretation of the source code and the reported experiences.

The system needs to distinguish at least four concepts:

| Concept                        | Example from your incident                         |
| ------------------------------ | -------------------------------------------------- |
| Explicit user preference       | You selected the MOMENTUM 4 through GNOME Settings |
| Currently usable fallback      | Laptop speakers after the MOMENTUM 4 disconnected  |
| Newly available output         | Shure AONIC 50 connected and exposed an LDAC sink  |
| Actual application destination | Chrome continued playing through the laptop        |

Those four things are not necessarily the same device, and they need not have the same lifetime.

U11: what the current preference-history policy did

The arrows show the event sequence, not an actual audio-signal path. The Shure is available, but the older history ranking still controls the choice.

The U11 record documents the decisive scoring difference in WirePlumber 0.4.17:

- Laptop output: historical priority bonus of 300,000.
- Shure AONIC 50: historical priority bonus of 260,000.
- Newly connected device: no additional bonus for recent arrival.

Ordinary `priority.session` values cannot overcome that 40,000-point historical advantage in this configuration.

Current WirePlumber 0.5 retains the essential precedence rule. Its official documentation explicitly says that saved selections override session priorities. Its `state-default-nodes.lua` implementation ranks the stored history independently of ordinary session priority.

This explains why simply increasing the Shure's priority is unlikely to solve your particular problem while its older history position remains in force.

There is also a second independent mechanism: WirePlumber remembers routing targets for individual applications. Changing the default sink does not necessarily mean every stream follows it. Current settings including `node.stream.restore-target`, `linking.follow-default-target`, and `linking.allow-moving-streams` govern those interactions.

We therefore need to test default-output selection and actual movement of playing streams separately, instead of treating 'Bluetooth connected' as proof that either occurred.

## 7. Why simply enabling switch-on-connect is not the complete solution

I inspected the current PipeWire implementation directly:

[pulse-module-switch-on-connect.c](https://github.com/PipeWire/pipewire/blob/master/src/modules/module-protocol-pulse/modules/pulse-module-switch-on-connect.c)

The implementation already has several sensible protections:

- It normally ignores internal sound devices.
- It excludes HDMI outputs by default.
- It ignores virtual outputs and inputs by default.
- It operates only after initial device discovery, rather than taking over every device already present when the module starts.

But it has two important limitations.

First, it can switch both audio outputs and microphone inputs. A newly available microphone should not necessarily take over an ongoing video conference. This exact concern was raised during the 2022 Debian discussion.

Debian Bug report logs

Second, the module exposes an option called `only_from_unavailable`. This sounds close to the behavior we might want: switch only if the previously preferred output is unavailable.

However, the current source explicitly marks this option as unimplemented. It accepts the option and warns about it, but does not enforce the intended restriction.

There is another subtlety: the module writes `default.configured.audio.sink` or `default.configured.audio.source`, the same metadata family WirePlumber uses to track selected preferences.

Thus an automatic policy action can enter the history machinery as a newly configured default. This is an architectural concern worth testing: the stored history does not necessarily distinguish a user's explicit selection from a policy-generated selection.

Consequently, I would regard switch-on-connect as a useful workaround and experimental control, not yet the ideal solution.

## 8. What a better policy could look like

I would propose a connection-aware, preference-preserving routing policy, rather than another fixed priority adjustment.

The basic principle would be:

> A saved preference determines which device is desirable. A device's availability determines what is possible. A recent connection can indicate new user intent. Temporary fallback must not be confused with a deliberate choice.

A sensible first version might behave as follows.

| Scenario                                                        | Proposed behavior                                                    |
| --------------------------------------------------------------- | -------------------------------------------------------------------- |
| Laptop speakers active; Bluetooth headphones connect            | Switch to headphones automatically                                   |
| Headphones disconnect                                           | Return to a usable fallback, respecting the user's safety preference |
| Different Bluetooth headphones connect while using fallback     | Switch to the newly connected headphones                             |
| User explicitly selects speakers while headphones are connected | Respect that choice; do not immediately override it                  |
| Bluetooth device briefly disconnects and reconnects             | Avoid unnecessary rapid switching                                    |
| HDMI monitor appears                                            | Do not automatically take over solely because of its arrival         |
| New microphone becomes available during a call                  | Preserve the active microphone unless the user explicitly changes it |
| Application has an explicit per-stream target                   | Preserve it unless policy explicitly permits moving it               |

Some of these choices, particularly how long a manual preference should remain authoritative, deserve discussion with users and upstream maintainers.

### The necessary state model

I would separate three things that are currently too easily conflated:

- Explicit preference: what the user most recently selected deliberately, with its provenance retained.
- Active routing decision: where audio is actually going right now, including temporary fallback.
- Device lifecycle: whether an output has appeared, disappeared, changed profiles, or become ready for playback.

The policy would evaluate an event using all three.

The most important improvement is preserving the distinction between the last explicitly selected device and the currently active fallback. If headphones disappear, routing audio to speakers temporarily must not necessarily turn the speakers into the user's long-term preference.

A second important improvement is differentiating a newly available logical device from a new node produced by a profile transition. Otherwise switching between A2DP and HFP could trigger inappropriate routing decisions.

There is a timing dimension, too. In U11 the Shure disconnected almost immediately after connecting, then connected again. A good implementation must avoid responding to unstable intermediate states as though they represented separate user decisions.

## 9. Where a contribution belongs, and how to establish it

For the particular U11 failure, I would target WirePlumber's default-node selection policy, not the Linux kernel or Bluetooth controller firmware.

BlueZ successfully established the connection. PipeWire exposed a usable Shure output. The selection policy chose the laptop. That separation of responsibilities is important.

The current WirePlumber source already has an extensible sequence of default-node selection hooks. A candidate implementation could be developed as an optional policy hook first, instead of changing the default behavior for everyone.

WirePlumber 0.5.18 documentation

That would provide a relatively conservative path to upstream acceptance while still allowing a materially different algorithm.

### Proposed experimental matrix

Before writing the patch, I'd want the maintainer to reproduce at least these cases under a fixed WirePlumber version:

| Test                                           | Main question                                  |
| ---------------------------------------------- | ---------------------------------------------- |
| Fresh history, one headset                     | Does ordinary device priority already work?    |
| Existing history, headset below internal audio | Can we reproduce U11 deterministically?        |
| Two headsets connected sequentially            | Which connection represents the latest intent? |
| Explicit selection of laptop speakers          | Does automatic switching respect the override? |
| Headset disconnect/reconnect in a few seconds  | Does routing remain stable?                    |
| HFP/A2DP transition                            | Is the logical device identity maintained?     |
| Chrome or another stream already playing       | Does the sound actually move?                  |
| Microphone in active use                       | Is the capture route protected?                |
| WirePlumber restart or full reboot             | Does the policy preserve its intended state?   |

Run the same matrix against WirePlumber 0.4.17 and a current 0.5 build, preferably using isolated state directories. Do not erase the existing default-node history before preserving it as evidence.

That comparison would distinguish behavior inherited from the original 2022 implementation from anything introduced later.

For a read-only snapshot on your installed system, these commands are useful:

```
wireplumber --version
pipewire --version
wpctl status
cat ~/.local/state/wireplumber/default-nodes
pactl list short modules | grep switch-on-connect
pw-metadata -n default
```

The state file and metadata may expose device identifiers, so those should be sanitized before publication.

## 10. Current assessment

Root cause of U11 is strongly established.

The project record at commit `f165d16` documents that WirePlumber selected the internal output despite successful Shure initialization. Its recorded history ordering matches the upstream selection algorithm.

Historical precedent is substantial.

KDE's 2018 rejected proposal, the long-running Debian report, the 2022 WirePlumber issue, subsequent forum discussions, and the September 2026 reports demonstrate recurring user friction and competing requirements.

A universally preferred replacement policy is not established.

We have genuine user accounts on both sides, but no representative preference survey and no proof that one unconditional rule is acceptable to most users.

The upstream review record is incomplete.

The official freedesktop.org GitLab tracker blocked some requests through its access protection. I verified the GitHub mirror, source commits, public reports, and historical mailing lists, but I cannot claim to have exhaustively reviewed every upstream proposal or rejection.

I reviewed your GitHub repositories and the U11 record, along with upstream PipeWire and WirePlumber code. I did not independently access your machine's raw journal or HCI capture files, and made no changes to any repository.

### My conclusion

I think there is a credible contribution opportunity here, but it is more interesting than a simple Bluetooth headset does not automatically become the default bug.

The deeper question is:

How should a desktop audio policy distinguish an explicit preference, a temporary fallback, and a new indication of user intent?

The historical implementations answer parts of that question, but each loses information about the user's circumstances.

What especially interests me is the distinction between choosing laptop speakers and being forced to use laptop speakers because the headset disappeared. Your incident exposes the consequences of treating these two very different events as equivalent inputs to a preference-ranking policy.

I would not propose simply making every newly connected device win. That would recreate the problems KDE and PulseAudio developers were concerned about.

Instead, I would take the verified U11 sequence, the Debian reproducer, the 2018 KDE objections, and the currently available WirePlumber hooks, and formulate a proposal for an optional connection-aware routing policy that preserves explicit choices while treating fallback as temporary.

That seems to me the strongest engineering direction: something we could specify, test, compare against current behavior, and discuss upstream without dismissing the very real reasons the existing implementation was designed as it was.

Part 2:

## Two different policies are being confused — and your examples expose why

Your distinction between a professional setup and an everyday one changes the engineering question considerably.

A professional workstation might have an active recording, monitored outputs, conference audio, and equipment that occasionally connects or disconnects. In that environment, an automatic device takeover can be a serious mistake.

On an everyday computer, the very same behavior can be exactly what people want: put on headphones, turn them on, and hear the movie. Nobody should need to understand PipeWire to accomplish that.

Neither preference is inherently wrong. The mistake would be treating one preference as universally correct.

I found three particularly important things in the newer sources:

1. Selectable policies are already technically plausible. WirePlumber has configurable state-restoration and priority mechanisms, and PipeWire provides an optional switch-on-connect module. The missing piece is a coherent user-facing policy choice.
2. The existing history mechanism really is a stack. Your intuition about recency ordering matches WirePlumber's implementation more closely than the large numerical scores suggest.
3. Bluetooth reconnection is a separate problem, and there are fresh 2026 reports of repeat-connection failures. They should not be merged into a routing-policy fix merely because their symptoms look similar.

### The stack issue

The source of WirePlumber 0.5 explicitly ranks previously selected outputs by their position in a stored list, without allowing `priority.session` to overturn that ordering. The large bonuses in version 0.4.17 are an implementation of precedence, not meaningful user-facing preference numbers.

WirePlumber 0.5.18 documentation

But there is an important difference between most recently selected and most recently used.

Suppose your saved order is:

Stored preference order

1

Sennheiser MOMENTUM 4

Last explicitly selected

2

Laptop speakers

Older selection

3

Shure AONIC 50

Even older selection

When MOMENTUM 4 disappears, the laptop wins. When Shure connects, its position remains unchanged because merely connecting is not considered a new user selection.

That explains U11. But it also suggests a more precise configurable policy than simply raising Bluetooth priorities:

Connection-driven selection could update the active output while preserving the separate history of explicit human choices.

This would let an everyday setup operate by last-connected device without destroying the professionally useful remembered configuration.

## A major discovery: BlueZ developers debated almost exactly your reconnection-policy idea

I found a particularly valuable discussion in [BlueZ issue #294 — Device last-connected-time API](https://github.com/bluez/bluez/issues/294).

It began in 2022 with a request to remember which Bluetooth device was connected most recently, so audio devices could reconnect in a sensible order.

The author, `jonas2515`, proposed tracking last-use information and implementing startup reconnection. BlueZ maintainer `Vudentz` challenged the approach, explaining that reconnecting every paired device indiscriminately could be expensive, interfere with other connection requests, and introduce privacy concerns.

They discussed policy choices resembling:

- Do not initiate startup reconnections.
- Reconnect devices that were connected when the daemon last shut down.
- Optionally reconnect all relevant paired devices.

The maintainer favored a narrowly scoped policy rather than automatically reconnecting everything. A further concern was that attempting reconnection to half-paired devices might unexpectedly invoke pairing or reveal the adapter's Bluetooth address.

This is not evidence that the policy was implemented. It is an upstream design discussion, and I have not verified an accepted implementation of `ReconnectStartup`.

But it directly supports your underlying argument: the correct behavior depends on the intended use, and connection history can be useful without being an unconditional command to reconnect everything.

The discussion also provides a warning for your three headsets: automatically selecting whichever connected most recently is not the same thing as actively attempting to connect all three. Those should be separate policies.

### Why this matters for your second symptom

The current BlueZ policy source, `plugins/policy.c`, still restricts its principal audio reconnect-on-disconnect mechanism to specific disconnect reasons, notably link timeout and local-host suspend.

An ordinary, clean disconnection caused by turning headphones off does not necessarily trigger that host-side recovery mechanism. BlueZ often relies on the headphones themselves to initiate reconnection when they are turned back on.

That can explain why reconnect behavior appears inconsistent, but it does not by itself prove the cause of your particular first-cycle/second-cycle observation.

The important distinction is that a headset can fail at three separate transitions:

1\. Bluetooth link

Headphones and laptop establish a connection.

2\. Audio service and profile

A2DP is connected and PipeWire receives an audio sink.

3\. Audio routing

WirePlumber chooses that sink and directs the intended application streams to it.

For U11, your captured logs establish that stages 1 and 2 completed, while stage 3 did not select Shure.

Your older observation about repeated headphone power cycles could involve stage 1 or 2 instead, and should be tested independently.

## The checkbox you imagined has already existed in KDE

This is another significant finding.

KDE historically offered an audio setting with almost exactly the wording you suggested:

> Automatically switch all running streams when a new output becomes available

The option is documented in the 2018 [KDE developer discussion](https://mail.kde.org/pipermail/plasma-devel/2018-March/083152.html). KDE's official 2019 Plasma 5.17 announcement subsequently reported that the feature had been fixed to work properly.

However, PipeWire-era reports show the same interface has not always worked reliably with the new audio stack. In 2021, a Manjaro user reported that the option was disabled because the required PulseAudio-compatible module was unavailable.

Manjaro Linux Forum

I have not verified an equivalent built-in checkbox in GNOME on your Ubuntu 24.04 installation.

The engineering opportunity may therefore involve restoring a consistent, well-defined contract between the desktop setting and WirePlumber's policy, rather than inventing an entirely new concept.

## Recent reports: October 2026

I found several particularly relevant reports. These deserve separate treatment because they describe different failed transitions.

| Report                                                                                     | Observed failure                                                                                            | Relationship to your experience           |
| ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| [Ubuntu #2169383](https://bugs.launchpad.net/bugs/2169383), Oct 2–3, 2026                  | Headset becomes the default output, but existing application streams remain on speakers                     | Routing changes but streams do not follow |
| [Pop!\_OS #4102](https://github.com/pop-os/pop/issues/4102), Sep 12, 2026                  | Bluetooth connects, but the audio sink is missing on the first connection after boot; reconnecting fixes it | Failure before route selection            |
| [BlueZ #2524](https://github.com/bluez/bluez/issues/2524), Sep 2026                        | Headset reconnects with HFP but without A2DP; subsequent reconnect may recover it                           | Incomplete audio-profile connection       |
| [BlueZ #2575](https://github.com/bluez/bluez/issues/2575), Sep 24, 2026                    | First conference call works; second A2DP/HFP transition fails                                               | Repeat-operation state failure            |
| [Void Linux user report](https://www.reddit.com/r/voidlinux/comments/1eq6khf), Aug 2024    | Earbuds work initially but later do not appear as an audio output, despite reporting connection             | Repeated-connection failure               |
| [r/pipewire user report](https://www.reddit.com/r/pipewire/comments/1wgazl6), Sep 14, 2026 | Connecting earbuds fails to move existing application audio                                                 | User expectation matches yours            |

These are reports, not independently verified root causes. Their combined value is that they demonstrate why a single generic symptom such as Bluetooth connected but sound not working is insufficient for engineering diagnosis.

The Ubuntu report is especially useful. Its author states explicitly that the behavior worked on Ubuntu 24.04 before upgrading to 26.04.1. In that case, unlike yours, WirePlumber correctly changed the default node, but existing streams did not move even though the relevant movement settings were enabled.

So the problem spans both choosing the right output and moving the audio streams to that output.

## Could your system have worked a few months ago without any software change?

Yes. There is a plausible explanation consistent with U11.

Imagine that, months ago, the Shure was higher in the saved selection history than the laptop speakers. Whenever the Shure connected, it won the selection.

Later, perhaps after selecting laptop speakers manually for some particular task, the laptop moved higher in that history. Now the Shure could connect successfully without becoming the selected output.

This could happen without any change to WirePlumber's executable code.

That is a hypothesis, not an established reconstruction of your earlier history. The U11 record confirms today's relative positions, but not exactly when they changed.

The alternative is a real behavioral regression caused by a package update, device profile change, or another component. To distinguish the possibilities we need historical state snapshots and package versions, rather than relying solely on present-day behavior.

There is one particularly useful comparison: your U11 machine runs WirePlumber 0.4.17, which is the old Ubuntu 24.04 line. If the same executable version was in use when automatic switching appeared to work, a state-dependent explanation becomes more compelling.

## A policy design I would actually propose

Your checkbox is a good starting point, but I would offer three choices rather than two because the distinction between an established preference and an unavailable fallback is useful.

Proposed setting: Automatic audio output switching

Keep current output

Do not change outputs automatically when another device connects.

Switch when the current output is unavailable

Preserve explicit choices while allowing automatic recovery when the active device disappears.

Switch to newly connected audio devices

A newly connected, trusted headset or speaker becomes the output, including for existing streams that follow the default.

Illustrative behavior: the Shure connects, and the active audio output becomes the Shure. Later, Lenovo earbuds connect, and the output switches to the Lenovo, without manually opening sound settings.

I would apply that setting to outputs separately from microphone inputs. Professional applications with explicitly pinned routing targets should also retain the ability to opt out of default-stream movement.

Importantly, I would not make this control change Bluetooth pairing, automatic device discovery, or reconnection attempts. Those are separate decisions.

### Remembering individual device configurations

Your other observation is also correct in principle: remembering a device's audio profile, volume, mute state, and codec preferences is not the same operation as remembering which output should currently be active.

WirePlumber already stores several classes of state independently, including default nodes, device profiles, routes, volume, and application-stream properties.

WirePlumber 0.5.18 documentation

For unpairing and re-pairing, I would define an explicit lifecycle rule: forgetting a device should remove the remembered preferences associated with that pairing, unless the user specifically requests a broader preference-retention feature.

There is a potential complication here. WirePlumber state can be keyed by persistent node names associated with a Bluetooth device. Forgetting a pairing in BlueZ does not logically guarantee that an independent WirePlumber state file has discarded every historical reference to it. That is something I would verify experimentally before proposing changes.

## The experiment that could separate all these problems

I would ask the project maintainer to perform a single controlled sequence, capturing BlueZ, WirePlumber metadata, and actual application routes at every transition.

| Step | Operation                                              | What must be recorded                                                  |
| ---- | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| 1    | Play a continuous audio stream through laptop speakers | Current configured default, active sink, actual Chrome route           |
| 2    | Connect Shure                                          | HCI connection, A2DP node creation, default selection, stream movement |
| 3    | Disconnect Shure                                       | Disconnect reason, fallback target, changes to stored history          |
| 4    | Reconnect Shure                                        | Same measurements as step 2                                            |
| 5    | Repeat twice more                                      | Whether failure emerges only on later cycles                           |
| 6    | Explicitly select laptop output, reconnect Shure       | Whether manual choice changes the result                               |
| 7    | Explicitly select Shure, reconnect Shure               | Whether the historical rank changes the result                         |

The key is to record state transitions, not merely the final state.

For example, the following two traces mean different things:

```
Bluetooth CONNECTED
A2DP sink CREATED
default.audio.sink = laptop
Chrome -> laptop
```

This is U11's policy problem.

```
Bluetooth CONNECTED
A2DP sink CREATED
default.audio.sink = Shure
Chrome -> laptop
```

This is a stream-movement problem of the kind reported in Ubuntu bug #2169383.

And:

```
Bluetooth CONNECTED
A2DP sink NOT CREATED
default.audio.sink = laptop
```

This is a Bluetooth audio-profile or device-enumeration problem, illustrated by Pop!\_OS issue #4102.

We should not try to repair all three with the same workaround.

## Final direction

I now see two independent contributions worth investigating.

The first is a user-selectable WirePlumber output-switching policy. KDE history, real user reports, and WirePlumber's own implementation provide a strong technical foundation. The objective would be to reconcile automatic switching with preservation of deliberate choices.

The second is Bluetooth reconnection lifecycle correctness. Here the BlueZ discussions about `ReconnectStartup`, the existing restrictions in `policy.c`, and the recent repeat-connection reports are the stronger foundations. We need a deterministic reproduction before attributing your earlier experience to one specific bug.

I also checked the 2023 BlueZ proposal [PR #633](https://github.com/bluez/bluez/pull/633), which attempted retry handling for simultaneous connection failures. It was closed unmerged because the GitHub mirror was not the accepted patch-submission path; the bot directed contributors to the Linux Bluetooth mailing list. Its closure is therefore not evidence that maintainers rejected the technical idea.

The common principle underlying both projects is the one you identified: distinguish what the user deliberately requested from what the system did automatically because a device happened to appear, disappear, or temporarily become unavailable.

That is a meaningful design issue, not merely a configuration inconvenience. And the existing discussions give us a way to approach maintainers with specific failure cases and an optional policy, without suggesting that their original reasons for preserving stable routing were mistaken.
