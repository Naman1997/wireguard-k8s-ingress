# wireguard-k8s-lb

## This repo is a WIP.

## Hardware Requirements

- A small cloud vm with a public ip - this will act as the gateway for all traffic
- At least one lxc container that connects to the cloud vm over wireguard in cloud
- A kubernetes cluster running in the same subnet as the lxc containers

## Rough structure

- Create a small cloud vm in AWS and install wireguard, docker & fail2ban using user-data
- Create lxc containers in Proxmox to be used as ingress endpoints (externalIPs) for the cluster
- Wait for ssh to the cloud vm and lxc containers
- On the cloud vm: Run `scripts/init.sh` (probably need to modify this) (null resource)
- On the lxc containers: Run `scripts/create-wg-connections.sh` (maybe part of lxc module) (change logic for LAST_OCTET - use index of the lxc resource for this value)
- Test the wireguard connection
- On the cloud vm:
    - Figure out the `UUID` and `PGID` of the user
    - Set up these docker containers:
        - DuckDNS container for ddns (use docker-compose)
        - WatchTower to always keep containers up to date (can be configured to not be added) (staging v/s prod ingress can differ here)
        - Nginx container to proxy domain names to route ingress traffic for duckdns subdomains to the wireguard IPs
        - Certbot for ssl certs for each domain
- On the host(?) run helm install to install k8s ingress with externalIPs of the lxc containers


# Useful commands/docs
```
sudo systemctl enable wg-quick@wg0.service
sudo wg set wg0 peer <Peer's public key> allowed-ips <Peer's IP address>
wg set wg0 peer <Peer's public key> allowed-ips <Peer's IP address> endpoint <endpoint domain>:<port> persistent-keepalive 25
```

https://github.com/joncombe/docker-nginx-letsencrypt-setup/tree/main [Probably need to see if this can work with stable-alpine image tag]

https://hub.docker.com/r/linuxserver/duckdns [docker-compose section]