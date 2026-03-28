#!/bin/bash

# TUIC v5 Server Auto-Install Script
# Supported OS: Ubuntu 20.04+, Debian 10+
# Run as root

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo ">>> Starting TUIC Server Installation..."

# 1. Install Docker & Dependencies
echo ">>> Installing Dependencies..."
apt-get update -qq
apt-get install -y -qq docker.io docker-compose curl openssl net-tools

# 2. Setup Directory
INSTALL_DIR="/root/tuic-server"
mkdir -p "$INSTALL_DIR/certs"
cd "$INSTALL_DIR"

# 3. Generate Credentials
UUID=$(uuidgen || cat /proc/sys/kernel/random/uuid)
PASSWORD=$(openssl rand -hex 8)
PUBLIC_IP=$(curl -4 -s ifconfig.me)

echo ">>> Generated Credentials:"
echo "    UUID: $UUID"
echo "    PASS: $PASSWORD"
echo "    IP:   $PUBLIC_IP"

# 4. Generate Self-Signed Certs
echo ">>> Generating Certificates..."
openssl req -x509 -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/privkey.pem -out certs/fullchain.pem \
  -days 3650 -subj "/CN=$PUBLIC_IP"

# 5. Create Config Files

# config.json
cat > config.json <<EOF
{
    "server": "[::]:443",
    "users": {
        "$UUID": "$PASSWORD"
    },
    "certificate": "/etc/tuic/certs/fullchain.pem",
    "private_key": "/etc/tuic/certs/privkey.pem",
    "congestion_control": "bbr",
    "alpn": ["h3", "spdy/3.1"],
    "zero_rtt_handshake": false,
    "dual_stack": true,
    "auth_timeout": "10s",
    "task_negotiation_timeout": "10s",
    "max_idle_time": "30s",
    "max_external_packet_size": 1500,
    "gc_interval": "3s",
    "log_level": "info"
}
EOF

# Dockerfile
cat > Dockerfile <<EOF
FROM alpine:latest
RUN apk add --no-cache curl
RUN curl -L -o /usr/bin/tuic-server https://github.com/EAimTY/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-linux-musl \\
    || curl -L -o /usr/bin/tuic-server https://github.com/tuic/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-linux-musl
RUN chmod +x /usr/bin/tuic-server
CMD ["tuic-server", "-c", "/etc/tuic/config.json"]
EOF

# docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  tuic:
    image: native/tuic
    build: .
    container_name: tuic-server
    restart: always
    network_mode: host
    volumes:
      - ./config.json:/etc/tuic/config.json
      - ./certs:/etc/tuic/certs

  nginx:
    image: nginx:alpine
    container_name: tuic-config-server
    restart: always
    ports:
      - "8080:80"
    volumes:
      - ./subscribe.yaml:/usr/share/nginx/html/subscribe.yaml
EOF

# subscribe.yaml (Template)
cat > subscribe.yaml <<EOF
port: 7890
socks-port: 7891
allow-lan: true
mode: rule
log-level: info
external-controller: :9090

proxies:
  - name: "VPS-TUIC-v5"
    type: tuic
    server: $PUBLIC_IP
    port: 443
    uuid: $UUID
    password: $PASSWORD
    IP: $PUBLIC_IP
    skip-cert-verify: true
    alpn:
      - h3

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - VPS-TUIC-v5
      - DIRECT

rules:
  - MATCH,PROXY
EOF

# 6. Start Services
echo ">>> Starting Services..."
docker-compose build
docker-compose up -d

# 7. Final Output
echo ""
echo "========================================================"
echo " TUIC Server Installed Successfully!"
echo "========================================================"
echo " Subscription URL: http://$PUBLIC_IP:8080/subscribe.yaml"
echo ""
echo " Manual Config:"
echo "   Server: $PUBLIC_IP"
echo "   Port:   443"
echo "   UUID:   $UUID"
echo "   Pass:   $PASSWORD"
echo "========================================================"
