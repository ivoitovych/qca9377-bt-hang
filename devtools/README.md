# devtools

Tooling for **contributing to this repository**, not for diagnosing Bluetooth.

If you came here because your controller hangs, you want
[`tools/`](../tools/) and the [README](../README.md) instead — nothing in this
directory touches Bluetooth.

| Script | Purpose |
|---|---|
| `repo-scan <dir> [--all]` | Refuse-to-publish scan: MAC addresses, BSSIDs, UUIDs, IPv4, AI attribution, binary captures |
| `repo-validate <dir>` | `bash -n`, `systemd-analyze verify`, `udevadm verify`, `jq`, `py_compile` over every tracked file |
| `repo-save <dir> "<msg>"` | validate → scan → commit → push → **verify the remote hash actually matches** |

```bash
./devtools/repo-validate .
./devtools/repo-scan . --all
./devtools/repo-save . "commit message"
./devtools/repo-save . -F message.txt --no-push
```

## Why these exist

This repository publishes **logs**. Kernel logs contain the Wi-Fi access point BSSID,
which public geolocation databases index — publishing one can reveal where a machine
physically is. They also contain device addresses, device names and filesystem UUIDs.

`repo-scan` is the last line of defence before that data leaves the machine. It knows
which placeholders are legitimate (`AA:BB:CC:*`, `11:11:11:*`, and the documented test
vectors used by `tools/sanitize-logs.sh`) and fails on anything else.

`repo-save` refuses to commit if validation or the scan fails, then confirms the remote
hash equals the local one. That last step is the one most often skipped by hand, and it
is the only thing that proves a push actually landed.

## Notes

- Read-only except `repo-save`, which is the only one that writes or pushes.
- Non-zero exit on failure, so they compose.
- They take the target directory as an argument — no hardcoded paths.
- **Not installed** by `install.sh`. They are useless to end users and would only
  clutter `/usr/local/bin`.

These previously lived outside the repository, in a separate untracked-by-anything
directory. That meant they existed on exactly one machine and were backed up nowhere —
the same argument that motivated publishing this project in the first place.
