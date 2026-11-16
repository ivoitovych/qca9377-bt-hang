#!/bin/bash
# 4C: boot the noble cloud image under QEMU/KVM (4 vCPUs, 4 GiB, user-mode network only, no host devices),
# cloud-init runs /mnt/data/vm-run.sh from the data ISO. Console log in vm/console.log.
V=<work dir>/verify/vm
cd $V
nice -n 19 ionice -c 3 qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -nodefaults -display none -serial file:$V/console.log -monitor none \
    -nic user,model=virtio-net-pci \
    -drive file=work.img,if=virtio,format=qcow2 \
    -drive file=seed.iso,if=virtio,format=raw,readonly=on \
    -drive file=results.img,if=virtio,format=raw \
    -drive file=data.iso,if=none,id=cd0,format=raw,readonly=on -device ide-cd,drive=cd0 \
    -no-reboot
echo "qemu exit status $?"
