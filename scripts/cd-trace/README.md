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

**A run as done on 2026-11-02:** close Totem; `scripts/cd-trace/totem-debug.sh
"cdda://sr0/Track%201.wav"`; `python3 -I scripts/cd-trace/trace.py 600 tmp/cd-gaps/runN`
(background); listen through a few gaps; then `journalctl --since <start> --grep
"\[Videos\]: UNDERFLOW"` for the underflow times, and the three analysers.

**Prerequisites present on the laptop:** strace, the GStreamer tools, `usbmon` (debugfs). The
desktop user is `i` (uid 1000). PipeWire-pulse already logs stream UNDERFLOWs at its current
log level.

Results of 2026-11-02: `evidence/off-topic/X1-cd-playback-underflow-every-16s.md`; the raw
recordings (22 MB, both runs) in `archive/off-topic/X1/cd-gaps-runs-20261102.tar.xz` (local,
SHA-256 `92cba5f4ff701563633474331f34b6b547f15661b14c5a8a01e3aa468eb06910`).
