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

from pytest_bluezenv import Bluetoothd, DbusSystem, HostPlugin
from pytest_bluezenv import utils

START = ("signal ", "method call ", "method return ", "error ")


PROF_UUID = "6e2c1d84-7a3b-4f50-9c1e-5b8d2a7f0e14"
PROF_PATH = "/u29prof"


def _make_profile_class():
    import dbus
    import dbus.service

    class ProfileObject(dbus.service.Object):
        def __init__(self, bus, path):
            super().__init__(bus, path)
            self.fds = []
            self.log = logging.getLogger("u29prof")

        @dbus.service.method("org.bluez.Profile1", in_signature="",
                             out_signature="")
        def Release(self):
            self.log.info("Release")

        @dbus.service.method("org.bluez.Profile1", in_signature="oha{sv}",
                             out_signature="")
        def NewConnection(self, device, fd, props):
            self.log.info("NewConnection %s", device)
            self.fds.append(fd.take())

        @dbus.service.method("org.bluez.Profile1", in_signature="o",
                             out_signature="")
        def RequestDisconnection(self, device):
            self.log.info("RequestDisconnection %s", device)

    return ProfileObject


class U29Profile(HostPlugin):
    """A minimal external profile (RFCOMM, vendor UUID) so that
    Device1.Connect() has a profile to connect: role 'server' on the peer,
    'client' on the DUT."""

    name = "u29prof"
    depends = [Bluetoothd()]

    def __init__(self, role):
        self.role = role

    @utils.mainloop_wrap
    def setup(self, impl):
        import dbus

        self.bus = utils.get_dbus(private=True)
        self.obj = _make_profile_class()(self.bus, PROF_PATH)
        manager = dbus.Interface(self.bus.get_object("org.bluez", "/org/bluez"),
                                 "org.bluez.ProfileManager1")
        opts = {"Role": self.role, "Name": "u29prof",
                "RequireAuthentication": False, "RequireAuthorization": False,
                "AutoConnect": True}
        if self.role == "server":
            opts["Channel"] = dbus.UInt16(3)
        manager.RegisterProfile(PROF_PATH, PROF_UUID, opts)


class LongDbusSystem(DbusSystem):
    """System bus whose reply_timeout limit is 120 s instead of 20 s, so
    that a pairing agent may take 40 s to confirm (arm I)."""

    def setup(self, impl):
        old = utils.DEFAULT_TIMEOUT
        utils.DEFAULT_TIMEOUT = 120
        try:
            super().setup(impl)
        finally:
            utils.DEFAULT_TIMEOUT = old


class UBluetoothd(Bluetoothd):
    depends = [LongDbusSystem()]

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
