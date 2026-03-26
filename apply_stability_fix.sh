#!/bin/bash

# This script applies the stability improvements to an existing TUIC VPN server.
# Run it as root on your other servers.

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo ">>> Applying sysctl network optimizations (UDP buffers & BBR)..."
cat > /etc/sysctl.d/99-tuic-bbr.conf <<EOF
net.core.rmem_max=2500000
net.core.wmem_max=2500000
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system > /dev/null

echo ">>> Updating TUIC application timeouts..."
CONFIG_FILE="/root/tuic-server/config.json"

if [ -f "$CONFIG_FILE" ]; then
    # We use sed to safely update these specific keys without affecting users or certificates
    sed -i 's/"auth_timeout": "[^"]*"/"auth_timeout": "10s"/' "$CONFIG_FILE"
    sed -i 's/"task_negotiation_timeout": "[^"]*"/"task_negotiation_timeout": "10s"/' "$CONFIG_FILE"
    sed -i 's/"max_idle_time": "[^"]*"/"max_idle_time": "30s"/' "$CONFIG_FILE"
    sed -i 's/"max_external_packet_size": [0-9]*/"max_external_packet_size": 1400/' "$CONFIG_FILE"
    
    echo ">>> Restarting TUIC Server..."
    cd /root/tuic-server && docker-compose restart tuic > /dev/null 2>&1 || docker restart tuic-server
    echo ">>> Success! Stability improvements applied successfully."
else
    echo "Error: TUIC Config not found at $CONFIG_FILE."
    echo "Ensure you are running this script on a server with TUIC installed in /root/tuic-server."
    exit 1
fi
