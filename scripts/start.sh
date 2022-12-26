#!/usr/bin/env bash

################
# IMPORTANT: The ip2tor_host.sh loop running in the foreground is sending a 'hello' every 2 seconds
# For the moment, I see no need to have the crontab running
################


################
# Preparation of scheduled tasks
# Inspired from https://www.baeldung.com/linux/create-crontab-script
################

# A simple task to check visually that cron is running
# (crontab -l; echo "* * * * * touch /home/ip2tor/logs/cron-alive") | awk '!x[$0]++' | crontab -
# Send a HELLO (code 0) to the host every 3 minutes
# (crontab -l; echo "*/3 * * * * /usr/local/bin/ip2tor_host.sh checkin 0 'Automated HELLO from host' >> /home/ip2tor/logs/host_checkin_hello.log 2>&1") | awk '!x[$0]++' | crontab -

################
# Run the task scheduler 'cron'
################
# service cron start

################
# Run Tor
################
service tor start

################
# Run the host script in a loop
################
source /home/ip2tor/.env

# Set the DEBUG_LOG value to 0 or 1 in the .env file
# If DEBUG_LOG is 1, docker will show the debug logs in screen
DEBUG_LOG=$DEBUG_LOG /usr/local/bin/ip2tor_host.sh loop
