#!/usr/bin/with-contenv bash

if ip link show | grep -q "wg0:"; then
    sudo wg-quick down wg0
fi
rm -f privatekey publickey wg0.conf
wg genkey | tee privatekey | wg pubkey > publickey

INTERFACE_NAME=$(ip route get 8.8.8.8 | awk '/dev/ { print $5 }')
LB_PRIVATE_KEY=$(ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "cat privatekey")
cat > wg0.conf <<EOF
[Interface]
Address = 10.1.0.1/24
SaveConfig = true
PostUp = iptables -I INPUT -p TCP --dport 80 -j ACCEPT; iptables -I INPUT -p TCP --dport 443 -j ACCEPT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE_NAME -j MASQUERADE;
PostDown = iptables -D INPUT -p TCP --dport 80 -j ACCEPT; iptables -D INPUT -p TCP --dport 443 -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE_NAME -j MASQUERADE;
ListenPort = 51820
PrivateKey = $LB_PRIVATE_KEY
EOF

sudo wg-quick up ~/wg0.conf