# CO-03 — U12: bluetoothd rebuild and the Ubuntu backport

**State (2026-10-31; see the note of 2026-11-16 below for what is newer):** backported, built
and tested off the laptop. It was waiting for the operator's test on the laptop and decision on
filing; `docs/STATUS.md` records the package as staged on 2026-11-13, not installed. The
work is in [`backport/`](backport/README.md):
- five commits on `5.72-0ubuntu5.8`: BT-7, the helper part of `3d9900eb754d`,
  `a14d59725ef3` and `664a5d3785a1`;
- the package `5.72-0ubuntu5.9~co03.1`;
- a test plan run on base first: the trigger lost A2DP 70 of 70 times before and 0 of 70 after
  (the earlier "0/70 → 70/70" counted passes, the opposite way to `docs/STATUS.md`), and no
  other test changed.

**Note of 2026-11-16 (which build is staged):** the package staged in the headset kit
(`artifacts/bluez-5.72-0ubuntu5.9~co03.1/bluez_5.72-0ubuntu5.9~co03.1_amd64.deb`, SHA-256
`ffbedfd78fcdc124a343070663bb45739e554aa750c52bd514cb527d23b40c4a`, the value in
`results/laptop-only-work-2026-11-11/headset-session/SESSION-CHECKLIST.md`) was read without
installing it: `dpkg-deb -I` gives `bluez 5.72-0ubuntu5.9~co03.1`, and its changelog
(`dpkg-deb -x`, `changelog.Debian.gz`) lists five patches: `co03-01` (adapter: short start
discovery reply, `a734b06059cb`) and `co03-02` (a2dp: NULL stream in `transport_cb`,
`0bed9886cff3`), which are the BT-7 fixes, and `co03-03` to `co03-05` (U12: `3d9900eb754d`'s
helper part, `a14d59725ef3`, `664a5d3785a1`). The daemon inside it, `usr/libexec/bluetooth/bluetoothd`,
has SHA-256 `59d2ea79b4d98eb4f1e04de1d1622908a263885856cb13ea770109431f8a2453` (the full value is
in the same checklist; `docs/STATUS.md` truncates it, and that value belongs to the daemon, not to
the package). The `.deb` itself is **not in the repository**: it is a local artifact of the headset
kit, and only its hash is recorded here. So the staged `~co03.1` build **does carry the BT-7 fixes**, as
this page, BRIEF and STATUS say. The Ubuntu bundle's `5.72-0ubuntu5.9`
(`../ubuntu-bluez-5.72-0ubuntu5.9-bundle/`) is a different build and **does not**: its notes
say "the final CO-03 candidate left them out" (it carries only the three U12 patches). Both
statements are true; they are about two builds. The version `~co03.1` sorts below the bundle's
`5.72-0ubuntu5.9`.

The facts and steps below are the state before that work.

**Target:** Ubuntu 24.04's `bluez` (5.72), through a Launchpad bug with a tested backport.

**Comes from:** `U12` (`EX-063`, `EX-064`). An application opening the microphone while A2DP
is starting loses A2DP until the headset reconnects.

## The facts

- **Upstream fix:** `a14d59725` (Pauli Virtanen, 2024-11-02, "transport: don't disconnect
  A2DP if canceling Acquire() with Release()"), first released in 5.80.
- **Ubuntu noble** (2026-10-20): `5.72-0ubuntu5.8` in security, `5.72-0ubuntu5.7` in updates.
  The changelog has no entry for it, and Launchpad has no bug for it.
- **The running bluetoothd is this project's build** of `5.72-0ubuntu5.5` plus the BT-7 fixes,
  so it also lacks the five CVE fixes of `5.72-0ubuntu5.7` (STATUS, the machine's warnings).
- **On 5.72**, `git apply --check` of the fix applies hunk 1 at offset −8. Hunk 2 fails in
  `a2dp_resume_complete()` ("patch failed: profiles/audio/transport.c:394").
  - 24 commits touch `profiles/audio/transport.c` between 5.72 and the fix.
  - By subject, `47da1efdc` ("Unset transport owner before owner free") and `87ad4c66b`
    ("fix crash when freeing transport") may need to come with it. Not checked yet.

## Next

1. Backport onto `5.72-0ubuntu5.8`'s source, by reviewer 4's recipe (checked 2026-10-21):
   - the `transport_a2dp_get_stream()` helper part of `3d9900eb7`;
   - then `a14d59725` (hunks 1 to 5 apply);
   - then the `A2DP_OPS` line wired by hand.

   Audit the companions `664a5d3785a1`, `aa118e965b02`, `47da1efdc584` and `87ad4c66b934`.
2. Build bluetoothd with the two BT-7 fixes and the backport, then run BlueZ's unit tests.
   This is off the laptop: nothing is installed.
3. Draft the Launchpad bug: the symptom, `EX-063`/`EX-064` in short, the patch, and the test.
4. **The operator** installs the build, repeats the trigger (an application opening the
   microphone as A2DP starts), and decides the filing.

**Decides:** installing and filing are the operator's.
