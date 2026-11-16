FROM ubuntu:24.04
# Verification image: Ubuntu 24.04 userspace, the archive's systemd (8.18, for its runtime libraries), and tools.
# noble-proposed is enabled at pin priority 1, so that `apt-get download pkg=version` can fetch 255.4-1ubuntu8.19.
ENV DEBIAN_FRONTEND=noninteractive
RUN printf 'Types: deb\nURIs: http://archive.ubuntu.com/ubuntu\nSuites: noble-proposed\nComponents: main restricted universe multiverse\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' > /etc/apt/sources.list.d/proposed.sources \
 && printf 'Package: *\nPin: release a=noble-proposed\nPin-Priority: 1\n' > /etc/apt/preferences.d/proposed \
 && apt-get update -qq \
 && apt-get install -y -qq systemd systemd-journal-remote libsystemd-dev gcc make python3 strace gdb util-linux procps psmisc kmod ca-certificates curl \
 && apt-get clean
