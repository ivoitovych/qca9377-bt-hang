# Ubuntu 24.04 image for CO-03's VM tests: the bluez build environment
# (co03-noble-build:1) plus what pytest-bluezenv needs to boot two QEMU/KVM
# guests with emulated controllers (btvirt). The guests run this image's
# userspace, so a bluetoothd built in co03-noble-build:1 runs there as is.
# The kernel is the one PipeWire's CI uses (copied from co36-pw-ci:f44).
FROM co03-noble-build:1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         qemu-system-x86 python3-pip python3-dbus python3-gi \
         python3-pexpect python3-pytest dbus-daemon dbus chrony \
         util-linux gdb meson ninja-build python3-venv procps \
         kmod iproute2 \
    && apt-get clean

COPY pytest_bluezenv-0.1.9 /src/pytest_bluezenv-0.1.9
# pytest-bluezenv needs pytest >= 8 (noble ships 7.4); dbus-python and
# PyGObject stay the distribution's
RUN python3 -m pip install --break-system-packages --ignore-installed \
         "pytest>=8" pluggy iniconfig pexpect ptyprocess \
    && python3 -m pip install --break-system-packages --no-deps \
         /src/pytest_bluezenv-0.1.9 \
    && ls -la /usr/local/lib/python3.12/dist-packages/pytest_bluezenv/bin/
COPY bzImage /bluez-kernel/bzImage
