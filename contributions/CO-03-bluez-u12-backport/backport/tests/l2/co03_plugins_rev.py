# SPDX-License-Identifier: GPL-2.0-or-later
"""
MediaApp with several local endpoints that records, for every
SetConfiguration/ClearConfiguration bluetoothd makes, WHICH local endpoint
received it and the configuration bytes. The companion test needs this to
see which local SEP a reconfiguration ended on.
"""

import dbus
import dbus.service

from .co03_plugins import (
    ENDPOINT_IFACE,
    MEDIA_IFACE,
    SBC_CAPS,
    MediaApp,
    _Endpoint,
    _now_ns,
)
from pytest_bluezenv import utils
import logging


class _EndpointRev(_Endpoint):
    def __init__(self, bus, path, app):
        super().__init__(bus, path, app)
        self.ep_path = path

    @dbus.service.method(ENDPOINT_IFACE, in_signature="oa{sv}", out_signature="")
    def SetConfiguration(self, transport, props):
        path = str(transport)
        conf = [int(x) for x in props.get("Configuration", [])]
        self.app.transports[path] = _now_ns()
        self.app.transport_ep[path] = self.ep_path
        self.app.setconfs.append((_now_ns(), self.ep_path, path, conf))
        self.app.event("SetConfiguration", f"{self.ep_path} {path} {conf}")

    @dbus.service.method(ENDPOINT_IFACE, in_signature="o", out_signature="")
    def ClearConfiguration(self, transport):
        path = str(transport)
        self.app.transports.pop(path, None)
        self.app.cleared.append((path, _now_ns()))
        self.app.clears.append((_now_ns(), self.ep_path, path))
        self.app.event("ClearConfiguration", f"{self.ep_path} {path}")


class MediaAppRev(MediaApp):
    """MediaApp registering one SBC endpoint per entry of <uuids>, each
    recording which endpoint bluetoothd configured"""

    name = "media"

    @utils.mainloop_wrap
    def setup(self, impl):
        self.log = logging.getLogger("media")
        self.bus = utils.get_dbus()
        self.transports = {}
        self.transport_ep = {}
        self.setconfs = []
        self.clears = []
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
            ep = _EndpointRev(self.bus, path, self)
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

    def get_setconfs(self):
        return list(self.setconfs)

    def get_clears(self):
        return list(self.clears)

    def transport_endpoints(self):
        return dict(self.transport_ep)

    def set_configuration_caps(self, remote_sep, local_index, caps):
        """As MediaApp.set_configuration, with explicit configuration
        bytes; async, returns op id"""
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
                {"Capabilities": dbus.Array([dbus.Byte(x) for x in caps], signature="y")},
                reply_handler=reply, error_handler=error, timeout=40,
            )

        utils.mainloop_invoke(call)
        return op_id
