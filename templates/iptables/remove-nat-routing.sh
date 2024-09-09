#!/bin/bash
IN_FACE="{{ interface }}"
WG_PORT="{{ wireguard_port }}"
WG_FACE="wg0"
SUB_NET="10.20.0.0/24"

# Wireguard
iptables -D FORWARD -i $WG_FACE -j ACCEPT
iptables -t nat -D POSTROUTING -o $IN_FACE -j MASQUERADE
iptables -D INPUT -i $IN_FACE -p udp --dport $WG_PORT -j ACCEPT

# HTTP
iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT