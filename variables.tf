# AWS config
variable "region" {
  description = "AWS Region for this instance"
  type        = string
}

# Gateway config
variable "create_aws_instance" {
  description = "Specifies if an AWS VM should be created for the gateway or not. Custom gateway settings cannot be empty if this is false."
  type        = bool
}

variable "instance_type" {
  description = "AWS Instance Type"
  type        = string
}

variable "wireguard_port" {
  description = "Port to be used for wireguard. This will add an ingress rule to the security group for the instance."
  type        = number
}

variable "gateway_public_key" {
  description = "Public Key file path to be used for SSH"
  type        = string
}

variable "gateway_private_key" {
  description = "Private Key file path to be used for SSH"
  type        = string
}

variable "custom_gateway_ip" {
  description = "Private Key file path to be used for SSH"
  type        = string
}

variable "custom_gateway_username" {
  description = "Private Key file path to be used for SSH"
  type        = string
}

variable "aws_user_data" {
  description = "User Data for instance"
  type        = string
}

# Proxmox config
variable "PROXMOX_API_ENDPOINT" {
  description = "API endpoint for proxmox"
  type        = string
}

variable "PROXMOX_USERNAME" {
  description = "User name used to login proxmox"
  type        = string
}

variable "PROXMOX_PASSWORD" {
  description = "Password used to login proxmox"
  type        = string
}

variable "PROXMOX_IP" {
  description = "IP address for proxmox"
  type        = string
}

variable "DEFAULT_BRIDGE" {
  description = "Bridge to use when creating VMs in proxmox"
  type        = string
}

variable "TARGET_NODE" {
  description = "Target node name in proxmox"
  type        = string
}

variable "TEMPLATE_STORAGE" {
  description = "Name of storage containing container templates in proxmox"
  type        = string
}

# Proxy config
variable "proxy_public_key" {
  description = "SSH public key that will be used to login to wg proxy"
  type        = string
}

variable "proxy_private_key" {
  description = "SSH private key that will be used to login to wg proxy"
  type        = string
}

variable "proxy_memory" {
  description = "proxy memory"
  type        = number
}

variable "proxy_cores" {
  description = "proxy cpu cores"
  type        = number
}

variable "proxy_sockets" {
  description = "proxy cpu sockets"
  type        = number
}

variable "proxy_power_onboot" {
  description = "Poweron proxy whenever host node powers on"
  type        = bool
}

variable "redownload_proxy_image" {
  description = "Re-downloads the ubuntu cloud image if set to true"
  type        = bool
}

locals {
  # tflint-ignore: terraform_unused_declarations
  validate_versioning = (
    var.create_aws_instance ||
    (can(
      regex(
        "^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$", var.custom_gateway_ip
      )
    ) && var.custom_gateway_username != null && var.custom_gateway_username != "")
  ) ? true : tobool("Either create_aws_instance needs to be false or valid values are needed for custom_gateway_ip and custom_gateway_username")
}

# DuckDNS config
variable "gateway_duckdns_subdomain" {
  description = "DuckDNS domain that you wish to use for dynamic dns on the vps"
  type        = string
}

variable "proxy_duckdns_subdomain" {
  description = "DuckDNS domain that you wish to use for dynamic dns on the local proxy vm"
  type        = string
}

variable "duckdns_token" {
  description = "DuckDNS token that will be used to setup dynamic dns using https://hub.docker.com/r/linuxserver/duckdns"
  type        = string
}
