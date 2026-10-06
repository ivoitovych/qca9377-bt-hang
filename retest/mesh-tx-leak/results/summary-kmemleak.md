# Results: `diag-control` vs `diag-patched`

## kmemleak-enetdown-ext-plain

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -100` | `dmesg: Bluetooth: hci0: Send Mesh Failed -100` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enetdown kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enetdown-ext-shrink

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -100` | `dmesg: Bluetooth: hci0: Send Mesh Failed -100` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enetdown kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enetdown kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enetdown kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enetdown kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enetdown-legacy-plain

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -100` | `dmesg: Bluetooth: hci0: Send Mesh Failed -100` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enetdown kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enetdown-legacy-shrink

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -100` | `dmesg: Bluetooth: hci0: Send Mesh Failed -100` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enetdown kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enetdown kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enetdown kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enetdown kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enetdown kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enetdown kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enetdown kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enodev-ext-plain

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -19` | `dmesg: Bluetooth: hci0: Send Mesh Failed -19` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enodev kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enodev-ext-shrink

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -19` | `dmesg: Bluetooth: hci0: Send Mesh Failed -19` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enodev kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=1 from_mgmt_mesh_add=1 from_hci_sock_create=0` | `enodev kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enodev kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=1 from_mgmt_mesh_add=1 from_hci_sock_create=0` | `enodev kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enodev kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=1 from_mgmt_mesh_add=1 from_hci_sock_create=0` | `enodev kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enodev-legacy-plain

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -19` | `dmesg: Bluetooth: hci0: Send Mesh Failed -19` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enodev kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enodev-legacy-shrink

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -19` | `dmesg: Bluetooth: hci0: Send Mesh Failed -19` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enodev kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enodev kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enodev kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=1 from_mgmt_mesh_add=1 from_hci_sock_create=0` | `enodev kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enodev kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=1 from_mgmt_mesh_add=1 from_hci_sock_create=0` | `enodev kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enodev kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=1 from_mgmt_mesh_add=1 from_hci_sock_create=0` | `enodev kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enomem-ext-plain

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -12` | `dmesg: Bluetooth: hci0: Send Mesh Failed -12` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enomem kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enomem kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enomem kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enomem-ext-shrink

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -12` | `dmesg: Bluetooth: hci0: Send Mesh Failed -12` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enomem kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enomem kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enomem kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enomem-legacy-plain

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -12` | `dmesg: Bluetooth: hci0: Send Mesh Failed -12` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enomem kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enomem kmemleak round=1 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enomem kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=2 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=3 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=4 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=5 stack_scan=on slab_shrink=no unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

## kmemleak-enomem-legacy-shrink

| diag-control | diag-patched |
|---|---|
| `dmesg: Bluetooth: hci0: Send Mesh Failed -12` | `dmesg: Bluetooth: hci0: Send Mesh Failed -12` |
| `Mesh Send tag 1 -> Failed (0x03)` | `Mesh Send tag 1 -> Failed (0x03)` |
| `after_failure outstanding=1 handles=1` | `after_failure outstanding=0 handles=-` **≠** |
| `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `before_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` | `before_teardown kprobe hci_release_dev=0 hci_sock_destruct=1` |
| `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=0` | `after_teardown kprobe handle=1 added=1 mesh_send_sync=0 removed=1` **≠** |
| `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=1` | `after_teardown kprobe hci_release_dev=1 hci_sock_destruct=2` **≠** |
| `enomem kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` | `enomem kmemleak round=1 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` |
| `enomem kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=2 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=3 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=4 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |
| `enomem kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=3 from_mgmt_mesh_add=1 from_hci_sock_create=2` | `enomem kmemleak round=5 stack_scan=on slab_shrink=yes unreferenced=0 from_mgmt_mesh_add=0 from_hci_sock_create=0` **≠** |

diag-control kernel reports: 0

diag-patched kernel reports: 0

