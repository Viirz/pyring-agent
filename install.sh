#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}(+) Pyring Agent Installation${NC}"
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}(!) Error: .env file not found${NC}"
    echo -e "${YELLOW}(!) Please copy .env.example to .env and configure it first${NC}"
    echo ""
    echo "Run: cp .env.example .env"
    echo "Then edit .env with your configuration"
    exit 1
fi

# Validate .env file
echo -e "${GREEN}(+) Validating configuration...${NC}"
source .env

if [ "$UUID" = "your-uuid-here" ] || [ -z "$UUID" ]; then
    echo -e "${RED}(!) Error: UUID not configured in .env${NC}"
    exit 1
fi

if [ "$SERVER_URL" = "https://your-pyring-server:5000" ]; then
    echo -e "${YELLOW}(!) Warning: SERVER_URL is still set to default value${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}  ✓ Configuration validated${NC}"
echo ""

# Prompt for GPG keys
echo -e "${GREEN}(+) GPG Key Configuration${NC}"
echo ""
echo "Please provide your GPG keys. You can:"
echo "  1. Paste the key content directly (multi-line input)"
echo "  2. Press Ctrl+D when finished"
echo ""

# Get agent private key
echo -e "${YELLOW}Enter Agent Private Key (paste and press Ctrl+D):${NC}"
AGENT_PRIV_KEY=$(cat)

if [ -z "$AGENT_PRIV_KEY" ]; then
    echo -e "${RED}(!) Error: Agent private key is required${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}  ✓ Agent private key received${NC}"
echo ""

# Get server public key
echo -e "${YELLOW}Enter Server Public Key (paste and press Ctrl+D):${NC}"
SERVER_PUB_KEY=$(cat)

if [ -z "$SERVER_PUB_KEY" ]; then
    echo -e "${RED}(!) Error: Server public key is required${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}  ✓ Server public key received${NC}"
echo ""

# Confirm installation
echo -e "${YELLOW}Ready to install Pyring Agent with the following configuration:${NC}"
echo "  UUID: $UUID"
echo "  Server URL: $SERVER_URL"
echo "  SSL Verify: $SSL_VERIFY"
echo "  Status Interval: ${STATUS_INTERVAL}s"
echo "  Command Interval: ${COMMAND_INTERVAL}s"
echo ""
read -p "Proceed with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}(+) Creating user for running service...${NC}"
sudo useradd -s /usr/sbin/nologin -U -r monitoring 2>/dev/null || true
sudo usermod -a -G adm monitoring 2>/dev/null || true

echo -e "${GREEN}(+) Setting up monitoring directories...${NC}"
sudo mkdir -p /opt/monitoring 2>/dev/null || true
sudo mkdir -p /etc/monitoring 2>/dev/null || true
sudo mkdir -p /opt/monitoring/client/.pgp 2>/dev/null || true
sudo mkdir -p /opt/monitoring/client/.gnupg 2>/dev/null || true

# Copy project files
sudo cp -r client /opt/monitoring/ 2>/dev/null || true
sudo cp -r service /opt/monitoring/ 2>/dev/null || true
sudo cp requirements.txt /etc/monitoring/ 2>/dev/null || true

echo -e "${GREEN}(+) Installing GPG keys...${NC}"
# Save agent private key
echo "$AGENT_PRIV_KEY" | sudo tee /opt/monitoring/client/.pgp/priv_key.asc >/dev/null

# Save server public key
echo "$SERVER_PUB_KEY" | sudo tee /opt/monitoring/client/.pgp/server_pub_key.asc >/dev/null

# Set proper permissions for GPG directories
sudo chmod 700 /opt/monitoring/client/.gnupg 2>/dev/null || true
sudo chmod 700 /opt/monitoring/client/.pgp 2>/dev/null || true
sudo chmod 600 /opt/monitoring/client/.pgp/*.asc 2>/dev/null || true

echo -e "${GREEN}(+) Configuring environment file...${NC}"
# Copy .env to /etc/monitoring
sudo cp .env /etc/monitoring/.env

echo -e "${GREEN}(+) Setting file permissions...${NC}"
sudo chown -R monitoring:monitoring /opt/monitoring
sudo chown -R monitoring:monitoring /etc/monitoring

echo -e "${GREEN}(+) Setting up sudo permissions...${NC}"
echo "monitoring ALL=(ALL) NOPASSWD: \
      /usr/sbin/ip a, \
      /usr/sbin/ip route show, \
      /usr/bin/journalctl, \
      /usr/bin/tracepath, \
      /usr/bin/dmesg, \
      /usr/sbin/reboot *, \
      /usr/bin/systemctl start *, \
      /usr/bin/systemctl status *, \
      /usr/bin/systemctl restart *" | sudo tee /etc/sudoers.d/monitoring >/dev/null

echo -e "${GREEN}(+) Installing required system packages...${NC}"
sudo apt update >/dev/null 2>&1
sudo apt install -y python3-venv gnupg >/dev/null 2>&1

echo -e "${GREEN}(+) Creating Python virtual environment...${NC}"
sudo python3 -m venv /etc/monitoring/venv

echo -e "${GREEN}(+) Installing Python dependencies...${NC}"
sudo /etc/monitoring/venv/bin/pip install --upgrade pip >/dev/null 2>&1
sudo /etc/monitoring/venv/bin/pip install -r /etc/monitoring/requirements.txt

echo -e "${GREEN}(+) Validating virtual environment setup...${NC}"
if [ ! -f "/etc/monitoring/venv/bin/python" ]; then
    echo -e "${RED}(!) Error: Virtual environment was not created successfully${NC}"
    exit 1
fi

sudo /etc/monitoring/venv/bin/python -c "import dotenv, apscheduler, gnupg, requests" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}(!) Warning: Some Python packages may not have installed correctly${NC}"
    echo -e "${YELLOW}(!) Please check the installation manually${NC}"
fi

# Fix permissions after package installation
sudo chown -R monitoring:monitoring /etc/monitoring/venv

echo -e "${GREEN}(+) Setting up systemd service...${NC}"
sudo cp /opt/monitoring/service/monitoring.service /etc/systemd/system/monitoring.service
sudo systemctl daemon-reload
sudo systemctl enable monitoring.service

echo -e "${GREEN}(+) Starting monitoring service...${NC}"
sudo systemctl start monitoring.service

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Pyring Agent installed and started successfully!   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Service Status:${NC}"
sudo systemctl status monitoring.service --no-pager -l
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "  Check status:  sudo systemctl status monitoring"
echo "  View logs:     sudo journalctl -u monitoring -f"
echo "  Restart:       sudo systemctl restart monitoring"
echo "  Stop:          sudo systemctl stop monitoring"