#!/usr/bin/with-contenv bash
ENDPOINT_PUBLIC_KEY=$(cat publickey)
ssh -i /ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY remove
ENDSSH

if [ $? -eq 0 ]; then
    echo "Successfully removed peer with public key: $ENDPOINT_PUBLIC_KEY"
else
    echo "Unable to connect to LB. Unable to remove peer!"
    exit 1
fi