#!/usr/bin/with-contenv bash

LAST_OCTET=$(ip a | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1 | awk -F'.' '{print $4}')
if [ "$LAST_OCTET" -eq 1 ]; then
    echo "IP uses '1' as the last octet which is reserved for the Load Balancer VM. Retrying with a new pod!"
    exit 1
fi

wg genkey | tee privatekey | wg pubkey > publickey

cat > wg0.conf <<EOF
[Interface]
PrivateKey = $(cat privatekey)
Address = 10.1.0.$LAST_OCTET/24
DNS = 10.96.0.10
EOF

wg-quick up ./wg0.conf

ssh -i /ssh -o StrictHostKeyChecking=no -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    echo "Able to SSH into the load balancer VM!"
ENDSSH

LB_PUBLIC_KEY=$(ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "cat publickey")

# chmod u=rwx,go= wg0.conf

ENDPOINT_PUBLIC_KEY=$(cat publickey)
ssh -i /ssh "$load_balancer_user@$load_balancer_ip" "sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY allowed-ips 10.1.0.$LAST_OCTET/32"
if [ $? -eq 1 ]; then
    echo "You may need to redeploy the load balancer to re-initiate the wg interface"
    exit 1
fi

wg set wg0 peer $LB_PUBLIC_KEY allowed-ips 10.1.0.1/32 endpoint $endpoint_domain:51820 persistent-keepalive 25
if [ $? -eq 0 ]; then
    echo "Successfully added peer with public key: $ENDPOINT_PUBLIC_KEY"
fi

sleep infinity