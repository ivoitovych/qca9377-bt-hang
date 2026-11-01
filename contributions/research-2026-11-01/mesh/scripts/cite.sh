#!/bin/bash
# cite.sh <commit> - the source lines this research cites, by git grep at
# <commit> (blobs, not the working tree), into evidence/cite-<commit>.txt.
set -u
R=/root/exp/agent-work/research-mesh
G=/root/exp/qca9377-bt-hang/cache/linux
C="${1:?commit}"
mkdir -p "$R/evidence"
OUT=$R/evidence/cite-$C.txt
{
echo "# git -C $G grep -n -e <pattern> $C -- <file>   ($(date '+%F %T'))"
g() { echo "## $1 :: $2"; git -C "$G" grep -n -F -e "$2" "$C" -- "$1"; }
g net/bluetooth/hci_sync.c "u16 duration = adv->mesh ? adv->timeout :"
g net/bluetooth/hci_sync.c "adv->timeout * MSEC_PER_SEC;"
g net/bluetooth/hci_sync.c "set->duration = cpu_to_le16(duration / 10);"
g net/bluetooth/hci_sync.c "/* Only use work for scheduling instances with legacy advertising */"
g net/bluetooth/hci_sync.c "secs_to_jiffies(timeout));"
g net/bluetooth/hci_sync.c "if (!test_bit(HCI_RUNNING, &hdev->flags))"
g net/bluetooth/hci_sync.c "mutex_lock(&hdev->unregister_lock);"
g net/bluetooth/hci_sync.c "mutex_lock(&hdev->cmd_sync_work_lock);"
g net/bluetooth/hci_sync.c "_hci_cmd_sync_cancel_entry(hdev, entry, -ECANCELED);"
g net/bluetooth/hci_sync.c "/* Leave the backlog to hci_cmd_sync_clear() */"
g net/bluetooth/hci_event.c "hci_remove_adv_instance(hdev, ev->handle);"
g net/bluetooth/hci_event.c "mgmt_advertising_removed(NULL, hdev, ev->handle);"
g net/bluetooth/hci_core.c "hci_dev_set_flag(hdev, HCI_UNREGISTER);"
g net/bluetooth/hci_core.c "hci_cmd_sync_clear(hdev);"
g net/bluetooth/hci_core.c "mgmt_index_removed(hdev);"
g net/bluetooth/hci_core.c "adv->remaining_time = timeout;"
g net/bluetooth/hci_core.c "adv->duration = hdev->def_multi_adv_rotation_duration;"
g net/bluetooth/hci_core.c "list_del(&hdev->list);"
g net/bluetooth/mgmt.c "timeout = __le16_to_cpu(cp->timeout);"
g net/bluetooth/mgmt.c "if (timeout && !hdev_is_powered(hdev)) {"
g net/bluetooth/mgmt.c "static int mesh_send_done_sync(struct hci_dev *hdev, void *data)"
g net/bluetooth/mgmt.c "static void mesh_next(struct hci_dev *hdev, void *data, int err)"
g net/bluetooth/mgmt.c "static void mesh_send_done(struct work_struct *work)"
g net/bluetooth/mgmt.c "hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next);"
g net/bluetooth/mgmt.c "hci_dev_clear_flag(hdev, HCI_MESH_SENDING);"
g net/bluetooth/mgmt.c "hci_dev_set_flag(hdev, HCI_MESH_SENDING);"
g net/bluetooth/mgmt.c "sending = hci_dev_test_flag(hdev, HCI_MESH_SENDING);"
g net/bluetooth/mgmt.c "mesh_send_interval = msecs_to_jiffies((send->cnt) * 25);"
g net/bluetooth/mgmt.c "duration = send->cnt * INTERVAL_TO_MS(hdev->le_adv_max_interval);"
g net/bluetooth/mgmt.c "timeout = 1000;"
g net/bluetooth/mgmt.c "if (err != -ECANCELED)"
g net/bluetooth/mgmt.c "cancel_delayed_work_sync(&hdev->mesh_send_done);"
g net/bluetooth/mgmt.c "if (!send->adv_data_len || send->adv_data_len > 31)"
g net/bluetooth/mgmt.c "list_for_each_entry(hdev, &hci_dev_list, list) {"
g net/bluetooth/mgmt_util.c "sock_hold(sk);"
g net/bluetooth/mgmt_util.c "list_add_tail(&mesh_tx->list, &hdev->mesh_pending);"
g include/net/bluetooth/mgmt.h "__u8   cnt;"
g include/net/bluetooth/hci_core.h "struct delayed_work	mesh_send_done;"
} > "$OUT" 2>&1
echo "$OUT"
grep -c "" "$OUT"
