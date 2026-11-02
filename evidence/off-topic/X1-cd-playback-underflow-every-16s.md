# X1 — audio CD in Totem: the player's stream underflows every 16 s (off-topic, not Bluetooth)

**Claim.** Playing an audio CD in Ubuntu 24.04's standard player (Totem, opened from the file
manager) gives an audible interruption about every 16 s. PipeWire records each one as an
`UNDERFLOW` on Totem's own playback stream, i.e. the player had no audio ready to hand over. The
output device (a Bluetooth speaker on A2DP/SBC) kept running and logged no error; the same
interval held to within 0.7 s across four gaps.

**Relevance.** Off-topic for the Bluetooth work; registered because the operator heard it and it
looks like a defect of the standard CD playback chain (no component named yet).

**Setup (2026-11-02, the laptop):**
- Drive: ASUS SDRW-08D2S-U (USB 0e8d:1887, 480 Mbit/s, firmware A814), external, `usb-storage`,
  `/dev/sr0`; USB runtime power management `control=on`, `runtime_suspended_time` 0 (never
  suspended).
- Player: Totem 43.0-2ubuntu4, started by Nautilus over D-Bus; the CD is browsed through GNOME's CD
  backend (`gvfsd-cdda`, gvfs-backends 1.54.4-0ubuntu1~24.04.4). GStreamer 1.24.2-1ubuntu1.8,
  PipeWire 1.0.5-1ubuntu3.3 (pipewire-pulse).
- Output: a Bluetooth speaker, A2DP sink, codec SBC (`wpctl inspect`); Bluetooth device discovery
  was off during this run.

**Extraction** (the journal of the running boot; pipewire-pulse logs at debug level on this
machine):

```
$ journalctl -b --since "19:36:20" --until "19:37:50" --no-pager -o short-iso-precise --grep "Activating service name='org.gnome.Totem'|\[Videos\] (CREATE_PLAYBACK_STREAM|CORK_PLAYBACK_STREAM)|\[Videos\]: UNDERFLOW|\[Videos\] maxlength:4194304 tlength"
2026-11-02T19:36:20.400396+01:00 n dbus-daemon[2862]: [session uid=1000 pid=2862] Activating service name='org.gnome.Totem' requested by ':1.232' (uid=1000 pid=1516706 comm="/usr/bin/nautilus --gapplication-service" label="nautilus (unconfined)")
2026-11-02T19:36:26.321779+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-11-02T19:36:26.321829+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] maxlength:4194304 tlength:24008 minreq:4/0 prebuf:24008 latency:6000/44100 4
2026-11-02T19:36:26.329756+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] maxlength:4194304 tlength:27528 minreq:3528/472 prebuf:24004 latency:5118/44100 4
2026-11-02T19:36:26.348576+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] CREATE_PLAYBACK_STREAM tag:16 corked:1 sink-name:(null) sink-index:4294967295
2026-11-02T19:36:26.348600+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] maxlength:4194304 tlength:19404 minreq:1764/0 prebuf:0 latency:3969/44100 4
2026-11-02T19:36:26.357680+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] maxlength:4194304 tlength:19404 minreq:1764/472 prebuf:0 latency:3969/44100 4
2026-11-02T19:36:26.360347+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] CORK_PLAYBACK_STREAM tag:22 channel:0 cork:no
2026-11-02T19:36:41.103227+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos]: UNDERFLOW channel:0 offset:2604264 (0 suppressed)
2026-11-02T19:36:57.423008+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos]: UNDERFLOW channel:0 offset:5483112 (0 suppressed)
2026-11-02T19:37:13.039276+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos]: UNDERFLOW channel:0 offset:8237776 (0 suppressed)
2026-11-02T19:37:29.380308+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos]: UNDERFLOW channel:0 offset:11120388 (0 suppressed)
2026-11-02T19:37:42.699202+01:00 n pipewire-pulse[2851]: mod.protocol-pulse: [Videos] CORK_PLAYBACK_STREAM tag:316 channel:0 cork:yes
```

**Reading [arithmetic on the lines above]:**
- Wall-clock spacing of the underflows: 16.32 s, 15.62 s, 16.34 s.
- Stream offsets at 44100 Hz × 2 ch × 2 bytes = 176,400 B/s: 14.76 s, 31.08 s, 46.70 s, 63.04 s
  into the audio, i.e. one underflow per ~16 s of audio.
- The stream's target buffer (`tlength`) is 19,404–27,528 bytes, 0.11–0.16 s of audio.
- The operator stopped playback at 19:37:42 after hearing four interruptions, matching the four
  underflows.

