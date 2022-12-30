FROM debian:latest

RUN apt-get update -y 
RUN apt-get install -y sudo
RUN apt-get install -y tor
RUN apt-get install -y socat
RUN apt-get install -y jq
RUN apt-get install -y curl
RUN apt-get install -y supervisor
RUN apt-get install -y procps
RUN apt-get install -y lsof
RUN apt-get install -y nano



RUN useradd ip2tor --comment "IP2Tor Host Account" --create-home --home /home/ip2tor --shell /bin/bash
RUN chmod 750 /home/ip2tor

RUN mkdir /tmp/ip2tor/
RUN mkdir /tmp/ip2tor/scripts
RUN mkdir /tmp/ip2tor/contrib

COPY scripts/ip2tor_host.sh /tmp/ip2tor/scripts/ip2tor_host.sh
COPY scripts/ip2torc.sh /tmp/ip2tor/scripts/ip2torc.sh

RUN sudo install -m 0755 -o root -g root -t /usr/local/bin /tmp/ip2tor/scripts/ip2tor_host.sh
RUN sudo install -m 0755 -o root -g root -t /usr/local/bin /tmp/ip2tor/scripts/ip2torc.sh

COPY .env /etc/ip2tor.conf

# We add the correct folder for tor data, so the debian-tor user has access to it
RUN echo "DataDirectory /var/lib/tor" | sudo tee --append /etc/tor/torrc

COPY scripts/start.sh /usr/local/bin/start
RUN chmod u+x /usr/local/bin/start
CMD ["/usr/local/bin/start"]