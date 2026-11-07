#!/bin/sh
# Source hashes (both sides) and SHA256SUMS over the runs.
top=/root/exp/agent-work/u29-t1-a2dp-backport
cd "$top" || exit 1
{
  for side in base patched; do
    for f in profiles/audio/a2dp.c profiles/audio/avdtp.c src/error.c src/device.c; do
      echo "$side $(sha256sum "src/bluez-5.72-$side/$f")"
    done
  done
} > "$top/source-hashes.txt"
find runs -type f -not -name '*.btsnoop' | sort | xargs sha256sum > "$top/SHA256SUMS"
find runs -type f -name '*.btsnoop' | sort | xargs sha256sum >> "$top/SHA256SUMS"
sha256sum source-hashes.txt src/upstream-patch/0001-a2dp-Fix-connection-error-message.patch >> "$top/SHA256SUMS"
git -C src/bluez-5.72 rev-parse HEAD > "$top/source-revisions.txt"
git -C src/bluez-5.72-patched rev-parse HEAD >> "$top/source-revisions.txt"
cat "$top/source-hashes.txt"
