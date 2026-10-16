# u11 reviewer 2: web source check

Checked 2026-10-13. Read-only: nothing was posted, no sign-ins.
Labels: QUOTED (exact text and URL), INFERRED, NOT FOUND, NOT REACHABLE.
Dates are given as each source shows them. GitHub, GitLab and Bugzilla REST times are UTC.

Access notes:
- The GitLab web pages and `/api/v4/.../notes` return Anubis or 401 for the fetcher. The issue API (`/api/v4/projects/pipewire%2Fwireplumber/issues/<n>`) and `/-/issues/<n>/discussions.json` work with curl. Raw JSON is saved as `/root/exp/qca9377-bt-hang/tmp/u11-wp-*.json`; it prints with `/root/exp/qca9377-bt-hang/tmp/u11-gl-show.py <file> [--full]`.
- Reddit: `old.reddit.com/.../.json` returns `HTTP/2 302` to `https://old.reddit.com/login/?reason=lor2&...`, a login wall. Signing in was not allowed, so every Reddit claim is NOT REACHABLE.
- freedesktop.org/wiki returns 403 (418 with a browser user agent). The mirror `wiki.freedesktop.org/www/...` works.

---

## 1. github.com/PipeWire/wireplumber/issues/11

Source: https://api.github.com/repos/PipeWire/wireplumber/issues/11 (and `/comments`)

- Exists. Title QUOTED: "Automaticaly activate hotplugged device as default source/sink and move all streams to it". Reporter Harvie, created 2022-11-04T13:17:21Z. Closed 2022-11-16T17:30:36Z, state_reason `completed`.
- BT headset ask: CONFIRMED (paraphrase). The body says a newly connected BT headset has to be switched to manually, and asks for "switch to the most recently plugged" behaviour.
- 0.4.12: QUOTED. Harvie, 2022-11-11T13:22:19Z, cites the 0.4.12 changelog: WirePlumber "now maintains a stack of previously configured default nodes". Then Harvie, 2022-11-11T14:19:52Z: "But it only seems to work 1st time after restarting wireplumber, and then it fails again..."
  - Correction: the claim's wording "only worked after restarting" is close, but the comment says it worked once after a restart and then failed again.
- GitLab discussion: QUOTED. ford-prefect, 2022-11-16T17:01:01Z: "this is just a mirror repo". The rest of the thread is about disabling GitHub issues. gkiagia, 2022-11-21: "yes, please disable issues here. I am not watching them, unless I am pinged."
- "Closed without resolution": CONFIRMED in substance. The state_reason says `completed`, but nothing was fixed; the closure is tied to redirecting reporters to GitLab. INFERRED: ford-prefect closed it at 17:30:35/36, at the same time as his comment "I've filed and pinned an informational issue instead."
- Left out: the GitHub label is "completed", and the thread kept going until 2022-11-22.

## 2. r/archlinux, Feb 2021, PipeWire 0.3.21, BT headphones become default

- NOT FOUND / NOT REACHABLE. Three web searches (standard and extended) found no Reddit thread that mentions 0.3.21 together with Bluetooth default switching. Reddit itself is login-walled, so its own search could not be tried.
- A PipeWire GitLab issue came up in results: https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/1740, "BlueTooth headphones are not selected by default". The search snippet says it was filed against 0.3.38, so it is not this source.
- The claim cannot be verified as given.

## 3. plasma-devel 2018-March/083152

Source: https://mail.kde.org/pipermail/plasma-devel/2018-March/083152.html

- Exists. One message from David Rosca, "Wed Mar 21 16:47:25 UTC 2018", subject "PulseAudio switch-on-connect and device-manager modules".
- QUOTED: "module-switch-on-connect basically just switches all streams to newly connected devices."
- QUOTED: "module-device-manager is loaded by default and also existed before module-switch-on-connect." The message argues device-manager should stay the default.
- Checkbox: QUOTED. The text "Automatically switch all running streams when a new output becomes available" appears in a part of Nate Graham's message that Rosca quotes.
- Correction: this is a single post by one developer, quoting another. "KDE devs" in the claim overstates it. The page itself shows no decision by a group, only Rosca's position (INFERRED: the follow-up thread was not read).

