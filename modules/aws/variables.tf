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

variable "user_data" {
  description = "User Data for instance"
  type        = string
}
