#!/usr/bin/env bash

################
# IMPORTANT: The ip2tor_host.sh loop is sending a 'hello' every 2 seconds
# For the moment, I see no need to have the crontab running to check in
################
source /home/ip2tor/.env


##################
# 
# Test that the SSH connection is established with the host machine
# If cannot connect, we exit
#
# ################
server=${IP2TOR_HOST_IP}            # server IP
port=${IP2TOR_HOST_SSH_PORT}        # port
user=${HOST_SSH_USER}
ssh_keys_path="/home/ip2tor/.ssh/" # This is a mounted volume that corresponds with env variable (need to use the path of the mounted volume though!)
ssh_keys_file=${SSH_KEYS_FILE}

status=`nmap ${server} -Pn -p ${port} | egrep -io 'open|closed|filtered'`
if [ $status == "open" ];then
   echo "SSH Connection to ${server} over port ${port} is possible"
elif [ $status == "filtered" ]; then
   echo "SSH Connection to ${server} over port ${port} is possible but blocked by firewall"
   exit 1
elif [ $status == "closed" ]; then
   echo "SSH connection to ${server} over port ${port} is not possible"
   exit 1
else
   echo "Unable to get port ${port} status from ${server}"
   exit 1
fi

echo "This is your public key:" && cat ${ssh_keys_path}${ssh_keys_file}.pub


# This is an alternative if for some reason, when building the docker image, there are problems with the known_hosts
# echo "ssh -i "${ssh_keys_path}${ssh_keys_file}" ${user}@${server} -p ${port} -o StrictHostKeyChecking=accept-new 'echo CONNECTED'"
# connection_check=$(ssh -i "${ssh_keys_path}${ssh_keys_file}" ${user}@${server} -p ${port} -o StrictHostKeyChecking=accept-new "echo CONNECTED") 
echo "Trying:"
echo "ssh -i "${ssh_keys_path}${ssh_keys_file}" ${user}@${server} -p ${port} 'echo CONNECTED'"
connection_check=$(ssh -i "${ssh_keys_path}${ssh_keys_file}" ${user}@${server} -p ${port} "echo CONNECTED") 

if [ ! "CONNECTED" = "${connection_check}" ]; then
    echo "ERROR: Cannnot establish a SSH connection with the host ${server} at port ${port}"
    echo "Did you add the pub key to the authorized_keys file in the host?"
    exit 1
else
    echo "CONNECTED: SSH authorization could be established successfully. We continue the startup sequence..."
fi


################
#
# Preparation of Host .conf files for supervisord
#
################

while read -d ':' host_id_token; do
   

   # Need to read the Token id for the ${host_id}
   arr_host_id_token=(${host_id_token//,/ })
   host_id=${arr_host_id_token[0]}
   host_token=${arr_host_id_token[1]}

   echo "Preparing supervisord conf file for Host with ID: ${host_id}"

   program_name="ip2tor_host_${host_id}"
   file_path="/home/ip2tor/hosts/${program_name}.conf"

   cat <<EOF | sudo tee "${file_path}" >/dev/null
[program:${program_name}]
environment = 
    DEBUG_LOG=${DEBUG_LOG},
    IP2TOR_SHOP_URL=${IP2TOR_SHOP_URL},
    IP2TOR_HOST_ID=${host_id},
    IP2TOR_HOST_TOKEN=${host_token}
command=/usr/local/bin/ip2tor_host.sh loop
stdout_logfile=/home/ip2tor/logs/supervisor/${program_name}-stdout.log
stderr_logfile=/home/ip2tor/logs/supervisor/${program_name}-stderr.log
EOF


# Add a cronjob to sync this host. This will sync active bridges with the info from shop
(crontab -l; echo "*/30 * * * * DEBUG_LOG=${DEBUG_LOG} IP2TOR_SHOP_URL=${IP2TOR_SHOP_URL} IP2TOR_HOST_ID=${host_id} IP2TOR_HOST_TOKEN=${host_token} /usr/local/bin/ip2tor_host.sh sync >> /home/ip2tor/logs/host_sync.log 2>&1") | awk '!x[$0]++' | crontab -
# The same if we want to run it as ip2tor user
# (runuser -l ip2tor -c 'crontab -l'; echo "*/30 * * * * DEBUG_LOG=${DEBUG_LOG} IP2TOR_SHOP_URL=${IP2TOR_SHOP_URL} IP2TOR_HOST_ID=${host_id} IP2TOR_HOST_TOKEN=${host_token} /usr/local/bin/ip2tor_host.sh sync >> /home/ip2tor/logs/host_sync.log 2>&1") | awk '!x[$0]++' | runuser -l ip2tor -c 'crontab -'
done <<< "$IP2TOR_HOST_IDS_AND_TOKENS:"


################
# Preparation of scheduled tasks
# Inspired from https://www.baeldung.com/linux/create-crontab-script
################

# A simple task to check visually that cron is running
# (runuser -l ip2tor -c 'crontab -l'; echo "* * * * * touch /home/ip2tor/logs/cron-alive") | awk '!x[$0]++' | runuser -l ip2tor -c 'crontab -'


# This would add the crontab to the root user
# A simple task to check visually that cron is running
(crontab -l; echo "* * * * * touch /home/ip2tor/logs/cron-alive") | awk '!x[$0]++' | crontab -


echo 'This is how the crontab looks like after initializing:'
crontab -l

################
# Run the task scheduler 'cron'
################
service cron start

################
# Run supervisor
################

supervisord -c /home/ip2tor/contrib/supervisord.conf
echo 'Starting Tor ...'
echo "Starting ip2tor_host.sh loop (DEBUG_LOG=$DEBUG_LOG)..."
echo 'To check if Tor and the IP2TOR_HOST(s) are running alright, open a terminal in this container and run "supervisorctl status".'

# This two are so 'tail' does not complain it didn't find log files (a problem the first time we run this)
touch /home/ip2tor/logs/supervisor/empty.log
touch /home/ip2tor/logs/empty.log

tail -f /home/ip2tor/logs/supervisor/* & tail -f /home/ip2tor/logs/*.log
