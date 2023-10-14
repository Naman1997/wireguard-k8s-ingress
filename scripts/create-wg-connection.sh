#!/bin/rbash


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# sleep infinity
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ssh -i /workspace/ssh -o StrictHostKeyChecking=no -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    echo "Able to SSH into the load balancer VM!"
ENDSSH

LAST_OCTET=$(ip a | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -n1 | awk -F'.' '{print $4}')
if [ "$LAST_OCTET" -eq 1 ]; then
    echo "IP uses '1' as the last octet which is reserved for the Load Balancer VM. Retrying with a new pod!"
    exit 1
fi

CLIENT_PRIVATE_KEY=$(cat /workspace/config/CLIENT_PRIVATE_KEY)
ssh -i /workspace/ssh -T $load_balancer_user@$load_balancer_ip CLIENT_PRIVATE_KEY=$CLIENT_PRIVATE_KEY LAST_OCTET=$LAST_OCTET /bin/bash <<ENDSSH
cat > wg0_$LAST_OCTET.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.1.0.$LAST_OCTET/24
ENDSSH

scp -i /workspace/ssh $load_balancer_user@$load_balancer_ip:wg0_$LAST_OCTET.conf wg0.conf
sudo wg-quick up wg0.conf

LB_PUBLIC_KEY=$(ssh -i /workspace/ssh "$load_balancer_user@$load_balancer_ip" "cat publickey")
ENDPOINT_PUBLIC_KEY=$(cat /workspace/config/CLIENT_PUBLIC_KEY)
ssh -i /workspace/ssh "$load_balancer_user@$load_balancer_ip" "sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY allowed-ips 10.1.0.$LAST_OCTET/32"
if [ $? -eq 1 ]; then
    echo "You may need to redeploy the load balancer to re-initiate the wg interface"
    exit 1
fi

wg set wg0 peer $LB_PUBLIC_KEY allowed-ips 10.1.0.1/32 endpoint $endpoint_domain:51820 persistent-keepalive 25
if [ $? -eq 0 ]; then
    echo "Successfully added peer with public key: $ENDPOINT_PUBLIC_KEY"
fi

sleep infinity