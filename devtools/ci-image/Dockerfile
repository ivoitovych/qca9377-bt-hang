FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -q && apt-get install -y --no-install-recommends \
    ca-certificates git gawk systemd-journal-remote fakeroot strace python3 jq zstd xz-utils \
    bsdextrautils perl bc curl udev systemd procps sudo patch gzip bzip2 coreutils util-linux \
    binutils iproute2 less file diffutils findutils dbus python3-gi gir1.2-glib-2.0 \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m runner && echo 'runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner
