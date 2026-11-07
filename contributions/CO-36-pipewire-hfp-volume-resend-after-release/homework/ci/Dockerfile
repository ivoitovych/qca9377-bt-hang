# PipeWire's bluez_tests CI image, rebuilt locally (CO-36 Phase 0).
# Source: .gitlab-ci.yml of PipeWire 4cfc471123a0 (.fedora, FDO_DISTRIBUTION_TAG
# 2026-10-20.0): the same Fedora release, package list and setup script
# (setup-fedora-container.sh, copied unchanged).
FROM registry.fedoraproject.org/fedora:44

RUN dnf install -y \
      alsa-lib-devel autoconf automake avahi-devel bluez-libs-devel chrony \
      clang curl dbus-daemon dbus-devel doxygen fdk-aac-free-devel file \
      findutils gcc gcc-c++ gdb git glib-devel graphviz gstreamer1-devel \
      gstreamer1-plugins-base-devel jack-audio-connection-kit-devel libasan \
      liblc3-devel libcanberra-devel libebur128-devel libell-devel \
      libffado-devel libldac-devel libmysofa-devel libplist-devel \
      libsndfile-devel libubsan libusb1-devel lilv-devel libva-devel \
      libX11-devel libtool make ModemManager-devel meson openssl-devel \
      pulseaudio-libs-devel python3-dbus python3-docutils \
      python3-gobject-devel python3-pexpect python3-pip python3-pytest \
      python3-pytest-rerunfailures python3-pytest-xdist python3-wheel \
      qemu-system-x86 readline-devel sbc-devel ShellCheck SDL2-devel \
      spandsp-devel systemd-devel virtiofsd vulkan-loader-devel \
      webrtc-audio-processing-devel which valgrind ninja-build pkgconf \
      pulseaudio-utils openal-soft readline-devel pandoc fftw-libs-single \
      fftw-devel onnxruntime-devel \
    && dnf clean all

COPY setup-fedora-container.sh /setup-fedora-container.sh
RUN /bin/sh /setup-fedora-container.sh \
      ebbb4ee31ad7011cead3d6394c68d10076ab55fc \
      pytest-bluezenv==0.1.9 \
      https://github.com/pv/bluez-test-functional-kernel/releases/download/2026-09-15.1/bzImage-v7.2-cfgc2208dd3
RUN python3 -m pip install /bluez/pytest_bluezenv-*.whl
