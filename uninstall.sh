#!/bin/bash

echo "(-) Stopping monitoring service..."
# Stop the monitoring service
sudo systemctl stop monitoring.service >/dev/null 2>&1

echo "(-) Disabling monitoring service..."
# Disable the monitoring service
sudo systemctl disable monitoring.service >/dev/null 2>&1

echo "(-) Removing service file..."
# Remove the service file from the systemd directory
sudo rm /etc/systemd/system/monitoring.service >/dev/null 2>&1

echo "(-) Reloading systemd..."
# Reload systemd to recognize the changes
sudo systemctl daemon-reload >/dev/null 2>&1

echo "(-) Removing monitoring user and group..."
# Remove the 'monitoring' user and group
sudo userdel monitoring >/dev/null 2>&1
sudo groupdel monitoring >/dev/null 2>&1

echo "(-) Removing monitoring files..."
# Delete the monitoring files including virtual environment
sudo rm -r /opt/monitoring >/dev/null 2>&1
sudo rm -r /etc/monitoring >/dev/null 2>&1
sudo rm /etc/sudoers.d/monitoring >/dev/null 2>&1

echo "(-) Cleaning up logs..."
# Delete logs
sudo journalctl --vacuum-time=1s --unit=monitoring.service >/dev/null 2>&1

echo "(-) Uninstalling packages..."
# Remove gnupg as it was specifically installed for monitoring
sudo apt remove --purge gnupg -y >/dev/null 2>&1
# Note: We don't remove python3-venv as it might be used by other applications
# The virtual environment in /etc/monitoring/venv is already removed above
echo "(!) Note: python3-venv package is left installed as it may be used by other applications"

echo "(✓) Monitoring service has been uninstalled successfully!"