#!/bin/bash

port="55937"
sum=0

output=$(iptables -L ufw-user-input -v -n --line-numbers | grep "$port" | awk '{print $3}')

for value in $output; do
  sum=$((sum + value))
done

echo "Total bytes for port $port: $sum"