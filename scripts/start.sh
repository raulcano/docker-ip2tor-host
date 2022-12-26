#!/usr/bin/env bash

################
# Preparation of scheduled tasks
# Inspired from https://www.baeldung.com/linux/create-crontab-script
################

# A simple task to check visually that cron is running
(crontab -l; echo "* * * * * touch /home/ip2tor/logs/cron-alive") | awk '!x[$0]++' | crontab -
# Send a HELLO (code 0) to the host every 3 minutes
(crontab -l; echo "*/3 * * * * /usr/local/bin/ip2tor_host.sh checkin 0 'Automated HELLO from host' >> /home/ip2tor/logs/host_checkin_hello.log 2>&1") | awk '!x[$0]++' | crontab -

################
# Run the task scheduler 'cron'
################
service cron start

################
# Run the host script in loop
################
/usr/local/bin/ip2tor_host.sh loop