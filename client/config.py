import os
from dotenv import load_dotenv
from monitoring import Monitoring
from apscheduler.schedulers.background import BlockingScheduler

def main():
    load_dotenv('/etc/monitoring/.env')
    uuid: str = os.getenv("UUID")
    server_url: str = os.getenv("SERVER_URL", "https://localhost:5000")
    ssl_verify: bool = os.getenv("SSL_VERIFY", "false").lower() == "true"
    status_interval: int = int(os.getenv("STATUS_INTERVAL", "15"))
    command_interval: int = int(os.getenv("COMMAND_INTERVAL", "10"))
    monitoring = Monitoring(uuid, server_url, ssl_verify)
    
    scheduler = BlockingScheduler()
    scheduler.add_job(monitoring.send_status, 'interval', seconds=status_interval)
    scheduler.add_job(monitoring.get_and_run_command, 'interval', seconds=command_interval)
    scheduler.start()
    print("Scheduler started, monitoring in progress...", flush=True)
    print(scheduler.print_jobs(), flush=True)

if __name__ == "__main__":
    main()
