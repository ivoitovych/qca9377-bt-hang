# X1 — gvfs cdda: read ahead so that audio-CD playback does not stall (off-topic)

> **Current state (2026-11-06): two small patches, not the worker thread described below.**
> - `patch1-small/0001-cdda-Limit-paranoia-read-ahead-to-avoid-playback-sta.patch`: one call,
>   `cdio_paranoia_cachemodel_size(p, 150)`, behind a meson `has_function` check.
> - `patch-track/0001-cdda-Refuse-to-open-invalid-and-non-audio-tracks.patch`: open accepts
>   only audio tracks between the disc's first and last track numbers.
>
> Review record: `REVIEW-ACTIONS.md`. Everything from "The fix (draft, 2026-11-02)" on is the
> first, superseded design (a worker thread per open track), kept for its measurements; it is
> not what is being submitted.

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
  `2710b35c…796`. ⚠️ *Corrected 2026-11-06:* that value matches none of the files found since.
  The package's own binary, diverted since 11-02 to `/usr/libexec/gvfsd-cdda.distrib` (mtime
  2026-10-05, the package install), has SHA-256 `7ccf101e…cc18`, and its md5 `862cd94c…d748`
  equals the entry in dpkg's `gvfs-backends.md5sums`; so the undo restores the genuine file.

**Tested on the laptop, 2026-11-02 20:27–20:31 (the operator's word):** the installed binary
diverted (`dpkg-divert --local --divert /usr/libexec/gvfsd-cdda.distrib --rename
/usr/libexec/gvfsd-cdda`), the test copy put in place, the audio CD unmounted and remounted with
`gio`; the new backend (pid 1673163) runs the test copy (`/proc/<pid>/exe` SHA-256 `07426241…`).
Track 1 played in Totem for 4 min, traced with `scripts/cd-trace/` (run `run3-fix`):
- **0 `UNDERFLOW`s** on Totem's stream (before the fix: 11 in 3 min, every 16 s);
- the player's source made 6,150 pulls of 7,056 bytes (~246 s of audio); none took 0.05 s or more
  except the first (4.37 s, the initial spin-up at track start, as before the fix);
- the drive still reads in ~3 s bursts every ~16 s (paranoia's 1200-sector refills, 2.7–3.7 s,
  pauses 12.5–13.7 s), now inside the reader thread, out of the player's path.
Raw run: `archive/off-topic/X1/cd-gaps-run3-fix-20261102.tar.xz` (local).
The operator, listening through the run: "It feels like all good" (no gaps heard).

**State on the laptop:** the patched `gvfsd-cdda` is still in place (diverted original at
`/usr/libexec/gvfsd-cdda.distrib`). To undo: `rm /usr/libexec/gvfsd-cdda`, then
`dpkg-divert --local --rename --remove /usr/libexec/gvfsd-cdda`, then unmount and remount the CD.
A gvfs package update would install over the diversion target name only after the diversion is
removed — remove it before updating gvfs.

**Not done:** an outside review of the draft; seek and error paths exercised on hardware (only
straight playback was tested); the upstream issue or merge request on
gitlab.gnome.org/GNOME/gvfs — the operator's.
