terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.38.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.22.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.PROXMOX_API_ENDPOINT
  username = "${var.PROXMOX_USERNAME}@pam"
  password = var.PROXMOX_PASSWORD
  insecure = true
}

# AWS module
module "gateway" {
  source              = "./modules/aws"
  count               = var.create_aws_instance ? 1 : 0
  instance_type       = var.instance_type
  wireguard_port      = var.wireguard_port
  gateway_public_key  = var.gateway_public_key
  gateway_private_key = var.gateway_private_key
  user_data           = var.aws_user_data
}

resource "null_resource" "prepare_folders" {
  provisioner "remote-exec" {
    when = create
    connection {
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file("~/.ssh/id_rsa")
    }
    inline = [
      "mkdir -p /root/ubuntu-template"
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
      "if [ ! -f ubuntu.img ] || [ \"${var.redownload_proxy_image}\" = true ]; then wget -O ubuntu.img \"${local.iso_url}\"; fi",
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

locals {
  proxy_user   = "wg"
  proxy_ip     = module.proxy.0.address
  gateway_user = var.create_aws_instance ? "ubuntu" : var.custom_gateway_username
  gateway_ip   = var.create_aws_instance ? module.gateway.0.address : var.custom_gateway_ip
}

resource "local_file" "ansible_hosts" {
  depends_on = [module.gateway, module.proxy]
  filename   = "${path.module}/ansible_hosts"
  content = templatefile("${path.module}/templates/ansible/ansible_hosts.template", {
    proxy_ip     = local.proxy_ip,
    proxy_user   = local.proxy_user,
    proxy_key    = var.proxy_private_key,
    gateway_ip   = local.gateway_ip,
    gateway_user = local.gateway_user,
    gateway_key  = var.gateway_private_key,
  })
}

resource "local_file" "wireguard_vars" {
  depends_on = [module.gateway, module.proxy]
  filename   = "${path.module}/ansible/wireguard_vars"
  content = templatefile("${path.module}/templates/ansible/wireguard_vars.template", {
    duckdns_domain   = var.gateway_duckdns_subdomain,
    proxy_ssh_user   = local.proxy_user,
    gateway_ssh_user = local.gateway_user,
    wireguard_port   = var.wireguard_port,
  })
}

resource "local_file" "duckdns_vars" {
  depends_on = [module.gateway, module.proxy]
  filename   = "${path.module}/ansible/duckdns_vars"
  content = templatefile("${path.module}/templates/ansible/duckdns_vars.template", {
    gateway_duckdns_subdomain = var.gateway_duckdns_subdomain,
    proxy_duckdns_subdomain   = var.proxy_duckdns_subdomain,
    duckdns_token             = var.duckdns_token,
  })
}

resource "null_resource" "setup_wireguard_connection" {
  depends_on = [local_file.ansible_hosts, local_file.wireguard_vars]
  provisioner "local-exec" {
    when    = create
    command = "ansible-playbook -v ansible/1-wireguard.yml -i ansible_hosts -e \"@ansible/wireguard_vars\""
  }
}

resource "null_resource" "setup_unattended_upgrades" {
  depends_on = [null_resource.setup_wireguard_connection]
  provisioner "local-exec" {
    when    = create
    command = "ansible-playbook -v ansible/2-unattended-upgrades.yml -i ansible_hosts"
  }
}

# FIXME
# resource "null_resource" "setup_qmeu_guest_agent" {
#   depends_on = [null_resource.setup_unattended_upgrades]
#   provisioner "local-exec" {
#     when    = create
#     command = "ansible-playbook -v ansible/3-qemu-guest-agent.yml -i ansible_hosts"
#   }
# }

# resource "null_resource" "setup_duckdns" {
#   depends_on = [null_resource.setup_qmeu_guest_agent, local_file.duckdns_vars]
#   provisioner "local-exec" {
#     when    = create
#     command = "ansible-playbook -v ansible/4-duckdns.yml -i ansible_hosts -e \"@ansible/duckdns_vars\""
#   }
# }
