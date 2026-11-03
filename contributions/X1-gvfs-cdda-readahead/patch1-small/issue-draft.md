# Draft: gvfs GitLab issue (for the operator to edit and file; not filed)

**Title:** cdda: Audio CD playback stops for about 3 s every 16 s

**Body:**

Playing a track of an audio CD in Totem (which opens `cdda://` tracks through
gvfsd-fuse, e.g. `/run/user/1000/gvfs/cdda:host=sr0/Track 1.wav`) stops for about
3 seconds every 16 seconds. PipeWire logs an underflow of the player's stream at
each stop.

Steps:
1. Insert an audio CD in a USB optical drive.
2. Open a track from the CD in Totem.
3. Listen; or watch `journalctl --user -f` for `UNDERFLOW` lines.

Cause: `do_read()` in `daemon/gvfsbackendcdda.c` reads one sector at a time with
`cdio_paranoia_read()`. When paranoia's buffer is used up, that call first reads a
whole cache model from the drive: 1200 sectors (16 s of audio) by default, also in
`PARANOIA_MODE_DISABLE`. The client read waits for all of it. On the drive below that
takes about 3 s, longer than the player's buffer.

Measured (Track 1, 5:09, played twice per build from a stopped drive, Totem through
gvfsd-fuse; underflows counted in the user journal):
- gvfs 1.54.4 as shipped: 19 underflows in the middle of the track, both runs; copying
  the whole track with `gio cat` took 29.8 s;
- with the cache model set to 150 sectors: no underflow in the middle of the track in
  either run, longest wait of the player's source 0.17 s; copying took 29.0 s;
- the copied audio was identical to a direct `cd-paranoia -Z` read in both cases.

Environment: Ubuntu 24.04, gvfs 1.54.4, libcdio-paranoia 10.2+2.0.1, ASUS SDRW-08D2S-U
(USB), Totem through gvfsd-fuse.

The same symptom was reported downstream in Ubuntu as Launchpad bug 1967258 ("Totem
has short pause when playing CD", 2022; not seen in Rhythmbox, which reads the disc
with GStreamer's cdparanoiasrc). GStreamer's cdparanoiasrc sets the cache model to
150 sectors for playback.

A merge request with that change follows.
