import os
from dotenv import load_dotenv
from monitoring import Monitoring
from apscheduler.schedulers.background import BlockingScheduler

def main():
    load_dotenv('/etc/monitoring/.env')
    uuid: str = os.getenv("UUID")
    server_url: str = "http://localhost:5000"
    monitoring = Monitoring(uuid, server_url)
    
    scheduler = BlockingScheduler()
    scheduler.add_job(monitoring.send_status, 'interval', seconds=15)
    scheduler.add_job(monitoring.get_and_run_command, 'interval', seconds=10)
    scheduler.start()
    print("Scheduler started, monitoring in progress...", flush=True)
    print(scheduler.print_jobs(), flush=True)

if __name__ == "__main__":
    main()
