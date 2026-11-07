# SPDX-License-Identifier: GPL-2.0-or-later
"""paired_hosts: two hosts paired over BR/EDR, host0 initiating (the
same steps as PipeWire's test/bluezenv/conftest.py, for bluetoothctl 5.72)"""

import pytest


def vm_unpair(peer):
    """Runs in a VM: drop the kernel's link key for <peer>. The guests are
    reused between tests and the kernel keeps the key of the previous
    test's pairing across the bluetoothd restart, so the next Pair() would
    fail with AlreadyExists."""
    import subprocess

    from pytest_bluezenv import utils

    exe = utils.find_exe("tools", "btmgmt")
    res = subprocess.run([exe, "--index", "0", "unpair", peer],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         encoding="utf-8", timeout=10)
    return res.stdout


@pytest.fixture
def paired_hosts(hosts):
    host0, host1 = hosts

    host0.call(vm_unpair, host1.bdaddr)
    host1.call(vm_unpair, host0.bdaddr)

    host0.bluetoothctl.send("scan on\n")
    host0.bluetoothctl.expect(f"Controller {host0.bdaddr.upper()} Discovering: yes")

    host1.bluetoothctl.send("pairable on\n")
    host1.bluetoothctl.expect("Changing pairable on succeeded")
    host1.bluetoothctl.send("discoverable on\n")
    host1.bluetoothctl.expect(f"Controller {host1.bdaddr.upper()} Discoverable: yes")

    host0.bluetoothctl.expect(f"Device {host1.bdaddr.upper()}")
    host0.bluetoothctl.send(f"pair {host1.bdaddr}\n")

    idx, m = host0.bluetoothctl.expect(r"Confirm passkey (\d+).*:")
    key = m[0].decode("utf-8")
    host1.bluetoothctl.expect(f"Confirm passkey {key}")
    host0.bluetoothctl.send("yes\n")
    host1.bluetoothctl.send("yes\n")
    host0.bluetoothctl.expect("Pairing successful")

    yield hosts
