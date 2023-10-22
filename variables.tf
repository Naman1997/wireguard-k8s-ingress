# AWS config
variable "region" {
  description = "AWS Region for this instance"
  type = string
}

# AMI config
variable "ami_id" {
  description = "AMI to be used for this instance"
  type = string
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "AMI ID does not match the expected format (e.g., ami-0123456789abcdef0)."
  }
}

variable "ami_username" {
  description = "Username to be used for SSH"
  type = string
}

# Instance config
variable "instance_type" {
  description = "AWS Instance Type"
  type = string
}

variable "wireguard_port" {
  description = "Port to be used for wireguard. This will add an ingress rule to the security group for the instance."
  type = number
}

variable "ssh_public_key" {
  description = "Public Key file path to be used for SSH"
  type = string
}

variable "user_data" {
  description = "User Data for instance"
  type = string
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

# Jump box config
variable "jumpbox_public_key" {
  description = "SSH public key that will be used to login to wg jumpbox"
  type        = string
}

variable "jumpbox_memory" {
  description = "Jumpbox memory"
  type        = number
}

variable "jumpbox_cores" {
  description = "Jumpbox cpu cores"
  type        = number
}

variable "jumpbox_sockets" {
  description = "Jumpbox cpu sockets"
  type        = number
}

variable "jumpbox_power_onboot" {
  description = "Poweron jumpbox whenever host node powers on"
  type        = bool
}