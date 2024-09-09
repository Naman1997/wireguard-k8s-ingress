#!/bin/bash 
IN_FACE="{{ interface }}"
WG_PORT="{{ wireguard_port }}"
WG_FACE="wg0"
SUB_NET="10.20.0.0/24"

# Wireguard
iptables -A FORWARD -i $WG_FACE -j ACCEPT
iptables -t nat -A POSTROUTING -o $IN_FACE -j MASQUERADE
iptables -I INPUT 1 -i $IN_FACE -p udp --dport $WG_PORT -j ACCEPT

# HTTP(S)
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT