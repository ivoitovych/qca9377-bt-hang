# SPDX-License-Identifier: GPL-2.0-or-later
"""
CO-03 VM host plugins for pytest-bluezenv:

- CoBluetoothd: bluetoothd from an explicit path, with extra environment
  (the host1 test fixture reads CO03_SINK_* variables).
- MediaApp: a minimal A2DP media application on D-Bus: registers one SBC
  MediaEndpoint1 (source or sink), records SetConfiguration and
  ClearConfiguration, and runs MediaTransport1 calls (Acquire, TryAcquire,
  Release) asynchronously from named D-Bus client connections, so a test
  can place them in time and see each reply.
"""

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

# SBC: all frequencies, channel modes, block lengths, subbands, both
# allocations; bitpool 2..53
SBC_CAPS = (0xFF, 0xFF, 2, 53)
# 44.1 kHz joint stereo, 16 blocks, 8 subbands, loudness, bitpool 2..53
SBC_CONF = (0x21, 0x15, 2, 53)

MEDIA_IFACE = "org.bluez.Media1"
ENDPOINT_IFACE = "org.bluez.MediaEndpoint1"
TRANSPORT_IFACE = "org.bluez.MediaTransport1"


def _now_ns():
    return time.time_ns()


class CoBluetoothd(Bluetoothd):
    """bluetoothd from the path in environment variable <exe_var> of the
    tester (parent) side, with <env> added to its environment"""

    def __init__(self, exe_var, env=None, **kw):
        super().__init__(**kw)
        self.exe_var = exe_var
        self.extra_env = dict(env or {})

    def presetup(self, config):
        self.exe = os.environ[self.exe_var]
        if not os.path.isfile(self.exe):
            raise FileNotFoundError(self.exe)

    def setup(self, impl):
        os.environ.update(self.extra_env)
        logging.getLogger("co03").info(
            f"bluetoothd {self.exe} env {self.extra_env}"
        )
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
        path = str(transport)
        self.app.transports[path] = _now_ns()
        self.app.event("SetConfiguration", path)

    @dbus.service.method(ENDPOINT_IFACE, in_signature="o", out_signature="")
    def ClearConfiguration(self, transport):
        path = str(transport)
        self.app.transports.pop(path, None)
        self.app.cleared.append((path, _now_ns()))
        self.app.event("ClearConfiguration", path)

    @dbus.service.method(ENDPOINT_IFACE, in_signature="", out_signature="")
    def Release(self):
        self.app.event("Release", "")


