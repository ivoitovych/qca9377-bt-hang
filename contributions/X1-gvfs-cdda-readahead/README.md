# X1 — gvfs cdda: read ahead so that audio-CD playback does not stall (off-topic)

**The defect** (issue X1, `evidence/off-topic/X1-cd-playback-underflow-every-16s.md`): an audio
CD played in Totem through GNOME's CD backend stops for about 3 s every 16 s. `gvfsd-cdda`
answers each client read with a synchronous `cdio_paranoia_read()`; when paranoia's cache of
`CACHEMODEL_SECTORS` = 1200 sectors (16.0 s of audio) is used up, that call reads the next 1200
sectors before returning (~3 s on the laptop's USB drive, spinning up after 13 s idle), and the
player, pulling without read-ahead, runs dry. Measured: 11 of 11 underflows at the refill bursts.
Upstream gvfs master (`2d30ce9b`, 1.62.1) has the same read path; no report found on
gitlab.gnome.org (issue search "cdda", 2026-11-02).

**The fix (draft, 2026-11-02, not sent):** `gvfs-cdda-readahead-draft.diff`, one file,
`daemon/gvfsbackendcdda.c`, +148 −22, on gvfs master `2d30ce9b73ba`:
- a worker thread per open track owns the paranoia handle and keeps up to 10 s of the sectors
  following the one the client wants in a ring (`RA_SECTORS` = 750, ~1.7 MB per open file);
- `do_read()` copies from the ring and only waits at the start or after a seek;
- a seek outside the ring restarts the worker there; a read error reaches the client with the
  existing "Error from “paranoia”" message, and a failed sector is retried on the next read, as
  before; close stops and joins the worker before freeing paranoia;
- the worker starts on the first audio read, so browsing or reading metadata does not spin the
  disc.
Commit message draft: `commit-msg-draft.txt`.

**Built (2026-11-02), only `gvfsd-cdda`, with every other backend off** (`build/`):
- gvfs master + patch, Ubuntu 26.04 container, gcc 15.2.0: compiles and links, 0 warnings;
- upstream tag 1.54.4 + patch, Ubuntu 24.04 container: applies with offset −16, 0 warnings;
- Ubuntu's source `1.54.4-0ubuntu1~24.04.4` + patch (`build/build-ubuntu-src.sh`): 0 warnings;
  test copy with RUNPATH `/usr/lib/x86_64-linux-gnu/gvfs` (as the installed binary) resolves
  every library against the installed ones. SHA-256 of the test copy `07426241…0a7` (local:
  `tmp/cd-gaps/build/out-ubuntu/gvfsd-cdda.test`); installed `/usr/libexec/gvfsd-cdda`
  `2710b35c…796`.

**Not done:** the test on the laptop (swap `/usr/libexec/gvfsd-cdda` for the test copy with
`dpkg-divert`, unmount and remount the CD, play, retrace with `scripts/cd-trace/`; undo with
`dpkg-divert --rename --remove`) — **waits for the operator's word**; a review of the draft; the
upstream issue or merge request on gitlab.gnome.org/GNOME/gvfs — the operator's.
