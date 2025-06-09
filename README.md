# Pyring Agent

This project implements a monitoring agent that periodically sends status updates to a Pyring Server. It is designed to run as a systemd service for easy management and automation.

## Related Repositories

- **Pyring Server**: [https://github.com/your-username/pyring-server](https://github.com/your-username/pyring-server) - The server component that receives and processes monitoring data from agents

## Project Structure

- **client/config.py**: Contains the main logic for the Pyring Agent, including configuration constants and the `send_status` function that handles sending status updates and logging in case of failures.
  
- **client/monitoring.py**: Core monitoring functionality and communication with the Pyring Server.

- **client/task.sh**: A shell script that performs a recovery when the agent cannot send request to the Pyring Server.

- **service/monitoring.service**: A systemd service unit file that defines how the monitoring service is managed by systemd. It specifies the service name, description, execution command, and dependencies. Updated to use the virtual environment Python interpreter.

- **install.sh**: A shell script that automates the installation and setup of the Pyring Agent, including creating a Python virtual environment and installing dependencies.

- **uninstall.sh**: A shell script that automates the uninstallation of the Pyring Agent, including removing the virtual environment.

- **update_venv.sh**: A script to update the Python virtual environment and dependencies.

- **health_check.sh**: A diagnostic script to verify the installation and service health.

- **requirements.txt**: Lists all Python dependencies for the virtual environment.

- **README.md**: This documentation file.

## Prerequisites

- Python 3.x with venv module
- GPG key pair from Pyring Server admin dashboard:
  - Agent private key (for this Pyring Agent)
  - Server public key (for secure communication with Pyring Server)
- System packages:
  - `python3-venv` (for virtual environment support)
  - `gnupg` (for GPG functionality)
- System utilities:
  - `ip`
  - `journalctl`
  - `traceroute`
  - `dmesg`

The service uses a dedicated Python virtual environment located at `/etc/monitoring/venv` with the following Python packages:
- `requests`
- `python-dotenv`
- `apscheduler`
- `python-gnupg`

## Installation

1. Clone the repository or download the project files.
2. Navigate to the project directory.
3. Set up GPG keys from the Pyring Server admin dashboard:

   ```bash
   # Copy the agent private key from Pyring Server admin dashboard to:
   # /path/to/client/agent-private-key.asc
   
   # Copy the server public key from Pyring Server admin dashboard to:
   # /path/to/client/server-public-key.asc
   ```

4. Run the installation script to install the Pyring Agent:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   This script will:
   - Create a dedicated `monitoring` user and group
   - Set up directories in `/opt/monitoring` and `/etc/monitoring`
   - Create a Python virtual environment at `/etc/monitoring/venv`
   - Install all required Python packages in the virtual environment
   - Configure systemd service with proper permissions

5. Configure the environment variables in `/etc/monitoring/.env`:

   ```env
   UUID="your-uuid-here"
   ```

6. Start the service:

   ```bash
   sudo systemctl start monitoring.service
   ```

7. Check the service status:

   ```bash
   sudo systemctl status monitoring.service
   ```

## Running the Service

To start the Pyring Agent, use the following command:

```bash
sudo systemctl start monitoring
```

To enable the Pyring Agent to start on boot:

```bash
sudo systemctl enable monitoring
```

## Checking Service Status

You can check the status of the Pyring Agent with:

```bash
sudo systemctl status monitoring
```

## Logs

Logs can be viewed using the journalctl command:

```bash
journalctl -u monitoring.service
```

## Troubleshooting

### Health Check

Run the health check script to verify the installation:

```bash
chmod +x health_check.sh
./health_check.sh
```

This will check:
- Monitoring user existence
- Directory structure
- Virtual environment setup
- Python package installation
- Configuration files
- Service status and permissions

### Common Issues

1. **Service fails to start**: Check that the virtual environment is properly set up and all dependencies are installed.
2. **Permission errors**: Ensure the monitoring user owns all files in `/opt/monitoring` and `/etc/monitoring`.
3. **Import errors**: Verify that all Python packages are installed in the virtual environment using the health check script.

## Uninstallation

To uninstall the Pyring Agent, run the following script:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

This will stop the service, remove all related files including the virtual environment, and delete the `monitoring` user and group.

## Virtual Environment Management

The Pyring Agent uses an isolated Python virtual environment located at `/etc/monitoring/venv`. This ensures that:
- Dependencies don't conflict with system packages
- The service has exactly the versions it needs
- Updates can be managed independently

### Updating Dependencies

To update the Python packages in the virtual environment:

```bash
chmod +x update_venv.sh
./update_venv.sh
```

### Manual Virtual Environment Management

If you need to manually manage the virtual environment:

```bash
# Activate the virtual environment
sudo -u monitoring /etc/monitoring/venv/bin/python

# Install a package
sudo /etc/monitoring/venv/bin/pip install package-name

# List installed packages
sudo /etc/monitoring/venv/bin/pip list

# Update all packages
sudo /etc/monitoring/venv/bin/pip install --upgrade pip
sudo /etc/monitoring/venv/bin/pip install -r /etc/monitoring/requirements.txt --upgrade
```

## Security

- The `monitoring` user is created as a system user with no login shell for security purposes.
- The `sudoers` file is updated to allow the `monitoring` user to execute specific commands without a password.

## Contributing

Feel free to submit issues or pull requests for improvements or bug fixes.