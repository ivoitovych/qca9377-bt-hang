#!/usr/bin/env python3
"""List and describe the tracks of a simulated audio CD with the cdda backend's own code.

Usage: gvfs-cdda-listing-test.py BACKEND_C LIBCDIO_SRC FIRST [--data N]

Same fake drive as gvfs-cdda-track-test.py (three tracks numbered FIRST to FIRST+2;
with --data N, track N is a data track). The program compiles the backend's code from
get_track_num_from_name() up to do_seek_on_read() and from set_info_for_track() up to
do_query_fs_info(), taken unchanged from BACKEND_C, then
  - runs do_enumerate() and prints the names and sizes it lists,
  - runs do_query_info() for "Track 0.wav" to "Track <FIRST+4>.wav" and prints the result
    and the title it attaches (the metadata list holds "Title <n>" for track n).
Exit 0: the listing is exactly the audio tracks FIRST..FIRST+2, every listed track and no
other can be queried, and each carries its own title. Exit 1: anything else.
"""
import argparse
import importlib.util
from pathlib import Path
import shlex
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("track_test", HERE / "gvfs-cdda-track-test.py")
track_test = importlib.util.module_from_spec(spec)
spec.loader.exec_module(track_test)

PREAMBLE = track_test.PREAMBLE.replace(
    "  const char *device_path;\n} GVfsBackendCdda;",
    "  const char *device_path;\n  char *album_title, *album_artist, *genre;\n  GList *tracks;\n"
    "} GVfsBackendCdda;") + r"""
typedef struct { char *artist; char *title; int duration; } GVfsBackendCddaTrack;
typedef struct { const char *filename; int error; } GVfsJobQueryInfo;
typedef struct { int error; GList *infos; } GVfsJobEnumerate;
/* do_enumerate() frees the infos after adding them, so record name and size here */
static char listed_name[100][32];
static long listed_size[100];
static int listed_count;
static void record_infos (GList *l)
{
  for (; l; l = l->next, listed_count++) {
    g_strlcpy (listed_name[listed_count], g_file_info_get_name (l->data), 32);
    listed_size[listed_count] = g_file_info_get_size (l->data);
  }
}
#define g_vfs_job_enumerate_add_infos(j,l) record_infos (l)
#define g_vfs_job_enumerate_done(j) ((void)0)
"""

# The fake drive's helper functions, from the track test (everything before main()).
FIXTURE_HEAD = track_test.FIXTURE[:track_test.FIXTURE.index("int main(void)")]

MAIN = r"""
int main(void)
{
  CdIo_t io = { .op = { .get_first_track_num = first, .get_num_tracks = count,
                        .get_track_lba = start_lba, .get_track_format = format } };
  cdrom_drive_t drive = { .p_cdio = &io, .opened = 1, .tracks = track_count,
                          .nsectors = 16, .read_audio = read_audio };
  GVfsBackendCdda backend = { .drive = &drive, .device_path = "fixture" };
  int failures = 0;

  for (int i = 0; i <= track_count; i++) {
    drive.disc_toc[i].bTrack = FIRST_TRACK + i;
    drive.disc_toc[i].dwStartSector = i * sectors_per_track;
  }
  for (int i = 0; i < track_count; i++) {
    GVfsBackendCddaTrack *t = g_new0 (GVfsBackendCddaTrack, 1);
    t->title = g_strdup_printf ("Title %d", FIRST_TRACK + i);
    backend.tracks = g_list_append (backend.tracks, t);
  }
  printf("disc: tracks %d to %d%s\n", FIRST_TRACK, FIRST_TRACK + track_count - 1,
         DATA_TRACK ? ", one of them a data track" : "");

  GVfsJobEnumerate ejob = { .error = -1 };
  char listed[16] = { 0 };
  do_enumerate(&backend, &ejob, "/", NULL, 0);
  for (int i = 0; i < listed_count; i++) {
    int n = 0;
    sscanf(listed_name[i], "Track %d.wav", &n);
    printf("listed: %s (%ld bytes)\n", listed_name[i], listed_size[i]);
    if (n >= 0 && n < 16) listed[n] = 1;
  }

  for (int n = 0; n <= FIRST_TRACK + track_count + 1; n++) {
    char name[32];
    snprintf(name, sizeof(name), "/Track %d.wav", n);
    GFileInfo *info = g_file_info_new();
    GVfsJobQueryInfo qjob = { .filename = name, .error = -1 };
    do_query_info(&backend, &qjob, name, 0, info, NULL);
    int exists = n >= FIRST_TRACK && n < FIRST_TRACK + track_count && n != DATA_TRACK;
    int ok = qjob.error == -1;
    const char *title = ok ? g_file_info_get_attribute_string(info, "xattr::org.gnome.audio.title") : NULL;
    char want[32];
    snprintf(want, sizeof(want), "Title %d", n);
    int good = (ok == exists) && (listed[n] ? 1 : 0) == exists &&
               (!ok || (title != NULL && strcmp(title, want) == 0));
    printf("query_info Track %d.wav: %s%s%s%s\n", n, ok ? "ok" : "refused",
           ok ? ", title " : "", title ? title : "", good ? "" : "  <-- UNEXPECTED");
    if (!good) failures++;
    g_object_unref(info);
  }
  printf(failures ? "FAIL: %d unexpected\n" : "PASS: listing and query_info agree\n", failures);
  return failures ? 1 : 0;
}
"""


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("backend", type=Path)
    parser.add_argument("libcdio_source", type=Path)
    parser.add_argument("first", type=int)
    parser.add_argument("--data", type=int, default=0)
    args = parser.parse_args()

    source = args.backend.read_text()
    start = source.index("static int\nget_track_num_from_name")
    end = source.index("static void\ndo_seek_on_read", start)
    start2 = source.index("static void\nset_info_for_track")
    end2 = source.index("static void\ndo_query_fs_info", start2)
    flags = shlex.split(subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "gio-2.0", "libcdio_paranoia"], text=True))
    lib = args.libcdio_source.resolve()
    with tempfile.TemporaryDirectory() as directory:
        harness = Path(directory) / "test.c"
        binary = Path(directory) / "test"
        harness.write_text(PREAMBLE + source[start:end] + source[start2:end2] +
                           FIXTURE_HEAD + MAIN)
        subprocess.run(
            ["cc", "-std=gnu11", "-DHAVE_STRNDUP", "-Wno-unused-function",
             f"-DFIRST_TRACK={args.first}", "-DOPEN_TRACK=0",
             f"-DDATA_TRACK={args.data}", "-I" + str(lib / "lib/driver"), str(harness),
             *flags, "-I" + str(lib / "include"), "-o", str(binary)],
            check=True)
        return subprocess.run([str(binary)], timeout=15).returncode


if __name__ == "__main__":
    raise SystemExit(main())
