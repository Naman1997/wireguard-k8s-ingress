output "public_ip" {
  value = aws_instance.wg_instance.public_ip
}

output "ssh_username" {
  value = var.ami_username
}