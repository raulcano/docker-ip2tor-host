# Docker-ip2tor-host
The code here includes the structure to deploy an ip2tor host using Docker compose.

# Configuration of the Host

Before running the docker container, the Host machine needs to be configured described below.  
For convenience, the main steps are included in the file ```_host-init.sh_EDIT_AND_RENAME```, so if you're ok with it, you can set it to executable and run it (remember you'll still need to configure manually your OpenSSH stuff).
Docker installation is also needed, but it was too tricky to automatize in the same script, so I created a different one ```_host-init-docker.sh```, based on the instructions from here: https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04

__NOTE:__ These instructions correspond to a host machine running Ubuntu 22.04.1 LTS.

# TL;DR

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
6. Add in the ```docker-compose.yml``` file the port range available for bridges (this won't open the ports in the host machine, but will have them internally exposed from docker). Only when a bridge is activated, the port will be open to the outside world.  
__IMPORTANT:__ This range needs to be the same than the port range assigned to this host in the Shop!

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
We'll be using ```ufw``` as our firewall, even though other options will be available.
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


## The docker-compose.yml file
Decide on a port range you will be offering for Tor Bridges in this host. Let's say, it's the range __21212__ to __21221__.

Make sure the firewall is not blocking traffic in that range of ports. For example, run ```ufw status``` for a quick view of which rules are enabled (see the "Firewall" section for more details).  

Edit the ```docker-compose.yml``` file to ensure that the same ports you decided to offer for bridges, are exposed in the container:
```
ip2tor-host:
  ...
  ...
  ports:
      - "21212-21221:21212-21221"
  ...
  ...
```
## Host IP
You need to retrieve the public IP of the Host machine, so it can be added in the Shop. If this is your home network, try a service like https://www.whatismyip.com/ (without being connected to a  VPN!). The IP is the one you'll need to use to create a Host in the Shop.

## Environment variables
The ```.env``` file contains a few variables you'll need to complete for the IP2Tor Host to work fine.

```
# This variable can be 0 (disabled) or 1 (enabled). If enabled, you'll get a lot of verbosity in your terminal when running the Host
DEBUG_LOG=0

# This can be a clearnet URL or an Onion address of the shop this Host will connect to
IP2TOR_SHOP_URL=https://myshop.com
# IP2TOR_SHOP_URL=masdfasdfasda93393933.onion

# This ID is the one retrieved from the Shop once the Host is created there
IP2TOR_HOST_ID=58b61c0b-0a00-0b00-0c00-0d0000000000

# This token is the one retrieved from the Shop once the Host is created there. 
# Go to the Host detail page and see the token there
IP2TOR_HOST_TOKEN=5eceb05d00000000000000000000000000000000

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

# First range of ports to open in the host. You can add more later manually in the docker-compose.yml file
# It seems that docker is not too happy exposing a large amount of ports. I tried manually and noticed that above ca. 400 ports it wouldn't run
RANGE1_START_PORT=17000
RANGE1_END_PORT=17400
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