output "address" {
  value       = proxmox_vm_qemu.node.network[0].macaddr
  description = "MAC Address of the node"
}

output "name" {
  value       = proxmox_vm_qemu.node.name
  description = "Name of the node"
}