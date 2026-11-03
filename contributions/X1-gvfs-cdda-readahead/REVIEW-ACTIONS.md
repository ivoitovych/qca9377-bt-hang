# X1 — outside review round on patch 1 (2026-11-03): findings and actions

The reviewers saw only the patch (`patch1/0001-…patch`, commit `954268f324f5`), as a maintainer
would. Their findings are opinions; the "check" column says what was verified here and how.
Reviewers are numbered in the order their reviews arrived.

## Findings

| # | Finding | From | Check | Status |
|---|---|---|---|---|
| F1 | Try the 2 s paranoia cache model (`cdio_paranoia_cachemodel_size(p, 150)`) alone, without a thread, before the 160-line read-ahead | R2, R3, R4 | matches the earlier candidate fix in the evidence file and the quiet build's step size | **experiment E1 running** |
| F2 | Two open tracks → two workers enter libcdio at once on the one shared `cdrom_drive_t`; before the patch all drive access ran on the backend's single job thread | R2, R3, R4 (R4: "confirmed concurrent access") | confirmed from source: `MAX_JOB_THREADS=1` (`daemon/meson.build:333`); shared drive fields written during reads (`cddap_interface.c:93-95`); the message-buffer `realloc` path is not used because gvfs opens the drive with `CDDA_MESSAGE_FORGETIT` (`gvfsbackendcdda.c:335`, `cdda.h:55`) | confirmed; moot if F1 suffices |
| F3 | `do_read()` clears `ra_errno` on every new-sector request, so a failed read-ahead sector is retried while the client still reads buffered data | R2, R3 | confirmed in the patch (`do_read`, the unconditional `ra_errno = 0`) | confirmed; moot if F1 suffices |
| F4 | Closing a handle waits for an in-flight speculative paranoia read (not interruptible) | R2, R3, R4 | true by construction (`free_read_handle` joins) | to measure if the thread design stays |
| F5 | Forced unmount (disc removed) can release the drive without stopping the worker | R4 | mechanism confirmed in source: `on_uevent` → `g_vfs_backend_force_unmount` (`gvfsbackend.c:1087-1093`) closes channels and the job source; finalize → `release_device` closes the drive (`gvfsbackendcdda.c:256`, `120`); nothing stops the worker. Whether the daemon exits before finalize: not traced | confirmed mechanism; moot if F1 suffices |
| F6 | The "two 128 KiB windows" comment states an observation as a kernel contract | R2, R3 | agreed: observed with default readahead; the simulator shows resets return with larger windows | reword if the thread design stays |
| F7 | GStreamer's cdparanoia source uses a 150-sector cache for playback-like modes | R3 | **verified 2026-11-03** in GStreamer main, `subprojects/gst-plugins-base/ext/cdparanoia/gstcdparanoiasrc.c`, `gst_cd_paranoia_src_open()`: with `cache-size` -1 (auto, the default) and paranoia mode ≤ `PARANOIA_MODE_FRAGMENT`, `cache_size = 150` ("if paranoia mode is low (the default), assume we're doing playback"), then `paranoia_cachemodel_size (src->p, cache_size)` | verified; citable precedent |
| F8 | gvfs accepts `libcdio_paranoia >= 0.78.2` (`meson.build:430`); old versions lack `cdio_paranoia_cachemodel_size()` | R3 | the minimum is confirmed; the version that introduced the function is not (local clone has no history) | needs a configure check (`cc.has_function`) or an agreed minimum bump |
| F9 | An independent public report of the same 16 s stall through Totem/gvfs (openSUSE forum, 2025) | R3 | **verified 2026-11-03, partly:** forums.opensuse.org/t/audio-cd-read-jumping/182452, first post 2025-02-07 (Leap 15.6): playback stalls at about 15.9 s and 31.9 s; a second user reproduced gaps with GStreamer on `/run/user/1000/gvfs/cdda:host=sr0/Track 5.wav`, underruns with aplay. Worked: a bigger player cache (`mplayer -cache 1024`); conclusion "keeping the cd drive spinning". A smaller paranoia cache was **not** tried there; closed without a fix | cite as the same bug, not as evidence for F1 |
| F10 | Ring index uses the absolute sector (`next % RA_CAPACITY`); `cdio_paranoia_seek()` result unchecked | R3 | true; the old code did not check the seek either | minor, if the thread design stays |
| F11 | Out-of-ring seeks and the first read still pay a full refill | R3 | true | F1 shrinks it for both designs |
| F12 | `g_thread_new()` failure unchecked | R1 | not taken: `g_thread_new()` aborts on failure; `g_thread_try_new()` is the variant that returns an error | rejected |
| F13 | Byte-for-byte comparison of a track read through the backend with `cd-paranoia` | R2 | — | add to tests |
| F14 | Subject should describe the change, not the benefit (GNOME handbook) | R3 | — | apply to the final patch |
| F15 | The merge request needs a compact before/after evidence summary (drive, versions, max read latency, underruns), since maintainers see only the patch and description | R2, R3 | — | draft for the operator |

## Actions

| # | Action | Depends on | State |
|---|---|---|---|
| A1 | **E1:** 1.54.4 + only the 150-sector cache model (no thread, no speed change), installed on the laptop; play whole tracks with `scripts/cd-trace/trace.py` and GStreamer logging; pass = no mid-track underflow, max player wait well under the old ~3 s, operator's ear on noise | — | building |
| A2 | Verify F7 (GStreamer source) and F9 (public report) | — | done (F9 partly: same bug, fix not tested there) |
| A3 | Find the libcdio-paranoia version that introduced `cdio_paranoia_cachemodel_size()`; add a meson `has_function` check, or propose a minimum bump | F8 | open |
| A4 | If E1 passes: patch 1 becomes the small change (+ configure check), commit message per F14, tests F13, two tracks, close, disc removal, EOF on the small version; the thread version kept as a tested fallback | A1, A3 | open |
| A5 | If E1 fails: redesign the thread version as one reader per drive (F2, F4, F5), fix F3, F6, F10; its tests as in the pre-submission checklist | A1 | open |
| A6 | Pre-submission checklist items still apply to whichever version goes: live master + CI, the sentence on the channel read-ahead, listening session | A4 or A5 | open |
| A7 | Draft the merge-request description with the evidence summary, for the operator | A4 or A5 | open |
| A8 | Patch 2 (drive speed): re-evaluate after E1 — if small reads alone are quiet enough, no speed change is needed | A1 | open |
