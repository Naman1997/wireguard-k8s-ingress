#!/usr/bin/with-contenv bash

wg genkey | tee privatekey | wg pubkey > publickey

LAST_NUMBER=$(ip a | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1 | awk -F'.' '{print $4}')
ENDPOINT_PUBLIC_KEY=$(cat publickey)

cat > wg0.conf <<EOF
[Interface]
PrivateKey = $(cat privatekey)
Address = 10.1.0.$LAST_NUMBER/24
EOF

wg-quick up ./wg0.conf

ssh -i /ssh -o StrictHostKeyChecking=no -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    wg genkey | tee privatekey | wg pubkey > publickey
ENDSSH

server_b_public_key=$(ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "cat publickey")

cat > wg0-server-b.conf <<EOF
    [Interface]
    Address = 10.1.0.1/24
    SaveConfig = true
    PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface_name -j MASQUERADE;
    PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface_name -j MASQUERADE;
    ListenPort = 51820
    PrivateKey = $(cat privatekey)
EOF
chmod u=rwx,go= wg0.conf
scp -i /ssh wg0-server-b.conf "$load_balancer_user@$load_balancer_ip:~/wg0.conf"

ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg-quick up ~/wg0.conf"

ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY allowed-ips 10.1.0.$LAST_NUMBER/32"

wg set wg0 peer $server_b_public_key allowed-ips 10.1.0.1/32 endpoint $endpoint_domain:51820 persistent-keepalive 25
