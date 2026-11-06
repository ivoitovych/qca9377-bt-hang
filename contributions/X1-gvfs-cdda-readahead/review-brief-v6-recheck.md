# Recheck before submission: gvfs cdda patches, v6

**Review target: the two patch files at repository commit
`b94997130c3ac27a53e736244571176858a637ef`** (byte-identical at every later commit that carries
this brief). Both apply to gvfs master `2d30ce9b73babfd5e6ca6762ac3af46c1b092337` (still master
on 2026-11-07), alone and in either order. Please review the files, not a chat copy: one removed
master line ends in a space, which pastes lose.

| Patch | File | SHA-256 |
|---|---|---|
| 1, "cdda: Limit paranoia read-ahead to avoid playback stalls" | [raw](https://github.com/ivoitovych/qca9377-bt-hang/raw/b94997130c3ac27a53e736244571176858a637ef/contributions/X1-gvfs-cdda-readahead/patch1-small/0001-cdda-Limit-paranoia-read-ahead-to-avoid-playback-sta.patch) | `1ed683bc7f55b0d646a8dc1748ed0197cc8c928a87c4ce4838bdd460cfba0a5a` |
| 2, "cdda: Refuse to open invalid and non-audio tracks" | [raw](https://github.com/ivoitovych/qca9377-bt-hang/raw/b94997130c3ac27a53e736244571176858a637ef/contributions/X1-gvfs-cdda-readahead/patch-track/0001-cdda-Refuse-to-open-invalid-and-non-audio-tracks.patch) | `120786957f2fa84530b0476ddcaede5f0c786e072164859752c210b76ef94044` |

Previous version, reviewed at `a42b08114a5b77dbf9ab1471970a4b70d13d9d66`. The record of every
point and what was done with it: `REVIEW-ACTIONS.md`, H26–H38.

They will be submitted as **two merge requests, one commit and one issue each**.

## What changed since a42b081

**Patch 2, code: the open check.** v5.3 compared the track number with `drive->tracks`, which
is a count. A disc may number its tracks from above 1, so v5.3 refused the last tracks of such a
disc, which master opens directly and reads correctly. v6 bounds the number by the disc's real
first and last track numbers, the same ones libcdio-paranoia's lookups use (`toc.c:40-60`,
`:98-127`):

```c
  track_num = get_track_num_from_name (job->filename);
  first_track = cdio_get_first_track_num (cdda_backend->drive->p_cdio);
  last_track = cdio_get_last_track_num (cdda_backend->drive->p_cdio);

  /* Only audio tracks on the disc can be opened */
  if (track_num == -1 || last_track == CDIO_INVALID_TRACK ||
      track_num < first_track || track_num > last_track ||
      !cdio_cddap_track_audiop (cdda_backend->drive, track_num))
```

- `cdio_get_last_track_num()` returns `CDIO_INVALID_TRACK` whenever the first track number or the
  count is invalid, so that one test covers both (libcdio `lib/driver/track.c`, 2.2.0 `:67-80`,
  0.78.2 `:60-71`).
- The range is checked before `audiop()`, so libcdio's format lookup never sees a number outside
  the disc (one reviewer noted that its Linux driver accepts `last + 1`).
- The parser, the sector guard and the leak fixes are unchanged from v5.3.
- Enumerate and query_info still assume 1..N, as on master. On a disc that starts above 1 they
  keep their existing limitation, which is out of scope for this patch; open no longer adds a
  new one.
- libcdio 0.78.2, gvfs's minimum, declares `p_cdio`, both functions and `CDIO_INVALID_TRACK`.

**Both messages, wording only.**
- Patch 1: deleted the sentence about the wait after open or seek. The 150-sector history now
  sits next to the build note. `See:` is kept, because the maintainer writes `See:` for
  references (`e0961eb`, `f1bc25c`).
- Patch 2: rewritten in six short paragraphs: the failures, the cause, the parser, the open
  checks, the leaks, the result. The list of tested names moves to the MR description.

Patch 1's code is unchanged (tree `29fc5683`).

## Evidence for v6

| Check | Result |
|---|---|
| Shifted-TOC harness (a reviewer's, plus variants), real libcdio 2.2.0 and libcdio-paranoia 10.2+2.0.2, ubuntu:26.04, gcc 15.2.0 | TOC 2–4, open 4; TOC 97–99, open 99: master and v6 read every expected PCM byte to EOF, v5.3 refuses. TOC 2–4, open 1 or 5: v5.3 and v6 refuse, master opens a wrong range. TOC 1–3 with track 3 a data track: v5.3 and v6 refuse, master does not (the run times out). TOC 1–3, open 3: all three read |
| gvfs master + patch 2, compile with `--werror` | 0 warnings |
| gvfs master + both, compile | 0 warnings; meson probe YES |
| gvfs `fedora-test` CI job, run locally in its image | all 6 steps as master |
| Apply | each alone and in either order (same resulting file); also gnome-46, -47, -49, -50 |
| Laptop: Ubuntu 1.54.4 + both v6 patches, 13-track disc, ASUS SDRW-08D2S-U | -2, 0, 14, 99, 100, 255, 256, 257, 4294967297, 1junk, +1, 1.wav.wav refused at once with "No such file"; Track 1 to 13, 01, 0001, 0011 read; first MiB: 01 and 0001 equal 1, 0011 equals 11, all hashes as with v5.3; `gio info` refuses 1junk; listing unchanged (Track 1–13) |

Not tested: a physical disc numbered from above 1 (no such disc here; covered by the harness only),
a physical mixed-mode disc.

## Questions

1. Is the v6 open check correct, including the `CDIO_INVALID_TRACK` handling and the order of
   the tests?
2. Does any sentence of either message overclaim, or read harder than it needs to for a
   maintainer reading quickly?
3. Ready to submit: yes or no?
