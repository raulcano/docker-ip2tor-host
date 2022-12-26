FROM debian:latest

RUN apt-get update -y 
RUN apt-get install -y sudo
RUN apt-get install -y tor
RUN apt-get install -y socat
RUN apt-get install -y jq
RUN apt-get install -y git
RUN apt-get install -y curl

RUN useradd ip2tor --comment "IP2Tor Host Account" --create-home --home /home/ip2tor --shell /bin/bash
RUN chmod 750 /home/ip2tor

RUN mkdir /tmp/ip2tor/
RUN mkdir /tmp/ip2tor/scripts
RUN mkdir /tmp/ip2tor/contrib

COPY scripts/ip2tor_host.sh /tmp/ip2tor/scripts/ip2tor_host.sh
COPY scripts/ip2torc.sh /tmp/ip2tor/scripts/ip2torc.sh
COPY contrib/ip2tor /tmp/ip2tor/contrib/ip2tor

RUN sudo install -m 0755 -o root -g root -t /usr/local/bin /tmp/ip2tor/scripts/ip2tor_host.sh
RUN sudo install -m 0755 -o root -g root -t /usr/local/bin /tmp/ip2tor/scripts/ip2torc.sh
# To make sure that logs are rotated and deleted add the logrotate config - IS THIS NECESSARY? WE ARE NOT RUNNING ANYTHING AS SERVICE
RUN sudo install -m 0644 -o root -g root -t /etc/logrotate.d/ /tmp/ip2tor/contrib/ip2tor

COPY .env /etc/ip2tor.conf

COPY scripts/start.sh /usr/local/bin/start
RUN chmod u+x /usr/local/bin/start
CMD ["/usr/local/bin/start"]