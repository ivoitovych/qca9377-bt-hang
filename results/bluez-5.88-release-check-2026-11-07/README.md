# Which BlueZ release carries the applied commits (2026-11-07)

BlueZ **5.88** was tagged on 2026-11-05 (`Release 5.88`, commit
`34b6f8e0e998728ce9e8e64e280d9d390c511804`, committer date 2026-11-05T21:50:04+01:00). Every one of the
eleven BlueZ commits this project got applied is in it.

Commands (2026-11-07):

```
git -C cache/bluez-upstream fetch -q https://git.kernel.org/pub/scm/bluetooth/bluez.git tag 5.88 master
git -C cache/bluez-upstream log -1 "--format=%H %cI %s" 5.88
scripts/bluez-release-contains.sh cache/bluez-upstream 5.88 > output.txt     # exit 0
```

`output.txt` (verbatim, not redacted): 11 lines, each `in 5.88`.

Control, same script on the previous tag: `scripts/bluez-release-contains.sh cache/bluez-upstream 5.87`
→ 11 lines, each `NOT in 5.87`. So the check can say "no", and 5.88 is the first release with them.

Not checked here: which distributions package 5.88. Ubuntu 24.04 ships 5.72.
