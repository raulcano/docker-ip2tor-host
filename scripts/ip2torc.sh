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

function convert_public_key_to_hex(){
  command_key_convert="sudo docker exec ip2tor-host-key-convertr key-convertr --to-hex ${1}"
  result=$(run_command_on_host_machine "${command_key_convert}")
  echo "${result}"
}


function reload_nginx() {
  ssh -i "/home/ip2tor/.ssh/${SSH_KEYS_FILE}" ${HOST_SSH_USER}@${IP2TOR_HOST_IP} -p ${IP2TOR_HOST_SSH_PORT} "sudo docker exec ip2tor-host-nginx service nginx reload"
}

function run_command_on_host_machine(){
  command=${1}
  ssh -i "/home/ip2tor/.ssh/${SSH_KEYS_FILE}" ${HOST_SSH_USER}@${IP2TOR_HOST_IP} -p ${IP2TOR_HOST_SSH_PORT} "${command}"
}

function add_nostr_alias(){
  port=${1}
  alias=${2}
  public_key=${3}
  public_key_hex=$(convert_public_key_to_hex ${public_key})
  echo "Adding Nostr alias '${alias}' to public key '${public_key}'"

  echo "Writing new config in nginx templates..."
  # To add a line for an alias of the form
  # location /myalias {redirect 301 nostr://npub0dafs2328adfasd;}

  # Modify the conf file that is loaded when the container is (re)started - this doesn't apply changes immediately, but it's necessary for whtn the container is rebooted
  # add alias of the form mydomain.com/alias
  sudo sed -i "/^    #alias_marker/i \ \ \ \ location\ \/${alias}\ {return\ 301\ nostr:\/\/${public_key};}" /home/ip2tor/.docker/nginx/default.conf.template
  # sudo sed -i "/^        #nip05_marker/i \ \ \ \ \ \ \ \ if\ (\$arg_name\ =\ \"${alias}\"){return\ 200\ '{\"names\":{\"${alias}\":\"${public_key}\"}}';}" /home/ip2tor/.docker/nginx/default.conf.template
  sudo sed -i "/^        #nip05_marker/i \ \ \ \ \ \ \ \ if\ (\$arg_name\ =\ \"${alias}\"){return\ 200\ '{\"names\":{\"${alias}\":\"${public_key_hex}\"}}';}" /home/ip2tor/.docker/nginx/default.conf.template

  # add alias of the form alias.mydomain.com
  file_path="/home/ip2tor/.docker/nginx/nostr_alias_${alias}.conf.template"

  cat <<EOF | sudo tee "${file_path}" >/dev/null
server {
    listen ${NGINX_HTTP_PORT};
    server_name ${alias}.${NOSTR_DOMAIN};

    ##
    # Here goes the redirect to the HTTPS
    ##
    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen ${NGINX_HTTPS_PORT} ssl;
    server_name ${alias}.${NOSTR_DOMAIN};

    ##
    # Logging Settings
    ##
    error_log  stderr warn;
    access_log  /dev/stdout main;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA256:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EDH+aRSA+AESGCM:EDH+aRSA+SHA256:EDH+aRSA:EECDH:!aNULL:!eNULL:!MEDIUM:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4:!SEED";

    add_header Strict-Transport-Security "max-age=31536000";

    ssl_certificate /etc/nginx/ssl/${NOSTR_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/${NOSTR_DOMAIN}/privkey.pem;


    ##
    # Here goes the redirect to the nostr public key
    ##
    location / {
        set \$mobile_rewrite do_not_perform;

        if (\$http_user_agent ~* "(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino") {
            set \$mobile_rewrite perform;
        }

        if (\$http_user_agent ~* "^(1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-)") {
            set \$mobile_rewrite perform;
        }

        if (\$mobile_rewrite = perform) {
            return 301 nostr://${public_key};
        }

        rewrite ^ https://iris.to/${public_key} redirect;
    }
}
EOF
  # we cannot simply copy the default.conf.template into the default.conf because the .template has env variables that are replaced when the docker image is built
  cmd_template_default_conf="sudo docker exec ip2tor-host-nginx sed -i \"/^    #alias_marker/i \ \ \ \ location\ \/${alias}\ {return\ 301\ nostr:\/\/${public_key};}\" /etc/nginx/conf.d/default.conf"
  # cmd_template_default_conf2="sudo docker exec ip2tor-host-nginx sed -i \"/^        #nip05_marker/i \ \ \ \ \ \ \ \ if\ (\\\$arg_name\ =\ \\\"${alias}\\\"){return\ 200\ '{\\\"names\\\":{\\\"${alias}\\\":\\\"${public_key}\\\"}}';}\" /etc/nginx/conf.d/default.conf"
  cmd_template_default_conf2="sudo docker exec ip2tor-host-nginx sed -i \"/^        #nip05_marker/i \ \ \ \ \ \ \ \ if\ (\\\$arg_name\ =\ \\\"${alias}\\\"){return\ 200\ '{\\\"names\\\":{\\\"${alias}\\\":\\\"${public_key_hex}\\\"}}';}\" /etc/nginx/conf.d/default.conf"
  cmd_template_subdomain_conf="sudo docker exec ip2tor-host-nginx cp /etc/nginx/templates/nostr_alias_${alias}.conf.template /etc/nginx/conf.d/nostr_alias_${alias}.conf"
  
  echo "Writing new config in nginx container..."
  run_command_on_host_machine "${cmd_template_default_conf}"
  run_command_on_host_machine "${cmd_template_default_conf2}"
  run_command_on_host_machine "${cmd_template_subdomain_conf}"
  
  reload_nginx
}

function remove_nostr_alias() {
  alias=${1}
  echo "Removing alias ${alias}"

  # To remove a line that starts with a particular text:
  # sed -i '/^location/myalias/d' filename
  sudo sed -i "/^    location \/${alias} /d" /home/ip2tor/.docker/nginx/default.conf.template
  sudo sed -i "/arg_name = \"${alias}\"/d" /home/ip2tor/.docker/nginx/default.conf.template

  # remove alias of the form alias.mydomain.com
  file_path="/home/ip2tor/.docker/nginx/nostr_alias_${alias}.conf.template"

  if ! [ -f "${file_path}" ]; then
    echo "Alias subdomain file for '${alias}.${NOSTR_DOMAIN}' does not exist"
    echo "no alias on this subdomain..!"
    
  else 
    sudo rm -f ${file_path}
  fi

  cmd_template_default_conf="sudo docker exec ip2tor-host-nginx sed -i \"/^    location \/${alias} /d\" /etc/nginx/conf.d/default.conf"
  cmd_template_default_conf2="sudo docker exec ip2tor-host-nginx sed -i \"/arg_name = \\\"${alias}\\\"/d\" /etc/nginx/conf.d/default.conf"
  cmd_template_subdomain_conf="sudo docker exec ip2tor-host-nginx rm /etc/nginx/conf.d/nostr_alias_${alias}.conf"

  run_command_on_host_machine "${cmd_template_default_conf}"
  run_command_on_host_machine "${cmd_template_default_conf2}"
  run_command_on_host_machine "${cmd_template_subdomain_conf}"

  reload_nginx
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
