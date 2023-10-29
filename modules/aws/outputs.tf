output "address" {
  value       = aws_instance.wg_instance.associate_public_ip_address
  description = "IP Address of the node"
}
