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
Collector `scripts/cd-trace/trace.py`, analysers `slowcalls.py`, `rhythm.py`, `gstpull.py`,
launcher `totem-debug.sh` (all in `scripts/cd-trace/`, README there). Raw recordings of both runs
(22 MB: GStreamer log, strace, usbmon, pw-top, journal) in
`archive/off-topic/X1/cd-gaps-runs-20261102.tar.xz` (local, SHA-256 `92cba5f4…6910`). Track 1 opened as
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
⚠️ *Corrected 2026-11-02 evening:* Totem does not read through `giosrc`. It opens the track
through gvfsd-fuse, as `/run/user/1000/gvfs/cdda:host=sr0/Track 1.wav` (`ls -l /proc/<totem
pid>/fd`, 23:38, fd 30), and gst-plugins-base 1.24.2 `gst/gio/gstgioelement.c:119-122` leaves the
`cdda` scheme out of giosrc (quoted by the simulator work, below). The blocking read and the gap are
the same; only the path differs: Totem → kernel FUSE (128 KiB reads) → gvfsd-fuse → gvfsd-cdda.

**Candidate fixes (not tried):** gvfs could shrink paranoia's block for streaming
(`cdio_paranoia_cachemodel_size()`, `p_block.c:395`) or read ahead asynchronously; the player side
could buffer slow GIO sources (a `queue2`); either removes the gap. Workaround: rip the CD and
play the files. Upstream (gvfs) not yet searched for an existing report.

## Runs 4–7 (2026-11-02 21:01–21:52): a second disc, drive noise, and a read-ahead defect

The operator played another CD with the read-ahead build (run 3's binary, SHA-256 `07426241…0a7`)
and reported (1) a loud drive ("taking off airplane"), louder than the music, and (2) two gaps in
the first track. Raw data: `tmp/cd-gaps/run4-disc2` … `run7-quiet` (strace, usbmon, journal,
GStreamer log). Sector-level analysis: `scripts/cd-trace/lbas.py <usbmon.txt>` (decodes READ CD
commands from the USB mass-storage command blocks).

**Run 4 (24×, read-ahead build), measured.** Underflows at 21:10:51.36 and 21:10:55.93
(`grep UNDERFLOW run4-disc2/journal.txt`), at 41.0 s and 45.6 s of audio. `lbas.py` shows the
disc read in 1,200-sector blocks every ~16 s, then two blocks of **re-reads** behind the player:
`21:10:50.213 … 3072 … 4272, 1201 sectors, reread 1201` and `21:10:54.778 … 3072 … 4615, 1201,
reread 1201`. One thread, one descriptor (`strace`). So the ring reset and the disc was re-read
while the player waited 1.709 s and 1.586 s (`gstpull.py`).

**Cause of the reset (simulator work, reproduced; trigger not explained).** Through gvfsd-fuse the
reader is the kernel page cache. It requests 128 KiB windows up to about two windows (≤ 119
sectors) ahead of the application. In run 4 the strace shows a SEEK request at 21:10:50.2126 and
21:10:54.7779, each to a page-aligned offset 96 and 81 sectors behind what gvfsd-cdda had served
(the page holding the player's position). gvfsd-fuse seeks whenever the FUSE offset differs from
its position (`client/gvfsfusedaemon.c:1272-1283`, 1.54.4). The ring dropped every sector before
the one wanted, so the backward request fell outside it → reset → re-read. Why the kernel asked
for that page again (eviction, invalidation, an interrupted read) is **not** shown by these traces.
A simulator around the verbatim read-ahead code reproduces the reset with an injected page loss
(18/21, 21/21 and 9/12 runs across scenarios). It was not seen in runs 5–7.

**Fix (in the test build, simulator-verified):** keep the last 2 s (150 sectors) already served
in the ring (`RA_HISTORY_SECTORS`), ring capacity 900 sectors. With the injected loss: 0 resets,
0 underflows in all three scenario sets; in the 336-run baseline matrix 18 runs differ by ±1
underflow or 0.3–0.5 s of silence (jitter sweeps; attributed to timing noise of the 20× time scale,
not isolated) and none gained a reset; the thread checker finds no new warning. Simulator and reports: `/root/exp/agent-work/x1-cdsim-20261102/`
(local).

**Drive noise (measured).** Paranoia's default reads 16 s of audio at the drive's full speed
(24×): ~1.5–2.3 s of loud reading, then ~13 s idle with spin-down, every 16 s. At 8× (`hdparm -E
8`, run 5) the bursts took ~3.3 s; no mid-track gap. The test build then asks the drive itself for
4× (`cdio_cddap_speed_set`) and reads 2 s per step (`cdio_paranoia_cachemodel_size(150)`): run 7
shows a SET CD SPEED command (0xBB, read speed 0x02C4 = 708 KB/s = 4×) although the drive had just
been set to 24×, and steady reads of 150 sectors with 1.5–2.2 s pauses for the whole track; no
mid-track underflow, one at 0.6 s into the track (the slow first fill), one at the track end. The
operator: "it got better". Simulator: step 150 spins the drive up once per track against 18–19
times at step 1200.

**Other findings.** libcdio-paranoia's `paranoia_cb_mode2str[]` has 13 names
(`paranoia.c:116-120`), the enum continues to `PARANOIA_CB_CACHEERR` (13) and `WROTE` (14)
(`paranoia.h:85-86`), so indexing it with every event reads past its end; it affected only our
diagnostic line (fixed). gvfs's `num_open_files` counter is changed without a lock in
`do_open_for_read`/`do_close_read`, which is not reachable: the cdda daemon runs one job thread
(`daemon/meson.build:339`, `MAX_JOB_THREADS=1`).
