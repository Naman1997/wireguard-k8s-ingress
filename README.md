# wireguard-k8s-ingress

## Objective

The basic idea is to have an encrypted tunnel for exposing ports from your kubernetes cluster through a VPS. This solves a couple issues that I would wanted to solve:
- Minimal cost for a cluster: You can self-host the expensive part of the infa and just rent an extremely cheap VPS to pass through the traffic
- No need to worry about MITM between the proxy and VPS: Encryted communication using WireGuard
- No need to open ports in your personal firewall which is generally required when exposing local resources
- Simplified installation: This script takes around 20 minutes to configure everything assuming you're on a brand new VMs

## What this might be a bad idea for?

This depends a lot on the server configuration and the bandwidth limits. However, as a general rule of thumb, this may be a bad idea for any bandwidth heavy websites that you may want to expose.

The total latency a client will experience will be the sum of the following:
- The latency between the proxy vm and the VPS
- The latency between the client and the VPS

If let's say, the proxy VM, VPS and Client are in different countries, then this latency will be significant. If all of them are in the same country, but the internet connection for any VM is capped at lets say 1 Mbps, then there will be bandwidth limitations and you can't really steam 1080p videos over that link at that point.

## Prerequisites

- A small cloud vm with a public ip - this will act as the gateway for all traffic
- One vm that connects to the cloud vm over wireguard in cloud
- A kubernetes cluster running in the same subnet as the vm
- The host that runs this script needs to have access to the kubernetes cluster using kubectl and helm
- The host that runs this script should have passwordless SSH access into both the proxy VM as well as the VPS

## How to install

#### Optional Steps

I would recommend to run the following in order to save yourself some time. Although these commands are present in the playbook, you may want to run them because the ansible output does not stream the current state - which means you may have to wait for a bit for these commands to finish.

```
# On the cloud VPS
sudo apt update -y && sudo apt dist-upgrade -y
sudo apt install docker.io nginx wireguard-tools -y
sudo reboot

# On the proxy VM
sudo apt update -y && sudo apt dist-upgrade -y
sudo apt install nginx wireguard-tools -y
sudo reboot
```

#### Configuration

```
# Create a copy of config example files - Do not move or delete the example files!
cp ansible/ansible_vars.example ansible/ansible_vars
cp ansible_hosts.example ansible_hosts

# Update all the config example files
vim ansible/ansible_vars
vim ansible_hosts

# Allow traffic to the UDP port that you're using for wireguard on your VPS
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

# Edit this config to point to your domain
vim ./nginx-example/ingress.yaml

# Create the ingress object
kubectl create -f ./nginx-example/ingress.yaml
```