# CO-03 references

**Our record:**
- `docs/issues.md`, U12.
- `docs/STATUS.md`: the U12 row, and the machine's warning about the running bluetoothd.
- `evidence/exhibits/063-a2dp-start-aborted-headset-never-answers-abort.md`.
- `evidence/exhibits/064-a2dp-lost-microphone-autoswitch-releases-pending-start.md`.

**Raw evidence** (git-ignored, unfiltered): `archive/incidents/20261019-a2dp-lost/`, which
holds the day's HCI and USB captures, the journal files, the live state at 19:50 and the
configuration. Its README lists them.

**Reviews:**
- `reviews/2026-10-20T2332Z-source-investigation-task.md`, item 6.
- `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI4.

**Upstream:**
- BlueZ `a14d59725`.
- The BT-7 fixes carried in our build: `a734b06059cb`, `0bed9886cff3`.
- Ubuntu's `bluez` publishing history on Launchpad (`getPublishedSources`, noble).

**Trees:** `cache/bluez-upstream` (BlueZ git). The 5.72 worktree used for the check is
`tmp/research-20261021/bluez-5.72`, a scratch copy.
