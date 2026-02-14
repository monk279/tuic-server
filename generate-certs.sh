#!/bin/bash
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -nodes -sha256 -keyout certs/privkey.pem -out certs/fullchain.pem -days 3650 -subj "/CN=$(curl -4 -s ifconfig.me)"
chmod 777 certs/privkey.pem certs/fullchain.pem
