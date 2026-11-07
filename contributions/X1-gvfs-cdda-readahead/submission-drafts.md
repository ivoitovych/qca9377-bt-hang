# Submission drafts: two gvfs issues, two merge requests (not filed)

Order: file both issues, add each issue's `Fixes:` trailer to its commit (gvfs commits link
their issue this way: `Fixes: https://gitlab.gnome.org/GNOME/gvfs/-/issues/875`, 864, 863,
862, 851), re-export, push the two branches, then open the two MRs. `#A` and `#B` stand for
the issue numbers GitLab assigns. Each text below is pasted as it stands, between the rules.

Patch files at `3e6b7d7`: patch 1 `patch1-small/0001-cdda-Limit-paranoia-read-ahead-to-avoid-playback-sta.patch`,
patch 2 `patch-track/0001-cdda-Refuse-to-open-invalid-and-non-audio-tracks.patch`.

## Issue A — playback stall

**Title:** cdda: Audio CD playback stops for about 3 seconds every 16 seconds

---

Playing an audio CD in Totem, which reads the track through gvfsd-fuse
(`/run/user/1000/gvfs/cdda:host=sr0/Track 1.wav`), stops for about 3 seconds every
16 seconds. PipeWire logs an underflow of the player's stream at each stop.

Steps to reproduce:

1. Insert an audio CD into a USB optical drive.
2. Play a track from it in Totem.
3. Listen, or watch `journalctl --user -f` for the underflow lines.

`do_read()` in `daemon/gvfsbackendcdda.c` takes one sector at a time from
`cdio_paranoia_read()`. When paranoia's buffer is empty, that call first refills its cache
from the drive, normally 1200 sectors or 16 seconds of audio, also in the
`PARANOIA_MODE_DISABLE` used here. On this drive the refill takes about 3 seconds, and the
player runs dry while it waits.

Measured with a 5:09 track, played twice per build from a stopped drive: 19 mid-track
underflows in each run as shipped, none in either run with the cache model set to 150
sectors.

Environment: Ubuntu 24.04, gvfs 1.54.4, libcdio-paranoia 10.2+2.0.1, ASUS SDRW-08D2S-U
(USB). The read path is the same on master.

The same pause is reported downstream as https://bugs.launchpad.net/bugs/1967258, filed
against Totem in 2022; it does not occur in Rhythmbox, which reads the disc with GStreamer's
cdparanoiasrc. That element sets the cache model to 150 sectors for playback.

---

## Issue B — invalid track names

**Title:** cdda: Track names that are not audio tracks on the disc can be opened

---

With a 13-track audio CD in a USB drive:

- `gio cat 'cdda://sr0/Track%2099.wav' > /dev/null` keeps the drive busy for more than
  five minutes, until it is stopped.
- `gio cat 'cdda://sr0/Track%20257.wav'` returns the audio of track 1.
- `Track 0.wav` opens too, and so would the data tracks of a mixed-mode disc.

`do_open_for_read()` in `daemon/gvfsbackendcdda.c` passes whatever number `sscanf()` finds
in the file name to libcdio without checking it. For a track that is not on the disc,
libcdio returns a negative error code where a sector number is expected, and paranoia is
sent there. libcdio's track number is 8 bits wide, so 257 becomes 1.

Environment: Ubuntu 24.04, gvfs 1.54.4, libcdio 2.1.0, ASUS SDRW-08D2S-U (USB). The open
path is the same on master.

---

## MR 1 — patch 1

**Title:** cdda: Limit paranoia read-ahead to avoid playback stalls

---

Fixes #A

Set paranoia's cache model to 150 sectors, as GStreamer's cdparanoiasrc does for playback,
so that a refill no longer outlasts the player's buffer. The call is behind a meson
`has_function()` check, so builds against libcdio-paranoia older than 10.2+0.93+1, which
already read ahead 150 sectors, are unchanged.

Tested with Ubuntu 24.04's gvfs 1.54.4 and this patch, Totem reading through gvfsd-fuse,
an ASUS SDRW-08D2S-U USB drive, a 5:09 track played twice per build: 19 mid-track
underflows in each run without the patch, none with it. Copying the whole track took 29.8 s
before and 29.0 s after, and the audio was identical to a direct `cd-paranoia` read. On
master the patch builds without warnings, and the meson check finds the function.

Independent of the other cdda fix for #B: the two touch different code and apply in either
order.

---

## MR 2 — patch 2

**Title:** cdda: Refuse to open invalid and non-audio tracks

---

Fixes #B

Parse the track number strictly, and open only audio tracks between the disc's first and
last track numbers.

Tested with Ubuntu 24.04's gvfs 1.54.4 and both cdda patches, a 13-track disc in an ASUS
SDRW-08D2S-U USB drive, `gio cat 'cdda://sr0/Track%20N.wav'`:

- refused at once with "No such file": `Track -2`, `0`, `14`, `99`, `100`, `255`, `256`,
  `257`, `4294967297`, `1junk`, `+1`, `1.wav.wav`;
- read as before: `Track 1` to `13`; `Track 01` and `Track 0001` read track 1, `Track 0011`
  reads track 11;
- `gio info` refuses `Track 1junk.wav`; `gio list` is unchanged.

The bounds are the disc's first and last track numbers rather than the track count, because
a disc may number its tracks from above 1, and master reads such tracks. I checked this with
a test program that runs `do_open_for_read()` on a simulated drive (a fake libcdio driver)
under real libcdio 2.2.0 and libcdio-paranoia 10.2+2.0.2:
with tracks numbered 2 to 4, `Track 4.wav` reads all its audio to the end, as on master;
`Track 1.wav` and `Track 5.wav` are refused. With tracks 1 to 3 and track 3 a data track,
`Track 3.wav` is refused.

On master the patch builds without warnings.

Independent of the other cdda fix for #A: the two touch different code and apply in either
order.

---
