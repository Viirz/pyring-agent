#!/bin/bash

echo "=== Monitoring Service Health Check ==="
echo ""

# Check if monitoring user exists
echo "[1/7] Checking monitoring user..."
if id "monitoring" &>/dev/null; then
    echo "  ✓ User 'monitoring' exists"
else
    echo "  ✗ User 'monitoring' does not exist"
fi

# Check if directories exist
echo "[2/7] Checking directories..."
if [ -d "/opt/monitoring" ]; then
    echo "  ✓ /opt/monitoring directory exists"
else
    echo "  ✗ /opt/monitoring directory missing"
fi

if [ -d "/etc/monitoring" ]; then
    echo "  ✓ /etc/monitoring directory exists"
else
    echo "  ✗ /etc/monitoring directory missing"
fi

# Check virtual environment
echo "[3/7] Checking virtual environment..."
if [ -f "/etc/monitoring/venv/bin/python" ]; then
    echo "  ✓ Virtual environment exists"
    PYTHON_VERSION=$(/etc/monitoring/venv/bin/python --version 2>&1)
    echo "    Python version: $PYTHON_VERSION"
else
    echo "  ✗ Virtual environment missing"
fi

# Check Python packages
echo "[4/7] Checking Python packages..."
if [ -f "/etc/monitoring/venv/bin/python" ]; then
    PACKAGES=("dotenv" "apscheduler" "gnupg" "requests")
    for package in "${PACKAGES[@]}"; do
        if /etc/monitoring/venv/bin/python -c "import $package" &>/dev/null; then
            echo "  ✓ $package is installed"
        else
            echo "  ✗ $package is missing"
        fi
    done
else
    echo "  ✗ Cannot check packages - virtual environment missing"
fi

# Check configuration file
echo "[5/7] Checking configuration..."
if [ -f "/etc/monitoring/.env" ]; then
    echo "  ✓ Configuration file exists"
    if grep -q "UUID=" "/etc/monitoring/.env"; then
        echo "  ✓ UUID configured"
    else
        echo "  ✗ UUID not configured"
    fi
else
    echo "  ✗ Configuration file missing"
fi

# Check systemd service
echo "[6/7] Checking systemd service..."
if [ -f "/etc/systemd/system/monitoring.service" ]; then
    echo "  ✓ Service file exists"
    if systemctl is-enabled monitoring.service &>/dev/null; then
        echo "  ✓ Service is enabled"
    else
        echo "  ✗ Service is not enabled"
    fi
    
    if systemctl is-active monitoring.service &>/dev/null; then
        echo "  ✓ Service is running"
    else
        echo "  ✗ Service is not running"
    fi
else
    echo "  ✗ Service file missing"
fi

# Check permissions
echo "[7/7] Checking file permissions..."
if [ -d "/opt/monitoring" ] && [ -d "/etc/monitoring" ]; then
    OPT_OWNER=$(stat -c '%U:%G' /opt/monitoring)
    ETC_OWNER=$(stat -c '%U:%G' /etc/monitoring)
    
    if [ "$OPT_OWNER" = "monitoring:monitoring" ]; then
        echo "  ✓ /opt/monitoring has correct ownership"
    else
        echo "  ✗ /opt/monitoring ownership: $OPT_OWNER (should be monitoring:monitoring)"
    fi
    
    if [ "$ETC_OWNER" = "monitoring:monitoring" ]; then
        echo "  ✓ /etc/monitoring has correct ownership"
    else
        echo "  ✗ /etc/monitoring ownership: $ETC_OWNER (should be monitoring:monitoring)"
    fi
else
    echo "  ✗ Cannot check permissions - directories missing"
fi

echo ""
echo "=== Health Check Complete ==="

# Show service logs if service exists
if systemctl list-unit-files | grep -q "monitoring.service"; then
    echo ""
    echo "Recent service logs:"
    sudo journalctl -u monitoring.service --no-pager -n 5
fi
