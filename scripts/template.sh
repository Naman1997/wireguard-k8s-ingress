#!/bin/bash
BOOTDISK=scsi0
qm destroy 6000 || true
qm create 6000 --memory 2048 --net0 virtio,bridge=vmbr0 --cores 2 --sockets 1
qm importdisk 6000 ubuntu-template/ubuntu.img local-lvm
qm set 6000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-6000-disk-0,cache=writeback,discard=on
qm set 6000 --boot c --bootdisk $BOOTDISK
qm resize 6000 $BOOTDISK +5G
qm set 6000 --ipconfig0 ip=dhcp
qm set 6000 -efidisk0 local-lvm:0,format=raw,efitype=4m,pre-enrolled-keys=0
qm set 6000 --ide2 local-lvm:cloudinit
qm set 6000 --ciuser wg --citype nocloud --ipconfig0 ip=dhcp
qm set 6000 --sshkeys '/root/ubuntu-template/id_rsa.pub'
qm set 6000 --name ubuntu-golden --template 1

# Make sure vmid exists
sleep 10
while ! qm config 6000 >/dev/null 2>&1; do
  sleep 5
done

# Make sure disk resize happened
qm=$(qm config 6000 | grep "$BOOTDISK" | cut -d "," -f 4 | cut -d "=" -f 2 | sed s/"M"// | tail -1 | tr -d "G")
while [ "$qm" -lt 5 ]; do
  qm=$(qm config 6000 | grep "$BOOTDISK" | cut -d "," -f 4 | cut -d "=" -f 2 | sed s/"M"// | tail -1 | tr -d "G")
  sleep 5
done