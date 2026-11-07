#!/usr/bin/python3
# Widget-level run of a failed Device1.Pair() for a chosen set of D-Bus errors.
# Observations only: the harness output is recorded, the test fails only if the
# harness itself fails. Used for the unpatched and the MR !137 builds.
#
# env: OUTDIR, HARNESS, ERRORS (comma list, default all three), CONTROL=1 (toast counter control)
import os
import subprocess
import unittest

import dbus
import dbusmock

OUTDIR = os.environ.get('OUTDIR', '/out')
HARNESS = os.environ.get('HARNESS', '/work/widget-harness')
ERRORS = [e for e in os.environ.get('ERRORS', 'AuthenticationRejected,AuthenticationFailed,AuthenticationCanceled').split(',') if e]
ADDRESS = '11:22:33:44:55:66'


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

    def run_harness(self, tag, error, control=False):
        if error:
            text = ''.join(' ' + c if c.isupper() and i else c for i, c in enumerate(error))
            self.dev.AddMethod('org.bluez.Device1', 'Pair', '', '',
                               'raise dbus.exceptions.DBusException("%s", name="org.bluez.Error.%s")'
                               % (text, error))
        os.makedirs(OUTDIR, exist_ok=True)
        env = dict(os.environ)
        env.update(G_MESSAGES_DEBUG='all', GSK_RENDERER='cairo', GSETTINGS_BACKEND='memory',
                   GDK_BACKEND='x11', GTK_A11Y='none')
        if control:
            env['HARNESS_CONTROL_TOAST'] = '1'
        out = subprocess.run([HARNESS, OUTDIR, tag], env=env, capture_output=True,
                             text=True, timeout=60)
        open('%s/%s.stdout.log' % (OUTDIR, tag), 'w').write(out.stdout)
        open('%s/%s.stderr.log' % (OUTDIR, tag), 'w').write(out.stderr)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)

    def test_errors(self):
        for e in ERRORS:
            self.setUp()
            self.run_harness(e, e)

    def test_control(self):
        if os.environ.get('CONTROL') == '1':
            self.run_harness('control-toast', None, control=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
