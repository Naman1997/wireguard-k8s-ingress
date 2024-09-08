# wireguard-k8s-ingress

[![Ansible](https://github.com/Naman1997/wireguard-k8s-ingress/actions/workflows/main.yml/badge.svg)](https://github.com/Naman1997/wireguard-k8s-ingress/actions/workflows/main.yml)

## Objective

The objective of this project is to create an encrypted tunnel used for exposing services on your kubernetes cluster through a VPS. This project is also useful for people who wish learn kubernetes by deploying on their own hardware.

This approach solves a couple issues:
- Minimal cost for a cluster: You can self-host the expensive part of the infastructure and just rent an extremely cheap/free VPS to pass through the traffic
- No need to worry about MITM between the proxy and VPS: Encryted communication using WireGuard
- No need to open ports on your router which is generally required when exposing local services
- Simplified installation: This script takes around 20 minutes to configure everything assuming you're on a brand new VMs
- No need for a static IP on either side of the connection
- Hide your public IP address while still exposing k8s services
- Optionally enable security features such as a WAF from your cloud provider of choice

## What does this project do?

You can read all the steps in the `ansible` and `scripts` directories, however overview of the steps is as follows:
- Checks for relevant binaries that are expected to be present on the host running the script
- Checks for access to a kubernetes cluster from the host running the script
- Checks for passwordless SSH connectivity from the host to the cloud VPS and the proxy VM 
- Installs docker on the cloud VPS and sets up a duckdns container monitoring the IP address of the cloud VM
- Sets up unattended updates on both VMs
- Sets up a WireGuard tunnel between both VMs
- Creates a caddy container on the cloud VM and nginx configuration on the proxy VM for load-balancing the traffic across worker nodes
- Installs nginx ingress controller on the kubernetes cluster using the IP address of the proxy VM as the upstream traffic load-balancer

## Prerequisites

- A small cloud VPS with a public ip - this will act as the gateway for all traffic
- A proxy VM that will connect to the cloud VPS over WireGuard
- Both the proxy VM as well as the cloud VM need to be running Debian or it's derivatives like Ubuntu
- sudo users for both VMs
- A kubernetes cluster running in the same subnet as the proxy VM
- The host that runs this script needs to have access to the kubernetes cluster using kubectl and helm
- The host that runs this script should have passwordless SSH access into both the proxy VM as well as the VPS
- The CIDR 10.20.0.0/24 should be available on both the VPS and the proxy VM

## How to install

### Optional Steps

I would recommend to run the following commands. Although these commands are present in the playbook, you may want to run them because the ansible output does not stream the progress.

```
# On the cloud VPS
sudo apt update -y && sudo apt dist-upgrade -y
sudo apt install docker.io wireguard-tools -y
sudo reboot

# On the proxy VM
sudo apt update -y && sudo apt dist-upgrade -y
sudo apt install nginx wireguard-tools -y
sudo reboot
```

### Configuration

```
# Create a copy of config example files - Do not move or delete the example files!
# Make sure to supply users with sudo privileges for both VMs
cp ansible_vars.example ansible_vars
cp ansible_hosts.example ansible_hosts

# Update all the config example files
vim ansible_vars
vim ansible_hosts
```

The ansible vars to be updated are:
| Variable    | Description |
| -------- | ------- |
| duckdns_domain  | The DuckDNS domain that will be used for inital setup. This domain will be used to track the IP address of your VPS in case it changes.    |
| duckdns_token | Your DuckDNS authentication token.     |
| wireguard_port    | The port to be used for routing wireguard traffic. You will need to make sure that this port along with ports 80 and 443 are accessible from your Cloud Provider.    |
| ssl_email    | Email address to be used for setting up Let's Encrypt certificates.    |

```
# Allow traffic to ports 80, 443 and to the UDP port that you're using for wireguard on your VPS
# For example, if you're using AWS, open ports using Network Security Groups
# The port variable that you used for "wireguard_port" in "ansible_vars" needs to be opened here for UDP traffic

# Setup the connection
make
```

The last step will take some time to complete. Once finished, you can create an ingress object to test the connection.
An example is provided below:

```
# Create a nginx deployment and expose it on port 80
kubectl create deployment nginx --image=nginx --replicas=5
kubectl expose deploy nginx --port 80

# Edit this config to point to your duckdns domain
vim ./nginx-example/ingress.yaml

# Create the ingress object
kubectl create -f ./nginx-example/ingress.yaml
```

## Adding new domains

As a getting started example, this project uses the duckdns domain you provide as a valid domain. In case you wish to use your own domain, you need to follow these steps:
- SSH into your VPS and update `~/caddy/Caddyfile`
- Create an ingress object using the same domain. Note that the ingress object will keep using port 80 in kubernetes as the HTTPS challenge is handled from the VPS

## References

- [Bypass CGNAT](https://github.com/mochman/Bypass_CGNAT)
- [Setup WireGuard Firewall Rules](https://www.cyberciti.biz/faq/how-to-set-up-wireguard-firewall-rules-in-linux/)
