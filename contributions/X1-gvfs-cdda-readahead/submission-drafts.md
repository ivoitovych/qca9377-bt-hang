# Submission drafts: two gvfs issues, two merge requests (not filed)

Order:

1. File issue A, then issue B.
2. Add to each commit a `Fixes:` trailer with the issue's URL exactly as GitLab shows it.
   Recent gvfs commits use the work-item form,
   `Fixes: https://gitlab.gnome.org/GNOME/gvfs/-/work_items/886` (also 860); older ones
   `/-/issues/N` (875, 864).
3. Re-export both patches, and check that the `From:` address is one on the GitLab account.
4. Push the two branches; open MR 1, then MR 2, which names MR 1 as `!N`.

`#A`, `#B` and `!M1` stand for the numbers GitLab assigns. Each text below is pasted as it
stands, between the rules.

Patch files at `3e6b7d7`: patch 1 `patch1-small/0001-cdda-Limit-paranoia-read-ahead-to-avoid-playback-sta.patch`,
patch 2 `patch-track/0001-cdda-Refuse-to-open-invalid-and-non-audio-tracks.patch`.

## Issue A — playback stall

**Title:** cdda: Audio CD playback stops for about 3 seconds every 16 seconds

---

Playing an audio CD track in Totem stops for about 3 seconds every 16 seconds. Totem reads
the track through gvfsd-fuse (`/run/user/1000/gvfs/cdda:host=sr0/Track 1.wav` here). PipeWire
logs an underflow of the player's stream at each stop.

Steps to reproduce:

1. Insert an audio CD into a USB optical drive.
2. Open one of its tracks in Totem: `totem 'cdda://sr0/Track%201.wav'`, or `Track 1.wav`
   from the CD's folder in Files (the device name may differ).
3. Listen. Each stop also shows as an underflow line in `journalctl --user -f`.

`do_read()` in `daemon/gvfsbackendcdda.c` takes one sector at a time from
`cdio_paranoia_read()`. When paranoia's buffer is empty, that call first refills its cache
from the drive, normally 1200 sectors or 16 seconds of audio, even in the
`PARANOIA_MODE_DISABLE` used here. On this drive the refill takes about 3 seconds, and the
player runs dry while it waits.

Measured with a 5:09 track, played twice per build from a stopped drive: 19 mid-track
underflows in each run as shipped, none in either run with the cache model set to 150
sectors.

Environment: Ubuntu 24.04, gvfs 1.54.4, libcdio-paranoia 10.2+2.0.1, ASUS SDRW-08D2S-U
(USB). `do_read()` is the same on master.

A similar pause was reported downstream in https://bugs.launchpad.net/bugs/1967258, filed
against Totem in 2022; its reporter did not see it in Rhythmbox, which reads the disc with
GStreamer's cdparanoiasrc. That element sets the cache model to 150 sectors for playback.

---

## Issue B — invalid track names

**Title:** cdda: Opening a track that is not on the disc keeps the drive busy or returns another track

---

With a 13-track audio CD in a USB drive:

- `gio cat 'cdda://sr0/Track%2099.wav' > /dev/null` keeps the drive busy for more than
  five minutes, until it is stopped.
- `gio cat 'cdda://sr0/Track%20257.wav' > 257.wav` writes the audio of track 1.
- `Track 0.wav` opens too.

`do_open_for_read()` in `daemon/gvfsbackendcdda.c` passes whatever number `sscanf()` finds
in the file name to libcdio without checking it. For a track that is not on the disc,
libcdio returns a negative error code where a sector number is expected, and paranoia is
sent there. libcdio's track number is 8 bits wide, so 257 becomes 1. Nothing checks that
the track is an audio track either, so the data tracks of a mixed-mode disc would open too.

Environment: Ubuntu 24.04, gvfs 1.54.4, libcdio 2.1.0, libcdio-paranoia 10.2+2.0.1, ASUS
SDRW-08D2S-U (USB). `do_open_for_read()` is the same on master.

---

## MR 1 — patch 1

**Title:** cdda: Limit paranoia read-ahead to avoid playback stalls

---

Fixes #A

Set paranoia's cache model to 150 sectors, as GStreamer's cdparanoiasrc does for playback,
reducing the normal read-ahead from 16 seconds of audio to 2 seconds. The call is behind a
meson `has_function()` check, so builds against libcdio-paranoia older than 10.2+0.93+1,
which already read ahead 150 sectors, are unchanged.

Tested with Ubuntu 24.04's gvfs 1.54.4 and this patch, Totem reading through gvfsd-fuse,
an ASUS SDRW-08D2S-U USB drive, a 5:09 track played twice per build: 19 mid-track
underflows in each run without the patch, none with it. Copying the whole track took 29.8 s
before and 29.0 s after, and the audio was identical to a direct `cd-paranoia` read. On
master the patch builds without warnings, and the meson check finds the function. It also
applies cleanly to gnome-46, -47, -49 and -50.

Independent of the fix for #B: either can be merged alone, and they apply in either order.

---

## MR 2 — patch 2

**Title:** cdda: Refuse to open invalid and non-audio tracks

---

Fixes #B

Refuse track names whose number has a sign or trailing characters or is above 99, and open
only audio tracks between the disc's first and last track numbers.

Tested with Ubuntu 24.04's gvfs 1.54.4 and both cdda patches, a 13-track disc in an ASUS
SDRW-08D2S-U USB drive, `gio cat 'cdda://sr0/Track%20<n>.wav'`:

- refused at once with "No such file", for `<n>` = `-2`, `0`, `14`, `99`, `100`, `255`,
  `256`, `257`, `4294967297`, `1junk`, `+1`, and the name `Track 1.wav.wav`;
- read as before: `1` to `13`; `01` and `0001` read track 1, `0011` reads track 11;
- `gio info` refuses `Track 1junk.wav`; `gio list` is unchanged.

The bounds are the disc's first and last track numbers rather than the track count, because
a disc may number its tracks from above 1, and master reads such tracks. I checked this with
a test program that compiles the backend's `do_open_for_read()` and runs it on a simulated
drive (a fake libcdio driver) under real libcdio 2.2.0 and libcdio-paranoia 10.2+2.0.2:
with tracks numbered 2 to 4, `Track 4.wav` reads all its audio to the end, as on master;
`Track 1.wav` and `Track 5.wav` are refused. With tracks 1 to 3 and track 3 a data track,
`Track 3.wav` is refused.

On master the patch builds without warnings. It also applies cleanly to gnome-46, -47, -49
and -50.

Independent of !M1 (#A): either can be merged alone, and they apply in either order.

---
