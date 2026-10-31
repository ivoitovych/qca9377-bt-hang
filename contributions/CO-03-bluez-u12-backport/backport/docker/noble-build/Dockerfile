# Ubuntu 24.04 build environment for bluez 5.72 (CO-03).
# deb-src enabled; build dependencies of the archive's bluez source package.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && apt-get build-dep -y bluez \
    && apt-get install -y --no-install-recommends \
         devscripts dpkg-dev quilt git ca-certificates fakeroot \
         build-essential pkg-config libtool automake autoconf \
    && apt-get clean
