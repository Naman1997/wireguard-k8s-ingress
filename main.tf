terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.22.0"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.PROXMOX_API_ENDPOINT
  pm_user         = "${var.PROXMOX_USERNAME}@pam"
  pm_password     = var.PROXMOX_PASSWORD
  pm_tls_insecure = true
}

# resource "aws_key_pair" "wg_key" {
#   key_name   = "wg-keypair"
#   public_key = file(var.ssh_public_key)
#   tags = {
#     Name = "WireGuard K8s Ingress"
#   }
# }

# resource "aws_security_group" "wg_sg" {
#   name        = "wg-security-group"
#   description = "wg security group for SSH, HTTP, HTTPS and WireGuard"

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow all outbound traffic"
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "SSH access"
#   }

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "HTTP access"
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "HTTPS access"
#   }

#   ingress {
#     from_port   = var.wireguard_port
#     to_port     = var.wireguard_port
#     protocol    = "udp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "WireGuard access"
#   }

#   tags = {
#     Name = "WireGuard K8s Ingress"
#   }
# }

# resource "aws_instance" "wg_instance" {
#   ami           = var.ami_id
#   instance_type = var.instance_type
#   key_name      = aws_key_pair.wg_key.key_name
#   security_groups = [aws_security_group.wg_sg.name]
#   user_data = var.user_data

#   root_block_device {
#     volume_size = 8
#   }

#   tags = {
#     Name = "WireGuard K8s Ingress"
#   }
# }

resource "null_resource" "prepare_folders" {
  provisioner "remote-exec" {
    connection {
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file("~/.ssh/id_rsa")
    }

    inline = [
      "rm -rf /root/ubuntu-template",
      "mkdir /root/ubuntu-template"
    ]
  }
}

data "external" "versions" {
  depends_on = [null_resource.prepare_folders]
  program = [
    "${path.module}/scripts/versions.sh",
    "${local.version}"
  ]
}

locals {
  version = "mantic-server-cloudimg-amd64.img"
  sha     = data.external.versions.result["sha"]
  iso_url = "https://cloud-images.ubuntu.com/mantic/current/${local.version}"
}

# resource "null_resource" "prepare_files" {
#   depends_on = [data.external.versions]
#   provisioner "remote-exec" {
#     when = create
#     connection {
#       host     = var.PROXMOX_IP
#       user     = var.PROXMOX_USERNAME
#       password = var.PROXMOX_PASSWORD
#     }

#     inline = [
#       "mkdir -p /var/lib/vz/snippets",
#       "cd /root/ubuntu-template",
#       "wget -O ubuntu.img ${local.iso_url}",
#       "calculated_sha=$(sha256sum ubuntu.img | awk '{print $1}')",
#       "if [ \"$calculated_sha\" != \"${local.sha}\" ]; then echo \"sha512 mismatch!!!!!\" && rm ubuntu.img && exit 1; fi"
#     ]
#   }

#   provisioner "file" {
#     when        = create
#     source      = var.jumpbox_public_key
#     destination = "/root/ubuntu-template/id_rsa.pub"
#     connection {
#       type     = "ssh"
#       host     = var.PROXMOX_IP
#       user     = var.PROXMOX_USERNAME
#       password = var.PROXMOX_PASSWORD
#     }
#   }
# }

resource "null_resource" "create_template" {
  # depends_on = [null_resource.prepare_files]

  provisioner "remote-exec" {
    when = create
    connection {
      host     = var.PROXMOX_IP
      user     = var.PROXMOX_USERNAME
      password = var.PROXMOX_PASSWORD
    }

    script = "${path.root}/scripts/template.sh"
  }
}

resource "proxmox_vm_qemu" "wg-jumpbox" {
  depends_on  = [null_resource.create_template]
  name        = "wg-jumpbox"
  target_node = var.TARGET_NODE
  memory      = var.jumpbox_memory
  cores       = var.jumpbox_cores
  agent       = 1
  onboot      = var.jumpbox_power_onboot
  bootdisk    = "scsi0"
  clone       = "ubuntu-golden"
  full_clone  = true
  network {
    model  = "virtio"
    bridge = var.DEFAULT_BRIDGE
  }
}
