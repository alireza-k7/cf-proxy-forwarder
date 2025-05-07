#!/bin/bash

# Make sure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Install necessary packages
apt-get update
apt-get install -y apache2-utils docker.io docker-compose curl

# Create username and password
echo "Setting up proxy authentication"
echo "Enter username for proxy:"
read USERNAME

# Create the passwd file
touch passwd
chmod 777 passwd

# Add the user to the passwd file (htpasswd from apache2-utils)
htpasswd -c passwd "$USERNAME"
PASSWORD=$(cat passwd | cut -d':' -f2)
chmod 644 passwd

# If already running, stop and remove containers
docker compose down

# Start the services
echo "Starting Docker Compose services..."
docker compose up -d

# Wait for services to be fully up
echo "Waiting for services to initialize..."
sleep 10

# Get cloudflared's actual IP
CLOUDFLARED_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' cloudflared)
echo "CloudFlared container IP: $CLOUDFLARED_IP"

# Update the squid.conf file with the correct cloudflared IP
sed -i "s/172.20.0.2/$CLOUDFLARED_IP/g" squid.conf

# Update /etc/hosts in the squid container
docker exec squid-proxy bash -c "echo '$CLOUDFLARED_IP cloudflared' >> /etc/hosts"

# Install DNS utilities in the squid container for testing
echo "Installing diagnostic tools in Squid container..."
docker exec squid-proxy apt-get update
docker exec squid-proxy apt-get install -y dnsutils net-tools iputils-ping

# Restart Squid to apply changes
echo "Restarting Squid to apply configuration changes..."
docker restart squid-proxy
sleep 10

echo "Checking service status..."
docker compose ps

# Test DNS resolution
echo "Testing DNS resolution within Squid container..."
docker exec squid-proxy dig +short google.com

# Get the server's IP address
SERVER_IP=$(hostname -I | awk '{print $1}')

# Wait a bit more for Squid to fully initialize
echo "Waiting for Squid to fully initialize..."
sleep 5

# Check squid logs for any errors
echo "Checking Squid logs for errors:"
docker exec squid-proxy tail -n 20 /var/log/squid/cache.log

# Test proxy access to verify everything is working
echo "Testing proxy access (this may take a moment)..."
PROXY_URL="http://$USERNAME:$PASSWORD@$SERVER_IP:3128"
echo "Proxy URL: $PROXY_URL"

# Safe test with timeout
curl -m 30 -s -o /dev/null -w "HTTP Status Code: %{http_code}\n" -x "$PROXY_URL" http://example.com

echo "Setup complete! Your HTTP proxy is available at $SERVER_IP:3128"
echo "Use the following format to connect: http://$USERNAME:password@$SERVER_IP:3128"
echo "NOTE: If your password contains special characters, you may need to URL encode them"

echo "You can verify Squid is running with: docker logs squid-proxy"
