terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.22.0"
    }
  }
}

resource "aws_key_pair" "wg_key" {
  key_name   = "wg-keypair"
  public_key = file(var.gateway_public_key)
  tags = {
    Name = "WireGuard K8s Ingress"
  }
}

resource "aws_security_group" "wg_sg" {
  name        = "wg-security-group"
  description = "wg security group for SSH, HTTP, HTTPS and WireGuard"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  ingress {
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard access"
  }

  tags = {
    Name = "WireGuard K8s Ingress"
  }
}

resource "aws_instance" "wg_instance" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.wg_key.key_name
  security_groups = [aws_security_group.wg_sg.name]
  user_data       = var.user_data

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "WireGuard K8s Ingress"
  }
}
