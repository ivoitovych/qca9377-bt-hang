#!/bin/bash
# vk.sh SCRIPT ARGS... : run /work/verify/bin/SCRIPT in the verification image (nice, ionice, low cpu shares).
# Extra docker options in VKOPTS (mounts, -e VAR=value); they come before the image name.
W=<work dir>
R=<worktree>
s=$1; shift
exec nice -n 19 docker run --rm --cpu-shares 256 -v $W:/work -v $R:/repo $VKOPTS co46-verify:1 nice -n 19 ionice -c 3 /work/verify/bin/$s "$@"
