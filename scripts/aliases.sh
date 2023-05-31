#!/bin/bash

# I tried creating a service to load on startup , but that didn't work for aliases (for other functions this might be useful)
# see here: https://linuxconfig.org/how-to-run-script-on-startup-on-ubuntu-20-04-focal-fossa-server-desktop

# It turns out that aliases won't be loaded in the system if they run via a script like this:
# https://stackoverflow.com/questions/24054154/how-do-create-an-alias-in-shell-scripts

# In the end, in order to load these aliases in your system, I added them to ~/.bashrc by loading this file, like this:

# if [ -f /path/to/aliases.sh ]; then
# . /path/to/aliases.sh
# fi

# Instructions found here: https://stackoverflow.com/questions/3952033/how-can-i-automatically-load-alias-on-startup#3952039


alias off='sudo shutdown now'
alias doff='sudo docker-compose down && sudo shutdown now'
alias restart='sudo reboot now'
alias hello='sudo docker exec -it ip2tor-host ip2tor_host.sh hello'
alias activate='sudo docker exec -it ip2tor-host ip2tor_host.sh activate'
alias checkin='sudo docker exec -it ip2tor-host ip2tor_host.sh checkin 0 "Manual HELLO message"'
alias suspend='sudo docker exec -it ip2tor-host ip2tor_host.sh suspend'

alias hd='sudo docker-compose down'
alias hb='sudo docker-compose build'
alias hu='sudo docker-compose up -d && sudo docker-compose logs -f'
alias hdbu='sudo docker-compose down && sudo docker-compose build && sudo docker-compose up -d && sudo docker-compose logs -f'
alias dlogs='sudo docker-compose logs -f --tail="20"'

alias fstatus='sudo ufw status'
alias fenable='sudo ufw enable'
alias fdisable='sudo ufw disable'

alias status='sudo docker exec -it ip2tor-host supervisorctl status'
alias sync='sudo docker exec -it ip2tor-host ip2tor_host.sh sync'
alias log='sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/supervisord.log'
alias logip2tor='sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_host-stdout.log'
alias elogip2tor='sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_host-stderr.log'
alias logtor='sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/tor-stdout.log'
alias elogtor='sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/tor-stderr.log'

# Get the stdout logs of a bridge, passing the port number as an argument
# E.g. "logbridge 21212" will return the contents of the file "ip2tor_bridge_21212-stdout.log"
# You can replace $1 with $@ if you  want multiple args.
alias logbridge='f(){ sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_bridge_$1-stdout.log; unset -f f; }; f'
# Get the stdout error logs of a bridge, passing the port number as an argument
# E.g. "elogbridge 21212" will return the contents of the file "ip2tor_bridge_21212-stderr.log"
alias elogbridge='f(){ sudo docker exec -it ip2tor-host cat /home/ip2tor/logs/supervisor/ip2tor_bridge_$1-stderr.log; unset -f f; }; f'
alias sizes='sudo find . -type f -exec du -Sh {} + | sort -rh | head -n 20'

# rebuild the container 'ip2tor-host' only
alias rehost='sudo docker-compose up -d --no-deps --build ip2tor-host && sudo docker-compose logs -f'