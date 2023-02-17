#!/usr/bin/env bash
#
# ip2torc.sh
#
# License: MIT
# Copyright (c) 2020 The RaspiBlitz developers

set -u

# How to show debug logs:
# DEBUG_LOG=1 ./ip2torc.sh



# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ] || [ "$1" = "--help" ]; then
  echo "management script to add, check, list or remove IP2Tor bridges (using socat and systemd)"
  echo "ip2torc.sh add [PORT] [TARGET]"
  echo "ip2torc.sh add_nostr_alias [PORT] [ALIAS] [PUBLIC_KEY]"
  echo "ip2torc.sh check [TARGET]"
  echo "ip2torc.sh list"
  echo "ip2torc.sh remove [PORT]"
  echo "ip2torc.sh remove_nostr_alias [ALIAS]"
  echo "ip2torc.sh sync"
  exit 1
fi


###################
# GET CONFIG
###################
source "/etc/ip2tor.conf"

###################
# DEBUG + CHECKS
###################
DEBUG_LOG=${DEBUG_LOG:-0}
function debug() { ((DEBUG_LOG)) && echo "### $*"; }

if ! command -v tor >/dev/null; then
  echo "Tor is not installed - exiting."
  echo "Please setup Tor and run again."
  exit 1
fi

if ! command -v socat >/dev/null; then
  echo "socat not found - installing it now..."
  sudo apt-get update &>/dev/null
  sudo apt-get install -y socat &>/dev/null
  echo "socat installed successfully."
fi


###################
# FUNCTIONS
###################
function add_nostr_alias(){
  port=${1}
  alias=${2}
  public_key=${3}
  echo "adding Nostr alias '${alias}' to public key '${public_key}'"

#   To add a line for an alias
# Location /myalias {redirect 301 nostr:aaaa}
# Add the line '#alias_marker' to the config file. New aliases will be added before it
# sudo sed -i '/^    #alias_marker/i \ \ \ \ location\ \/mynewalias\ {return\ 301\ nostr:\/\/npubMYNEWADDRESS}' default.conf.template

}

function add_bridge() {
  # requires sudo
  port=${1}
  target=${2}
  
  echo "adding bridge from port: ${port} to: ${target}"
  
  program_name="ip2tor_bridge_${port}"
  file_path="/home/ip2tor/tor_bridges/${program_name}.conf"
  if [ -f "${file_path}" ]; then
    debug "Bridge exists already: we found the file ${file_path}"
    exit 0
  fi

  if getent passwd debian-tor > /dev/null 2&>1 ; then
    service_user=debian-tor
  elif getent passwd toranon > /dev/null 2&>1 ; then
    service_user=toranon
  else
    service_user=root
  fi

  cat <<EOF | sudo tee "${file_path}" >/dev/null
;HOST_ID=${IP2TOR_HOST_ID}
;IP2Tor Tor Bridge Service (Port ${port})
[program:${program_name}]
command=/usr/bin/socat TCP4-LISTEN:${port},bind=0.0.0.0,reuseaddr,fork SOCKS4A:localhost:${target},socksport=9050
stdout_logfile=/home/ip2tor/logs/supervisor/${program_name}-stdout.log
stderr_logfile=/home/ip2tor/logs/supervisor/${program_name}-stderr.log
user=${service_user}
EOF

  echo "Updating supervisor after adding the service 'ip2tor_${port}'. File created: /home/ip2tor/tor_bridges/ip2tor_${port}.conf"
  supervisorctl update

  echo "Opening the port in the host firewall..."
  ssh -i "/home/ip2tor/.ssh/${SSH_KEYS_FILE}" ${HOST_SSH_USER}@${IP2TOR_HOST_IP} -p ${IP2TOR_HOST_SSH_PORT} "sudo ufw allow ${port} comment 'Tor Bridge on port ${port}'"


}

function check_bridge_target() {
  target=${1}
  echo "checking bridge target: ${target}"
  echo "no idea yet what and how to check!"
}

