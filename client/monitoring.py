import requests
import subprocess
import time
import threading
import gnupg
import json
import os

class Monitoring:
    def __init__(self, uuid, server_url, ssl_verify):
        self.uuid = uuid
        self.server_url = server_url
        self.server_ip = server_url.split('/')[2] 
        self.status = 1
        self.retries = 5
        self.ssl_verify = ssl_verify
        self.lock = threading.Lock()
        
        # Initialize GPG with custom directory and options
        self.gpg_home = '/opt/monitoring/client/.gnupg'
        self.gpg = gnupg.GPG(
            gnupghome=self.gpg_home,
            options=['--pinentry-mode', 'loopback', '--batch', '--yes']
        )
        self.priv_key_path = '/opt/monitoring/client/.pgp/priv_key.asc'
        self.server_pub_key_path = '/opt/monitoring/client/.pgp/server_pub_key.asc'
        
        # Import keys
        self._import_keys()

    def _parse_and_import_key(self, key_string):
        """Parse a key string with escaped newlines and import it"""
        try:
            # Replace escaped newlines with actual newlines
            parsed_key = key_string.replace('\\n', '\n')
            
            # Import the key
            import_result = self.gpg.import_keys(parsed_key)
            
            if import_result.count > 0:
                print(f"Successfully imported {import_result.count} key(s)", flush=True)
                print(f"Key fingerprints: {import_result.fingerprints}", flush=True)
                return True
            else:
                print(f"Failed to import key: {import_result.stderr}", flush=True)
                return False
                
        except Exception as e:
            print(f"Error parsing and importing key: {e}", flush=True)
            return False

    def _import_keys(self):
        """Import PGP keys if they exist"""
        try:
            # Import private key
            if os.path.exists(self.priv_key_path):
                with open(self.priv_key_path, 'r') as f:
                    priv_key_data = f.read()
                    if priv_key_data.strip():  # Only import if file has content
                        print(f"Importing private key from {self.priv_key_path}", flush=True)
                        # Check if it's an escaped format
                        if '\\n' in priv_key_data:
                            success = self._parse_and_import_key(priv_key_data.strip())
                            print(f"Private key import success: {success}", flush=True)
                        else:
                            import_result = self.gpg.import_keys(priv_key_data)
                            print(f"Imported private key: {import_result.count} keys", flush=True)
                            if import_result.stderr:
                                print(f"Private key import stderr: {import_result.stderr}", flush=True)
            else:
                print(f"Private key file not found: {self.priv_key_path}", flush=True)
            
            # Import server public key
            if os.path.exists(self.server_pub_key_path):
                with open(self.server_pub_key_path, 'r') as f:
                    pub_key_data = f.read()
                    if pub_key_data.strip():  # Only import if file has content
                        print(f"Importing server public key from {self.server_pub_key_path}", flush=True)
                        # Check if it's an escaped format
                        if '\\n' in pub_key_data:
                            success = self._parse_and_import_key(pub_key_data.strip())
                            print(f"Server public key import success: {success}", flush=True)
                        else:
                            import_result = self.gpg.import_keys(pub_key_data)
                            print(f"Imported server public key: {import_result.count} keys", flush=True)
                            if import_result.stderr:
                                print(f"Server public key import stderr: {import_result.stderr}", flush=True)
            else:
                print(f"Server public key file not found: {self.server_pub_key_path}", flush=True)
                
            # List all keys after import
            print("=== All keys after import ===", flush=True)
            all_priv_keys = self.gpg.list_keys(True)
            all_pub_keys = self.gpg.list_keys()
            print(f"Total private keys: {len(all_priv_keys)}", flush=True)
            print(f"Total public keys: {len(all_pub_keys)}", flush=True)
            
        except Exception as e:
            print(f"Error importing keys: {e}", flush=True)

    def _encrypt_and_sign_data(self, data):
        """Encrypt data with server public key and sign with private key"""
        try:
            json_data = json.dumps(data)
            
            # Get key fingerprints
            priv_keys = self.gpg.list_keys(True)  # True for private keys
            pub_keys = self.gpg.list_keys()
            
            print(f"Available private keys: {len(priv_keys)}", flush=True)
            print(f"Available public keys: {len(pub_keys)}", flush=True)
            
            if not priv_keys:
                print("No private key found for signing", flush=True)
                return None
            
            if len(pub_keys) < 2:
                print("Server public key not found for encryption", flush=True)
                return None
            
            # Debug: Print key information
            for i, key in enumerate(priv_keys):
                print(f"Private key {i}: {key['fingerprint']} - {key.get('uids', ['No UID'])}", flush=True)
            
            for i, key in enumerate(pub_keys):
                print(f"Public key {i}: {key['fingerprint']} - {key.get('uids', ['No UID'])}", flush=True)
            
            # Use the private key for signing
            priv_key_id = priv_keys[0]['fingerprint']
            
            # Find the server's public key (not our own)
            server_key_id = None
            for key in pub_keys:
                # Look for the server key by checking if it's NOT our own key
                if key['fingerprint'] != priv_key_id:
                    server_key_id = key['fingerprint']
                    break
            
            if not server_key_id:
                print("Server public key not found for encryption", flush=True)
                return None
            
            print(f"Using private key for signing: {priv_key_id}", flush=True)
            print(f"Using server public key for encryption: {server_key_id}", flush=True)
            
            # Encrypt and sign with passphrase handling
            encrypted_data = self.gpg.encrypt(
                json_data,
                recipients=[server_key_id],
                sign=priv_key_id,
                always_trust=True,
                passphrase=self.uuid
            )
            
            print(f"Encryption status: {encrypted_data.ok}", flush=True)
            print(f"Encryption stderr: {encrypted_data.stderr}", flush=True)
            
            if encrypted_data.ok:
                return str(encrypted_data)
            else:
                print(f"Encryption failed: {encrypted_data.status}", flush=True)
                print(f"Encryption stderr: {encrypted_data.stderr}", flush=True)
                return None
                
        except Exception as e:
            print(f"Error encrypting and signing data: {e}", flush=True)
            return None

    def _decrypt_and_verify_response(self, encrypted_response):
        """Decrypt response with private key and verify signature with server public key"""
        try:
            decrypted_data = self.gpg.decrypt(encrypted_response)
            
            if decrypted_data.ok:
                if decrypted_data.valid:
                    print("Signature verified successfully", flush=True)
                else:
                    print("Warning: Signature verification failed", flush=True)
                
                return json.loads(str(decrypted_data))
            else:
                print(f"Decryption failed: {decrypted_data.status}", flush=True)
                return None
                
        except Exception as e:
            print(f"Error decrypting and verifying response: {e}", flush=True)
            return None

    def send_status(self):
        if not self.lock.acquire(blocking=False):
            print("send_status is already running, skipping this execution.", flush=True)
            return

        try:
            url = f'{self.server_url}/agents'
            data = {
                'status': self.status
            }
            headers = {
                'X-Agent-UUID': self.uuid
            }

            # Encrypt and sign the data
            encrypted_data = self._encrypt_and_sign_data(data)
            if not encrypted_data:
                print("Failed to encrypt data, skipping send", flush=True)
                return

            while self.retries > 0:
                try:
                    response = requests.post(url, data=encrypted_data, headers=headers, verify=self.ssl_verify)
                    response.raise_for_status()
                    
                    # Decrypt and verify response if needed
                    if response.content:
                        decrypted_response = self._decrypt_and_verify_response(response.content)
                        if decrypted_response:
                            print(f"Decrypted response: {decrypted_response}", flush=True)
                    
                    print(f"Data sent successfully: {data}", flush=True)
                    return
                except requests.exceptions.RequestException as e:
                    error_msg = f"Failed to send data: {e}"
                    if hasattr(e, 'response') and e.response is not None:
                        error_msg += f" | Status Code: {e.response.status_code}"
                        try:
                            error_msg += f" | Server Response: {e.response.text}"
                        except:
                            error_msg += " | Could not read server response"
                    print(error_msg, flush=True)
                    print(f"Retries chance: {self.retries}", flush=True)
                    self.retries -= 1

            print("All retries failed, getting logs and running task.sh", flush=True)
            try: 
                ip_route_logs = subprocess.check_output("sudo /usr/sbin/ip route show", shell=True).decode('utf-8')
                journalctl_logs = subprocess.check_output("sudo /usr/bin/journalctl -u NetworkManager --since today", shell=True).decode('utf-8')
                tracepath_logs = subprocess.check_output(f"sudo /usr/bin/tracepath {self.server_ip}", shell=True).decode('utf-8')
                dmsg_logs = subprocess.check_output("sudo /usr/bin/dmesg | tail -10", shell=True).decode('utf-8')
                network_int_logs = subprocess.check_output("sudo /usr/sbin/ip a", shell=True).decode('utf-8')
            except subprocess.CalledProcessError as e:
                print(f"Failed to get logs: {e}", flush=True)

            self.status = 2
            data['status'] = self.status

            while self.status == 2:
                try:
                    subprocess.run(['sh', '/opt/monitoring/client/task.sh'])
                    
                    encrypted_recovery_data = self._encrypt_and_sign_data(data)
                    if encrypted_recovery_data:
                        response = requests.post(url, data=encrypted_recovery_data, headers=headers, verify=self.ssl_verify)
                        if response.status_code != 200:
                            time.sleep(1)
                            raise requests.exceptions.RequestException
                        print(f"Data sent successfully after recovery: {data}", flush=True)
                        self.status = 1
                        self.retries = 5
                except requests.exceptions.RequestException as e:
                    error_msg = f"Failed to send data after recovery: {e}"
                    if hasattr(e, 'response') and e.response is not None:
                        error_msg += f" | Status Code: {e.response.status_code}"
                        try:
                            error_msg += f" | Server Response: {e.response.text}"
                        except:
                            error_msg += " | Could not read server response"
                    print(error_msg, flush=True)

            logs_url = f'{self.server_url}/logs'
            logs_data = {
                'ip_route': ip_route_logs,
                'journalctl': journalctl_logs,
                'tracepath': tracepath_logs,
                'dmsg': dmsg_logs,
                'network_int': network_int_logs
            }
            
            encrypted_logs = self._encrypt_and_sign_data(logs_data)
            if encrypted_logs:
                try:
                    response = requests.post(logs_url, data=encrypted_logs, headers=headers, verify=self.ssl_verify)
                    response.raise_for_status()
                    print(f"Logs sent successfully", flush=True)
                except requests.exceptions.RequestException as e:
                    error_msg = f"Failed to send logs: {e}"
                    if hasattr(e, 'response') and e.response is not None:
                        error_msg += f" | Status Code: {e.response.status_code}"
                        try:
                            error_msg += f" | Server Response: {e.response.text}"
                        except:
                            error_msg += " | Could not read server response"
                    print(error_msg, flush=True)
        finally:
            self.lock.release()
    
    def get_and_run_command(self):
        url = f'{self.server_url}/agents'
        data = {
            'status': 5
        }
        headers = {
            'X-Agent-UUID': self.uuid
        }

        # Encrypt and sign the data
        encrypted_data = self._encrypt_and_sign_data(data)
        if not encrypted_data:
            print("Failed to encrypt command request data", flush=True)
            return

        try:
            # Send the initial POST request
            response = requests.post(url, data=encrypted_data, headers=headers, verify=self.ssl_verify)
            if response.status_code == 404:
                print("No command to execute", flush=True)
                return
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            error_msg = f"Failed to send data: {e}"
            if hasattr(e, 'response') and e.response is not None:
                error_msg += f" | Status Code: {e.response.status_code}"
                try:
                    error_msg += f" | Server Response: {e.response.text}"
                except:
                    error_msg += " | Could not read server response"
            print(error_msg, flush=True)
            return

        # Decrypt and verify the response
        try:
            commands = self._decrypt_and_verify_response(response.content)
            if not commands:
                print("Failed to decrypt command response", flush=True)
                return
        except Exception as e:
            print(f"Failed to parse response: {e}", flush=True)
            return

        # Execute each command and send the results back
        for command in commands:
            command_id = command.get("command_id")
            command_text = command.get("command")

            if not command_id or not command_text:
                print(f"Invalid command data: {command}", flush=True)
                continue

            try:
                # Execute the command
                command_output = subprocess.check_output(command_text, shell=True, stderr=subprocess.STDOUT).decode('utf-8')
            except subprocess.CalledProcessError as e:
                command_output = f"Error executing command: {e.output.decode('utf-8')}"

            # Send the command response back
            result_data = {
                'status': 6,
                'command_id': command_id,
                'response': command_output
            }

            encrypted_result = self._encrypt_and_sign_data(result_data)
            if encrypted_result:
                try:
                    result_response = requests.post(url, data=encrypted_result, headers=headers, verify=self.ssl_verify)
                    result_response.raise_for_status()
                    print(f"Command result sent successfully for command_id: {command_id}", flush=True)
                except requests.exceptions.RequestException as e:
                    error_msg = f"Failed to send command result: {e}"
                    if hasattr(e, 'response') and e.response is not None:
                        error_msg += f" | Status Code: {e.response.status_code}"
                        try:
                            error_msg += f" | Server Response: {e.response.text}"
                        except:
                            error_msg += " | Could not read server response"
                    print(error_msg, flush=True)