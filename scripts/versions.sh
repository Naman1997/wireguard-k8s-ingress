#!/bin/bash
sha=$(curl -s https://cloud-images.ubuntu.com/mantic/current/SHA256SUMS | grep $1 | awk '{print $1}')
jq -n --arg sha $sha '{"sha":$sha}'