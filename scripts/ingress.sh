#!/bin/bash

# Setup wireguard
ansible-playbook -v ansible/4-reverse-proxy.yml -i ansible_hosts -e "@ansible/ansible_vars"
NGINX_SETUP=$?
if [ $NGINX_SETUP -ne 0 ]; then
    echo "Unable to setup reverse proxy configs...exiting."
    exit 1
fi

# Setup wireguard
ansible-playbook -v ansible/5-ingress.yml -i ansible_hosts
INGRESS_SETUP=$?
if [ $INGRESS_SETUP -ne 0 ]; then
    echo "Unable to setup ingress. Please make sure to cleanup older configs!"
    exit 1
fi

echo "Successfully installed nginx controller in nginx-ingress namespace"