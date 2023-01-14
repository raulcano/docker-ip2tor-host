#!/bin/bash

source /usr/share/.env

echo 'Deleting old backup files...'

find /home/ip2tor/backups/*.tgz -type f -mtime +${DELETE_OLD_BACKUPS_AFTER_DAYS} | xargs rm -f