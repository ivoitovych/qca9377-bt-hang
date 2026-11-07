# SPDX-License-Identifier: GPL-2.0-or-later
"""
Host plugins for the temporary-device lifetime experiment.

- UBluetoothd: bluetoothd from the path in a tester environment variable,
  started with -d and an EMPTY main.conf (TemporaryTimeout stays at its
  default of 30 s).
- DbusRec: runs `dbus-monitor --system` in the guest and keeps every
  message with the guest clock at reception; also starts/stops a discovery
  client (scripts/vm_discovery.py) in the guest.
"""

import logging
import os
import signal
import subprocess
import threading
import time

from pytest_bluezenv import Bluetoothd, HostPlugin
from pytest_bluezenv import utils

START = ("signal ", "method call ", "method return ", "error ")


class UBluetoothd(Bluetoothd):
    def __init__(self, exe_var, **kw):
        super().__init__(**kw)
        self.exe_var = exe_var

    def presetup(self, config):
        self.exe = os.environ[self.exe_var]
        if not os.path.isfile(self.exe):
            raise FileNotFoundError(self.exe)


class DbusRec(HostPlugin):
    name = "dbusrec"
    depends = [Bluetoothd()]

    def setup(self, impl):
        self.log = logging.getLogger("dbusrec")
        self.msgs = []          # (recv_ns, text)
        self.cur = None
        self.lock = threading.Lock()
        exe = utils.find_exe("", "dbus-monitor")
        self.job = subprocess.Popen(
            [exe, "--system"], stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
            text=True, bufsize=1)
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()
        self.disc = None
        self.disc_lines = []

    def _read(self):
        for line in self.job.stdout:
            now = time.time_ns()
            line = line.rstrip("\n")
            with self.lock:
                if line.startswith(START):
                    self.cur = [now, line]
                    self.msgs.append(self.cur)
                elif self.cur is not None:
                    self.cur[1] += "\n" + line

    def teardown(self):
        for job in (self.job, self.disc):
            if job is not None and job.poll() is None:
                job.terminate()

    # --- RPC API ----------------------------------------------------------

    def now(self):
        return time.time_ns()

    def find(self, substrs, after_ns=0):
        """recv time (ns) of the first message after <after_ns> that
        contains all <substrs>, else None"""
        with self.lock:
            for t, text in self.msgs:
                if t >= after_ns and all(s in text for s in substrs):
                    return t
        return None

    def count(self, substrs, after_ns=0):
        with self.lock:
            return sum(1 for t, text in self.msgs
                       if t >= after_ns and all(s in text for s in substrs))

    def dump(self):
        with self.lock:
            return [(t, text) for t, text in self.msgs]

    def start_discovery(self, script, transport, discoverable):
        self.disc = subprocess.Popen(
            ["python3", script, transport, discoverable],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL, text=True, bufsize=1)

        def rd():
            for line in self.disc.stdout:
                self.disc_lines.append((time.time_ns(), line.rstrip("\n")))

        threading.Thread(target=rd, daemon=True).start()

    def discovery_lines(self):
        return list(self.disc_lines)
