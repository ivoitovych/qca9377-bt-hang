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

MR 2's test program is byte-identical to `patch-track/track-test/gvfs-cdda-track-test.py`
(SHA-256 `3e52485addf56cc80d9cee923d79de84dc6f1b361b54dc9da56b4ab0f7b6e520`). Its table comes
from `patch-track/track-test/run-track-test.sh` (ubuntu:26.04, gcc 15.2.0, glib 2.88.0,
libcdio 2.2.0 with its source, libcdio-paranoia 10.2+2.0.2), run on master `2d30ce9b` and on
patch 2 (`05428d9`): `results.tsv` and `run.log` beside it.

Patch files at `3e6b7d7`: patch 1 `patch1-small/0001-cdda-Limit-paranoia-read-ahead-to-avoid-playback-sta.patch`,
patch 2 `patch-track/0001-cdda-Refuse-to-open-invalid-and-non-audio-tracks.patch`.

## Issue A — playback stall

**Title:** cdda: Audio CD playback stops for about 3 seconds every 16 seconds

---

Playing an audio CD track in Totem stops for about 3 seconds every 16 seconds. PipeWire
logs an underflow of the player's stream at each stop.

Steps to reproduce:

1. Insert an audio CD into a USB optical drive.
2. Open a track in Totem: `totem 'cdda://sr0/Track%201.wav'` (the device name may differ).
   Totem opens it through gvfsd-fuse, as `/run/user/1000/gvfs/cdda:host=sr0/Track 1.wav`
   here, so gvfsd-cdda serves the reads.
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
a disc may number its tracks from above 1, and master reads such tracks. The attached test
program checks this. It compiles the backend's own code, from `get_track_num_from_name()` to
`do_seek_on_read()`, against a fake libcdio driver, opens one track of a simulated
three-track disc and reads it to the end. With libcdio 2.2.0 and libcdio-paranoia
10.2+2.0.2:

| Disc | Opened | master | this patch |
|---|---|---|---|
| tracks 2–4 | Track 4.wav | reads | reads |
| tracks 97–99 | Track 99.wav | reads | reads |
| tracks 2–4 | Track 1.wav | opens sectors -401 to -401 | refused |
| tracks 2–4 | Track 5.wav | opens sectors 4500 to -401 | refused |
| tracks 1–3 | Track 3.wav | reads | reads |
| tracks 1–3, track 3 data | Track 3.wav | opens it | refused |
| tracks 1–3, track 3 data | Track 2.wav | reads | reads |

"reads": all 3,528,000 bytes of the track's audio as expected, then end of file.

On master the patch builds without warnings. It also applies cleanly to gnome-46, -47, -49
and -50.

Test program: [gvfs-cdda-track-test.py](UPLOAD). Run it from a gvfs checkout, with an
unpacked libcdio source tree of the installed version, for example
`python3 gvfs-cdda-track-test.py daemon/gvfsbackendcdda.c ../libcdio-2.2.0 2 4` (tracks 2 to
4, open Track 4.wav); `--data 3` makes track 3 a data track.