## 4. PulseAudio docs and 11.0 release notes

Sources: https://wiki.freedesktop.org/www/Software/PulseAudio/Documentation/User/Modules/ and https://wiki.freedesktop.org/www/Software/PulseAudio/Notes/11.0. The freedesktop.org/wiki URLs return 403; these mirrors work.

- module-switch-on-connect: QUOTED: "This module is not loaded by default, beacuse it's a bit too aggressive." (typo as in the source). QUOTED: "If the user sets the default sink or source manually, that choice gets forgotten when plugging in a new sound…". CONFIRMED.
- Same section (paraphrase): before PA 14.0 this module also moved running streams; since 14.0 the core moves them when the default changes. Arguments: `blacklist` (default "hdmi", since 14.0), `ignore_virtual` (since 12.0), `only_from_unavailable` (since 6.0). The page also says some distributions load the module by default.
- 11.0 notes: QUOTED section title "USB and bluetooth devices preferred over internal sound cards". QUOTED: "connecting a bluetooth device, it's not necessary to manually set the new device as default". CONFIRMED.
- Left out by the claim: the same section has an update, QUOTED: "Most USB devices weren't prioritized over built-in sound cards in 11.0 after all". The fix moved to 11.1.
- 11.0 release date: 05 Sep 2017. Source is the LWN copy of the announcement, https://lwn.net/Articles/732970/, timestamp "Tue, 05 Sep 2017 13:30:46 +0300". The wiki page itself shows no release date.

## 5. bugs.kde.org 392103

Sources: https://bugs.kde.org/rest/bug/392103 and https://bugs.kde.org/rest/bug/392103/comment

- Current title QUOTED: "Enable switchOnConnect by default when using PulseAudio directly". The title now ends with "when using PulseAudio directly"; the claim gives only the first part.
- Creator Nate Graham, 2018-03-20T14:45:26Z. Status RESOLVED, resolution **WONTFIX**, last change 2025-08-02T01:25:56Z.
- Edmundson's objection: QUOTED. David Edmundson, 2018-03-20T16:50:01Z: "Also, it's not necessarily a better default." His example is an office monitor with speakers: "I still wanted audio to come out my headphone jack."
- Left out by the claim:
  - nowrep (David Rosca), 2018-03-20T15:37:47Z, QUOTED: "module-switch-on-connect conflicts with module-device-manager which is loaded by default in Plasma".
  - Edmundson closed it the same day, 2018-03-20T21:04:45Z, QUOTED: "I don't like bug reports in the form of proposing a solution rather than in the form of a bug so I'm closing this". Graham then filed bug 392117.
- 2019 reopen: QUOTED. Nate Graham, 2019-08-28T17:56:12Z: "The Phonon KCM has now been removed, so there is no longer a technical barrier to implementing switch-on-connect." Edmundson, 2019-08-28T19:44:29Z: "I also don't know how we would (in any non terrible way) enable this by default on the client side."
- 2020: QUOTED. Nate Graham, 2020-06-16T00:53:51Z: "the only remaining objection to doing this by default is that HDMI devices would be automatically switched to". He notes that PA 14 excludes HDMI. CONFIRMED.
- 2024: QUOTED. Harald Sitter, 2024-01-23T10:14:09Z: "Needs re-investigation with pipewire :|" and "There is also the question why upstreams don't enable it." CONFIRMED.
- 2025: QUOTED. A third user, 2025-08-01T23:27:31Z, asked: "It seems like audio auto-switches with pipewire these days". Nate Graham, 2025-08-02T01:25:56Z: "This does indeed work as I expect with PipeWire nowadays." and "It's probably still valid for a pure PulseAudio setup".
- Final state: RESOLVED **WONTFIX**, not FIXED. Graham's own words say the issue may remain on pure PulseAudio.

## 6. Debian bug 998073

Source: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=998073

