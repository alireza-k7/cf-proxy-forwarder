# cf-proxy-forwarder
Forward HTTP requests from Cloudflare Workers through a secured Squid proxy using Docker Compose.

A Docker-based proxy forwarding service that routes outbound HTTP(S) traffic through a Squid proxy with basic authentication — designed for use with Cloudflare Workers.

---

## 🌐 DNS Configuration (Required)

> ⚠️ Before you begin, it is **strongly recommended** to set your server's DNS to Cloudflare's (1.1.1.1) to avoid DNS resolution issues.

### On Ubuntu:

Edit the Netplan or systemd-resolved config (example for Netplan):

```bash
sudo vim /etc/netplan/01-netcfg.yaml
nameservers:
  addresses: [1.1.1.1, 1.0.0.1]
netplan apply

---
## 🚀 Run This Project

To clone and start the project, run:

```bash
git clone https://github.com/alireza-k7/cf-proxy-forwarder.git
cd cf-proxy-forwarder
chmod +x setup-proxy.sh
./setup-proxy.sh
