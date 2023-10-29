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

# AWS module
module "gateway" {
  source              = "./modules/aws"
  count               = var.create_aws_instance ? 1 : 0
  ami_id              = var.ami_id
  instance_type       = var.instance_type
  wireguard_port      = var.wireguard_port
  gateway_public_key  = var.gateway_public_key
  gateway_private_key = var.gateway_private_key
  user_data           = var.aws_user_data
}

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

resource "null_resource" "prepare_files" {
  depends_on = [data.external.versions]
  provisioner "remote-exec" {
    when = create
    connection {
      host     = var.PROXMOX_IP
      user     = var.PROXMOX_USERNAME
      password = var.PROXMOX_PASSWORD
    }
    inline = [
      "mkdir -p /var/lib/vz/snippets",
      "cd /root/ubuntu-template",
      "wget -O ubuntu.img ${local.iso_url}",
      "calculated_sha=$(sha256sum ubuntu.img | awk '{print $1}')",
      "if [ \"$calculated_sha\" != \"${local.sha}\" ]; then echo \"sha512 mismatch!!!!!\" && rm ubuntu.img && exit 1; fi"
    ]
  }

  provisioner "file" {
    when        = create
    source      = var.proxy_public_key
    destination = "/root/ubuntu-template/id_rsa.pub"
    connection {
      type     = "ssh"
      host     = var.PROXMOX_IP
      user     = var.PROXMOX_USERNAME
      password = var.PROXMOX_PASSWORD
    }
  }
}

resource "null_resource" "create_template" {
  depends_on = [null_resource.prepare_files]
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

resource "time_sleep" "sleep" {
  depends_on      = [null_resource.create_template]
  create_duration = "30s"
}

module "proxy" {
  depends_on     = [time_sleep.sleep]
  source         = "./modules/domain"
  count          = 1
  name           = "wg-proxy"
  memory         = var.proxy_memory
  vcpus          = var.proxy_cores
  sockets        = var.proxy_sockets
  autostart      = var.proxy_power_onboot
  default_bridge = var.DEFAULT_BRIDGE
  target_node    = var.TARGET_NODE
  private_key    = var.proxy_private_key
}

resource "local_file" "ansible_hosts" {
  depends_on = [module.gateway, module.proxy]
  filename   = "${path.module}/ansible_hosts"
  content = templatefile("${path.module}/templates/ansible_hosts.tpl", {
    proxy_ip     = module.proxy.0.address,
    proxy_user   = "wg",
    proxy_key    = var.proxy_private_key,
    gateway_ip   = var.create_aws_instance ? module.gateway.0.address : var.custom_gateway_ip,
    gateway_user = var.create_aws_instance ? var.ami_username : var.custom_gateway_username,
    gateway_key  = var.gateway_private_key,
  })
}

