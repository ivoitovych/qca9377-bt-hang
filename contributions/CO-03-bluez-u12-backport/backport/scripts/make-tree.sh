#!/bin/sh
# Create the git tree of Ubuntu noble's bluez 5.72-0ubuntu5.8 (Ubuntu's
# patches applied, as dpkg-source -x left it) at
# /root/exp/agent-work/co03/src/bluez, branch noble-5.72-0ubuntu5.8.
set -eu
top=/root/exp/agent-work/co03/src
ver=5.72-0ubuntu5.8
tree=$top/bluez
if [ -e "$tree" ]; then
    echo "exists: $tree" >&2
    exit 1
fi
cp -a "$top/archive/bluez-$ver" "$tree"
cd "$tree"
git init -q -b noble-5.72-0ubuntu5.8
git config user.name "Iaroslav Voitovych"
git config user.email "yaroslav.voytovych@gmail.com"
# quilt's bookkeeping is not source
printf '.pc/\n' >> .git/info/exclude
git add -A
GIT_AUTHOR_DATE="2026-10-13T11:28:01+01:00" git commit -q -m "Import bluez $ver (Ubuntu 24.04 noble)

Source package bluez_$ver.dsc from the Ubuntu archive (noble-security,
noble-updates), unpacked with dpkg-source -x: upstream 5.72 with
debian/patches/series applied."
git tag -a "import/$ver" -m "bluez $ver as published"
git log --oneline
