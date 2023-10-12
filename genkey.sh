#!/usr/bin/with-contenv bash

LAST_OCTET=$(ip a | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1 | awk -F'.' '{print $4}')
if [ "$LAST_OCTET" -eq 1 ]; then
    echo "IP ends with 1 which is reserver for the Load Balancer. Retrying with a new pod!"
    exit 1
fi

wg genkey | tee privatekey | wg pubkey > publickey

ENDPOINT_PUBLIC_KEY=$(cat publickey)

cat > wg0.conf <<EOF
[Interface]
PrivateKey = $(cat privatekey)
Address = 10.1.0.$LAST_OCTET/24
EOF

wg-quick up ./wg0.conf

ssh -i /ssh -o StrictHostKeyChecking=no -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    if ip link show | grep -q "wg0:"; then
        sudo wg-quick down wg0
    fi
    rm -f privatekey publickey wg0.conf
    wg genkey | tee privatekey | wg pubkey > publickey
ENDSSH

LB_PUBLIC_KEY=$(ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "cat publickey")
LB_PRIVATE_KEY=$(ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "cat privatekey")


cat > wg0-server-b.conf <<EOF
[Interface]
Address = 10.1.0.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface_name -j MASQUERADE;
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface_name -j MASQUERADE;
ListenPort = 51820
PrivateKey = $LB_PRIVATE_KEY
EOF

chmod u=rwx,go= wg0.conf

scp -i /ssh wg0-server-b.conf "$load_balancer_user@$load_balancer_ip:~/wg0.conf"
rm wg0-server-b.conf

ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg-quick up ~/wg0.conf"

ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY allowed-ips 10.1.0.$LAST_OCTET/32"

wg set wg0 peer $LB_PUBLIC_KEY allowed-ips 10.1.0.1/32 endpoint $endpoint_domain:51820 persistent-keepalive 25
