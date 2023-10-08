#!/usr/bin/with-contenv bash
wg genkey | tee privatekey | wg pubkey > publickey