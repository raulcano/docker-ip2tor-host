#!/usr/bin/env bash

################
# IMPORTANT: The ip2tor_host.sh loop running in the foreground is sending a 'hello' every 2 seconds
# For the moment, I see no need to have the crontab running to check in
################


################
# Preparation of scheduled tasks
# Inspired from https://www.baeldung.com/linux/create-crontab-script
################

# A simple task to check visually that cron is running
(crontab -l; echo "* * * * * touch /home/ip2tor/logs/cron-alive") | awk '!x[$0]++' | crontab -

# Clean open bridges in host that do not have a corresponding entry in the shop 
(crontab -l; echo "*/30 * * * * /usr/local/bin/ip2tor_host.sh sync >> /home/ip2tor/logs/host_sync.log 2>&1") | awk '!x[$0]++' | crontab -

################
# Run the task scheduler 'cron'
################
service cron start


################
# Run supervisor
################
source /home/ip2tor/.env
supervisord -c /home/ip2tor/contrib/supervisord.conf
echo 'Starting Tor ...'
echo "Starting ip2tor_host.sh loop (DEBUG_LOG=$DEBUG_LOG)..."
echo 'To check if Tor and the IP2TOR_HOST are running alright, open a terminal in this container and run "supervisorctl status".'

tail -f /home/ip2tor/logs/supervisor/* & tail -f /home/ip2tor/logs/*.log
