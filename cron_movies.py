#!/usr/bin/env python3
"""
cron_movies.py — Unified Movie + Series Auto-Update Cron
hdhub4u (সব category) + fibwatch.art (সব category) একসাথে চালায়

Usage:
  python3 cron_movies.py               # default: 3 pages hdhub + fibwatch latest
  python3 cron_movies.py --pages 10    # 10 pages per category
  python3 cron_movies.py --full        # full scan (20 pages)
  python3 cron_movies.py --hdhub-only  # only hdhub4u
  python3 cron_movies.py --fib-only    # only fibwatch
"""

import sys
import os
import argparse
from datetime import datetime

# Path setup
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

import database as db

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def run_hdhub(pages=3, categories=None):
    log(f"🎬 HDHub4u scraping শুরু ({pages} pages/category)...")
    try:
        from scrapers.hdhub_full import run
        saved = run(categories=categories, max_pages=pages, workers=8)
        log(f"✅ HDHub4u: {saved} items saved")
        return saved
    except Exception as e:
        log(f"❌ HDHub4u error: {e}")
        import traceback
        traceback.print_exc()
        return 0


def run_fibwatch(pages=50):
    log(f"🎬 Fibwatch.art scraping শুরু ({pages} pages/category)...")
    try:
        from scrapers.fibwatch import run_all_categories, run_latest
        saved = run_all_categories(max_pages=pages)
        # Latest section also
        saved += run_latest(max_pages=min(pages * 10, 200))
        log(f"✅ Fibwatch: {saved} items saved")
        return saved
    except Exception as e:
        log(f"❌ Fibwatch error: {e}")
        import traceback
        traceback.print_exc()
        return 0


def main():
    parser = argparse.ArgumentParser(description="Media Hub Movies Cron")
    parser.add_argument("--pages",      type=int, default=3,    help="Pages per category (default: 3)")
    parser.add_argument("--full",       action="store_true",     help="Full scan (20 pages)")
    parser.add_argument("--hdhub-only", action="store_true",     help="Only hdhub4u")
    parser.add_argument("--fib-only",   action="store_true",     help="Only fibwatch")
    parser.add_argument("--cats",       nargs="*",               help="HDHub4u category slugs")
    args = parser.parse_args()

    if args.full:
        pages = 20
    else:
        pages = args.pages

    log("=" * 60)
    log("🚀 Media Hub Cron শুরু হচ্ছে...")
    log(f"   Pages: {pages} | Full: {args.full}")
    log("=" * 60)

    # DB init
    try:
        db.init_db()
        log("✅ Database initialized")
    except Exception as e:
        log(f"❌ DB init failed: {e}")
        sys.exit(1)

    total = 0

    if not args.fib_only:
        total += run_hdhub(pages=pages, categories=args.cats)

    if not args.hdhub_only:
        total += run_fibwatch(pages=min(pages * 10, 100))

    log("=" * 60)
    log(f"🏁 Cron সম্পন্ন। Total saved: {total}")
    log(f"   Movies: {db.count_movies()} | Series: {db.count_series()}")
    log("=" * 60)


if __name__ == "__main__":
    main()