**Ruled out [measured]:** the drive's USB autosuspend (never suspended); kernel read errors during
playback (none in the kernel log 19:36–19:38; the `Illegal mode for this track` errors at 19:21
are a filesystem probe of the audio disc, before playback); Bluetooth discovery (off; it was on
during an earlier attempt, 19:22:39–19:23:56); errors on the Bluetooth output (pw-top: none).

**Inferred, not shown:** the CD is read in bursts; between bursts the drive slows or stops, and
the next read arrives later than the ~0.1 s the stream can absorb. Which layer should read ahead
(gvfsd-cdda, GIO, Totem/GStreamer, or the stream) is not established.

**Not done yet:** (1) the same track through GStreamer's own CD source, bypassing gvfsd-cdda;
(2) a passive USB capture of the drive's reads during Totem playback, to see a read stall before
each gap; (3) the same playback to the laptop's speakers (expected to gap the same way, since the
underflow is on the player's side).

Recorder outputs of the run (disc-block counters, which do not see audio-CD reads; pw-top):
`tmp/cd-gaps/run1/` (local), made by `tmp/cd-gaps/record.py`.

## Run 2 (2026-11-02 19:52–19:55): traced, root cause found

**Tracing (all passive, no rebuild):** Totem started with
`GST_DEBUG=3,giosrc:6,basesrc:5,wavparse:5,queue2:5,multiqueue:4,playsink:4,pulsesink:6,audiobasesink:5,audioringbuffer:5,audiosink:5`
(`GST_DEBUG_FILE=/tmp/cd-gaps-gst.log`); `strace -f -tt -T` attached to the running
`gvfsd-cdda`; the drive's USB traffic (usbmon text, bus 1 device 5); `pw-top -b`; the journal.
Collector `tmp/cd-gaps/trace.py`, analysers `slowcalls.py`, `rhythm.py`, `gstpull.py` (all in
`tmp/cd-gaps/`, outputs in `tmp/cd-gaps/run2/`, local). Track 1 opened as
`cdda://sr0/Track%201.wav`.

**Measured:**
- 11 `UNDERFLOW`s on Totem's stream, 19:52:55.57 to 19:55:35.33, spaced 16.32 / 15.59 / … s,
  at 14.8, 31.1, 46.7, 63.0, 78.6, 95.0, 110.6, 127.0, 142.6, 158.9, 174.5 s of audio.
- `gvfsd-cdda`'s disc reads (`ioctl CDROM_SEND_PACKET`, 575 in all, 38.3 s total, max 0.168 s)
  come in bursts of exactly 48 reads lasting 2.9–3.3 s, separated by pauses of 12.5–13.8 s with
  no read at all. Within a burst the reads start slow and speed up (0.158, 0.145, 0.132, 0.121 …
  0.080 s): the disc spinning back up. Every underflow falls 1.0–1.1 s into a burst, within 0.07 s
  of a read (`rhythm.py`).
- The player's source pulls 7,056 bytes (40 ms of audio) per request, 4,513 such requests;
  normally answered at once. Eleven requests block for 3.03–3.26 s, at offsets 14.76, 31.08,
  46.68, 63.04 … s of audio — the burst duration, at the underflow positions (`gstpull.py`).

**From source:**
- gvfs 1.54.4 `daemon/gvfsbackendcdda.c:643-746` `do_read()`: each client read is answered with at
  most one sector (2,352 bytes) obtained by a synchronous `cdio_paranoia_read()` (line 707);
  paranoia is opened with `PARANOIA_MODE_DISABLE` (line 626) and its cache model is left at the
  default.
- libcdio-paranoia `lib/paranoia/p_block.h:34` `#define CACHEMODEL_SECTORS 1200`;
  `p_block.c:373` sets `cdcache_size` to it; `paranoia.c:2626` `i_read_c_block()` reads
  `totaltoread = p->cdcache_size` sectors in one call, `p->d->nsectors` (25 here) per request.
  1,200 sectors × 2,352 bytes = 2,822,400 bytes = 16.0 s of audio: 48 requests × 25 sectors.

**Root cause (measured + source):** when paranoia's 1,200-sector block is used up, the next
one-sector read in `gvfsd-cdda` blocks while paranoia reads the whole next 16 s from the disc
(~3 s on this drive, including spin-up after the 13 s idle). Totem/GStreamer pulls through
`giosrc` with no read-ahead queue, so that request blocks the playback thread for ~3 s, and the
PipeWire stream (0.1 s buffer) underflows: about 3 s of silence every 16 s.

**Candidate fixes (not tried):** gvfs could shrink paranoia's block for streaming
(`cdio_paranoia_cachemodel_size()`, `p_block.c:395`) or read ahead asynchronously; the player side
could buffer slow GIO sources (a `queue2`); either removes the gap. Workaround: rip the CD and
play the files. Upstream (gvfs) not yet searched for an existing report.
