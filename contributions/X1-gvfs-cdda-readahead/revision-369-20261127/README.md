# !369, revised for the maintainer's review of 2026-11-26 (prepared 2026-11-27)

The review is `../review-369-2026-11-26.md`: five notes, four asks. This directory holds the revision, its tests and
reply drafts. **Nothing is pushed or posted.** The force-push to the fork branch and the replies are the operator's.

## What changed

- **Ask 1:** a first or last track number of `CDIO_INVALID_TRACK` is refused explicitly. Before, an invalid first
  track was only refused indirectly, since 0xFF is above every valid number.
- **Ask 2:** one helper, `is_audio_track()`, used by `do_open_for_read()` and `do_query_info()`. `do_query_info()`
  now also refuses a track below the first track number. Its separate "File doesn’t exist" branch is gone; the
  string is still used by other backends.
- **Ask 3:** a new translatable string, "Error from “libcdio” on drive %s", with a translator comment. The
  "paranoia" string stays on the failed read in `do_read()`.
- **Ask 4:** the first track need not be 1.
  - `do_enumerate()` lists from the first to the last track number.
  - `set_info_for_track()` takes a track's metadata by its offset from the first track.

  Why this option and not the other: MMC (X3T10/1048D rev 11, READ DISC INFORMATION) says "The first track number
  is not required to be one. A disc may start with any valid track number". libcdio reads the number from the TOC,
  and libcdio-paranoia indexes by track minus first track. Dropping `first_track` from the check instead would refuse
  Track 4 on a disc numbered 2 to 4, where master opens it. Sources, each marked quoted, inferred or not found:
  `facts-ask4.md`. Discs numbered above 1 are rare: one report was found, an audio CD with tracks 4 to 6
  (libcdio-devel, 2018-12-09).

## Files

- `patches/squashed-0001-…patch`: the single commit for the force-push, on gvfs master `cb179822` (which includes
  !368); +61 −21 in `daemon/gvfsbackendcdda.c`; the commit message is updated for the four asks.
- `patches/revision-0001-…patch`: the same change as a commit on top of the posted patch (+38 −19), for reading what
  moved.
- `reply-drafts.md`: one reply per note and a three-line force-push note, to be edited by the operator.
- `tests/`, `results/`: the programs, the container scripts and their outputs; `SHA256SUMS`.

## Tested (2026-11-27, ubuntu:26.04 container, gcc 15.2.0, libcdio 2.2.0, libcdio-paranoia 10.2+2.0.2)

- **Build:** `--werror` with only the cdda backend enabled: 0 warnings (`results/compile.log`,
  `results/build-status.txt`).
- **Track opening:** the dossier's simulated-drive program, 18 cases, run on master, on the posted patch and on the
  revision (`results/run.log`).
  - The revision gives the same result as the posted patch in every case.
  - On a disc numbered 2 to 4, Track 4 reads in full.
  - Track 0, 99, 257, a data track, and a track outside the range are refused.
- **Listing and query_info:** a new test, 5 discs × 3 sources (`results/listing-results.tsv`).
  - Master and the posted patch fail the discs numbered 2 to 4, 5 to 7, and 2 to 4 with a data track 2. On 2 to 4
    they list only Track 2 and 3, and give Track 2 the title of track 3.
  - The revision passes all five discs.
  - `results/first-run-results.tsv` is a first run whose listing rows failed on harness bugs. It is kept as a
    record; the listing results above are the rerun.

**Not run:** a real disc numbered above 1 (none here; the laptop was not touched); `meson test`, which has no cdda
coverage; the 1.54.4 build and the gnome-46 to gnome-50 branches; gvfs's CI; the daemon itself.

## For the operator

1. Option 1 for ask 4 (support a first track above 1), or option 2 (drop `first_track`)? The drafts assume option 1.
2. Is merging `do_query_info()`'s two failure messages into one acceptable?
3. The force-push rebases the branch onto current master, which includes !368. The commit keeps the posted patch's
   author.
