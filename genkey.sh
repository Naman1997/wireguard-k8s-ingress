#!/usr/bin/with-contenv bash

# Step 1: Generate public and private keys for Server A
wg genkey | tee privatekey | wg pubkey > publickey

# Step 2: Create a local variable for the last number of the IP address
LAST_NUMBER=$(ip a | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1 | awk -F'.' '{print $4}')
ENDPOINT_PUBLIC_KEY=$(cat publickey)

# Step 3: Generate wg0.conf file for Server A
cat > wg0.conf <<EOF
[Interface]
PrivateKey = $(cat privatekey)
Address = 10.1.0.$LAST_NUMBER/24
EOF

# Step 4: Start the WireGuard interface on Server A
wg-quick up ./wg0.conf

# Step 6: Generate the wg0.conf file for Server B
ssh -i /ssh -o StrictHostKeyChecking=no -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    wg genkey | tee privatekey | wg pubkey > publickey
ENDSSH

server_b_public_key=$(ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "cat publickey")

# Step 7: Transfer the wg0.conf file to Server B (Load Balancer)
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

# Step 8: Start the WireGuard interface on Server B (Load Balancer)
ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg-quick up ~/wg0.conf"

# Step 9: Add a peer to Server B's WireGuard interface
ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY allowed-ips 10.1.0.$LAST_NUMBER/32"

# Step 10: Close the SSH session to Server B (Load Balancer)

# Step 11: Add a peer to Server A's WireGuard interface
wg set wg0 peer $server_b_public_key allowed-ips 10.1.0.1/32 endpoint $endpoint_domain:51820 persistent-keepalive 25
