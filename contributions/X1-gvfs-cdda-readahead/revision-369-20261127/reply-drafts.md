# Reply drafts for !369 (for the operator to edit and post)

Reply to note 1 (CDIO_INVALID_TRACK for first_track):

> Done. The first track number is now checked against CDIO_INVALID_TRACK together with the last one. Before, an invalid first track was only refused indirectly (0xFF is above every valid track number), which was not obvious from the code.

Reply to note 2 (share the check with do_query_info()):

> Done. The check is now one helper, is_audio_track(), used by do_open_for_read() and do_query_info(). do_query_info() now refuses a track below the first or above the last track number, and a data track, with the existing "The file does not exist or isn’t an audio track" message. Its separate "File doesn’t exist" branch is gone; that string is still used by other backends.

Reply to note 3 (libcdio, not paranoia):

> You are right. The failure comes from libcdio's sector lookup. It now has its own string, "Error from “libcdio” on drive %s", with a translator comment. The "paranoia" string stays where it is, on the failed paranoia read in do_read().

Reply to note 4 (first track need not be 1):

> I went with supporting a first track other than 1, everywhere. MMC says "The first track number is not required to be one. A disc may start with any valid track number" (valid numbers 01h to 63h), libcdio takes the number from the TOC, and libcdio-paranoia indexes its tables by track number minus the first track. fetch_metadata() already starts the metadata list at the first track. A normal Red Book disc starts at 1 (ECMA-130 says so), so this is rare, and I have no such disc; I only found one report of an audio CD with tracks 4 to 6 (libcdio-devel, December 2018).
>
> do_enumerate() now lists the tracks from the first to the last track number, and set_info_for_track() looks the metadata up by the offset from the first track; before, it used track_num - 1. I could not test with a real disc. With a simulated drive on a disc numbered 2 to 4, master listed Track 2 and 3, refused Track 4 and gave Track 2 the title of track 3; now the listing is Track 2 to 4 and each track has its own title. A disc numbered 1 to 3 behaves as before.

Reply to note 5 (general):

> Thank you for the review.

Note for the force-push (3 lines):

> Force-pushed: the branch is rebased on current master (the cdio_paranoia_cachemodel_size() change is in) and the commit now also covers the four review notes.
> New: one is_audio_track() helper shared by open and query_info, an explicit check of the first track number, and a first track other than 1 supported in do_enumerate() and set_info_for_track().
> New string: "Error from “libcdio” on drive %s"; the commit message is updated to match.
