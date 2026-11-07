# Build gnome-bluetooth master (adf070af) and run the pairing-failure test headless.
# Base: Fedora (latest tag at build time; the resolved release is logged by scripts/build.sh).
FROM fedora:latest

RUN dnf -y install \
      gcc meson ninja-build pkgconf-pkg-config gettext git \
      glib2-devel gtk4-devel libadwaita-devel gsound-devel libnotify-devel \
      systemd-devel upower-devel gobject-introspection-devel \
      python3 python3-gobject python3-dbus python3-dbusmock \
      dbus-daemon dbus-tools xorg-x11-server-Xvfb xorg-x11-xauth ImageMagick \
      mesa-dri-drivers adwaita-icon-theme google-noto-sans-fonts \
      gtk4-devel-tools \
    && dnf clean all

# COPY makes a private copy; the original under src/ is never modified.
COPY src/gnome-bluetooth-adf070af /build/gnome-bluetooth
WORKDIR /build/gnome-bluetooth
# Optional: apply an unedited diff to the copy (--build-arg APPLY_DIFF=yes).
# git apply is all-or-nothing: if it does not apply cleanly the build stops with its message.
COPY src/mr-137.diff /build/mr-137.diff
ARG APPLY_DIFF=no
RUN if [ "$APPLY_DIFF" = yes ]; then git apply --verbose /build/mr-137.diff; fi
RUN meson setup /build/builddir -Dgtk_doc=false --prefix=/usr/local \
 && meson compile -C /build/builddir \
 && meson install -C /build/builddir

COPY tests/ /work/tests/
