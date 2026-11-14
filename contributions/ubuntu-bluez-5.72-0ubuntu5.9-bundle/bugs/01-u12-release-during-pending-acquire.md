Title: bluez: Release() during a pending A2DP Acquire() aborts the stream and disconnects A2DP

Bug: https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/<LP-U12> (placeholder)
Package: bluez 5.72-0ubuntu5.8 (Ubuntu 24.04 LTS, noble); fix in 5.72-0ubuntu5.9 (one upload with four other bugs)

[Impact]

When an application opens the microphone of a Bluetooth headset just as A2DP playback starts, WirePlumber switches the
headset to its hands-free profile and releases the A2DP transport while bluetoothd's Acquire (AVDTP START) is still pending.
BlueZ 5.72 turns that Release() into an AVDTP ABORT. A headset that answers ABORT loses its A2DP profile connection
immediately; a headset that does not answer it (seen with a Sennheiser MOMENTUM 4) loses the whole AVDTP session after the
2 s abort timeout. Nothing reconnects A2DP; only the hands-free profile remains until the headset is reconnected. The pending
Acquire() is also never answered.

bluetoothd log of an occurrence:

    media_owner_add() Owner :1.81 Request Acquire
    media_owner_remove() Owner :1.81 Request Acquire
    a2dp_cancel() aborting setup
    cancel_request() Start: Operation canceled (125)
    session_cb() Transaction label doesn't match
    cancel_request() Abort: Connection timed out (110)
    connection_lost() Disconnected from <headset>
    profile a2dp-sink state changed: connected -> disconnected (0)

Fixed upstream by a14d59725ef3 ("transport: don't disconnect A2DP if canceling Acquire() with Release()", BlueZ 5.80):
the Acquire() is answered with an error, START is waited out and followed by SUSPEND.

[Patches]

Three patches, all from upstream, in the order of the series (attached: the debdiff 5.72-0ubuntu5.8 to 5.72-0ubuntu5.9, which
carries them with four other bugs' patches; the file names are those in debian/patches):
- transport-Add-transport_a2dp_get_stream-helper.patch: the transport_a2dp_get_stream() helper of 3d9900eb754d (BlueZ 5.79),
  which the fix calls; the rest of that commit changes D-Bus behaviour and is left out;
- transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch: a14d59725ef3 (the A2DP_OPS hunk is applied by hand:
  5.72's macro has no _set_delay argument and no A2DP get_stream op, so only the remove_owner op is wired in);
- a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch: 664a5d3785a1 (BlueZ 5.80, the same upstream series): without it a
  reconfiguration to another endpoint made while the cancelled START is pending ends on the old endpoint.

[Test Plan]

Setup used so far (no hardware): emulated controllers in QEMU/KVM guests of Ubuntu 24.04 userspace, one guest runs the
packaged /usr/libexec/bluetooth/bluetoothd under test, the other plays a headset that answers START after 200 ms and never
answers ABORT (the MOMENTUM 4's timing). A D-Bus client calls Acquire() on the A2DP transport and Release() in the same
main-loop turn.

1. Install bluez 5.72-0ubuntu5.8 (before) and run the trigger. Expected before: an AVDTP ABORT is sent, the Acquire() reply
   never comes, A2DP is disconnected about two seconds later and a later Acquire() fails.
2. Install bluez and libbluetooth3 5.72-0ubuntu5.9 from -proposed and repeat. Expected after: no ABORT, the Acquire() is
   answered with org.bluez.Error.Failed ("Operation canceled"), START is waited out, SUSPEND follows, Release() is answered,
   A2DP stays connected, and a new Acquire() works and media reaches the remote.
3. With a real headset and Ubuntu's PipeWire 1.0.5 and WirePlumber 0.4.17: play audio and open a recording application in the
   same second, ten times; before, A2DP is sometimes lost until the headset reconnects; after, never (a timing-dependent
   check, so not a reliable reproducer).

Results on the 5.72-0ubuntu5.9 candidate (2026-11-14), each "before" 5.72-0ubuntu5.8 and "after" the candidate:
- emulated controllers in QEMU/KVM guests, the source of each version built with ASan/UBSan, Release() during a pending Acquire()
  against remotes that answer ABORT and that never do, same main-loop turn and 87 ms later, T201 to T207 ten runs each:
  5.72-0ubuntu5.8: A2DP lost 70/70, ABORT sent 70/70, Acquire() never answered 70/70, a later Acquire() with media 0/70;
  5.72-0ubuntu5.9: A2DP lost 0/70, ABORT 0/70, Acquire() answered with org.bluez.Error.Failed 70/70, a later Acquire() with media
  70/70, no sanitizer report;
- the binary packages installed in QEMU guests with Ubuntu 24.04's own PipeWire 1.0.5 and WirePlumber 0.4.17: trigger T201 from a
  D-Bus client: lost 3/3 on 5.72-0ubuntu5.8, kept 3/3 on 5.72-0ubuntu5.9; WirePlumber/PipeWire switching the profile to "off"
  while START is pending (R310): lost 3/3 on 5.72-0ubuntu5.8, kept in 7 of 7 runs that reached the trigger on
  5.72-0ubuntu5.9 (5 further runs did not reach the trigger and do not count); the normal Acquire()/Release() control passes on both;
- the 35 tests of the transport harness (transport.c with stubs, ASan/UBSan): 27 pass and 8 fail on 5.72-0ubuntu5.8, 35 pass on
  5.72-0ubuntu5.9; the 31 VM tests: the 14 that fail on 5.72-0ubuntu5.8 pass on 5.72-0ubuntu5.9, none changes the other way;
- dpkg-buildpackage; `make check` 30 of 32 on both, the same two unit tests fail on both (test-mesh-crypto, test-vcp), the same warnings.

[Where problems could occur]

The change is in profiles/audio/transport.c (the A2DP Acquire/Release/Suspend path) and, for the third patch, the start of
a2dp_resume() and a2dp_suspend() in profiles/audio/a2dp.c. A mistake would show as an Acquire() that is never answered, a
Release() that waits for ever or answers twice, a stream left in a wrong state, or an A2DP transport that cannot be acquired
again; PipeWire and WirePlumber are the clients that call these. Behaviour changes on purpose: a Release() during a pending
Acquire() now waits for START and SUSPEND instead of aborting, and the Acquire() gets an error reply instead of none. An owner
that exits (not Release()) during a pending Acquire() still sends ABORT, as before. The three BAP failures of PipeWire's own VM
tests are unchanged.

[Other Info]

- The fix is in BlueZ 5.80 and therefore in 26.04, 26.10 and 27.04 (checked 2026-11-01: 5.85, 5.87-4, 5.87-5).
- Launchpad 2056196 (noble, New) is a headset that switches A2DP to HSP for a call on another device; it neither shows nor
  rules out this bug.
- Upstream commits: a14d59725ef35d91b8504770046c701d0a2efe07, 664a5d3785a1a57989d236b6fd649321a39451f5,
  3d9900eb754d277ef6abf21bed827cdc9e79ddb4 (helper part).
