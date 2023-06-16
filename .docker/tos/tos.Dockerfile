# Dockerfile for the Tor hidden service
FROM debian:latest

RUN apt-get update -y
RUN apt-get install -y sudo
RUN apt-get install -y python3
RUN apt-get install -y pip
RUN apt-get install -y python3-dotenv
# RUN python3 -m pip install python-dotenv

COPY .env /usr/share/.env
COPY .docker/tos/serve-page.py /usr/share/serve-page.py
COPY .docker/tos/tos.html /usr/share/tos.html

COPY .docker/tos/start.sh /usr/local/bin/start
RUN chmod u+x /usr/local/bin/start
CMD ["/usr/local/bin/start"]