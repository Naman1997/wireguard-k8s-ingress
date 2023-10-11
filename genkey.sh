#!/usr/bin/with-contenv bash
wg genkey | tee privatekey | wg pubkey > publickey
sh genkey.sh
LAST_NUMBER=$(ip a | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1 | awk -F'.' '{print $4}')

cat <<EOF > wireguard.conf
[Interface]
PrivateKey = $(cat privatekey)
Address = 10.1.0.$LAST_NUMBER/24
EOF

wg-quick up ./wg0.conf

# TODO: Either mount the lb-publickey or ssh to get the value
# TODO: Mount the value of lb-endpoint from a configmap
# TODO: Make the subnet configurable so that it does not clash with the pod cidr
wg set wg0 peer $(cat /lb-publickey) allowed-ips 10.1.0.1/32 endpoint $(cat /lb-endpoint) persistent-keepalive 25