Independent of !M1 (#A): either can be merged alone, and they apply in either order.

---

## Attachment to MR 2: gvfs-cdda-track-test.py

Uploaded as a file into MR 2's description, where GitLab replaces `(UPLOAD)` with its
`/uploads/…` link. Not pasted into the description: GitLab mails the description to
subscribers, and email does not collapse a long block. Shown here so that the package
reviews as one document.

```python
#!/usr/bin/env python3
"""Open one track of a simulated audio CD with the cdda backend's own code.

Usage: gvfs-cdda-track-test.py BACKEND_C LIBCDIO_SRC FIRST TRACK [--data N]

The simulated disc has three tracks numbered FIRST, FIRST+1 and FIRST+2, 1500 sectors
each; with --data N, track N is a data track. The program compiles the backend's code
from get_track_num_from_name() up to do_seek_on_read(), taken unchanged from BACKEND_C
(daemon/gvfsbackendcdda.c), against a fake libcdio driver, opens "Track TRACK.wav" and,
if it opens, reads it to the end.

Exit 0: an audio track on the disc opened and read with the expected PCM, then EOF.
Exit 1: the open was refused.
Exit 2: a track that is not an audio track on the disc opened, or the wrong sectors did.
A failed assertion means that a read returned the wrong data.

Needs a C compiler, pkg-config and the gio-2.0, libcdio and libcdio_paranoia development
files. LIBCDIO_SRC is an unpacked libcdio source tree of the installed version: the fake
driver fills libcdio's private driver struct (lib/driver/cdio_private.h). Tested with
libcdio 2.2.0. No disc, daemon, privilege or network is needed.
"""
import argparse
from pathlib import Path
import shlex
import subprocess
import tempfile

PREAMBLE = r"""
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gio/gio.h>
#include <cdio/version.h>
#define DO_NOT_WANT_PARANOIA_COMPATIBILITY
#include <cdio/paranoia/paranoia.h>
#include "cdio_private.h"

/* Stand-ins for the daemon types; job results are recorded instead of sent over D-Bus. */
typedef struct {
  cdrom_drive_t *drive;
  int num_open_files;
  const char *device_path;
} GVfsBackendCdda;
typedef GVfsBackendCdda GVfsBackend;
typedef struct {
  const char *filename;
  int error;
  gsize bytes;
  void *handle;
} GVfsJobOpenForRead;
typedef GVfsJobOpenForRead GVfsJobRead;
typedef void *GVfsBackendHandle;
#define G_VFS_BACKEND_CDDA(x) (x)
#define G_VFS_JOB(x) (x)
#define _(x) (x)
#define g_vfs_job_failed(j,domain,code,...) ((j)->error=(code))
#define g_vfs_job_failed_from_error(j,e) ((j)->error=(e)->code, g_error_free(e))
#define g_vfs_job_succeeded(j) ((void)0)
#define g_vfs_job_open_for_read_set_can_seek(j,v) ((void)0)
#define g_vfs_job_open_for_read_set_handle(j,v) ((j)->handle=(v))
#define g_vfs_job_read_set_size(j,n) ((j)->bytes=(n))
"""

FIXTURE = r"""
enum { track_count = 3, sectors_per_track = 1500 };

static track_t first(void *unused) { return FIRST_TRACK; }
static track_t count(void *unused) { return track_count; }

static track_format_t format(void *unused, track_t track)
{
  if (track >= FIRST_TRACK && track < FIRST_TRACK + track_count)
    return track == DATA_TRACK ? TRACK_FORMAT_DATA : TRACK_FORMAT_AUDIO;
  return TRACK_FORMAT_ERROR;
}

static lba_t start_lba(void *unused, track_t track)
{
  if (track == CDIO_CDROM_LEADOUT_TRACK)
    track = FIRST_TRACK + track_count;
  return cdio_lsn_to_lba((track - FIRST_TRACK) * sectors_per_track);
}

/* Every byte of sector s is s % 251, so a read from the wrong place shows. */
static long read_audio(cdrom_drive_t *drive, void *dest, lsn_t sector, long count)
{
  /* A timed cache-management read can use a null data pointer. */
  if (dest != NULL)
    for (long i = 0; i < count; i++)
      memset((char *)dest + i * CDIO_CD_FRAMESIZE_RAW,
             (sector + i) % 251, CDIO_CD_FRAMESIZE_RAW);
  return count;
}

int main(void)
{
  CdIo_t io = { .op = { .get_first_track_num = first, .get_num_tracks = count,
                        .get_track_lba = start_lba, .get_track_format = format } };
  cdrom_drive_t drive = { .p_cdio = &io, .opened = 1, .tracks = track_count,
                          .nsectors = 16, .read_audio = read_audio };
  GVfsBackendCdda backend = { .drive = &drive, .device_path = "fixture" };
  char name[32];
  unsigned char buffer[CDIO_CD_FRAMESIZE_RAW];
  int on_disc = OPEN_TRACK >= FIRST_TRACK && OPEN_TRACK < FIRST_TRACK + track_count &&
                OPEN_TRACK != DATA_TRACK;
  long want_first = (OPEN_TRACK - FIRST_TRACK) * sectors_per_track;
  long want_last = want_first + sectors_per_track - 1;

  for (int i = 0; i <= track_count; i++) {
    drive.disc_toc[i].bTrack = FIRST_TRACK + i;
    drive.disc_toc[i].dwStartSector = i * sectors_per_track;
  }
  snprintf(name, sizeof(name), "/Track %d.wav", OPEN_TRACK);
  GVfsJobOpenForRead job = { .filename = name, .error = -1 };

  printf("disc: tracks %d to %d%s\n", FIRST_TRACK, FIRST_TRACK + track_count - 1,
         DATA_TRACK ? ", one of them a data track" : "");
  do_open_for_read(&backend, &job, job.filename);
  if (job.handle == NULL) {
    printf("%s: open refused (%s)\n", name + 1,
           job.error == G_IO_ERROR_NOT_FOUND ? "not found" : "other error");
    return 1;
  }

  ReadHandle *h = job.handle;
  if (!on_disc || h->first_sector != want_first || h->last_sector != want_last) {
    printf("%s: opened sectors %ld to %ld, %s\n", name + 1, h->first_sector,
           h->last_sector, on_disc ? "the wrong ones" : "but it is not an audio track on the disc");
    free_read_handle(h);
    return 2;
  }
  do_read(&backend, &job, h, (char *)buffer, sizeof(buffer));
  assert(job.bytes == (gsize)h->header_size && memcmp(buffer, "RIFF", 4) == 0);
  for (long sector = want_first; sector <= want_last; sector++) {
    do_read(&backend, &job, h, (char *)buffer, sizeof(buffer));
    assert(job.error == -1 && job.bytes == sizeof(buffer));
    for (size_t i = 0; i < sizeof(buffer); i++)
      assert(buffer[i] == sector % 251);
  }
  do_read(&backend, &job, h, (char *)buffer, sizeof(buffer));
  assert(job.error == -1 && job.bytes == 0);
  free_read_handle(h);
  printf("%s: read all %ld PCM bytes, then EOF\n", name + 1,
         (long)sectors_per_track * CDIO_CD_FRAMESIZE_RAW);
  return 0;
}
"""


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("backend", type=Path)
    parser.add_argument("libcdio_source", type=Path)
    parser.add_argument("first", type=int)
    parser.add_argument("track", type=int)
    parser.add_argument("--data", type=int, default=0)
    args = parser.parse_args()

    source = args.backend.read_text()
    start = source.index("static int\nget_track_num_from_name")
    end = source.index("static void\ndo_seek_on_read", start)
    flags = shlex.split(subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "gio-2.0", "libcdio_paranoia"], text=True))
    lib = args.libcdio_source.resolve()
    with tempfile.TemporaryDirectory() as directory:
        harness = Path(directory) / "test.c"
        binary = Path(directory) / "test"
        harness.write_text(PREAMBLE + source[start:end] + FIXTURE)
        subprocess.run(
            ["cc", "-std=gnu11", "-DHAVE_STRNDUP",
             f"-DFIRST_TRACK={args.first}", f"-DOPEN_TRACK={args.track}",
             f"-DDATA_TRACK={args.data}", "-I" + str(lib / "lib/driver"), str(harness),
             *flags, "-I" + str(lib / "include"), "-o", str(binary)],
            check=True)
        return subprocess.run([str(binary)], timeout=15).returncode


if __name__ == "__main__":
    raise SystemExit(main())
```
