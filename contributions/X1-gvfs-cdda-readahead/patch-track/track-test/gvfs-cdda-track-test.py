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
