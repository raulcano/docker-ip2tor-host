#!/usr/bin/env bash
chmod +x /home/ip2tor/scripts/host_checkin_hello.sh

# Inspired from https://www.baeldung.com/linux/create-crontab-script
(crontab -l; echo "3 * * * * /home/ip2tor/scripts/host_checkin_hello.sh") | awk '!x[$0]++' | crontab -