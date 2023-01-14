#!/usr/bin/env bash

source /usr/share/.env
echo "Serving Terms of Service in ${IP2TOR_HOST_IP}:${TOS_PORT}..."
python3 /usr/share/serve-page.py