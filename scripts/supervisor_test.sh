#!/usr/bin/env bash
#


# create a sample config file for supervisor
port=${1}
target=${2}
service_user=root

port=21212
tartget="7sxfdodl4lrl2rz6vgbkn2ck4gujselh6gln3tiia6a6scfqtjd2ojad.onion"
service_user=root
program_name="ip2tor_bridge_${port}"

conf_file_path="/etc/supervisor/conf.d/ip2tor_${port}.conf"
# conf_file_path="/home/ip2tor/scripts/${program_name}.conf"

cat <<EOF | sudo tee "${conf_file_path}" >/dev/null
[program:${program_name}]
; IP2Tor Tunnel Service (Port ${port})
command=/usr/bin/socat TCP4-LISTEN:${port},bind=0.0.0.0,reuseaddr,fork SOCKS4A:localhost:${target},socksport=9050
user=${service_user}
EOF


# supervisorctl start program_name
echo "Update supervisor after adding the service 'ip2tor_${port}' by creating the config file /etc/supervisor/conf.d/ip2tor_${port}.conf"
supervisorctl update

## To stop a service
echo "Update supervisor after removing the service 'ip2tor_${port}' by deleting the config file /etc/supervisor/conf.d/ip2tor_${port}.conf"
rm -f /etc/supervisor/conf.d/ip2tor_${port}.conf
supervisorctl update



