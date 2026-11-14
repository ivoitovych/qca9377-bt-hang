Title: bluetoothd: use-after-free of a media endpoint when it exits while a sound server streams over A2DP

Bug: https://bugs.launchpad.net/ubuntu/+source/bluez/+bug/<LP-U23> (placeholder)
Package: bluez 5.72-0ubuntu5.8 (Ubuntu 24.04 LTS, noble); fix in 5.72-0ubuntu5.9 (one upload with four other bugs)

[Impact]

When bluetoothd exits without powering the adapter off first (for example when it loses the system bus), while a sound server
holds an acquired A2DP transport, an A2DP endpoint is freed while clear_endpoint() is still using it. The stream is locked by
the acquired transport, so removing the endpoint is deferred; the exit path frees the media applications first and releases
the endpoints afterwards; release_endpoint() then clears the transport, which unlocks the stream, unregisters the SEP and
frees the endpoint under clear_endpoint(). Seen with an AddressSanitizer build of bluetoothd at exit:

    ERROR: AddressSanitizer: heap-use-after-free  READ of size 8
        #0 clear_endpoint profiles/audio/media.c:300
        #1 release_endpoint profiles/audio/media.c:566
        #2 path_free profiles/audio/media.c:3276
        #3 remove_interface gdbus/object.c:660
        #4 g_dbus_unregister_interface gdbus/object.c:1394
        #5 unload_driver src/adapter.c:7590
        #7 a2dp_exit profiles/audio/a2dp.c:3575
        #8 plugin_cleanup src/plugin.c:217
        #9 main src/main.c:1456

In a production (non-sanitizer) build this is a read of freed memory in the exiting daemon. In every occurrence the log had just
shown "Disconnected from D-Bus. Exiting.".

A second defect in the same path: release_endpoint() sends Release to the endpoint and then removes it; for an A2DP endpoint the
removal unregisters its SEP, whose destroy callback calls release_endpoint() again, so the endpoint's owner gets Release twice.

[Patches]

Three patches, in order:
- media-Unlink-endpoints-from-their-application-on-removal.patch: the endpoint half of upstream 7482aceece70 ("profiles/audio:
  fix UAF on external media service teardown"), with the unlinking before the A2DP early return; needed by the third patch;
- media-Fix-sending-Release-twice-to-A2DP-endpoints.patch: marks the endpoint as released once Release is sent (written for this
  update; fixes bd3ca4fdf463);
- media-Fix-use-after-free-releasing-endpoints-on-adapter-removal.patch: path_free() releases the endpoints before freeing the
  applications (written for this update; fixes ee0f3c03fb1d).
The last two are not in an upstream release: the matching series for BlueZ master has been written and tested but is not merged
(state of 2026-11-14: not sent).

[Test Plan]

Setup (no hardware): QEMU/KVM guests with an emulated controller, BlueZ's own functional-test harness (test/functional,
pytest-bluezenv) from master driving the 5.72 bluetoothd built with AddressSanitizer and UBSan; the test starts A2DP, has a
D-Bus client acquire the transport, then kills the bus (or stops bluetoothd) and requires a clean exit
(test_a2dp_exit_with_acquired_transport).

1. Build 5.72-0ubuntu5.8 with --enable-asan --enable-ubsan and run the test ten times. Before: the AddressSanitizer report above
   in every run (10 of 10 in our run).
2. Build 5.72-0ubuntu5.9 the same way and run it ten times. After: no report, clean exit.
3. Run the other tests of the harness that touch media endpoints and A2DP; outcomes must be unchanged.

Results on the candidate 5.72-0ubuntu5.9 (2026-11-14), before and after:
- 5.72-0ubuntu5.8: 10 of 10 runs fail with three AddressSanitizer reports each, the first
  `heap-use-after-free profiles/audio/media.c:300 in clear_endpoint`;
- 5.72-0ubuntu5.9: 0 of 10 runs fail, no report;
- the L2 VM suite (31 tests) and BlueZ's unit tests (30 of 32, the same two failing on both) show no other difference.

[Where problems could occur]

The change is limited to the media plugin (profiles/audio/media.c): the order in which endpoints and applications are released
when an adapter is removed or bluetoothd exits, and an extra "released" flag on an endpoint. A mistake would show as an endpoint
whose owner is not told (no Release) or is told twice, a leaked endpoint, or a crash when an adapter is removed or the daemon
exits. Applications that register A2DP endpoints over D-Bus (PipeWire, PulseAudio) are the clients involved. Each Release is now
sent once where it was sent twice for A2DP endpoints; a client that relied on the second one would see a difference.

[Other Info]

- Present on BlueZ master (14bd6ab65 reproduced under AddressSanitizer, 10 of 10) and not fixed in 26.04, 26.10 or 27.04, so
  the SRU policy asks for the development release first: the two written-for-this-update patches have no upstream commit yet
  (open question for the SRU team, see BUNDLE.md).
- Originally seen in the ASan runs of the Release()-during-Acquire() work (LP: #<LP-U12>), at test teardown.
