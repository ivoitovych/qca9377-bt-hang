# Every possible contribution checked against upstream (2026-11-22)

**Question.** For each row of the contribution register (`contributions/README.md`): is the
defect already fixed upstream, or is someone else's patch for it posted; is there a public bug
report or discussion; are any of our items linked to each other through one upstream thread;
and where a fix by someone else exists, is a backport request (stable kernels, Ubuntu 24.04)
the right next step, and what homework would it need first.

**Tree read:** `main` at `5a7238f6` (2026-11-22 14:19 +0100). **Upstream read:**
2026-11-22, from 15:19 UTC.

**Relation to the report of the same day.** `2026-11-22T1240Z-kernel-contributions-readiness.md`
read upstream for the kernel items a few hours earlier and rates their readiness. This page
does not rate readiness. It verifies that report's upstream statements independently, adds the
items it leaves out (BlueZ, PipeWire, WirePlumber, GNOME, gvfs, systemd, Ubuntu packages), and
looks for other people's work on the same defects.

**Sources reachable from where this was written:** the patchwork API (project `bluetooth` and
others), git (kernel.org: bluetooth-next, mainline, the stable lines, the stable queue, BlueZ;
freedesktop: PipeWire, WirePlumber), kernel.org's release list, the Launchpad API, the
freedesktop GitLab API, the kernel bugzilla. **Not reachable by a plain request:** lore's web
pages and git archive, GitHub's API (BlueZ and systemd issues), GNOME's GitLab API, syzbot.
Where an item depends on one of those, it says "not checked".

**Limits.** Nothing was built, run in a guest or tried on the laptop. A "backport candidate"
below is a candidate only: the project's rule (every line built and tested, the receiving
project's CI run on base and on base plus ours, before anything is sent) is not met by this
page for any item, and the homework each one needs is listed with it. Nothing was sent,
posted or commented anywhere. The register itself is not edited; a proposed text for each
row is given so that the maintainer of `main` can apply it.

Sections 1 (summary) and 2 (what to do) are written last; section 3 holds the items as they
were checked.

