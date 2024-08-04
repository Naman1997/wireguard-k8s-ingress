# wireguard-k8s-ingress

## This repo is a WIP.

## Hardware Requirements

- A small cloud vm with a public ip - this will act as the gateway for all traffic
- One proxmox vm that connects to the cloud vm over wireguard in cloud
- A kubernetes cluster running in the same subnet as the proxmox vm

## Rough structure

- We're assuming that the user has prepared a VPS and a local VM that is in the same subnet as the k8s cluster. Both VMs can be accessed without any password (passwordless authentication using SSH keys).
- Run some sort of script using a Makefile (make check) that can take in the ansible_host file and check a couple things:
    - Check if localhost has access to a cluster
    - Check if we're able to SSH into both VMs without any password
- Run another script under a separate section in the Makefile (make setup) to start running the ansible scripts to setup the VMs. This should also run the `ansible-galaxy collection install community.docker` command before starting.
- Run another script to now install and setup nginx on both VMs and copy the right templates on both VMs. Restart nginx once files have been copied. This script will also need to figure out the IP addresses of all the worker nodes in the kubernetes cluster so that we can update in the config.
- Run one last script to install the ingress object. And print an example on how to expose nginx to the domain.


# Pending sections

Make sure to install the docker module before running the duckdns playbook
```
ansible-galaxy collection install community.docker
```

Nginx configuration on VPS:

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
```

Nginx configuration on local VM:

```
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
```

Steps for localhost:

```
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