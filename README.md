# wireguard-k8s-lb

## Requirements

- A small vpc in the cloud with a public ip
- A kubernetes cluster with permissions to pass NET_ADMIN and SYS_MODULE process caps

## Rough structure

- Inputs: Public key from the public vpc
- Need a daemonset and a service. Daemonset will run the wireguard image and the public key will be passed into the pod via a configmap.
- The pod should generate it's own public and private keys on runtime (init container?)
- The pod will need some way to send its own public key to the the lb server (scp/ssh?)
- Since multiple pods will try to write to the file at the same time, there needs to be a lock file managed in the cluster
- Let's say pod 1 is created first - it'll capture the lock in a configmap
- While the lock is present in the configmap, other pods need to wait and keep retrying
- The 1st pod will ssh into the lb server and update the wg0 file. It'll also restart the wg0 service
- Once the service is restarted, it'll sleep 5 seconds
- Now, it'll release the lock in the configmap
- Now, other pods will compete to add themselves as the next peer
- The service will basically capture the traffic from the tunnel
- The service can now be consumed by a ingress as a load balancer for internal k8s services


# Useful commands
```
sudo systemctl enable wg-quick@wg0.service
sudo wg set wg0 peer <Peer's public key> allowed-ips <Peer's IP address>
```

Read (this)[https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-ubuntu-20-04] doc - especially the section on ufw

## Credits

This repo contains code from (docker-wireguard)[https://github.com/linuxserver/docker-wireguard]