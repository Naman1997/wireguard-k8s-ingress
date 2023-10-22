#!/bin/bash

latest_version=$(curl -s https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/latest-releases.yaml | yq '.[] | select(.title == "Standard").iso' | tr -d '"')
sha=$(curl -s https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/latest-releases.yaml | yq '.[] | select(.title == "Standard").sha512' | tr -d '"')


jq -n --arg latest_version $latest_version --arg sha $sha '{"latest_version":$latest_version, "sha":$sha}'