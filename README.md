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

# Setup the connection
make
```

The last step will take some time to complete. Once finished, you can create an ingress object to test the connection.
An example is provided below:

```
# Create a nginx deployment and expose it on port 80
kubectl create deployment nginx --image=nginx --replicas=5
k expose deploy nginx --port 80

# Edit this config to point to your domain
vim ./nginx-example/ingress.yaml

# Create the ingress object
k create -f ./nginx-example/ingress.yaml
```