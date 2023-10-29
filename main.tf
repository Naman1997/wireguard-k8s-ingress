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
      "if [ ! -f ubuntu.img ] || [ \"${var.redownload_proxy_image}\" == \"true\" ]; then wget -O ubuntu.img ${local.iso_url}; fi",
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
  gateway_user = var.create_aws_instance ? var.ami_username : var.custom_gateway_username
  gateway_ip   = var.create_aws_instance ? module.gateway.0.address : var.custom_gateway_ip
}

resource "local_file" "ansible_hosts" {
  depends_on = [module.gateway, module.proxy]
  filename   = "${path.module}/ansible_hosts"
  content = templatefile("${path.module}/templates/ansible_hosts.tpl", {
    proxy_ip     = local.proxy_ip,
    proxy_user   = local.proxy_user,
    proxy_key    = var.proxy_private_key,
    gateway_ip   = local.gateway_ip,
    gateway_user = local.gateway_user,
    gateway_key  = var.gateway_private_key,
  })
}

resource "local_file" "ansible_vars" {
  depends_on = [module.gateway, module.proxy]
  filename   = "${path.module}/ansible_vars"
  content = templatefile("${path.module}/templates/vars.tpl", {
    duckdns_domain   = var.duckdns_domain,
    proxy_ssh_user   = local.proxy_user,
    gateway_ssh_user = local.gateway_user,
    wireguard_port   = var.wireguard_port,
  })
}

resource "null_resource" "execute_ansible_playbook" {
  depends_on = [local_file.ansible_hosts, local_file.ansible_vars]
  provisioner "local-exec" {
    when    = create
    command = "ansible-playbook ansible/1-wireguard.yml -i ansible_hosts -e \"@ansible_vars\""
  }
}

# Does not work with dynamic ssh configs
# provider "docker" {
#   alias    = "remote"
#   host     = "ssh://${local.gateway_user}@${local.gateway_ip}:22"
#   ssh_opts = ["-i", "${var.gateway_private_key}"]
# }

# resource "docker_image" "duckdns" {
#   depends_on = [null_resource.execute_ansible_playbook, module.gateway]
#   provider   = docker.remote
#   name       = "lscr.io/linuxserver/duckdns:latest"
# }

# resource "docker_container" "duckdns" {
#   depends_on   = [null_resource.execute_ansible_playbook]
#   provider     = docker.remote
#   image        = docker_image.duckdns.image_id
#   name         = "duckdns"
#   privileged   = false
#   network_mode = "host"
#   restart      = "unless-stopped"
#   env = [
#     "SUBDOMAINS=${var.duckdns_domain}",
#     "TOKEN=${var.duckdns_token}",
#     "UPDATE_IP=ipv4",
#     "LOG_FILE=false"
#   ]
#   volumes {
#     container_path = "/config"
#     host_path      = "/home/${local.gateway_user}/duckdns"
#   }
# }
