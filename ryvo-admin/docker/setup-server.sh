#!/bin/bash
# One-time EC2 server bootstrap. Run on a fresh Ubuntu 24.04 instance:
#   ssh -i ryvo-key.pem ubuntu@<EC2_IP> 'bash -s' < docker/setup-server.sh
set -euo pipefail

echo "==> Updating system packages"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "==> Installing Docker"
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"

echo "==> Adding swap (helps small instances avoid OOM during builds)"
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "==> Installing git"
sudo apt-get install -y git

echo "==> Done. Log out and back in for docker group membership to take effect."
echo "Next: clone the repo and run bash docker/install.sh (prompts for domain, Stripe, Maps, Twilio)."
