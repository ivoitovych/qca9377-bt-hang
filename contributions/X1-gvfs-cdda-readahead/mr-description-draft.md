# Draft: GNOME GitLab merge-request description (for the operator to edit and submit; not submitted)

Two open choices for the operator, on which reviewers differ:

- **One MR with two commits, or two MRs.** One MR is this project's habit for related cdda
  changes (Bastien Nocera's !279); two MRs let the maintainer take either alone and keep the
  backport question of the playback fix separate. Both patches apply alone and in either order
  (checked here and by a reviewer on master and gnome-50/49/47/46). Count so far: one MR, R6;
  two MRs (each with its own issue), R2 and R3 (2026-11-04, H8 in `REVIEW-ACTIONS.md`).
- **File a gvfs issue first, or not.** GNOME's handbook asks for one; in this project only a
  minority of merged contributor fixes reference one, and one reviewer advises against filing
  one only for form, since the Launchpad link and the commit bodies carry the problem. If an
  issue is filed (draft: `patch1-small/issue-draft.md`), add `Fixes: <full issue URL>` to the
  first commit.

---

**Title (one MR):** cdda: Fix playback stalls and refuse invalid tracks

**Description:**

Two independent fixes to the cdda backend; either can be taken alone.

The first removes the pause of about 3 seconds every 16 seconds when an audio CD is played
through gvfs (Totem opens `cdda://` tracks through gvfsd-fuse). libcdio-paranoia refills
1200 sectors at a time since 10.2+0.93+1 (2014), and the backend never shrank that for
playback the way GStreamer's cdparanoiasrc does. The Launchpad report linked in the commit
shows the player's sink underflowing at 0:20.9, 0:37.3, 0:52.8, 1:09.2 and 1:24.8, about
16 seconds apart.

The second stops `do_open_for_read()` from handing track numbers that enumerate never lists to
libcdio: before it, `gio cat` of a track that is not on the disc kept the drive busy for
minutes, and `Track 257.wav` opened track 1.

Tested on an ASUS SDRW-08D2S-U USB drive with Totem through gvfsd-fuse and with `gio cat`;
details are in each commit. Built with `--werror`, also with `-Dcdda=false`; the project's
CI job (run locally in its image) passes as on master. Both apply cleanly to gnome-49 and
gnome-50.
