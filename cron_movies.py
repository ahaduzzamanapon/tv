"""
cron_movies.py — Movie Scraper Cron Script
cPanel Cron-এ প্রতি 6 ঘন্টায় চালাতে হবে:
  0 */6 * * * /usr/bin/python3 /home/USER/unified/cron_movies.py
"""
import sys, io, os

if hasattr(sys.stdout, 'buffer'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import database as db
from scrapers import fibwatch, hdhub
from datetime import datetime

FIBWATCH_CATEGORIES = [
    {"cat_id": "852", "group_name": "Bengali Dubbed", "language": "Bengali Dubbed", "max_pages": 150},
    {"cat_id": "1",   "group_name": "Bangla Movie",   "language": "Bangla",         "max_pages": 100},
]
FIBWATCH_LATEST_PAGES = 500
HDHUB_MAX_PAGES       = 5

def main():
    print(f"[{datetime.now()}] Movie cron started...")
    db.init_db()
    total = 0

    for cat in FIBWATCH_CATEGORIES:
        try:
            total += fibwatch.run_category(**cat)
        except Exception as e:
            print(f"fibwatch category error: {e}")

    try:
        total += fibwatch.run_latest(max_pages=FIBWATCH_LATEST_PAGES, group_name="Fibwatch Latest", language="Multi")
    except Exception as e:
        print(f"fibwatch latest error: {e}")

    try:
        total += hdhub.run(max_pages=HDHUB_MAX_PAGES)
    except Exception as e:
        print(f"hdhub error: {e}")

    print(f"[{datetime.now()}] Done. Total {total} movies saved.")

if __name__ == "__main__":
    main()
