#!/bin/bash
# Inside the container: the diff of a prototype tree (v-g) against the main revision it was made from.
cd /work/src/v-${1:-g} || exit 1
git diff -- src/libsystemd > /work/proto-${1:-g}.diff
wc -l /work/proto-${1:-g}.diff
