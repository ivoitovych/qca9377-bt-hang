#!/bin/sh
# Copies the co03 PipeWire master tree (4cfc4711, build-v0-asan) into
# agent-work/co36/pw, without the other campaign's core files and test
# mounts, so CO-36 runs never write into co03's tree.
set -eu
rsync -a \
    --exclude '/*.core' \
    --exclude '__pycache__' \
    --exclude '/test/bluezenv/co03_plugins.py' \
    --exclude '/test/bluezenv/test_co03_pw.py' \
    /root/exp/agent-work/co03/pw/ /root/exp/agent-work/co36/pw/
echo copied