- Exists. Title QUOTED: "wireplumber: fails to automatically switch to headphones when connected".
- Filing: Vincent Lefevre, "Fri, 29 Oct 2021 18:23:03 +0200". QUOTED: "I use bluetooth speakers by default." and "When I connect my bluetooth headphones, I want the system to automatically switch from the". Both devices are BT, as claimed.
- Left out by the claim: the bug was filed against pipewire-pulse and reassigned to wireplumber on 30 May 2022.
- Oct 2022 sequence: QUOTED. Vincent, "Sun, 9 Oct 2022 02:48:27 +0200":
  - "1. In pavucontrol, while VLC is playing, select the headphones."
  - "2. Switch off the headphones." / "-> The output is now the speakers. OK."
  - "3. Switch on the headphones." / "-> The output is still the speakers. Bad (this is this bug)."
  - Same message: "It is not fixed (same issue as previously), and worse, it appears". He also reports VLC "Unknown output" with no sound.
- 0.4.12: CONFIRMED. Dylan Aïssi uploaded 0.4.12-1 on 5 Oct 2022 and tagged the bug fixed. QUOTED: "I just uploaded the new wireplumber version with this feature in sid."
  - Left out: on 30 Sep 2022 Dylan said the switch-on-connect-like logic had "just been merged in wireplumber and should be available in the next release".
- Dec 2023: QUOTED. Vincent, "Mon, 18 Dec 2023 23:52:39 +0100": "FYI, I have a new laptop, where I use wireplumber 0.4.13-1", reporting no such problems. INFERRED: the old laptop was not retested.
- Maintainer reply: QUOTED. Dylan Aïssi, "Tue, 19 Dec 2023 10:26:44 +0100": "I don't see any change in the changelog of 0.4.13 that could be related to". He tagged it fixed-in 0.4.13-1 without closing.
- Closed: Dylan Aïssi, "Mon, 29 Apr 2024 11:40:39 +0200". QUOTED: "Let's close this bug, feel free to reopen if there is still an issue." Archived 28 May 2024. CONFIRMED.
- Microphone concern in 2022: CONFIRMED as a warning, not as an observed event.
  - Samuel Thibault, "Tue, 27 Sep 2022 10:51:55 +0200", QUOTED: "For the input part it is still not auto-switching".
  - Vincent, "Tue, 27 Sep 2022 13:36:38 +0200", QUOTED: "switching input may have a bad effect in the middle of a video conference".

## 7. Forum and Reddit threads

- https://discuss.kde.org/t/wireplumber-0-5-how-to-enforce-priority-based-auto-switching/44242: exists. edwinkm, "February 11, 2026, 11:24pm". QUOTED: "Once I pick something in the tray, it becomes the “configured default,” and priority-based switching stops." Date matches. The gist is a manual tray choice overriding priority. The fetched page showed only the first post.
- https://forum.manjaro.org/t/automatic-switch-sink-and-microphone-pipewire/164270: exists. pfspace, "21 June 2024, 04:01". The date matches.
  - The gist is NOT about Bluetooth. After an update, PipeWire switched the wired front-jack headphones and speakers whenever the plug moved. Fixed with hdajackretask and the Pro Audio profile. QUOTED: "I really like Pipewire and Wireplumber and would like to keep those instead of reverting to PulseAudio."
  - If the report cites it as BT-on-connect evidence, that is wrong.
- The five Reddit threads were all NOT REACHABLE (login wall), and a search engine found none of the IDs:
  - https://www.reddit.com/r/linux4noobs/comments/1fx9rl0
  - https://www.reddit.com/r/Fedora/comments/1ifvfz3
  - https://www.reddit.com/r/pipewire/comments/1ozrflt/
  - https://www.reddit.com/r/pipewire/comments/1wgazl6
  - https://www.reddit.com/r/voidlinux/comments/1eq6khf
  - INFERRED only: the base36 post IDs increase in the claimed date order, and the steps between them are similar (about 38-45 million per month). So the claimed dates (Aug 2024, Oct 2024, Feb 2025, late 2025, Sep 2026) are plausible. Titles, content and the exact 2026-09-14 date are unverified.

## 8. bluez/bluez issue 294

Sources: https://api.github.com/repos/bluez/bluez/issues/294 (and `/comments`)

- Exists. Title QUOTED: "Device last-connected-time API". jonas2515, created 2022-02-17T12:17:28Z. Closed 2025-09-16T02:37:12Z, state_reason `not_planned`; the claim leaves out the closure.
- Vudentz concerns:
  - Interference: QUOTED, 2022-02-18: "it is probably a bad idea to implement a last connected in pipewire" and "isn't there a risk that other subsystem start reconnecting as well?"
  - Privacy: QUOTED, 2022-11-15T19:58:04Z: "this sort of policy may have privacy problems since the user is not in control"
  - Half-paired: QUOTED, same comment: "pairing may kick in the process (e.g. half-paired cases)"
  - Address: QUOTED, same comment: "and even in case the pairing agent does require users input that would leak the controller bdaddr."
    - Correction: the address at risk is the local controller's bdaddr. The claim's "half-paired devices revealing address" misstates this.
  - Cost: NOT FOUND. No comment mentions cost, expense, overhead or battery.
- ReconnectStartup: QUOTED. Vudentz, 2022-11-15, proposed a ReconnectStartup policy and "I wouldn't default to it given the problems stated above." jonas2515 proposed "#ReconnectStartup = connected-on-shutdown" and "ReconnectStartupNDevices". Vudentz suggested "ReconnectStatup=on/yes" (typo as in the original) and an LRU count. All of these are proposals.
- Later comments:
  - ratijas, 2024-07-10: "Show Bluetooth devices ordered by last used"
  - stale-bot notices on 2025-06-19 and 2025-08-21
  - ratijas, 2025-09-16: "This is insanely annoying. I give up."
- Implemented? NOT FOUND in current master.
  - `src/main.conf` [Policy] lists only ReconnectUUIDs, ReconnectAttempts, ReconnectIntervals, AutoEnable and ResumeDelay. There is no ReconnectStartup, LastUsed or LastConnected.
  - `doc/org.bluez.Device.rst` has no LastUsed or LastConnected property. It has only bearer-level "last used" wording, QUOTED: "Connect to last used bearer first. Default." (PreferredBearer).
  - Sources: https://raw.githubusercontent.com/bluez/bluez/master/src/main.conf and https://raw.githubusercontent.com/bluez/bluez/master/doc/org.bluez.Device.rst
  - A GitHub code search was not done (it needs auth), so the check covers these two files only.

## 9. bluez/bluez pull 633

Sources: https://api.github.com/repos/bluez/bluez/issues/633 (and `/comments`)

- Exists. Title QUOTED: "Draft: device: Try to connect again later if all slots for connecting are used". jonas2515, created 2023-10-24T11:24:56Z, closed 2023-11-08T12:35:10Z, `merged_at` null.
- Bot: QUOTED. BluezTestBot:
  - 2023-10-24: "please send your patch to the Linux Bluetooth mailing list(linux-bluetooth@vger.kernel.org)."
  - 2023-10-31: "Note that this pull request will be closed in a week or two."
  - 2023-11-08: "Closing without taking any action."
- CONFIRMED.
- Nuance: the PR is about retrying when all connection slots are busy (EAGAIN), not "simultaneous connection failures" in general. Close enough.

## 10. Recent tracker entries

- https://bugs.launchpad.net/bugs/2169383 (API https://api.launchpad.net/1.0/bugs/2169383): exists.
  - Title QUOTED: "Existing audio streams do not switch to Bluetooth sink after reconnect". Created 2026-10-03T05:47:41 UTC, tags amd64, apport-bug, resolute, wayland-session.
  - QUOTED: "already running audio streams continue playing through the previous HDMI/speaker output."
  - QUOTED: "Ubuntu 26.04.1 LTS", "WirePlumber: 0.5.13-1ubuntu1", "PipeWire: 1.6.2", "This worked as expected on Ubuntu 24.04 before upgrading to Ubuntu 26.04.1."
  - CONFIRMED. The date is 2026-10-03 UTC; the claim gives "Oct 2-3".
- https://github.com/pop-os/pop/issues/4102: exists.
  - Title QUOTED: "Bluetooth headset connects at BlueZ level but no audio sink is created by PipeWire/WirePlumber (first connection after boot)". atiq-cs, created 2026-09-12T21:14:40Z, open.
  - QUOTED: "but PipeWire never creates a `bluez_output.*` sink for it." Disconnecting and reconnecting fixes it.
  - CONFIRMED.
