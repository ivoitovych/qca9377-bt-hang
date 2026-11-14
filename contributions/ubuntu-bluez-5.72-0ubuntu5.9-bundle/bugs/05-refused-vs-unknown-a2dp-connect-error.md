Title: bluez: a refused A2DP connection is reported as br-connection-unknown instead of br-connection-refused

Bug: https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/<LP-REFUSED> (placeholder)
Package: bluez 5.72-0ubuntu5.8 (Ubuntu 24.04 LTS, noble); fix in 5.72-0ubuntu5.9 (one upload with four other bugs)

[Impact]

When a headset has dropped the computer's pairing key, connecting to it fails in GNOME with a generic "unknown" error. The kernel
refuses the A2DP channel with ECONNREFUSED (Connection refused (111) in the bluetoothd log); error_to_errno() in
profiles/audio/a2dp.c turns that into -EAGAIN, which has no name in src/error.c, so the D-Bus error reply of Device1.Connect() is
"br-connection-unknown". Upstream maps ECONNREFUSED to itself, which gives
"br-connection-refused".

Limit: the message still does not tell the user that the headset forgot the key; no errno mapping on this path can, because the
HCI status never reaches a socket.

[Patches]

One patch, upstream a6ac17f0e393 ("a2dp: Fix connection error message", Frederic Danis, 2024-08-21, BlueZ 5.78):
a2dp-Fix-connection-error-message.patch, one added `case ECONNREFUSED:` line in error_to_errno().

[Test Plan]

Setup (no hardware): QEMU/KVM guests with emulated controllers; host0 runs bluetoothd under test as A2DP source, host1 an A2DP
sink. The two pair and trust each other; host0's kernel is given an inverted copy of the link key so that host1's controller
answers Authentication Complete 0x05; an SDP channel (PSM 1) holds the ACL up without authentication; a D-Bus client calls
Device1.Connect().

1. 5.72-0ubuntu5.8: the error is br-connection-unknown, with "avdtp_connect_cb() ... Connection refused (111)" (10 of 10 in our run).
2. 5.72-0ubuntu5.9: the error is br-connection-refused (10 of 10).
3. Control (no ACL held, kernel path EACCES, "Permission denied (13)"): br-connection-unknown on both (5 of 5).

Results on the candidate 5.72-0ubuntu5.9 (2026-11-14), before and after:
- 5.72-0ubuntu5.8, ACL held: br-connection-unknown 10 of 10, with "Connection refused (111)" in the AVDTP log each time;
- 5.72-0ubuntu5.9, ACL held: br-connection-refused 10 of 10, the same log line;
- control without a held ACL ("Permission denied (13)"): br-connection-unknown 5 of 5 on both;
- dpkg-buildpackage; `make check` 30 of 32 on both with the same two failures.

[Where problems could occur]

The patch adds one errno to a switch in error_to_errno() in profiles/audio/a2dp.c. The only change is the text of the D-Bus error
for connections refused by the remote: br-connection-refused instead of br-connection-unknown. A client that matches on the old
text for a refused connection would see a difference; nothing else (no state, no profile logic) changes.

[Other Info]

- Upstream a6ac17f0e3932d6b07ced87e41fe7a108fe55149, in BlueZ 5.78 and therefore in 26.04, 26.10 and 27.04.
- Found while investigating why a headset that forgot its key shows an unnamed error.
