variable "region" {
  description = "AWS Region for this instance"
  type = string
}

variable "ami_id" {
  description = "AMI to be used for this instance"
  type = string
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "AMI ID does not match the expected format (e.g., ami-0123456789abcdef0)."
  }
}

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

variable "ami_username" {
  description = "Username to be used for SSH"
  type = string
}

variable "user_data" {
  description = "User Data for instance"
  type = string
}