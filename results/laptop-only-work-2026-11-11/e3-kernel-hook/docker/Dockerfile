FROM ubuntu:24.04
# Test base: what a Ubuntu 24.04 desktop has (build tools, initramfs-tools, grub scripts) plus the
# kernel packages of 7.0.0-38, -42 and -43 downloaded (NOT installed) into the apt cache, so the
# tests can run `apt-get install` of a real kernel with real dpkg maintainer scripts, offline.
ENV DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates build-essential kmod zstd python3 patch \
      xz-utils initramfs-tools grub2-common grub-pc-bin cron linux-base
COPY proposed.sources /etc/apt/sources.list.d/proposed.sources
RUN apt-get update \
 && apt-get install -y --download-only --no-install-recommends \
      linux-image-7.0.0-38-generic linux-modules-7.0.0-38-generic linux-headers-7.0.0-38-generic \
      linux-image-7.0.0-42-generic linux-modules-7.0.0-42-generic linux-headers-7.0.0-42-generic \
      linux-image-7.0.0-43-generic linux-modules-7.0.0-43-generic linux-headers-7.0.0-43-generic
