#!/bin/bash
# stage.sh DESTDIR FILE... : copy files into DESTDIR with the work-area path replaced by <work dir>.
W=<work dir>
dest=$1; shift
mkdir -p "$dest"
for f in "$@"; do
    sed "s#<work dir>#<work dir>#g; s#<worktree>#<worktree>#g" "$f" > "$dest/$(basename "$f")"
done
