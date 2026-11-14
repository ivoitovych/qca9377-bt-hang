# CO-22 rechecked on the stable tips of 2026-11-14 (nothing sent)

Copied from `/root/exp/agent-work/lane5-status-stable-20261114/co22/` (one change: `asus.sh`
sets the throwaway committer `check@example.com`, where the run used `@example.invalid`). `CHECKS.md` has every
command and result.

- `d54601f21faf` and `cfa67a1dbfd9` (the ASUS QCA ROME entries) cherry-pick cleanly with `-x` on
  7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192, 5.15.225 and 5.10.274; `btusb.o` builds with the
  same W=1 warnings as unpatched (6.6.y has four `btmtk.h` errors under `-Werror` with or without
  the pair, the known 6.6 btmtk issue).
- Neither is in a stable release or queue (7.3 to 6.1 checked 2026-11-14 01:05 UTC; 5.15 and
  5.10 last on 11-02).
- `mail/stable-request-asus-rome-v3.eml`: the request with today's tips and state; v2 is kept in
  `../drafts/`.
- Daan Bouwman's patch for 0cf3:e303 (patchwork 14976888, 2026-11-12, not merged, with its own
  `Cc: stable`) stays out of the request. The owners call is now
  `../drafts/owners-call-qca-rome-ids-v2.eml`, without that ID (nine left; all nine checked absent
  from btusb at bluetooth-next `da3cc02587c6` on 2026-11-14, with the known entries found as a
  control).
