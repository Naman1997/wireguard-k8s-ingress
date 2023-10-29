[proxy]
proxy ansible_host=${proxy_ip} ansible_user=${proxy_user} ansible_ssh_private_key_file=${proxy_key} ansible_python_interpreter=/usr/bin/python3

[gateway]
gateway ansible_host=${gateway_ip} ansible_user=${gateway_user} ansible_ssh_private_key_file=${gateway_key} ansible_python_interpreter=/usr/bin/python3