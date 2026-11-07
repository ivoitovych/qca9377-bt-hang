# SPDX-License-Identifier: GPL-2.0-or-later
"""
U29 test plugins for pytest-bluezenv (adapted from CO-03's co03_plugins.py):

- CoBluetoothd: bluetoothd from an explicit path.
- U29Ops: one SBC A2DP endpoint (source or sink) on org.bluez.Media1, plus
  the failure injection and the client call:
    * set_wrong_key(peer): replace the kernel's stored link key for <peer>
      with a different value (MGMT Load Link Keys), as if the peer had lost
      the pairing and the stored key no longer matches
    * hold_acl(peer): keep an unsecured L2CAP channel (PSM 1, SDP) open so an
      ACL link exists before the AVDTP connection is attempted
    * connect(path): org.bluez.Device1.Connect() as a D-Bus client; the reply
      (or error name and message) is recorded
"""

import glob
import logging
import os
import socket
import struct
import time

import dbus
import dbus.service
from gi.repository import GLib

from pytest_bluezenv import Bluetoothd, HostPlugin
from pytest_bluezenv import utils

A2DP_SOURCE_UUID = "0000110a-0000-1000-8000-00805f9b34fb"
A2DP_SINK_UUID = "0000110b-0000-1000-8000-00805f9b34fb"
SBC_CAPS = (0xFF, 0xFF, 2, 53)
SBC_CONF = (0x21, 0x15, 2, 53)

MEDIA_IFACE = "org.bluez.Media1"
ENDPOINT_IFACE = "org.bluez.MediaEndpoint1"
DEVICE_IFACE = "org.bluez.Device1"


def _now_ns():
    return time.time_ns()


class CoBluetoothd(Bluetoothd):
    def __init__(self, exe_var, **kw):
        super().__init__(**kw)
        self.exe_var = exe_var

    def presetup(self, config):
        self.exe = os.environ[self.exe_var]
        if not os.path.isfile(self.exe):
            raise FileNotFoundError(self.exe)

    def setup(self, impl):
        logging.getLogger("u29").info(f"bluetoothd {self.exe}")
        super().setup(impl)


class _Endpoint(dbus.service.Object):
    def __init__(self, bus, path, app):
        super().__init__(bus, path)
        self.app = app

    @dbus.service.method(ENDPOINT_IFACE, in_signature="ay", out_signature="ay")
    def SelectConfiguration(self, caps):
        self.app.event("SelectConfiguration", list(int(x) for x in caps))
        return dbus.Array([dbus.Byte(x) for x in SBC_CONF], signature="y")

    @dbus.service.method(ENDPOINT_IFACE, in_signature="oa{sv}", out_signature="")
    def SetConfiguration(self, transport, props):
        self.app.event("SetConfiguration", str(transport))

    @dbus.service.method(ENDPOINT_IFACE, in_signature="o", out_signature="")
    def ClearConfiguration(self, transport):
        self.app.event("ClearConfiguration", str(transport))

    @dbus.service.method(ENDPOINT_IFACE, in_signature="", out_signature="")
    def Release(self):
        self.app.event("Release", "")


