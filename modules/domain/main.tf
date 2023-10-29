terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

resource "proxmox_vm_qemu" "node" {
  name        = var.name
  memory      = var.memory
  cores       = var.vcpus
  sockets     = var.sockets
  onboot      = var.autostart
  target_node = var.target_node
  scsihw      = "virtio-scsi-pci"
  full_clone = true
  clone      = "ubuntu-golden"

  network {
    model  = "virtio"
    bridge = var.default_bridge
  }
}

data "external" "address" {
  depends_on  = [proxmox_vm_qemu.node]
  working_dir = path.root
  program     = ["bash", "scripts/ip.sh", "${lower(proxmox_vm_qemu.node.network[0].macaddr)}"]
}