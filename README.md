# wireguard-k8s-ingress

## Prerequisites

- A small cloud vm with a public ip - this will act as the gateway for all traffic
- One proxmox vm that connects to the cloud vm over wireguard in cloud
- A kubernetes cluster running in the same subnet as the proxmox vm
- The host that runs this script needs to have access to the kubernetes cluster


## How to install

```
# Create a copy of config example files - Do not move or delete the example files!
cp ansible/wireguard_vars.example ansible/wireguard_vars
cp ansible/duckdns_vars.example ansible/duckdns_vars
cp ansible_hosts.example ansible_hosts

# Update all the config example files
vim ansible/wireguard_vars
vim ansible/duckdns_vars
vim ansible_hosts

# Allow traffic to the UDP port that you're using for wireguard on your VPS
# The port variable that you used for "wireguard_port" needs to be used

# Bypass CGNAT in case you're using Digital Ocean or Oracle cloud
# Repo: https://github.com/mochman/Bypass_CGNAT

# Optionally you can install updates on both VMs
# It is handled in the script in case you want to skip that, however it can take some time

# Setup the connection
make
```

The last step will take some time to complete. Once finished, you can create an ingress object to test the connection.
An example is provided below:

```
# Create a nginx deployment and expose it on port 80
kubectl create deployment nginx --image=nginx --replicas=5
kubectl expose deploy nginx --port 80

# Edit this config to point to your domain
vim ./nginx-example/ingress.yaml

# Create the ingress object
kubectl create -f ./nginx-example/ingress.yaml
```