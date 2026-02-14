# TUIC v5 Server

A one-click deployment script for [TUIC v5](https://github.com/EAimTY/tuic) proxy server using Docker. Compatible with [Clash Verge](https://github.com/clash-verge-rev/clash-verge-rev) and [Clash Party](https://github.com/mihomo-party-org/clash-party).

## Features

- **TUIC v5** protocol over **UDP** (QUIC-based)
- **BBR** congestion control
- **Docker** containerized deployment
- **Nginx** for serving Clash subscription URL
- Auto-generated **self-signed certificates**
- Auto-detected **IPv4** address

## Quick Start

SSH into your VPS as root and run:

```bash
curl -O https://raw.githubusercontent.com/monk279/tuic-server/main/install_tuic.sh
chmod +x install_tuic.sh
./install_tuic.sh
```

The script will:
1. Install Docker and dependencies
2. Generate a unique UUID and password
3. Create self-signed TLS certificates
4. Build and start the TUIC server container
5. Start an Nginx container to serve the Clash subscription file
6. Print your **Subscription URL** at the end

## Manual Setup

1. Copy `config.example.json` to `config.json` and fill in your credentials
2. Copy `subscribe.example.yaml` to `subscribe.yaml` and fill in your server details
3. Run `./generate-certs.sh` to generate certificates
4. Run `docker-compose build && docker-compose up -d`

## Client Configuration

Import the subscription URL into **Clash Verge** or **Clash Party**:

```
http://YOUR_SERVER_IP:8080/subscribe.yaml
```

> **Note:** Since this uses a self-signed certificate, enable `skip-cert-verify` in your client.

## Multi-User Support

Add more users by adding UUID/password pairs to `config.json`:

```json
"users": {
    "uuid-1": "password-1",
    "uuid-2": "password-2"
}
```

Then restart: `docker-compose restart tuic`

## Management

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# View logs
docker logs tuic-server

# Restart
docker-compose restart
```

## License

MIT
