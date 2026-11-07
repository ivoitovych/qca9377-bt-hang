# Runs INSIDE the device-under-test guest. A D-Bus client that sets a
# discovery filter (optional) and calls StartDiscovery on hci0, then stays
# connected (the discovery session ends when this process exits).
# usage: vm_discovery.py <transport|none> <discoverable|none>
import sys
import time

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

transport, discoverable = sys.argv[1], sys.argv[2]
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
adapter = dbus.Interface(bus.get_object("org.bluez", "/org/bluez/hci0"),
                         "org.bluez.Adapter1")
flt = {}
if transport != "none":
    flt["Transport"] = transport
if discoverable != "none":
    flt["Discoverable"] = dbus.Boolean(discoverable == "true")


def log(msg):
    print("%.6f %s" % (time.time(), msg), flush=True)


if flt:
    log("SetDiscoveryFilter %r" % (flt,))
    adapter.SetDiscoveryFilter(flt)
else:
    log("no SetDiscoveryFilter")
adapter.StartDiscovery()
log("StartDiscovery returned")
GLib.MainLoop().run()
