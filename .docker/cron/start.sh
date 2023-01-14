#!/usr/bin/env bash

source /usr/share/.env

################
# Preparing the tasks
################

# A simple task to check visually that cron is running
(crontab -l; echo "* * * * * touch /home/ip2tor/logs/cron/cron-alive.log") | awk '!x[$0]++' | crontab -

# Files backup
(crontab -l; echo "0 12 * * * /usr/local/bin/backup-files.sh >> /home/ip2tor/logs/cron/backup-files.log 2>&1") | awk '!x[$0]++' | crontab -

# Delete old backup files
(crontab -l; echo "30 12 * * * /usr/local/bin/delete-old-backup.sh >> /home/ip2tor/logs/cron/delete-old-backup.log 2>&1") | awk '!x[$0]++' | crontab -


################
# Check the crontab
################

echo 'This is how the crontab looks like after initializing:'
crontab -l

################
# Run the task scheduler 'cron'
################
echo "Starting cron..."
service cron start

touch /home/ip2tor/logs/cron/empty.log
tail -f /home/ip2tor/logs/cron/*.log