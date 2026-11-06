# Final review before submission: two gvfs cdda patches

Both apply to gvfs master `2d30ce9b73babfd5e6ca6762ac3af46c1b092337` (still master on
2026-11-06), alone and in either order. Please review the files, not a chat copy: one removed
master line ends in a space, which pastes lose.

- Patch 1, "cdda: Limit paranoia read-ahead to avoid playback stalls":
  https://github.com/ivoitovych/qca9377-bt-hang/raw/f3e53c7/contributions/X1-gvfs-cdda-readahead/patch1-small/0001-cdda-Limit-paranoia-read-ahead-to-avoid-playback-sta.patch
- Patch 2, "cdda: Refuse to open invalid and non-audio tracks":
  https://github.com/ivoitovych/qca9377-bt-hang/raw/f3e53c7/contributions/X1-gvfs-cdda-readahead/patch-track/0001-cdda-Refuse-to-open-invalid-and-non-audio-tracks.patch

## What changed since you last saw them

**Patch 1** (code unchanged since the version you reviewed, except the build check):
- `has_function('cdio_paranoia_cachemodel_size', prefix: '#include <cdio/paranoia/paranoia.h>', …)`.
  The setter exists only in libcdio-paranoia ≥ 10.2+0.93+1, which installs that header; a
  library without it keeps its 150-sector read-ahead, and the probe can only fail closed.
- Message: the first read after opening or seeking waits for the refill (open itself does not
  read); "has used a 1200-sector cache model since 10.2+0.93+1 (2014)".

**Patch 2** (the parser was replaced):
- The previous fix, `"Track %3d.wav"`, had a regression: `Track 0011.wav` read `001` and opened
  track 1 (master: 11), and `Track 0001.wav` was refused. Two reviewers found it; confirmed.
- The parser is now `g_ascii_string_to_unsigned (number, 10, 1, CDIO_CD_MAX_TRACKS, &n, NULL)` on
  the text between `"Track "` and `".wav"`: no overflow, no signs, no trailing characters, leading
  zeros kept. query_info shares the parser, so names such as `Track 1junk.wav` (which master
  treated as track 1) now fail there too; the message says so.
- Open still accepts exactly what enumerate lists: audio tracks `1..drive->tracks`.
- The sector-range guard after those checks is kept. libcdio-paranoia's lookups read only the TOC
  in memory, so it fires only for a drive that is not open (−400) or an inconsistent TOC.
- The open failure path calls `g_vfs_job_failed()` directly (no GError leak); the parser frees
  `basename` on every path.

## Evidence

| Check | Patch 1 | Patch 2 |
|---|---|---|
| gvfs master, compile `--werror` | 0 warnings | 0 warnings |
| gvfs `fedora-test` CI job, run locally in its image | all 6 steps as master | all 6 steps as master |
| `-Dcdda=false` | builds | — |
| Probe result / binary | "YES"; imports `cdio_paranoia_cachemodel_size` | — |
| Parser alone, 29 names (`-Wall -Wextra -Werror`; ASan + UBSan + leak check) | — | 0 failed |
| Laptop: Ubuntu 1.54.4 + both patches, 13-track disc, ASUS SDRW-08D2S-U | playback: 19 → 0 mid-track underflows per 5:09 run (2 runs each); copy 29.8 → 29.0 s; PCM = cd-paranoia | -2, 0, 14, 99, 100, 255, 256, 257, 4294967297, 1junk, +1, 1.wav.wav refused at once; 1, 01, 0001, 11, 0011, 13 read; whole files to EOF: 0011 byte-identical to 11, 01 and 0001 to 1; `gio info` refuses 1junk; the listing is unchanged |

Not tested: a mixed-mode disc (no such disc here; the audio check is the one enumerate and
query_info already use), a non-1-based TOC, a CDDA build against a pre-2014 libcdio-paranoia
with the real probe (one earlier review built against 10.2+0.90 with the define forced off).

## Considered and not taken

- **libcdio's first/last track numbers instead of `drive->tracks`**: true of the library, but
  enumerate, query_info and the metadata index all assume `1..N`; changing open alone would
  accept tracks nothing lists. A first track above 1 is a separate, backend-wide issue. The
  reviewer who proposed it withdrew it.
- **A strict parser accepting only the names enumerate emits**: v5 rejects malformed names but
  keeps leading-zero aliases, so no working name changes meaning.
- **Out of scope:** the same GError leak in `do_query_info` (three sites, pre-existing); a
  failed seek is not treated as a read error (separate bug).

## Questions

1. Any remaining correctness problem in either patch?
2. Is either commit message unclear or overclaiming anywhere, for a maintainer reading quickly?
3. Submission shape: two MRs (one commit each, an issue each), or one MR with two commits?
   Two other reviewers favour two MRs; an earlier review cited the project's habit of one.
4. Ready to submit: yes or no?
