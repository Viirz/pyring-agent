#!/bin/bash

echo "(+) Creating user for running service..."
# Create a user and group called 'monitoring'
sudo useradd -s /usr/sbin/nologin -U -r monitoring >/dev/null 2>&1
sudo usermod -a -G adm monitoring >/dev/null 2>&1

echo "(+) Setting up monitoring directories..."
# Copy the file needed for the monitoring service
sudo cp -r . /opt/monitoring >/dev/null 2>&1
sudo mkdir /etc/monitoring >/dev/null 2>&1
sudo touch /etc/monitoring/.env >/dev/null 2>&1
sudo cp requirements.txt /etc/monitoring/ >/dev/null 2>&1

echo "(+) Creating GPG directory..."
# Create GPG directory for the monitoring user
sudo mkdir -p /opt/monitoring/client/.gnupg >/dev/null 2>&1
sudo chmod 700 /opt/monitoring/client/.gnupg >/dev/null 2>&1

echo "(+) Setting file permissions..."
# Change the ownership of the files to the monitoring user and group
sudo chown -R monitoring:monitoring /opt/monitoring >/dev/null 2>&1
sudo chown -R monitoring:monitoring /etc/monitoring >/dev/null 2>&1

echo "(+) Configuring environment file..."
# Insert env file with template
echo "UUID=\"TEMPLATE_UUID\"" | sudo tee -a /etc/monitoring/.env >/dev/null

echo "(+) Setting up sudo permissions..."
# add access to monitoring group
echo "monitoring ALL=(ALL) NOPASSWD: \
      /usr/sbin/ip a, \
      /usr/sbin/ip route show, \
      /usr/bin/journalctl, \
      /usr/bin/traceroute, \
      /usr/bin/dmesg, \
      /usr/sbin/reboot *, \
      /usr/bin/systemctl start *, \
      /usr/bin/systemctl status *, \
      /usr/bin/systemctl restart *" | sudo tee /etc/sudoers.d/monitoring >/dev/null

echo "(+) Installing required packages..."
# install python3-venv for virtual environment support
sudo apt install -y python3-venv >/dev/null 2>&1
sudo apt install -y gnupg >/dev/null 2>&1

echo "(+) Creating Python virtual environment..."
# Create virtual environment in /etc/monitoring/venv
sudo python3 -m venv /etc/monitoring/venv >/dev/null 2>&1

echo "(+) Installing Python dependencies in virtual environment..."
# Install required Python packages from requirements.txt
sudo /etc/monitoring/venv/bin/pip install --upgrade pip >/dev/null 2>&1
sudo /etc/monitoring/venv/bin/pip install -r /etc/monitoring/requirements.txt >/dev/null 2>&1

echo "(+) Validating virtual environment setup..."
# Verify that the virtual environment and packages are properly installed
if [ ! -f "/etc/monitoring/venv/bin/python" ]; then
    echo "(!) Error: Virtual environment was not created successfully"
    exit 1
fi

# Test if required packages are importable
sudo /etc/monitoring/venv/bin/python -c "import dotenv, apscheduler, gnupg, requests" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "(!) Warning: Some Python packages may not have installed correctly"
    echo "(!) Please check the installation manually"
fi

echo "(+) Setting up systemd service..."
# Copy the service file to the systemd directory
sudo cp /opt/monitoring/service/monitoring.service /etc/systemd/system/monitoring.service >/dev/null 2>&1

# Reload systemd to recognize the new service
sudo systemctl daemon-reload >/dev/null 2>&1

# Enable the monitoring service to start on boot
sudo systemctl enable monitoring.service >/dev/null 2>&1

# Start the monitoring service
#sudo systemctl start monitoring.service

echo "(✓) Monitoring service has been set up successfully!"
echo "(✓) Python virtual environment created at: /etc/monitoring/venv"
echo "(!) Please configure the env file located in /etc/monitoring/.env and start the service."
echo ""
echo "Next steps:"
echo "  1. Edit /etc/monitoring/.env with your UUID"
echo "  2. Start the service: sudo systemctl start monitoring.service"
echo "  3. Check status: sudo systemctl status monitoring.service"