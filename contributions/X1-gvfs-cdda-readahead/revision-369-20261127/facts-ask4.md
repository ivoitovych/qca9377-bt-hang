# Ask 4: can an audio CD's first track number be other than 1? (2026-11-27)

Marks: **Q** quoted from a primary source I read; **I** inferred; **N** not found.
Local copies of what was read: `src/` (ecma130.txt, mmc-r10a.txt, libcdio sources, gvfs master file).

| # | Claim | Mark | Source |
|---|---|---|---|
| 1 | ECMA-130 (2nd ed., June 1996), clause 22.3.3, item 1, TNO: "Track Numbers 01 to 99 shall be those of the Information Tracks in the User Data area. Consecutive Information Tracks shall be numbered consecutively. The first Information Track of the user Data area of a disk shall have Track Number 01." So on a plain Red Book disc the first track is 1. | Q | `src/ecma130.txt` lines 1017-1021 |
| 2 | ECMA-130 clause 22.3.4, item 2: in the lead-in TOC, POINTER A0 carries "the Track Number of the first Information Track in the User Data area", A1 the last; i.e. the TOC has a field for it. | Q | `src/ecma130.txt` lines 1079-1082 |
| 3 | MMC (X3T10/1048D rev 11, 26 April 1997), READ DISC INFORMATION: "The Number of First Track identifies the first track number in the TOC or PMA. Valid track numbers are from 01h to 63h. The first track number is not required to be one. A disc may start with any valid track number. The track numbers between the first and last track number shall be in contiguous ascending order, except for lead-out areas." | Q | `src/mmc-r10a.txt` lines 5113-5115 (url: users.utcluj.ro/~baruch/media/sie/labor/SCSI/MMC-R10A.PDF) |
| 4 | The same sentence is in the SCSI-2 CD-ROM command set (READ TOC, note 185): "The first track number is not required to be one." | Q (via page fetch) | staff.uni-mainz.de/tacke/scsi/SCSI2-14.html; Pioneer SCSI-2 manual, implementors note |
| 5 | MMC READ TOC format 0: "The First Track Number field indicates the first track number in the first complete session Table of Contents. The Last Track Number field indicates the last track number in the last complete session Table of Contents before the lead-out." | Q | `src/mmc-r10a.txt` lines 3192-3194 |
| 6 | So the standards disagree in strictness: the disc format says 01 for the first track of the user data area; the drive command set allows any 01h-63h. Which discs make the drive report more than 1 (multisession tails, non-Red-Book writers) is not settled by them. | I | 1-5 |
| 7 | libcdio: `cdio_get_first_track_num()` returns the first track number from the driver or `CDIO_INVALID_TRACK` (0xFF) if the driver has none or the argument is NULL; `cdio_get_last_track_num()` is `first + number_of_tracks - 1`, or `CDIO_INVALID_TRACK`. | Q | libcdio master `lib/driver/track.c` lines 42-83 (`src/libcdio/track.c`) |
| 8 | libcdio, Linux driver: the first track is taken from the kernel's TOC header (`CDROMREADTOCHDR`, `cdth_trk0`), not assumed to be 1; tracks are stored at `tocent[i - i_first_track]`. | Q | `lib/driver/gnu_linux.c` lines 1175-1197, 597-637 (`src/libcdio/gnu_linux.c`) |
| 9 | libcdio constants: `CDIO_CD_MIN_TRACK_NO` 1, `CDIO_CD_MAX_TRACKS` 99, `CDIO_INVALID_TRACK` 0xFF. | Q | `include/cdio/track.h` lines 77-83 |
| 10 | libcdio-paranoia (the cdparanoia interface gvfs uses) indexes by real track numbers: `cdda_track_firstsector()` and `cdda_track_lastsector()` use `disc_toc[track - first_track]` and return -401 outside first..last (plus the lead-out for the first sector); `cdda_open` fills `disc_toc[i]` for `i < tracks` starting at `cdio_get_first_track_num()`. `d->tracks` is a count, not a last number. | Q | `cache/libcdio-paranoia/lib/cdda_interface/toc.c` lines 34-128, `cddap_interface.c` lines 41-58 (main checkout, read-only) |
| 11 | Real disc: an audio CD whose TOC runs from track 4 to 6 ("first: 4 last 6"), listed by cdrskin and by cd-paranoia ("audio tracks only", tracks 4, 5, 6). cd-paranoia's `display_toc()` looped from track 1 to the track count and printed wrong starts for tracks 5 and 6: the same class of bug as gvfs's. Thomas Schmitt, libcdio-devel, 2018-12-09, "Re: CD_MSF_FORMAT vs LBA on NetBSD". Whether the disc is a test disc written on purpose: not stated. | Q (via page fetch, paraphrased there) | lists.gnu.org/archive/html/libcdio-devel/2018-12/msg00015.html |
| 12 | Mixed-mode discs (data track first) start at track 1 (the data track); the first *audio* track is then 2. Sound Juicer bug 768596 (Bastien Nocera, 2016-07-08): "Yes, it's pretty weird that the 1st audio track is numbered as "2"." This is not a first track above 1; gvfs already handles it by skipping non-audio tracks. | Q | bugzilla.gnome.org/show_bug.cgi?id=768596 |
| 13 | MusicBrainz disc ID: first track number is an input, "normally one"; docs name multisession discs that report a different range. | Q (search-result excerpt only, page not opened) | MusicBrainz "Disc ID Calculation" (mirror seen: music.kde.cs.tsukuba.ac.jp/doc/Disc_ID_Calculation) |
| 14 | A commercial or ordinary single-session audio CD whose first track is above 1: | N | none found in web search (libcdio, cdparanoia, abcde, MusicBrainz, GNOME bugs) |
| 15 | Hidden-track discs (audio in the pregap of track 1) keep first track 1; cdparanoia shows track 1's start sector at e.g. 4575, not 0. | Q | paranoia list, 2001-05-21 (lists.xiph.org/pipermail/paranoia/2001-May/000587.html) |
| 16 | CD-Extra / enhanced CDs: the data session follows the audio session, so audio tracks keep 1..N (libcdio-paranoia has `cd_extra` handling that clips the last audio track). Not a first-track-above-1 case. | I | `toc.c` lines 117-123 |

