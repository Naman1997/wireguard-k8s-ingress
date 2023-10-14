#!/bin/rbash
ssh -i /workspace/ssh -vvv -T -o StrictHostKeyChecking=no $load_balancer_user@$load_balancer_ip LB_PRIVATE_KEY=$LB_PRIVATE_KEY /bin/bash <<ENDSSH
    if ip link show | grep -q "wg0:"; then
        sudo wg-quick down wg0
    fi
    rm -f privatekey publickey wg0.conf
    wg genkey | tee privatekey | wg pubkey > publickey
ENDSSH

LB_PRIVATE_KEY=$(ssh -i /workspace/ssh "$load_balancer_user@$load_balancer_ip" "cat privatekey")

ssh -i /workspace/ssh -T $load_balancer_user@$load_balancer_ip LB_PRIVATE_KEY=$LB_PRIVATE_KEY /bin/bash <<ENDSSH
cat > wg0.conf <<EOF
[Interface]
Address = 10.1.0.1/24
SaveConfig = true
PostUp = iptables -I INPUT -p TCP --dport 80 -j ACCEPT; iptables -I INPUT -p TCP --dport 443 -j ACCEPT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface_name -j MASQUERADE;
PostDown = iptables -D INPUT -p TCP --dport 80 -j ACCEPT; iptables -D INPUT -p TCP --dport 443 -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface_name -j MASQUERADE;
ListenPort = 51820
PrivateKey = $LB_PRIVATE_KEY
ENDSSH

ssh -i /workspace/ssh "$load_balancer_user@$load_balancer_ip" "sudo wg-quick up ~/wg0.conf"