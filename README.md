# wireguard-k8s-ingress

## This repo is a WIP.

## Hardware Requirements

- A small cloud vm with a public ip - this will act as the gateway for all traffic
- One proxmox vm that connects to the cloud vm over wireguard in cloud
- A kubernetes cluster running in the same subnet as the proxmox vm

## Rough structure

- Create a small cloud vm in AWS and install wireguard, docker & fail2ban using user-data
- Create proxmox vm in Proxmox to be used as ingress endpoints (externalIPs) for the cluster
- Wait for ssh to the cloud vm and proxmox vm
- On the cloud vm: Run `scripts/init.sh` (probably need to modify this) (null resource)
- On the proxmox vm: Run `scripts/create-wg-connections.sh` (maybe part of lxc module) (change logic for LAST_OCTET - use index of the lxc resource for this value)
- Test the wireguard connection
- On the cloud vm:
    - Figure out the `UUID` and `PGID` of the user
    - Set up these docker containers:
        - DuckDNS container for ddns (use docker-compose)
        - WatchTower to always keep containers up to date (can be configured to not be added) (staging v/s prod ingress can differ here)
        - Nginx container to proxy domain names to route ingress traffic for duckdns subdomains to the wireguard IPs
        - Certbot for ssl certs for each domain
- On the host(?) run helm install to install k8s ingress with externalIPs of the proxmox vm


# Useful commands/docs
```
sudo systemctl enable wg-quick@wg0.service
sudo wg set wg0 peer <Peer's public key> allowed-ips <Peer's IP address>
wg set wg0 peer <Peer's public key> allowed-ips <Peer's IP address> endpoint <endpoint domain>:<port> persistent-keepalive 25
```

https://github.com/joncombe/docker-nginx-letsencrypt-setup/tree/main [Probably need to see if this can work with stable-alpine image tag]

https://hub.docker.com/r/linuxserver/duckdns [docker-compose section]



```
# Run docker compose with env vars
UID="$(id -u)" GID="$(id -g)" SUBDOMAIN="${domain}" docker-compose up

```

Make sure to install the docker module before running the duckdns playbook
```
ansible-galaxy collection install community.docker
```

Nginx configuration:

```
# Install packages - skipping this step for cert-manager within k8s
# sudo apt install python3-certbot-nginx nginx -y

# Update /etc/nginx/sites-available/default on the vps node with this:

server { 
    server_name namansoracleapps.duckdns.org;
    listen 80;
    location / {
        proxy_pass http://10.1.0.2;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server { 
    server_name namansoracleapps.duckdns.org;
    listen 443;
    location / {
        proxy_pass https://10.1.0.2;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Restart nginx
sudo systemctl restart nginx

# Use certbot to update the config as well as the cert and key paths - skipping this step for cert-manager within k8s
# sudo certbot --nginx --non-interactive --agree-tos --email <email> -d <domain> --test-cert # Remove test-cert for live cert

# Update /etc/nginx/sites-available/default on the relay node with this:
upstream backend {
    server 192.168.0.116;
    server 192.168.0.117;
    server 192.168.0.118;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443;

    location / {
        proxy_pass https://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Restart nginx
sudo systemctl restart nginx

# Install nginx ingress controller and apply the ingress yaml file
kubectl label ns ingress-nginx pod-security.kubernetes.io/enforce=privileged # Needed for a talos cluster
# Edit the external lb IP in the values file 
vim ./nginx-example/nginx-controller.yaml
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --values ./nginx-example/nginx-controller.yaml --create-namespace
kubectl create deployment nginx --image=nginx --replicas=5
k expose deploy nginx --port 80
# Edit this config to point to your domain
vim ./nginx-example/ingress.yaml
k create -f ./nginx-example/ingress.yaml
```

Debug and restart for nginx

```
sudo nginx -t
sudo systemctl restart nginx
```