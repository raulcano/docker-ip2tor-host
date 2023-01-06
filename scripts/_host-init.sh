#!/usr/bin/env bash
# This script runs a few initial steps to configure the Host machine (outside docker)


sudo apt-get update -y
sudo apt-get upgrade -y

# OpenSSH installation
sudo apt-get install -y openssh-server 
sudo apt-get install -y openssh-client
sudo cp /etc/ssh/sshd_config  /etc/ssh/sshd_config.original_copy
# Manual config steps needed here
# ...
# Once done, restart openssh
# sudo /etc/init.d/ssh restart

# Firewall basic installation and config
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw enable <<<y