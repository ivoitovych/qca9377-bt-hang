#!/bin/sh
# Creates work/master-base and work/5.72-base from the exported sources,
# commits each untouched as the base. (Idempotent for the git part.)
set -eu
top=/root/exp/agent-work/u29-t3-lifetime-patch
w=$top/work
mkdir -p "$w/master-base" "$w/5.72-base"
if [ ! -e "$w/master-base/configure.ac" ]; then
    tar -xf "$top/src/bluez-master-a80671987.tar" -C "$w/master-base" --strip-components=1
fi
if [ ! -e "$w/5.72-base/configure.ac" ]; then
    tar -C "$top/src/bluez-5.72" -cf "$w/572.tar" .
    tar -xf "$w/572.tar" -C "$w/5.72-base"
fi
for t in master-base 5.72-base; do
    r=$w/$t
    [ -d "$r/.git" ] || git init -q "$r"
    git -C "$r" config user.name u29t3
    git -C "$r" config user.email u29t3@localhost
    # build products of the (already built) 5.72 export are not part of the base
    cat > "$r/.git/info/exclude" <<EOF
*.o
*.lo
*.la
*.a
*.log
.deps/
.libs/
.dirstamp
Makefile
config.status
config.h
stamp-h1
libtool
src/builtin.h
src/bluetooth.service
EOF
    if ! git -C "$r" rev-parse -q --verify HEAD >/dev/null; then
        git -C "$r" add -A
        # source files caught by the tree's own .gitignore (*.1) or by name
        git -C "$r" add -f src/bluetooth.conf
        [ ! -e "$r/LICENSES/preferred/LGPL-2.1" ] || git -C "$r" add -f LICENSES/preferred/LGPL-2.1
        git -C "$r" commit -q -m "base: untouched export"
    fi
done
git -C "$w/master-base" log --oneline
git -C "$w/5.72-base" log --oneline