Conclusion: a first track above 1 is allowed by the drive-level standards and handled by libcdio and libcdio-paranoia everywhere, is forbidden for a plain Red Book disc by ECMA-130, and has one real-world sighting (tracks 4 to 6, 2018, not a shipped disc as far as I can tell). A disc that does this is rare, not impossible.

# gvfs master: places that assume tracks start at 1 (daemon/gvfsbackendcdda.c, master cb179822 plus !369 as posted)

Line numbers of master before the revision (GitHub clone 2026-11-27).

1. `do_enumerate()`: `for (n = 1; n <= drive->tracks; n++)` and `Track %d.wav` with `n`: lists 1..count, not first..last.
2. `set_info_for_track()`: `g_list_nth_data (cdda_backend->tracks, track_num - 1)`: metadata list is built from the first track (`fetch_metadata()`, `cdtrack = cdio_get_first_track_num()` ... `last_cdtrack = cdtrack + num_tracks`), so for first = 2 the title of track 3 would come from track 4's entry.
3. `do_query_info()`: `track_num > drive->tracks` compares a number with a count (refuses Track 4 on a 2-4 disc).
4. `do_open_for_read()` on master before !369: no check at all (opens whatever libcdio takes); !369 as posted uses first/last correctly.
5. `get_track_num_from_name()`: minimum 1 (our !369 parser); equals the standards' minimum 01h, no change needed.
6. `fetch_metadata()` is already first-track aware, except `cdtrack != last_cdtrack - 1` (correct for any first).
7. Not affected: `do_read()`, `do_seek_on_read()`, `create_header()` (sectors only).