function list_bridges() {
  echo "# Bridges (PORT|TARGET|STATUS)"
  echo "# ============================"

  for f in /etc/systemd/system/ip2tor_*.service; do
    [ -e "$f" ] || continue

    cfg=$(sed -n 's/^ExecStart.*TCP4-LISTEN:\([0-9]*\),.*SOCKS4A:localhost:\(.*\),socksport=.*$/\1|\2/p' "${f}")
    port=$(echo "${cfg}" | cut -d"|" -f1)
    target=$(echo "${cfg}" | cut -d"|" -f2)
    status=$(systemctl status "ip2tor_${port}.service" | grep "Active" | sed 's/^ *Active: //g')
    echo "${port}|${target}|${status}"
  done

}

function remove_nostr_alias() {
  alias=${1}
  echo "Removing alias ${alias}"

#   To remove a line that starts with a particular text:
# sed -i '/^location /
# myalias /
# d' filename
# sudo sed -i '/^    location \/myalias /
# d' default.conf.template

}

function remove_bridge() {
  # requires sudo
  port=${1}
  echo "removing bridge from port: ${port}"

  program_name="ip2tor_bridge_${port}"
  file_path="/home/ip2tor/tor_bridges/${program_name}.conf"

  if ! [ -f "${file_path}" ]; then
    echo "file does not exist"
    echo "no bridge on this port..!"
    
    # If we exit with 1, the loop will still keep calling the API, notice that a bridge is suspended and does nothing in the host, nor update the bridge via API
    # So it will call the API again and again.
    # This way, the bridge is set to H and no endless calls to the API are done.
    # exit 1
    # exit 0
  else 
    echo "will now update supervisord, so the bridge is properly removed"
    sudo rm -f ${file_path}
    supervisorctl update
  fi

  log_file="/home/ip2tor/logs/supervisor/${program_name}-stdout.log"
  err_file="/home/ip2tor/logs/supervisor/${program_name}-stderr.log"
  CURRENTDATE=`date +"%Y-%m-%d_%T"`
  
  if [ -f "${err_file}" ]; then
    echo "The bridge error logs were moved to the folder 'deleted_bridges'"
    sudo mv ${err_file} /home/ip2tor/logs/supervisor/deleted_bridges/${CURRENTDATE}-${program_name}-stderr.log
  fi

  if [ -f "${log_file}" ]; then
    echo "The bridge stdout logs were moved to the folder 'deleted_bridges'"
    sudo mv ${log_file} /home/ip2tor/logs/supervisor/deleted_bridges/${CURRENTDATE}-${program_name}-stdout.log
  fi

  echo "Blocking access to the port in the host firewall..."
  ssh -i "/home/ip2tor/.ssh/${SSH_KEYS_FILE}" ${HOST_SSH_USER}@${IP2TOR_HOST_IP} -p ${IP2TOR_HOST_SSH_PORT} "sudo ufw delete allow ${port}"
  
  echo "successfully stopped and removed bridge."

}

#######
# ADD #
#######
if [ "$1" = "add" ]; then
  if ! [ $# -eq 3 ]; then
    echo "wrong number of arguments - run with -h for help"
    exit 1
  fi
  add_bridge "${2}" "${3}"

elif [ "$1" = "add_nostr_alias" ]; then
  if ! [ $# -eq 4 ]; then
    echo "wrong number of arguments - run with -h for help"
    exit 1
  fi
  add_nostr_alias "${2}" "${3}" "${4}"

#########
# CHECK #
#########
elif [ "$1" = "check" ]; then
  if ! [ $# -eq 2 ]; then
    echo "wrong number of arguments - run with -h for help"
    exit 1
  fi
  check_bridge_target "${2}"

########
# LIST #
########
elif [ "$1" = "list" ]; then
  if ! [ $# -eq 1 ]; then
    echo "wrong number of arguments - run with -h for help"
    exit 1
  fi
  list_bridges

##########
# REMOVE #
##########
elif [ "$1" = "remove" ]; then
  if ! [ $# -eq 2 ]; then
    echo "wrong number of arguments - run with -h for help"
    exit 1
  fi
  remove_bridge "${2}"

elif [ "$1" = "remove_nostr_alias" ]; then
  if ! [ $# -eq 2 ]; then
    echo "wrong number of arguments - run with -h for help"
    exit 1
  fi
  remove_nostr_alias "${2}"

else
  echo "unknown command - run with -h for help"
  exit 1
fi
