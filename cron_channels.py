"""
cron_channels.py — TV Channel Sync Cron Script
cPanel Cron-এ প্রতি 12 ঘন্টায় চালাতে হবে:
  0 */12 * * * /usr/bin/python3 /home/USER/unified/cron_channels.py
"""
import sys, io, os

if hasattr(sys.stdout, 'buffer'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import database as db
from scrapers import iptv
from datetime import datetime

def main():
    print(f"[{datetime.now()}] Channel cron started...")
    db.init_db()
    count = iptv.run()
    print(f"[{datetime.now()}] Done. {count} channels saved.")

if __name__ == "__main__":
    main()
