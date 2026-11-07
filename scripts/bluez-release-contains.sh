#!/bin/bash
# bluez-release-contains.sh <bluez-clone> <tag> — for each BlueZ commit this project got applied,
# print whether <tag> contains it (git merge-base --is-ancestor). Read-only.
# The list is the README's "Accepted upstream contributions" table (BlueZ rows).
set -uo pipefail
REPO="$1"
TAG="$2"
COMMITS=(
  "a734b06059cb adapter: Fix crash on short start discovery reply"
  "0bed9886cff3 a2dp: Fix crash on NULL stream in transport_cb"
  "ae23df052290 shared/mgmt: Fix notify leak in mgmt_unregister()"
  "6f5eeb402d3b unit/test-mgmt: Test unregistering from callbacks"
  "8da7e648a9fb emulator: Free hooks in btdev_destroy"
  "f3344d20d904 emulator: Add btdev_send_event (mgmt-tester series 1/3)"
  "2942883d2738 emulator/vhci: Add vhci_set_quirk_simultaneous_discovery (2/3)"
  "49a70562f0bf mgmt-tester: Add simultaneous discovery stop tests (3/3)"
  "b79d4a887 a2dp: Remove duplicate check in transport_cb"
  "7bc9684dc emulator: Avoid variable length array in send_cmd"
  "3e5b0da969c2 ioctl-tester: Fix name of the 3-DH packet type test"
)
for line in "${COMMITS[@]}"; do
  sha="${line%% *}"
  if ! git -C "$REPO" cat-file -e "$sha^{commit}" 2>/dev/null; then
    echo "UNKNOWN  $line"
  elif git -C "$REPO" merge-base --is-ancestor "$sha" "$TAG"; then
    echo "in $TAG  $line"
  else
    echo "NOT in $TAG  $line"
  fi
done