class U29Ops(HostPlugin):
    name = "u29"
    depends = []

    def __init__(self, uuid=A2DP_SOURCE_UUID):
        self.uuid = uuid

    @utils.mainloop_wrap
    def setup(self, impl):
        self.log = logging.getLogger("u29ops")
        self.bus = utils.get_dbus()
        self.events = []
        self.calls = {}
        self.call_id = 0
        self.acl_sock = None
        self.buses = []
        media = dbus.Interface(
            self.bus.get_object("org.bluez", "/org/bluez/hci0"), MEDIA_IFACE
        )
        self.ep = _Endpoint(self.bus, "/u29/ep0", self)
        media.RegisterEndpoint(
            "/u29/ep0",
            {
                "UUID": self.uuid,
                "Codec": dbus.Byte(0),
                "Capabilities": dbus.Array(
                    [dbus.Byte(x) for x in SBC_CAPS], signature="y"
                ),
            },
        )
        self.log.info(f"endpoint /u29/ep0 {self.uuid} registered")

    def teardown(self):
        if self.acl_sock is not None:
            try:
                self.acl_sock.close()
            except OSError:
                pass

    def event(self, name, arg):
        self.events.append((_now_ns(), name, arg))
        self.log.info(f"event {name} {arg}")

    def get_events(self):
        return list(self.events)

    # --- injection ------------------------------------------------------

    def stored_key_info(self, peer):
        """(key hex, type, path of the info file) of the bluetoothd state
        of this guest for <peer>"""
        paths = glob.glob(f"/run/bluetoothd-state-*/state/*/{peer.upper()}/info")
        if not paths:
            raise FileNotFoundError(f"no info file for {peer}")
        key = typ = None
        section = None
        for line in open(paths[0]).read().splitlines():
            if line.startswith("["):
                section = line
            elif section == "[LinkKey]" and line.startswith("Key="):
                key = line[4:]
            elif section == "[LinkKey]" and line.startswith("Type="):
                typ = int(line[5:])
        return key, typ, paths[0]

    def set_wrong_key(self, peer, index=0):
        """MGMT Load Link Keys (0x0012) with one key for <peer>: the stored
        key with every byte inverted, same type. Replaces all kernel keys of
        controller <index>. Returns (old key, new key, mgmt status)."""
        key, typ, _ = self.stored_key_info(peer)
        old = bytes.fromhex(key)
        new = bytes(b ^ 0xFF for b in old)
        addr = bytes(int(x, 16) for x in reversed(peer.split(":")))
        entry = addr + bytes([0, typ]) + new + bytes([0])
        params = struct.pack("<BH", 0, 1) + entry
        pkt = struct.pack("<HHH", 0x0012, index, len(params)) + params
        s = socket.socket(31, socket.SOCK_RAW, 1)
        try:
            import ctypes

            sa = struct.pack("<HHH", 31, 0xFFFF, 3)  # sockaddr_hci, control channel
            libc = ctypes.CDLL("libc.so.6", use_errno=True)
            if libc.bind(s.fileno(), ctypes.c_char_p(sa), len(sa)) != 0:
                raise OSError(ctypes.get_errno(), "bind(HCI control) failed")
            s.send(pkt)
            s.settimeout(5)
            while True:
                data = s.recv(512)
                ev, idx, plen = struct.unpack("<HHH", data[:6])
                if ev == 0x0001:
                    opcode, status = struct.unpack("<HB", data[6:9])
                    if opcode == 0x0012:
                        return (old.hex(), new.hex(), status)
        finally:
            s.close()

    def hold_acl(self, peer, psm=1):
        """open an L2CAP channel on <psm> (default 1, SDP) to <peer> and keep
        it, so that an ACL link exists"""
        s = socket.socket(31, socket.SOCK_SEQPACKET, 0)
        s.settimeout(10)
        s.connect((peer, psm))
        self.acl_sock = s
        return True

    def release_acl(self):
        if self.acl_sock is not None:
            self.acl_sock.close()
            self.acl_sock = None

    # --- client call ----------------------------------------------------

    def _start_call(self, cid, path, method):
        rec = self.calls[cid]
        rec["t_call"] = _now_ns()
        self.log.info(f"call {cid} {method} {path}")
        bus = dbus.SystemBus(private=True)
        bus.set_exit_on_disconnect(False)
        rec["client"] = bus.get_unique_name()
        self.buses.append(bus)  # keep the connection alive until the reply
        iface = dbus.Interface(bus.get_object("org.bluez", path), DEVICE_IFACE)

        def reply(*a):
            rec.update(t_reply=_now_ns(), ok=True)
            self.log.info(f"call {cid} reply ok")

        def error(exc):
            rec.update(t_reply=_now_ns(), ok=False, error=exc.get_dbus_name(),
                       message=exc.get_dbus_message())
            self.log.info(f"call {cid} error {rec['error']} {rec['message']}")

        getattr(iface, method)(reply_handler=reply, error_handler=error, timeout=40)
        return False

    def call(self, path, method="Connect"):
        self.call_id += 1
        cid = self.call_id
        self.calls[cid] = dict(id=cid, path=path, method=method)
        utils.mainloop_invoke(self._start_call, cid, path, method)
        return cid

    def result(self, cid, timeout=40.0):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if "t_reply" in self.calls[cid]:
                break
            time.sleep(0.02)
        return dict(self.calls[cid])
