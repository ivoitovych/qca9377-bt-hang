# CO-11a refreshed for the newer Ubuntu series, and CVE-2026-105460 checked on 5.72 (2026-11-14; nothing filed)

Copied from `/root/exp/agent-work/lane5-status-stable-20261114/task4/`. The 11-02 files in
`../ready-20261102/` are kept; for noble the btmon fixes now travel in the one 5.72 bundle
(`../../../ubuntu-bluez-5.72-0ubuntu5.9-bundle/`).

**The newer series.** Ubuntu put unrelated uploads into proposed on 2026-11-10 (mpris-proxy,
LP #2172906) under the versions CO-11a's debdiffs had proposed. So the btmon patch
(`dca0f10fd560`) is now on top of those uploads, renumbered:
- resolute `5.85-4ubuntu0.6` (`deliver/bluez_5.85-4ubuntu0.5_5.85-4ubuntu0.6.debdiff`);
- stonking `5.87-4ubuntu0.2` (`deliver/bluez_5.87-4ubuntu0.1_5.87-4ubuntu0.2.debdiff`);
- tenacious: nothing to do; `5.88-1` (2026-11-07) has both btmon fixes and the CVE fix, so
  `../ready-20261102/`'s tenacious debdiff is obsolete.
Each built in its own container, stock and patched. btmon replay, the dossier's 30 cells: stock
aborts in 12 cells on each series, patched in none. Live on the monitor socket (5 runs per cell,
120 per series): stock aborts 10 of 60 on each, patched 0 of 60 (the four binaries built from
each series' source with noble's toolchain, since the guest is 24.04).

**CVE-2026-105460** (btmon, HCI Return Link Keys: `num_keys` trusted beyond the payload; upstream
fix `6475b75e7e0e`, BlueZ 5.88, `Fixes: 7d103ce15295`):
- 5.72's btmon is affected: a crafted capture with a 3-byte Return Link Keys event claiming 85
  keys makes both 5.8's btmon and the bundle's print 85 key entries, read past the packet (the
  two outputs stay in the work area: they are heap contents printed as addresses and keys).
- Ubuntu lists noble (and xenial to jammy, resolute, stonking) as `needs-triage`, no patch; the
  fix applies to the bundle and to 5.8 without conflict in either order.
- **The lane's reading:** it is the security team's to carry (a USN across series), not patch 11
  of the bundle; if a noble security upload takes `5.72-0ubuntu5.9` first, the bundle becomes
  `5.10`. The useful step is telling the security team that 5.72 is affected, with the 5-line
  backport. If the patch is ever carried, the upstream commit's tool-attribution trailer is
  dropped. **The operator decides** whether and how to report it.

**Checked on copy (2026-11-14):** the CVE outputs (85 "Link key" entries in both, from a
`plen 3` event); the live table (20 runs exit 134, all on the two stock builds, none patched).
**Changed on copy:** the changelog trailer of both debdiffs (and `bin/setup-newer.sh`) gives the
operator's address where the work area had a placeholder.

Not done: `dpkg-buildpackage -S` or an sbuild/PPA build of the new debdiffs; a 26.x guest.
