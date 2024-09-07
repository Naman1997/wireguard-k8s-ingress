#!/bin/bash

# Make sure all binaries are available
which ansible ansible-galaxy kubectl helm
BINARIES_CHECK=$?
if [ $BINARIES_CHECK -ne 0 ]; then
    echo "Some binay is missing (ansible ansible-galaxy kubectl helm)...exiting"
    exit 1
fi

# Install docker module for ansible
ansible-galaxy collection install community.docker

if [ ! -f ansible/ansible_vars ]; then
    echo "File 'ansible/ansible_vars' not found!"
    exit 1
fi

if [ ! -f ansible_hosts ]; then
    echo "File 'ansible_hosts' not found!"
    exit 1
fi

if cmp --silent -- "ansible/ansible_vars" "ansible/ansible_vars.example"; then
  echo "File 'ansible/ansible_vars' has not been modified!"
fi

if cmp --silent -- "ansible_hosts" "ansible_hosts.example"; then
  echo "File 'ansible_hosts' has not been modified!"
fi

# Check cluster access
kubectl get nodes
CLUSTER_ACCESS=$?
if [ $CLUSTER_ACCESS -ne 0 ]; then
    echo "Unable to access cluster...exiting"
    exit 1
fi

# Check ssh access
ansible-playbook -v ansible/0-checks.yml -i ansible_hosts
SSH_ACCESS=$?
if [ $SSH_ACCESS -ne 0 ]; then
    echo "Unable to SSH into both VMs...exiting"
    exit 1
fi

echo "All checks passed successfully!"