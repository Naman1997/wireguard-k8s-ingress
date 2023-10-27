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

resource "null_resource" "update_known_hosts" {
  depends_on = [data.external.address]

  provisioner "local-exec" {
    command = <<-EOT
      n=0
      until [ "$n" -ge 10 ]
      ssh-keygen -R $ADDRESS &> /dev/null || true
      do
        echo "Attempt number: $n"
        ssh-keyscan -H $ADDRESS >> ~/.ssh/known_hosts
        ssh -q -o StrictHostKeyChecking=no wg@$ADDRESS exit < /dev/null
        if [ $? -eq 0 ]; then
          echo "Successfully added $ADDRESS"
          break
        fi
        n=$((n+1)) 
        sleep $[ ( $RANDOM % 10 )  + 1 ]s
      done
    EOT
    environment = {
      ADDRESS = data.external.address.result["address"]
    }
    when = create
  }
}

resource "null_resource" "wait_for_ssh" {
  depends_on = [null_resource.update_known_hosts]
  provisioner "remote-exec" {
    connection {
      host        = data.external.address.result["address"]
      user        = "wg"
      private_key = file(var.private_key)
      timeout     = "5m"
    }

    inline = [
      "# Connected!",
      "echo Connected to `hostname`"
    ]
  }
}
