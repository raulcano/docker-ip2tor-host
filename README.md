# Docker-ip2tor-host
The code here includes the structure to deploy an ip2tor host using Docker compose.

# Configuration of the Host

Before running the docker container, the Host machine needs to be configured described below.  
For convenience, the main steps are included in the file ```_host-init.sh_EDIT_AND_RENAME```, so if you're ok with it, you can set it to executable and run it (remember you'll still need to configure manually your OpenSSH stuff).
Docker installation is also needed, but it was too tricky to automatize in the same script, so I created a different one ```_host-init-docker.sh```, based on the instructions from here: https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04

__NOTE:__ These instructions correspond to a host machine running Ubuntu 22.04.1 LTS.

# TL;DR

0. [optional] Log in as a non-root user to your system (see below how to add the ```ip2tor``` user).  
__IMPORTANT__: If we are using a non-root user, we need to add it to the sudoers list so we won't get prompted for password. If we don't do this, bridges are not properly created (they use some functions with sudo). See below how to add the user to the sudoers list.

1. Install git (if not present) and download this repo to your server.
```
sudo apt-get install -y git
git clone https://github.com/raulcano/docker-ip2tor-host.git
```
2. Copy and rename ```_host-init.sh_EDIT_AND_RENAME``` to ```_host-init.sh```, edit it to point to the correct absolute location of the ```.env``` file.

```
# Copy and rename the file
cp _host-init.sh_EDIT_AND_RENAME _host-init.sh

# Open editor with _host-init.sh 
nano _host-init.sh

# Change this line with the path to wherever you have the .env file
...
source /absolute/path/to/docker-ip2tor-host/.env
```
3. Configure the environment variables in ```.env``` (see details below).

