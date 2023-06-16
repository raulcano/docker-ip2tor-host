#!/bin/bash

# Get the port parameter
port="$1"
iptables_file="/home/ip2tor/.docker/telegraf/iptables.txt"

# Read the iptables.txt file and extract the bytes consumed by port ${port}
# grep -E "tcp.*dpt:21059" /home/ip2tor/.docker/telegraf/iptables.txt | awk '{print $2}'
bytes=$(grep -E "tcp.*dpt:${port}" $iptables_file | awk '{print $2}')

# Print the output in the desired Telegraf input format
echo "iptables,port=${port} bytes_consumed=${bytes}"