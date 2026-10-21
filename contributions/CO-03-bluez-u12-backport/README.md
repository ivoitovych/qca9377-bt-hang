# CO-03 — U12: bluetoothd rebuild and the Ubuntu backport

**State:** investigating. The upstream fix does not apply to 5.72 as is.

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

1. Hand-backport hunk 2 onto `5.72-0ubuntu5.8`'s source, and find which of the 24 commits
   changed its context.
2. Build bluetoothd with the two BT-7 fixes and the backport, then run BlueZ's unit tests.
   This is off the laptop: nothing is installed.
3. Draft the Launchpad bug: the symptom, `EX-063`/`EX-064` in short, the patch, and the test.
4. **The operator** installs the build, repeats the trigger (an application opening the
   microphone as A2DP starts), and decides the filing.

**Decides:** installing and filing are the operator's.
