#!/usr/bin/with-contenv bash
ENDPOINT_PUBLIC_KEY=$(cat publickey)
ssh -i /ssh -o StrictHostKeyChecking=no -T $load_balancer_user@$load_balancer_ip /bin/bash <<ENDSSH
    sudo wg set wg0 peer $ENDPOINT_PUBLIC_KEY remove
ENDSSH