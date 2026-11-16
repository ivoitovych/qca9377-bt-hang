FROM ubuntu:24.04
# A fresh Ubuntu 24.04 with only what a maintainer would have: the archive's systemd (journalctl) and the
# package that provides systemd-journal-remote. Nothing else is added; the test runs as an unprivileged user.
RUN apt-get update -qq && apt-get install -y -qq systemd systemd-journal-remote && rm -rf /var/lib/apt/lists/*
RUN useradd -m tester
USER tester
WORKDIR /home/tester
