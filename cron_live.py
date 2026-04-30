"""
cron_live.py — Live Match Cron Script
cPanel Cron-এ প্রতি 5 মিনিটে চালাতে হবে:
  */5 * * * * /usr/bin/python3 /home/USER/unified/cron_live.py
"""
import sys, io, os

if hasattr(sys.stdout, 'buffer'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import database as db
from scrapers import embedhd
from datetime import datetime

def main():
    print(f"[{datetime.now()}] Live match cron started...")
    db.init_db()
    count = embedhd.run(db_insert=True)
    print(f"[{datetime.now()}] Done. {count} matches saved.")

if __name__ == "__main__":
    main()
