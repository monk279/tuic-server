#!/bin/bash

# VLESS + XTLS-Reality Auto-Install Script
# Runs alongside existing TUIC server
# TUIC uses UDP 443, Reality uses TCP 443
# Run as root

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo ">>> Starting VLESS+XTLS-Reality Installation..."

INSTALL_DIR="/root/tuic-server"
cd "$INSTALL_DIR"

# 1. Pull Xray image first (needed for key generation)
echo ">>> Pulling Xray Docker image..."
docker pull ghcr.io/xtls/xray-core:latest

# 2. Generate Credentials
echo ">>> Generating Credentials..."
UUID=$(docker run --rm ghcr.io/xtls/xray-core:latest uuid)
KEYS=$(docker run --rm ghcr.io/xtls/xray-core:latest x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey:" | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYS" | grep "PublicKey)" | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 8)
PUBLIC_IP=$(curl -4 -s ifconfig.me)

echo "    UUID:        $UUID"
echo "    Private Key: $PRIVATE_KEY"
echo "    Public Key:  $PUBLIC_KEY"
echo "    Short ID:    $SHORT_ID"
echo "    IP:          $PUBLIC_IP"

# 3. Create Xray config directory
mkdir -p "$INSTALL_DIR/xray"

# 4. Generate Xray config
cat > xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": [
            "www.microsoft.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

# 5. Allow unprivileged port binding (xray runs as non-root in container)
echo ">>> Configuring kernel for unprivileged port binding..."
sysctl -w net.ipv4.ip_unprivileged_port_start=0
grep -qxF 'net.ipv4.ip_unprivileged_port_start=0' /etc/sysctl.conf || echo 'net.ipv4.ip_unprivileged_port_start=0' >> /etc/sysctl.conf

# 6. Update docker-compose.yml — add xray service if not present
if ! grep -q "xray-reality" docker-compose.yml; then
  echo ">>> Adding Xray service to docker-compose.yml..."
  cat >> docker-compose.yml <<EOF

  xray:
    image: ghcr.io/xtls/xray-core:latest
    container_name: xray-reality
    restart: always
    network_mode: host
    cap_add:
      - NET_BIND_SERVICE
    volumes:
      - ./xray:/usr/local/etc/xray
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
EOF
fi

# 7. Configure Firewall — allow TCP 443
echo ">>> Configuring Firewall..."
if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
        echo "    Allowing 443/tcp in UFW..."
        ufw allow 443/tcp
    fi
fi

# 8. Generate VLESS share link
VLESS_LINK="vless://${UUID}@${PUBLIC_IP}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#VPS-Reality"

# 9. Save share link for nginx to serve
cat > reality_link.txt <<EOF
$VLESS_LINK
EOF

# Also add to nginx volumes if not already done
if ! grep -q "reality_link.txt" docker-compose.yml; then
  sed -i '/subscribe.yaml:\/usr\/share\/nginx\/html\/subscribe.yaml/a\      - ./reality_link.txt:/usr/share/nginx/html/reality_link.txt' docker-compose.yml
fi

# 10. Start/Restart Services
echo ">>> Starting Services..."
docker-compose up -d
# Force restart to pick up new configs
docker-compose restart

# 11. Final Output
echo ""
echo "========================================================"
echo " VLESS+XTLS-Reality Installed Successfully!"
echo "========================================================"
echo ""
echo " VLESS Share Link (import this into your client):"
echo ""
echo " $VLESS_LINK"
echo ""
echo " Download link: http://$PUBLIC_IP:8080/reality_link.txt"
echo ""
echo " Manual Config:"
echo "   Protocol:   VLESS"
echo "   Server:     $PUBLIC_IP"
echo "   Port:       443"
echo "   UUID:       $UUID"
echo "   Flow:       xtls-rprx-vision"
echo "   Security:   Reality"
echo "   SNI:        www.microsoft.com"
echo "   Fingerprint: chrome"
echo "   Public Key: $PUBLIC_KEY"
echo "   Short ID:   $SHORT_ID"
echo "========================================================"
echo " TUIC is still running on UDP 443 (unchanged)"
echo "========================================================"
