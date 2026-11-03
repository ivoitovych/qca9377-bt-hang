# X1 patch 1 — gvfs cdda read-ahead (for review; not submitted)

`0001-cdda-Read-ahead-so-that-audio-playback-does-not-stal.patch`
(SHA-256 `06ac145aa992c3444355ec36770c539ec408e5137e51c54fe9cb4c5834c12865`): one commit on gvfs
master `2d30ce9b73babfd5e6ca6762ac3af46c1b092337` ("Update Slovenian translation"); patch commit
`954268f324f5`. One file, `daemon/gvfsbackendcdda.c`, +160 −21. Only the read-ahead: no drive-speed
change, no diagnostics. Drive speed and read-step size are a separate patch 2, still being
evaluated.

What it does: a worker thread reads up to 10 s ahead into a ring and serves `do_read()` from it,
and the ring keeps the last 2 s already served (a client reading through gvfsd-fuse asks again for
data up to about 1.5 s behind; see the commit message).

## Tested

| what | how | result |
|---|---|---|
| compiles | gvfs master + this patch, ubuntu:26.04 container, cdda backend only (`../build/build-in-container.sh`) | 0 warnings |
| the read-ahead core on hardware | Ubuntu 24.04's gvfs 1.54.4 + the same read-ahead (without the 2 s history), the laptop's USB drive, Totem, 2026-11-02 run 3 | underflows 11 in 3 min → 0; the operator heard no gaps |
| the same, second disc | runs 4–6 (24×, 8×, 24×) | run 4: two 1.6–1.7 s stalls from a ring reset (the cause the 2 s history fixes); runs 5–6: none |
| the 2 s history | a simulator around the patch's own code, copied verbatim with a byte-identity check, with a modelled paranoia, drive and gvfsd-fuse/page-cache client | with an injected page-cache loss: resets 18/21, 21/21, 9/12 → 0 in each set; baseline set otherwise unchanged; no new thread-sanitizer report |

**Not yet tested:** the 2 s history on the real drive in playback (the test build with it is
installed on the laptop, together with the separate speed change and diagnostics, and has not been
played yet), and this exact patch on hardware (the laptop runs 1.54.4, not master).
Evidence: `evidence/off-topic/X1-cd-playback-underflow-every-16s.md`.

## Before submission (open; added 2026-11-03)

1. **One listening session with the 2 s history on the laptop.** The installed test build
   (`/usr/libexec/gvfsd-cdda`, SHA-256 `22179eef…8aff`, built from 1.54.4 + read-ahead + 2 s
   history + the separate speed change + diagnostics) has not been played yet. Play at least one
   whole track with `scripts/cd-trace/trace.py` running; pass: no mid-track underflow in the
   journal, no `cdda-ra: reset` outside seeks, and the operator hears no gap.
2. **Check against the live gvfs master and run its CI.** This patch is on `2d30ce9b73ba` from a
   local clone not refreshed since 2026-11-02. Fetch the current master, rebase, confirm it applies
   and compiles with 0 warnings, and run gvfs's own CI (`.gitlab-ci.yml`) locally on base and
   base + patch, judging only the difference.
3. **One sentence on why gvfs's existing read-ahead does not help**, for the commit message or
   the merge-request description: the request channel already queues one read-ahead job
   (`daemon/gvfsreadchannel.c:211-248`), but the cdda daemon runs a single job thread
   (`daemon/meson.build:333`, `MAX_JOB_THREADS=1`), so that job waits on the same blocking
   paranoia refill and cannot hide it.

The merge-request description also states the hardware and client tested (the drive model, USB,
Totem through gvfsd-fuse), as in the table above. The operator submits; nothing goes out without
the operator's word.

Review notes: an outside review (2026-11-03) recommended submitting as is. Its checkable points
were confirmed or already covered (`git diff --check` clean; the one-thread job model; about
2.1 MB per open track). Its suggestion to handle a `g_thread_new()` failure was not taken:
`g_thread_new()` aborts instead of returning an error (`g_thread_try_new()` is the variant that
returns one).