- https://github.com/bluez/bluez/issues/2524: exists.
  - Title QUOTED: "A2DP sink not connected on reconnect; device comes up HFP-only and no A2DP SEP is enumerated". poad42, created 2026-09-12T22:57:37Z.
  - **Closed 2026-10-07T18:57:55Z by the reporter without a fix.** QUOTED: "loos like nobody reads these issues so closing." (typo as in the source).
  - Gist CONFIRMED (Melomania P100 SE, bluez 5.87). The claim leaves out the closure.
- https://github.com/bluez/bluez/issues/2575: exists.
  - Title QUOTED: "A2DP: a2dp_resume() "SEP in bad state for resume" → Acquire NotAuthorized after A2DP↔HFP profile switching, until reconnect (Sony WH-1000XM5, 5.87)". pumpbroadmin-sys, created 2026-09-24T11:11:59Z, open.
  - QUOTED: "the headset works for the first call after connecting. The **second** call on the same connection fails."
  - CONFIRMED. The issue links #2523 and #2553, and says no btmon trace yet.
- All four numbers exist.

## 11. Plasma 5.17 and the 2021 Manjaro thread

- Plasma 5.17 announcement (https://kde.org/announcements/plasma/5/5.17.0/, "Tuesday, 15 October 2019"): NOT FOUND. It says nothing about switching streams, PulseAudio or switch-on-connect. Its only audio line, QUOTED: "You will also find that you can set the maximum volume for your audio devices to be lower than 100%."
- The "fixed in 5.17" statement exists, but only in a bug-tracker comment:
  - https://bugs.kde.org/show_bug.cgi?id=399487 ("\"Automatically switch all running streams...\" does nothing", RESOLVED FIXED, no version-fixed-in or commit link).
  - Nate Graham, 2019-08-28T17:59:10Z, QUOTED: "This is fixed in Plasma 5.17!"
  - Correction: the claim credits the announcement; the source is this comment.
- Manjaro 2021: https://forum.manjaro.org/t/after-switching-to-pipewire-kde-audio-settings-complain-that-module-gsettings-is-needed/53622. Termy, "14 Feb 2021 10:56".
  - The "Automatically switch all running streams…" option was greyed out with QUOTED: `needs the pulse-audio module "module-gsettings"`.
  - On 19 Feb 2021 Termy relayed a PipeWire contributor, QUOTED: "module-gsettings` is simply not implemented in pipewire and thus it's not working." Termy also filed KDE bug 433246.
  - No fix in the thread.
  - Correction: the missing module was **module-gsettings**, not module-switch-on-connect.

## 12. WirePlumber GitLab tracker

Searches: `issues?search=switch on connect`, `newly connected`, `bluetooth default`, `switch-on-connect` (0 hits), `automatically switch`, `hotplug`, and `new device` (title only). GitLab search matches words loosely, so the hit lists are long. The relevant hits:

| # | Title | State | Created | Closed |
|---|---|---|---|---|
| 62 | Wrong device selected after reboot with new device connected | opened | 2021-10-02T18:58:47Z | – |
| 248 | Wrong device selected after reboot with new device connected (same author, duplicate) | opened | 2021-10-02T18:59:59Z | – |
| 83 | Pipewire always switches output to Thunderbolt hub when connected | opened | 2021-10-23 | – |
| 221 | Audio dropouts and GUI popups due to output auto switching | opened | 2022-03-11 | – |
| 247 | Setting default device and automatic bluetooth switch | closed | 2022-04-06 | 2022-04-27 |
| 308 | Wireplumber policies worse than pipewire-media-session | opened | 2022-07-10 | – |
| 352 | Headphones are not switched to automatically unless they are set as the default/fallback sink | closed | 2022-09-19 | 2022-11-24 |
| 463 | when audio is paused, speaker output is automatically switched to headphone | opened | 2023-06-09 | – |
| 573 | Failure to switch devices on plug/unplug | closed | 2024-02-15 | 2024-03-11 |
| 629 | Auto switching audio to HDMI back and forth does not work anymore | opened | 2024-03-30 | – |
| 734 | Autoselection of headphones doesn't work after profile was changed between Duplex/Output | closed | 2024-10-14 | 2024-11-28 |
| 838 | sink priority not respected | closed | 2025-09-04 | 2025-09-18 |
| 840 | wireless USB headset not toggling sinks automatically | opened | 2025-09-04 | – |
| 853 | Wireplumber forcefully grabs my bluetooth headphones again seconds after I switched to other device (only Beats Solo 3) | closed | 2025-09-20 | 2025-09-23 |
| 861 | wireplumber 0.5.11 makes VLC stop playing when the audio output is switched automatically | closed | 2025-10-10 | 2025-10-10 |
| 914 | Manual device selection in KDE tray permanently overrides WirePlumber priority configuration | opened | 2026-02-16 | – |
| 930 / 931 | Unavailable remembered Bluetooth sink may remain selected after reboot instead of falling back to an available sink | closed | 2026-03-26 | 2026-03-27 / 2026-03-26 |
| 1005 | Wrong fallback device selected when Bluetooth disconnects | closed | 2026-09-03 | 2026-09-23T15:11:51Z |
| 1036 | question re: new find-best-profile behavior disregarding priority | closed | 2026-10-09 | 2026-10-09 |

No issue titled anything like "bluetooth headset not selected on connect" turned up (NOT FOUND).

### #1005 in full

Sources: https://gitlab.freedesktop.org/api/v4/projects/pipewire%2Fwireplumber/issues/1005 and `/-/issues/1005/discussions.json`

- Reporter benxiao, 2026-09-03, PipeWire 1.6.8 / WP 0.5.17. Label `type::suggestion-request`, closed by julian (Julian Bouzas) 2026-09-23T15:11:51Z.
- Problem: the default-nodes stack was BT → HDMI → USB headset. After BT disconnected, the USB headset was picked instead of HDMI.
- Maintainer's first answer (julian, 2026-09-03T18:25:15Z) said **priority beat history**, the opposite of "history beats priority":
  - QUOTED: "`priority.session` for the HDMI sink node is `696`, while the priority for the Arctis node is `1109`, which is higher."
  - QUOTED: "In general USB devices have higher priority than HDMI devices in wireplumber."
  - He suggested `wpctl set-default`.
- Reporter (2026-09-04), QUOTED: "Why even track `default-nodes` if the ordering is just going to be ignored anyways?" and "Wireplumber forcefully asserting that USB devices take priority even though the user selected HDMI before is unexpected behavior."
- Fix: julian, 2026-09-21T16:03:34Z, QUOTED: "I have created a MR that always prioritizes the previous device after the current device disconnects."
  - MR !902, "default-nodes: Rank stored nodes by stack position only", merged 2026-09-23T15:08:04Z, later commit 481ecffb.
  - The MR text explains the cause: the old C module gave each stack slot 20000 points, so priority.session could not reorder stored nodes. The Lua port (2325178d) "reduced each slot to 1 point but kept adding priority.session".
  - INFERRED: from !902 on (released in 0.5.18 according to #1036), history beats priority on fallback. Before that, priority could override history, which was a regression from the Lua port.
- Closing notes: julian, 2026-09-23, QUOTED: "Closing issue as this should be fixed now." Reporter confirmed, QUOTED: "it does indeed fix the issue!"
- "New device wins" option: NOT FOUND in #1005. The thread is only about the fallback on disconnect.
- Follow-up #1036 (2026-10-09): a user's priority config stopped working in 0.5.18. julian, 2026-10-09T14:36:33Z, QUOTED:
  - "What you're seeing is most likely caused by 481ecffb (See #1005), which is also in `0.5.18`."
  - "When the current default goes away, it falls back to the most recent one in that list that's still available."
  - The workaround is to never set the unwanted device as default. Closed by the reporter: "thanks that helped."

### #914 in full

Sources: https://gitlab.freedesktop.org/api/v4/projects/pipewire%2Fwireplumber/issues/914 and `/-/issues/914/discussions.json`

- Reporter fdkm, 2026-02-16, still open, label `user-experience`, "Discussed on Matrix chat."
- Description QUOTED: "This behavior is technically consistent, but highly confusing from a user perspective." The only way back to priority-based selection is `wpctl clear-default`. There is no GUI indication and no GUI way to clear it.
- **No maintainer has commented.** gkiagia only added a label (2026-02-16). The Matrix discussion is not public in the issue.
- felagund (not a maintainer):
  - 2026-02-28, QUOTED: "I have always found the approach "we will remember what you did last" suboptimal". He asks for a temporary set-default.
  - 2026-09-25: suggests `node.restore-default-targets = false` in a `wireplumber.conf.d` fragment and points to the ArchWiki. The setting was not verified here.
- fdkm, 2026-03-02, QUOTED: "I indeed would expect the GUI to use something like "wpctl set-current-output", and after that the next event (something plugged in) should use the normal priority model."
- Linked MR !916 ("docs: Improve documentation", by felagund, merged 2026-09-25) adds a priority docs page. It says it "Would partially tackle" #914.
- "New device wins": not discussed or rejected by maintainers in #914 (NOT FOUND).

### Maintainer explanation elsewhere (#352)

https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/352. This is the closest record of maintainers explaining why a stored choice beats a new device, and of a "new device wins" default being weighed. gkiagia, 2022-11-23T10:23:49Z, QUOTED:
- "wireplumber prefers to stick to your selection rather than changing to something else."
- "We have changed this behaviour back and forth in the past because some people want it this way and some others don't."
- "if it's a monitor without speakers, you don't want to switch to that"
- "It's a bit of a mess."

His workaround was `wpctl clear-default`. The reporter closed the issue as intended behaviour (2022-11-24).

Related, #62: gkiagia, 2021-11-01, QUOTED: "both devices have exactly the same priority, so either one is picked at random as the default, unless you explicitly make a change".

---

## Verdict table

| Claim | Verdict | Note |
|---|---|---|
| 1 | confirmed | Exists. Created 2022-11-04, closed 2022-11-16 (GitHub "completed") with no fix. 0.4.12 "only seems to work 1st time after restarting wireplumber, and then it fails again". The thread is mostly about the mirror and GitLab. |
| 2 | not found | No r/archlinux Feb 2021 / 0.3.21 thread found by three searches. Reddit is login-walled. |
| 3 | partly | One post by David Rosca (21 Mar 2018), quoting the checkbox text from Nate Graham. Not a group statement by "KDE devs". |
| 4 | confirmed | "not loaded by default, beacuse it's a bit too aggressive" and the 11.0 BT/USB preference are both quoted. The claim leaves out the 11.0 note that most USB devices weren't prioritized until 11.1. |
| 5 | partly | Timeline is right. It was also closed by Edmundson on 2018-03-20 before the 2019 reopen. The 2025 question came from a third user. Final state is RESOLVED WONTFIX (2025-08-02), not fixed. |
| 6 | confirmed | All dates and quotes match. The bug was first filed against pipewire-pulse. A mid-call input-switching warning was raised 27 Sep 2022 (Vincent), as a concern, not an observed event. |
| 7 | partly | KDE discuss (11 Feb 2026) matches. The Manjaro thread (21 Jun 2024) is about a wired jack, not BT. The 5 Reddit threads are not reachable; their IDs fit the claimed dates. |
| 8 | partly | Exists (2022-02-17, closed not_planned 2025-09-16). Interference, privacy and half-paired concerns are quoted. "Cost" is not found. The leaked address is the controller's bdaddr. ReconnectStartup was proposed but is not in BlueZ master. |
| 9 | confirmed | Draft PR 2023-10-24, closed unmerged 2023-11-08 by BluezTestBot after pointing to linux-bluetooth@vger.kernel.org. |
| 10 | confirmed | All 4 exist. LP 2169383 created 2026-10-03. pop 4102 created 2026-09-12, open. bluez 2524 created 2026-09-12 and closed by the reporter 2026-10-07 without a fix. bluez 2575 created 2026-09-24, open. |
| 11 | partly | The 5.17 announcement (15 Oct 2019) does not mention it; the "fixed in 5.17" is in a bug 399487 comment (2019-08-28). Manjaro Feb 2021: the missing module was module-gsettings. |
| 12 | partly | #914 has no maintainer comment. #1005: the maintainer first said priority beats history (USB > HDMI); MR !902 then made history win on fallback (in 0.5.18). "New device wins" was not discussed in either; gkiagia in #352 (2022) explains the stored choice and the HDMI dilemma. |
