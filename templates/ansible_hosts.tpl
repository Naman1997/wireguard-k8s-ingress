[proxy]
proxy ansible_host=${proxy_ip} ansible_user=${proxy_user} ansible_ssh_private_key_file=${proxy_key}

[gateway]
gateway ansible_host=${gateway_ip} ansible_user=${gateway_user} ansible_ssh_private_key_file=${gateway_key}