class MediaApp(HostPlugin):
    """
    Host plugin: one SBC endpoint per entry of <uuids> (A2DP source or
    sink UUID), registered with org.bluez.Media1.RegisterEndpoint.
    """

    name = "media"
    depends = []

    def __init__(self, uuids=(A2DP_SOURCE_UUID,)):
        self.uuids = tuple(uuids)

    @utils.mainloop_wrap
    def setup(self, impl):
        self.log = logging.getLogger("media")
        self.bus = utils.get_dbus()
        self.transports = {}
        self.cleared = []
        self.events = []
        self.ops = {}
        self.op_id = 0
        self.clients = {}
        self.fds = {}
        self.endpoints = []

        media = dbus.Interface(
            self.bus.get_object("org.bluez", "/org/bluez/hci0"), MEDIA_IFACE
        )
        for i, uuid in enumerate(self.uuids):
            path = f"/co03/ep{i}"
            ep = _Endpoint(self.bus, path, self)
            self.endpoints.append(ep)
            props = {
                "UUID": uuid,
                "Codec": dbus.Byte(0),
                "Capabilities": dbus.Array(
                    [dbus.Byte(x) for x in SBC_CAPS], signature="y"
                ),
            }
            media.RegisterEndpoint(path, props)
            self.log.info(f"endpoint {path} {uuid} registered")

    def teardown(self):
        for fd in list(self.fds.values()):
            try:
                os.close(fd)
            except OSError:
                pass

    def event(self, name, arg):
        self.events.append((_now_ns(), name, arg))
        self.log.info(f"event {name} {arg}")

    # --- helpers running in the GLib main loop -------------------------

    def _client(self, name):
        if name not in self.clients:
            bus = dbus.SystemBus(private=True)
            bus.set_exit_on_disconnect(False)
            self.clients[name] = bus
            self.log.info(f"client {name} = {bus.get_unique_name()}")
        return self.clients[name]

    def _start_op(self, op_id, client, method, path):
        rec = self.ops[op_id]
        rec["t_call"] = _now_ns()
        self.log.info(f"op {op_id} {client} {method} {path} call")
        try:
            bus = self._client(client)
            iface = dbus.Interface(bus.get_object("org.bluez", path), TRANSPORT_IFACE)
        except dbus.DBusException as exc:
            rec.update(t_reply=_now_ns(), error=exc.get_dbus_name(), message=str(exc))
            return False

        def reply(*args):
            rec["t_reply"] = _now_ns()
            rec["ok"] = True
            if args and isinstance(args[0], dbus.types.UnixFd):
                fd = args[0].take()
                self.fds[path] = fd
                rec["fd"] = fd
                rec["imtu"] = int(args[1])
                rec["omtu"] = int(args[2])
            self.log.info(f"op {op_id} {method} reply ok")

        def error(exc):
            rec["t_reply"] = _now_ns()
            rec["error"] = exc.get_dbus_name()
            rec["message"] = exc.get_dbus_message()
            self.log.info(f"op {op_id} {method} reply error {rec['error']} {rec['message']}")

        getattr(iface, method)(reply_handler=reply, error_handler=error, timeout=40)
        return False

    # --- RPC API (called from the tester; not in the main loop) --------

    def wait_transport(self, timeout=20.0, exclude=()):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            paths = [p for p in list(self.transports) if p not in exclude]
            if paths:
                return paths[0]
            time.sleep(0.05)
        raise TimeoutError("no transport configured")

    def current_transports(self):
        return list(self.transports)

    def seq(self, steps):
        """steps: list of (client, method, path, delay_ms); each call is
        made <delay_ms> after the first, on GLib timers armed at once.
        Returns the op ids."""
        ids = []

        def arm():
            for client, method, path, delay in steps:
                self.op_id += 1
                op_id = self.op_id
                self.ops[op_id] = dict(
                    id=op_id, client=client, method=method, path=path, delay_ms=delay
                )
                if delay <= 0:
                    self._start_op(op_id, client, method, path)
                else:
                    GLib.timeout_add(delay, self._start_op, op_id, client, method, path)
                ids.append(op_id)

        utils.mainloop_invoke(arm)
        return ids

    def results(self, ids, timeout=10.0):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if all("t_reply" in self.ops[i] for i in ids):
                break
            time.sleep(0.02)
        return [dict(self.ops[i]) for i in ids]

    def close_client(self, client):
        """The client's D-Bus connection goes away (an owner that exits)"""

        def close():
            bus = self.clients.pop(client)
            self.log.info(f"client {client} closing")
            bus.close()

        utils.mainloop_invoke(close)
        return _now_ns()

    def transport_props(self, path):
        def get():
            obj = self.bus.get_object("org.bluez", path)
            props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
            return {str(k): _plain(v) for k, v in props.GetAll(TRANSPORT_IFACE).items()}

        try:
            return utils.mainloop_invoke(get)
        except dbus.DBusException as exc:
            return {"_error": exc.get_dbus_name()}

    def remote_seps(self, device_path):
        def get():
            om = dbus.Interface(
                self.bus.get_object("org.bluez", "/"),
                "org.freedesktop.DBus.ObjectManager",
            )
            out = []
            for path, ifaces in om.GetManagedObjects().items():
                path = str(path)
                if path.startswith(device_path + "/sep") and ENDPOINT_IFACE in ifaces:
                    out.append(path)
            return sorted(out)

        return utils.mainloop_invoke(get)

    def set_configuration(self, remote_sep, local_index=0):
        """Remote endpoint SetConfiguration (reconfigure), from the main
        connection that owns the local endpoint; async, returns op id"""
        self.op_id += 1
        op_id = self.op_id
        rec = self.ops[op_id] = dict(id=op_id, method="SetConfiguration", path=remote_sep)

        def call():
            rec["t_call"] = _now_ns()
            obj = self.bus.get_object("org.bluez", remote_sep)
            iface = dbus.Interface(obj, ENDPOINT_IFACE)

            def reply(*a):
                rec.update(t_reply=_now_ns(), ok=True)

            def error(exc):
                rec.update(t_reply=_now_ns(), error=exc.get_dbus_name(),
                           message=exc.get_dbus_message())

            iface.SetConfiguration(
                dbus.ObjectPath(f"/co03/ep{local_index}"),
                {"Capabilities": dbus.Array([dbus.Byte(x) for x in SBC_CONF], signature="y")},
                reply_handler=reply, error_handler=error, timeout=40,
            )

        utils.mainloop_invoke(call)
        return op_id

    def write_media(self, path, count=50, interval=0.01):
        """Write <count> RTP/SBC-sized packets to the acquired fd of
        <path>; returns how many were written"""
        fd = self.fds.get(path)
        if fd is None:
            return -1
        written = 0
        payload = bytes(range(100))
        for seq in range(count):
            hdr = struct.pack(">BBHII", 0x80, 0x60, seq, seq * 128, 1)
            try:
                os.write(fd, hdr + b"\x01" + payload)
                written += 1
            except OSError as exc:
                self.log.info(f"write_media: {exc}")
                break
            time.sleep(interval)
        return written

    def read_media(self, path, timeout=3.0):
        """Read from the acquired fd of <path> for <timeout> s; returns
        (packets, bytes)"""
        fd = self.fds.get(path)
        if fd is None:
            return (-1, -1)
        sock = socket.socket(fileno=os.dup(fd))
        sock.settimeout(0.2)
        packets = nbytes = 0
        end = time.monotonic() + timeout
        try:
            while time.monotonic() < end:
                try:
                    data = sock.recv(4096)
                except socket.timeout:
                    continue
                except OSError as exc:
                    self.log.info(f"read_media: {exc}")
                    break
                if not data:
                    break
                packets += 1
                nbytes += len(data)
        finally:
            sock.close()
        return (packets, nbytes)

    def close_fd(self, path):
        fd = self.fds.pop(path, None)
        if fd is not None:
            os.close(fd)

    def get_events(self):
        return list(self.events)

    def get_cleared(self):
        return list(self.cleared)


def _plain(v):
    if isinstance(v, (dbus.Array, list)):
        return [_plain(x) for x in v]
    if isinstance(v, dbus.Boolean):
        return bool(v)
    if isinstance(v, (dbus.Byte, dbus.Int16, dbus.UInt16, dbus.Int32, dbus.UInt32, dbus.Int64, dbus.UInt64)):
        return int(v)
    return str(v)
