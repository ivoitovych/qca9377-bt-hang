# cd-trace — passive tracing of audio-CD playback (issue X1, off-topic)

Built 2026-11-02 to find why an audio CD played in Totem stops about every 16 s. Nothing here
sends anything to a device or changes a setting; everything records alongside a normal playback.

| tool | what it does |
|---|---|
| `totem-debug.sh [<uri>] [<log>]` | starts Totem on the desktop with GStreamer debug logging (source, WAV parser, queues, audio sink) to `<log>` (default `/tmp/cd-gaps-gst.log`), optionally opening a track such as `cdda://sr0/Track%201.wav`. Close Totem first |
| `trace.py <seconds> <outdir>` | for `<seconds>`: `strace -f -tt -T` of the running `gvfsd-cdda` (disc ioctls and client writes), the drive's USB traffic (text usbmon, bus/device of `/sys/bus/usb/devices/1-1`), `pw-top -b`, and at the end the journal's `[Videos]`/UNDERFLOW lines. Start playback first so `gvfsd-cdda` exists |
| `record.py <seconds> <outdir>` | the lighter first recorder: `/sys/block/sr0/stat` counters (which do **not** see audio-CD reads, they bypass block accounting) and `pw-top -b` |
| `slowcalls.py <strace.txt> [s]` | per-syscall totals and every call slower than `s` (default 0.05) |
| `rhythm.py <strace.txt> <HH:MM:SS.ffffff>...` | disc-read bursts and pauses, and where each given underflow falls relative to them |
| `gstpull.py <gst.log> [s]` | the player source's pull requests: sizes, and every request slower than `s`, with its position in seconds of audio |
| `analyse.py <rundir>` | `record.py`'s output: read bursts and pw-top error changes |
| `lbas.py <usbmon.txt> [gap_s]` | which disc sectors the drive was asked for, burst by burst, from `trace.py`'s usbmon text |
| `totem-quit.sh` | asks the desktop user's Totem to quit over D-Bus and waits up to 10 s; run before `totem-debug.sh` |
| `cdda-remount.sh` | unmounts and remounts the audio CD in the desktop session so gvfs starts a fresh `gvfsd-cdda` (after installing a test binary); prints its pid and the binary's checksum |
| `x1-check-submission.py` | **read-only, after submission (2026-11-07):** the live state of gvfs issues #893/#894 and MRs !368/!369 from GNOME GitLab (state, commits, pipeline, description against the frozen drafts, comments by others, the uploaded test program's SHA-256); exit 1 if anything no longer matches. Uses GraphQL for MRs: the REST API answers anonymous MR requests with 406, and the server refuses unknown User-Agent strings |

**A run as done on 2026-11-02:** close Totem; `scripts/cd-trace/totem-debug.sh
"cdda://sr0/Track%201.wav"`; `python3 -I scripts/cd-trace/trace.py 600 tmp/cd-gaps/runN`
(background); listen through a few gaps; then `journalctl --since <start> --grep
"\[Videos\]: UNDERFLOW"` for the underflow times, and the three analysers.

**Prerequisites present on the laptop:** strace, the GStreamer tools, `usbmon` (debugfs). The
desktop user is `i` (uid 1000). PipeWire-pulse already logs stream UNDERFLOWs at its current
log level.

The patches, their review record and the submission (gvfs !368, !369, 2026-11-07):
`contributions/X1-gvfs-cdda-readahead/`.

Results of 2026-11-02: `evidence/off-topic/X1-cd-playback-underflow-every-16s.md`; the raw
recordings (22 MB, both runs) in `archive/off-topic/X1/cd-gaps-runs-20261102.tar.xz` (local,
SHA-256 `92cba5f4ff701563633474331f34b6b547f15661b14c5a8a01e3aa468eb06910`).
