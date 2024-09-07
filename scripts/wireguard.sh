#!/bin/bash

# Setup DuckDNS
ansible-playbook -v ansible/1-duckdns.yml -i ansible_hosts -e "@ansible_vars"
DUCKDNS_SETUP=$?
if [ $DUCKDNS_SETUP -ne 0 ]; then
    echo "Unable to create docker container for duckdns. Make sure docker is installed on the VPS."
    exit 1
fi

# Setup unattended upgrades
ansible-playbook -v ansible/2-unattended-upgrades.yml -i ansible_hosts
UPGRADES_SETUP=$?
if [ $UPGRADES_SETUP -ne 0 ]; then
    echo "Unable to setup unattended upgrades. Make sure to use ubuntu/debian on both VMs."
    exit 1
fi

# Setup wireguard
ansible-playbook -v ansible/3-wireguard.yml -i ansible_hosts -e "@ansible_vars"
WIREGUARD_SETUP=$?
if [ $WIREGUARD_SETUP -ne 0 ]; then
    echo "Unable to setup wireguard. Please create a github issue for this one!"
    exit 1
fi

echo "Successfully installed and configured nginx on both VMs"