4. Run the initiation script:
```
cd docker-ip2tor-host/scripts
sudo chmod u+x _host-init.sh
. _host-init.sh
```
5. [optional] The init script will configure OpenSSH automatically to not allow login via password and to allow login via pub key., as well as pointing to the correct authorized_keys file. If you want to specify extra configuration, edit ```sshd_config``` file and restart OpenSSH.
```
sudo nano /etc/ssh/sshd_config

# edit the file at will, and save it
# ...
# restart OpenSSH

sudo /etc/init.d/ssh restart
```
~~6. Add in the ```docker-compose.yml``` file the port range available for bridges (this won't open the ports in the host machine, but will have them internally exposed from docker). Only when a bridge is activated, the port will be open to the outside world.  
__IMPORTANT:__ This range needs to be the same than the port range assigned to this host in the Shop!~~  
_[By using the ```network_mode: "host"``` in the docker-compose.yml file, we don't have to worry anymore about exposing ports from the container. The security of the ports that are exposed to the whole world is controlled by the firewall, which will open or close the corresponding port automatically every time a bridge is opened or closed in that same port.]_

7. Install docker (see ```_host-init-docker.sh```).

8. Build and run docker
```
cd docker-ip2tor-host
docker-compose build && docke-compose run
```

# Configuration
The following sections provide a bit more detail than the tl;dr. 

## OpenSSH
We want to connect the the host via SSH, so it's important to make sure openssh is installed.

First, we install the necessary packages:

```
sudo apt-get install openssh-server openssh-client
```

Configure the OpenSSH server. Recommended to allow authentication only via keys.
```
# Backup the original config file
sudo cp /etc/ssh/sshd_config  /etc/ssh/sshd_config.original_copy

# Edit the config file
sudo nano /etc/ssh/sshd_config
```

Add the allowed public keys to the right file (one per line), so you can connect from the particular machines owning the private key to each of those public ones.
```
sudo nano ~/.ssh/authorized_keys
```


Restart OpenSSH to ensure changes in config are taken into account:
```
sudo /etc/init.d/ssh restart
```

## Firewall
We'll be using ```ufw``` as our firewall, even though other options are available for you to choose.
These steps are to ensure that, by default, only the OpenSSH port (22) will be allowed for incoming traffic.
Once the IP2Tor Host is running, ports will be opened and closed automatically based on the active bridges.


First, we install ```ufw``` if not available:
```
sudo apt-get install ufw
```

To check the firewall status:
```
sudo ufw status
```

To check which ports are open, we can use any of these commands:
```
netstat -lntu
# or 
ss -lntu
```

Also, to check if a port is used, run any of these lines (in the example, we check if port 22 is open). If the output is blank, it means the port is not being used.
```
netstat -na | grep :22
# or
ss -na | grep :22
```

By default, we block all incoming traffic and allow all outgoing
```
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Now we allow SSH incoming traffic
```
sudo ufw allow ssh
```

Ensure ```ufw``` is enabled
```
sudo ufw enable
```

## Port forwarding
If you are running the IP2Tor Host in a home network, make sure to do a port forwarding in your router. That is, the selected WAN range shall be forwarded to the same LAN range of the machine in your local network that is running the Host (e.g. 192.168.0.100 or something like that).


## ~~The docker-compose.yml file~~
~~Decide on a port range you will be offering for Tor Bridges in this host. Let's say, it's the range __21212__ to __21221__.~~ 

~~Make sure the firewall is not blocking traffic in that range of ports. For example, run ```ufw status``` for a quick view of which rules are enabled (see the "Firewall" section for more details).~~

~~Edit the ```docker-compose.yml``` file to ensure that the same ports you decided to offer for bridges, are exposed in the container:~~
```
ip2tor-host:
  ...
  ...
  ports:
      - "21212-21221:21212-21221"
  ...
  ...
```
_[By using the ```network_mode: "host"``` in the docker-compose.yml file, we don't have to worry anymore about exposing ports from the container. The security of the ports that are exposed to the whole world is controlled by the firewall, which will open or close the corresponding port automatically every time a bridge is opened or closed in that same port.]_

## Host IP
You need to retrieve the public IP of the Host machine, so it can be added in the Shop. If this is your home network, try a service like https://www.whatismyip.com/ (without being connected to a  VPN!). The IP is the one you'll need to use to create a Host in the Shop.

## Environment variables
The ```.env``` file contains a few variables you'll need to complete for the IP2Tor Host to work fine.

```
# This variable can be 0 (disabled) or 1 (enabled). If enabled, you'll get a lot of verbosity in your terminal when running the Host
DEBUG_LOG=0

# A list of pairs host_id,host_token separated by a colon ":", each representing a Host in this machine
# The Host ID is the one retrieved from the Shop once the Host is created there
# The host token is the one retrieved from the Shop once the Host is created there. In the Shop, go to the Host detail page and see the token there
# For one Host ID, Token
IP2TOR_HOST_IDS_AND_TOKENS=58b61c0b-0a00-0b00-0c00-0d0000000000,5eceb05d00000000000000000000000000000000
# For multiple Host IDs and Tokens
IP2TOR_HOST_IDS_AND_TOKENS=58b61c0b-0a00-0b00-0c00-0d0000000000,5eceb05d00000000000000000000000000000000:58b61c0b-0a00-0b00-0c00-0d0000000000,5eceb05d00000000000000000000000000000000:58b61c0b-0a00-0b00-0c00-0d0000000000,5eceb05d00000000000000000000000000000000


# These are necessary for the docker container to connect to the host machine to open/close ports
# Put your host's public IP here
IP2TOR_HOST_IP=192.168.0.1

# Only change this if you are using a different port for SSH. Otherwise, just leave this as it is
IP2TOR_HOST_SSH_PORT=22

# The user we will be login as via SSH. Tested only with the same user that runs docker. Not sure if with different users this will work
HOST_SSH_USER=myuser

# The path to the authorized_keys file in the Host machine, so we can add the key of the container there. Make sure the file exist!
SSH_AUTHORIZED_KEYS_PATH_IN_HOST_MACHINE="/home/myuser/.ssh/authorized_keys"

# The absolute path to where we will store the private key of the container, as we access from the Host machine (not from within the running container)
# This must be the absolute path to the .ssh folder that is included in this git project
SSH_KEYS_PATH_FOR_CONTAINER="/home/myuser/docker-ip2tor-host/.ssh/"

# The name of the key. No need to change this
SSH_KEYS_FILE=id_ip2tor_host

# Port at which the Terms of Service will be exposed (in this IP). Make sure to allow this via the firewall
TOS_PORT=80
```


## Creating a non-root user and adding keys for SSH
If you are using a third-party VPS, maybe you get access to it by default with root access.
While this is convenient, for security reasons I prefer to create a user for managing the Host that is non-root. Let's go through the steps to create one.  
We assume these steps are done by the ```root``` user:

```
useradd ip2tor --comment "IP2Tor Service Account" --create-home --home /home/ip2tor --shell /bin/bash
chmod 750 /home/ip2tor

# change the password
sudo passwd ip2tor

# add the user to the 'sudo' group
usermod -aG sudo ip2tor
```

Also, if you want to avoid being asked for password whenever you use the ```sudo``` command for the new ```ip2tor``` user, you need to edit the sudoers file as follows:

```
nano /etc/sudoers
```
Add this line at the end and save the file. After this, once you log in with ```ip2tor``` again, you won't be prompted for password every time you do a ```sudo```.
```
ip2tor ALL=(ALL) NOPASSWD: ALL
```


Now, to ensure proper SSH connections via public key:
```
mkdir /home/ip2tor/.ssh
touch /home/ip2tor/.ssh/authorized_keys
nano /home/ip2tor/.ssh/authorized_keys
```
Add the public key of the machine you will be connecting from and save ```authorized_keys```

Also, edit ```sshd_config``` file to allow the login via public key:
```
sudo nano /etc/ssh/sshd_config
```


From now on, the user is in the system and you should SSH to the server with this one.

## Add aliases to the Host machine
This is merely for convenience, but you can add a list of aliases that are loaded on every system start.

Edit the ```~/.bashrc``` file:


```
nano ~/.bashrc
```

And add these lines at the bottom.
```
if [ -f /home/ip2tor/docker-ip2tor-host/scripts/aliases.sh ]; then
  . /home/ip2tor/docker-ip2tor-host/scripts/aliases.sh
fi
```
Now, save the file and restart the session for ```ip2tor```. You'll see those aliases have been loaded and are ready to use.

At the moment of writing this, the list of aliases is as follows:

```
alias off='sudo shutdown now'
alias doff='docker-compose down && sudo shutdown now'
alias restart='sudo reboot now'
alias hello='docker exec -it ip2tor-host ip2tor_host.sh hello'
alias activate='docker exec -it ip2tor-host ip2tor_host.sh activate'
alias checkin='docker exec -it ip2tor-host ip2tor_host.sh checkin 0 "Manual HELLO message"'
alias suspend='docker exec -it ip2tor-host ip2tor_host.sh suspend'

alias hd='sudo docker-compose down'
alias hb='sudo docker-compose build'
alias hu='sudo docker-compose up'
alias hdbu='sudo docker-compose down && sudo docker-compose build && sudo docker-compose up'

alias fstatus='sudo ufw status'
alias status='docker exec -it ip2tor-host supervisorctl status'
alias sync='docker exec -it ip2tor-host ip2tor_host.sh sync'
alias log='docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/supervisord.log'
alias logip2tor='docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_host-stdout.log'
alias elogip2tor='docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_host-stderr.log'
alias logtor='docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/tor-stdout.log'
alias elogtor='docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/tor-stderr.log'

# Get the stdout logs of a bridge, passing the port number as an argument
# E.g. "logbridge 21212" will return the contents of the file "ip2tor_bridge_21212-stdout.log"
# You can replace $1 with $@ if you  want multiple args.
alias logbridge='f(){ docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_bridge_$1-stdout.log; unset -f f; }; f'
# Get the stdout error logs of a bridge, passing the port number as an argument
# E.g. "elogbridge 21212" will return the contents of the file "ip2tor_bridge_21212-stderr.log"
alias elogbridge='f(){ docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_bridge_$1-stderr.log; unset -f f; }; f'
```

## Running the container
Finally, run the docker container of the IP2Tor Host with 
```
docker-compose build && docker-compose run
```

If you configured all previous steps properly, you are now ready to create Tor Bridges via this Host.

## Terms of Service (ToS)
There is a container that runs a lightweight Python web server with the sole purpose of exposing a Terms of Service page for this host, which you can link when you register the Host in the Shop.
The file ```.docker/tos/tos.html``` contains the ToS and you can edit it at will with your own terms.  
Likewise, the environment variable ```TOS_PORT``` defines via which port that page will be served. Make sure that the firewall allows that port:
```
sudo ufw allow <YOUR_CHOSEN_TOS_PORT>
```


## Using Acme.sh script for SSL certs

https://github.com/acmesh-official/acme.sh

1. Install from git in the home directory
```
cd ~
git clone https://github.com/acmesh-official/acme.sh.git
cd ./acme.sh
./acme.sh --install -m my@example.com
```

2. Issue the certificates.  While there are many ways to issue and renew your certs, I found the usage of API to be the most convenient:
https://github.com/acmesh-official/acme.sh/wiki/dnsapi . For example, if your domains are in Namesilo.com:
```
export Namesilo_Key="yourAPIkey"
./acme.sh --issue --dns dns_namesilo --dnssleep 900 -d ${NOSTR_DOMAIN}  -d '*.${NOSTR_DOMAIN}'
```

3. Create the destination folder for the certs. This is the folder that NGINX will check for the files.
```
mkdir ~/docker-ip2tor-host/ssl/${NOSTR_DOMAIN}/
```
3. Copy the issued certs to the destination folderwith this specific command provided by the acme script.
```
acme.sh --install-cert -d {NOSTR_DOMAIN} -d *.{NOSTR_DOMAIN} \
--key-file       ~/docker-ip2tor-host/ssl/${NOSTR_DOMAIN}/privkey.pem  \
--fullchain-file ~/docker-ip2tor-host/ssl/${NOSTR_DOMAIN}/fullchain.pem \
--reloadcmd     "sudo docker exec ip2tor-host-nginx service nginx reload"
```
4. To check the installed certificates and their validity:
```
acme.sh --list
```
You will get a list like this:
```
Main_Domain  KeyLength  SAN_Domains   CA           Created               Renew
example.com   "ec-256"   *.example.com  ZeroSSL.com  2023-05-29T10:57:24Z  2023-07-27T10:57:24Z
```

5. To uninstall the script, run ```acme.sh --uninstall```


## Removing logs periodically
In order to avoid ever growing log files, we can add the necessary cronjobs for deleting such files.
E.g.
```
25 15 * * mon sudo rm /home/ip2tor/docker-ip2tor-host/logs/cron/host_sync.log
```

