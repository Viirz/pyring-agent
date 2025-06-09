#!/bin/bash

echo "(+) Updating Python virtual environment for monitoring service..."

# Stop the service if it's running
echo "(-) Stopping monitoring service..."
sudo systemctl stop monitoring.service >/dev/null 2>&1

echo "(+) Upgrading pip in virtual environment..."
sudo /etc/monitoring/venv/bin/pip install --upgrade pip >/dev/null 2>&1

echo "(+) Installing/updating Python dependencies from requirements.txt..."
if [ -f "/etc/monitoring/requirements.txt" ]; then
    sudo /etc/monitoring/venv/bin/pip install -r /etc/monitoring/requirements.txt >/dev/null 2>&1
else
    echo "(!) requirements.txt not found, installing default packages..."
    sudo /etc/monitoring/venv/bin/pip install python-dotenv >/dev/null 2>&1
    sudo /etc/monitoring/venv/bin/pip install apscheduler >/dev/null 2>&1
    sudo /etc/monitoring/venv/bin/pip install python-gnupg >/dev/null 2>&1
    sudo /etc/monitoring/venv/bin/pip install requests >/dev/null 2>&1
fi

echo "(+) Ensuring proper ownership of virtual environment..."
sudo chown -R monitoring:monitoring /etc/monitoring/venv >/dev/null 2>&1

echo "(+) Starting monitoring service..."
sudo systemctl start monitoring.service >/dev/null 2>&1

echo "(✓) Virtual environment updated successfully!"
echo "Service status:"
sudo systemctl status monitoring.service --no-pager
