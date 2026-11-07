#!/usr/bin/python3
# Failed Device1.Pair() against gnome-bluetooth master, on a private dbusmock system bus.
#
# widget level : tests/widget-harness (real BluetoothSettingsWidget, Xvfb display)
# library level: GnomeBluetoothPriv.Client.setup_device() / setup_device_finish()
#
# env: OUTDIR (where logs and screenshots go), HARNESS (path of widget-harness)
import os
import subprocess
import sys
import unittest

import dbus
import dbusmock
import gi
from gi.repository import GLib

gi.require_version('GnomeBluetoothPriv', '3.0')
from gi.repository import GnomeBluetoothPriv

OUTDIR = os.environ.get('OUTDIR', '/work/out')
HARNESS = os.environ.get('HARNESS', '/work/widget-harness')

ADDRESS = '11:22:33:44:55:66'
ERRORS = [
    ('AuthenticationRejected', 'Authentication Rejected'),
    ('AuthenticationFailed', 'Authentication Failed'),
]


class PairFailure(dbusmock.DBusTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.start_system_bus()
        cls.start_session_bus()
        cls.dbus_con = cls.get_dbus(True)
        (cls.p_mock, cls.obj_bluez) = cls.spawn_server_template('bluez5', {})

    @classmethod
    def tearDownClass(cls):
        cls.p_mock.terminate()
        cls.p_mock.wait()
        super().tearDownClass()

    def setUp(self):
        self.obj_bluez.Reset()
        self.mock = dbus.Interface(self.obj_bluez, 'org.bluez.Mock')
        self.mock.AddAdapter('hci0', 'my-computer')
        self.path = self.mock.AddDevice('hci0', ADDRESS, 'My Phone')
        self.dev = dbus.Interface(self.dbus_con.get_object('org.bluez', self.path),
                                  dbusmock.MOCK_IFACE)

    def make_pair_fail(self, name, text):
        # the same D-Bus error bluetoothd returns: org.bluez.Error.<name>
        self.dev.AddMethod('org.bluez.Device1', 'Pair', '', '',
                           'raise dbus.exceptions.DBusException("%s", name="org.bluez.Error.%s")'
                           % (text, name))

    def run_widget(self, name, text):
        self.make_pair_fail(name, text)
        os.makedirs(OUTDIR, exist_ok=True)
        env = dict(os.environ)
        env['G_MESSAGES_DEBUG'] = 'all'
        env['GSK_RENDERER'] = 'cairo'
        env['GSETTINGS_BACKEND'] = 'memory'
        env['GDK_BACKEND'] = 'x11'
        tag = name
        out = subprocess.run([HARNESS, OUTDIR, tag], env=env, capture_output=True,
                             text=True, timeout=60)
        with open('%s/%s.stdout.log' % (OUTDIR, tag), 'w') as f:
            f.write(out.stdout)
        with open('%s/%s.stderr.log' % (OUTDIR, tag), 'w') as f:
            f.write(out.stderr)
        return out

    def _widget_case(self, name, text):
        out = self.run_widget(name, text)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        # the library error reaches create_callback(). AuthenticationFailed hits an empty
        # //FIXME branch (no output at all); any other error only gets a g_warning.
        line = 'Setting up %s failed: GDBus.Error:org.bluez.Error.%s: %s' % (self.path, name, text)
        if name == 'AuthenticationFailed':
            self.assertNotIn('Setting up', out.stderr)
        else:
            self.assertIn(line, out.stderr)
        # no dialog, toast, banner in either case; row label back to the original text
        self.assertIn('HARNESS SUMMARY after AdwDialog=0 AdwAlertDialog=0 AdwToast*=0 AdwBanner=0 toplevels=1', out.stdout)
        self.assertIn('HARNESS ROW after label="Not Set Up" visible=1', out.stdout)

    def test_widget_authentication_rejected(self):
        self._widget_case(*ERRORS[0])

    def test_widget_authentication_failed(self):
        self._widget_case(*ERRORS[1])

    def _library_case(self, name, text):
        self.make_pair_fail(name, text)
        client = GnomeBluetoothPriv.Client.new()
        ctx = GLib.main_context_default()
        for _ in range(50):
            ctx.iteration(False)
            GLib.usleep(100000)
            if client.props.num_adapters and client.get_devices().get_n_items():
                break
        device = client.get_devices().get_item(0)
        result = {}

        def cb(c, res, data=None):
            try:
                result['ret'] = c.setup_device_finish(res)
            except GLib.Error as e:
                result['err'] = e
        client.setup_device(device.get_object_path(), True, None, cb)
        for _ in range(100):
            ctx.iteration(False)
            GLib.usleep(50000)
            if result:
                break
        line = 'LIBRARY %s: ' % name
        if 'err' in result:
            e = result['err']
            line += 'setup_device_finish raised: domain=%s code=%s remote=%s message=%s' % (
                e.domain, e.code, Gio_remote_error(e), e.message)
        else:
            line += 'returned %r' % (result.get('ret'),)
        print(line)
        os.makedirs(OUTDIR, exist_ok=True)
        with open('%s/library-%s.log' % (OUTDIR, name), 'w') as f:
            f.write(line + '\n')
        self.assertIn('err', result)
        self.assertIn('org.bluez.Error.' + name, result['err'].message)

    def test_library_authentication_rejected(self):
        self._library_case(*ERRORS[0])

    def test_library_authentication_failed(self):
        self._library_case(*ERRORS[1])


def Gio_remote_error(e):
    from gi.repository import Gio
    return Gio.dbus_error_get_remote_error(e)


if __name__ == '__main__':
    unittest.main(verbosity=2)
