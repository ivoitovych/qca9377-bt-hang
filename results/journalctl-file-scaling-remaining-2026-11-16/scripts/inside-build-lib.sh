#!/bin/bash
# Inside co46-build:1: libsystemd.so of each variant (for the API test), copied to /work/bins/<v>/libsystemd.so.0
for v in "$@"; do
    cd /work/src/v-$v || continue
    t=$(ninja -C build -t targets all | grep -E '^libsystemd\.so\.[0-9.]+:' | head -1 | cut -d: -f1)
    echo "$v: target $t"
    nice -n 19 ionice -c 3 ninja -C build -j6 "$t" > /work/build-lib-$v.log 2>&1 || { tail -5 /work/build-lib-$v.log; continue; }
    cp -L build/$t /work/bins/$v/libsystemd.so.0
    ls -la /work/bins/$v/libsystemd.so.0
done
