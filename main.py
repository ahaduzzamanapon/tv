"""
main.py — Media Hub Master Auto-Scheduler
════════════════════════════════════════════════════════════════
এই একটা script server-এ চালিয়ে রাখলেই সব কিছু auto হবে:

  🔴 Live Matches  → প্রতি 5 মিনিটে refresh
                     (match শেষ হলে DB থেকে remove, নতুন এলে add)

  🎬 Movies        → প্রতি 6 ঘন্টায় নতুন movie scan করে DB-তে add
                     (fibwatch category, fibwatch latest, hdhub4u)

  📺 TV Channels   → প্রতি 12 ঘন্টায় GitHub M3U সোর্স sync

চালানোর কমান্ড:
  python main.py              ← সব কিছু auto চালাও (server mode)
  python main.py --once       ← একবার চালিয়ে বন্ধ (test)
  python main.py --live       ← শুধু live match loop
  python main.py --movies     ← শুধু movie loop
  python main.py --channels   ← শুধু channel loop
  python main.py --stats      ← DB stats দেখাও
════════════════════════════════════════════════════════════════
"""

import sys
import io
import os
import time
import threading
import argparse
from datetime import datetime, timedelta

# Windows-এ emoji/unicode সাপোর্টের জন্য UTF-8 stdout force
if hasattr(sys.stdout, 'buffer') and sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

sys.path.insert(0, os.path.dirname(__file__))

import database as db
from scrapers import embedhd, fibwatch, hdhub, iptv


# ══════════════════════════════════════════════════════
#  ⚙️  CONFIG — এখান থেকে সব timing পরিবর্তন করা যাবে
# ══════════════════════════════════════════════════════

LIVE_INTERVAL_MINUTES  = 5     # ⏱️ Live match: প্রতি 5 মিনিট
MOVIE_INTERVAL_HOURS   = 6     # ⏱️ Movies: প্রতি 6 ঘন্টা
CHANNEL_INTERVAL_HOURS = 12    # ⏱️ TV Channels: প্রতি 12 ঘন্টা

FIBWATCH_CATEGORIES = [
    {"cat_id": "852", "group_name": "Bengali Dubbed", "language": "Bengali Dubbed", "max_pages": 150},
    {"cat_id": "1",   "group_name": "Bangla Movie",   "language": "Bangla",         "max_pages": 100},
]
FIBWATCH_LATEST_PAGES = 500
HDHUB_MAX_PAGES       = 5


# ══════════════════════════════════════════════════════
#  📊 SCHEDULE TRACKER — কোন task কখন শেষবার/পরেরবার চলবে
# ══════════════════════════════════════════════════════

_schedule = {
    "LIVE":  {"last_run": None, "next_run": None, "interval_sec": LIVE_INTERVAL_MINUTES * 60,  "status": "⏳ Pending"},
    "MOVIE": {"last_run": None, "next_run": None, "interval_sec": MOVIE_INTERVAL_HOURS * 3600,  "status": "⏳ Pending"},
    "IPTV":  {"last_run": None, "next_run": None, "interval_sec": CHANNEL_INTERVAL_HOURS * 3600,"status": "⏳ Pending"},
}

_schedule_lock = threading.Lock()


def _update_schedule(task_name: str, status: str):
    with _schedule_lock:
        now = datetime.now()
        _schedule[task_name]["last_run"] = now
        _schedule[task_name]["next_run"] = now + timedelta(seconds=_schedule[task_name]["interval_sec"])
        _schedule[task_name]["status"]   = status


def _fmt_time(dt: datetime | None) -> str:
    if dt is None:
        return "—"
    return dt.strftime("%H:%M:%S | %d %b %Y")


def _fmt_countdown(dt: datetime | None) -> str:
    if dt is None:
        return "শীঘ্রই..."
    delta = dt - datetime.now()
    total = int(delta.total_seconds())
    if total <= 0:
        return "এখনই..."
    h, rem = divmod(total, 3600)
    m, s   = divmod(rem, 60)
    if h > 0:
        return f"{h}h {m}m পরে"
    if m > 0:
        return f"{m}m {s}s পরে"
    return f"{s}s পরে"


# ══════════════════════════════════════════════════════
#  🖨️  DISPLAY HELPERS
# ══════════════════════════════════════════════════════

def _log(tag: str, msg: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] [{tag:<6}] {msg}", flush=True)


def _print_banner():
    print("""
╔════════════════════════════════════════════════════════════╗
║           🎬  MEDIA HUB — AUTO SCRAPER  v2.0              ║
║  Server Mode — script চলছে, সব কিছু auto হবে             ║
╠════════════════════════════════════════════════════════════╣
║  Task             Interval    Description                  ║
║  ─────────────────────────────────────────────────────     ║
║  🔴 Live Matches   5 min      Match শেষ হলে remove,       ║
║                               নতুন এলে add                 ║
║  🎬 Movies         6 hrs      নতুন movie scan করে add      ║
║  📺 TV Channels   12 hrs      GitHub M3U sync              ║
╠════════════════════════════════════════════════════════════╣
║  Ctrl+C দিয়ে বন্ধ করুন                                    ║
╚════════════════════════════════════════════════════════════╝
""")


def _print_schedule_table():
    """Current schedule status দেখায় — কখন শেষবার/পরেরবার চলবে"""
    with _schedule_lock:
        print("\n┌─────────────────────────────────────────────────────────────────────────┐")
        print(  "│                     📅  CURRENT SCHEDULE STATUS                         │")
        print(  "├──────────────┬────────────────────────────┬────────────────────────────┤")
        print(  "│  Task        │  Last Run                  │  Next Run (Countdown)      │")
        print(  "├──────────────┼────────────────────────────┼────────────────────────────┤")
        for name, info in _schedule.items():
            icon = {"LIVE": "🔴", "MOVIE": "🎬", "IPTV": "📺"}.get(name, "•")
            label = f"{icon} {name:<6}"
            last  = _fmt_time(info["last_run"])
            nxt   = f"{_fmt_time(info['next_run'])} ({_fmt_countdown(info['next_run'])})"
            print(f"│  {label:<12}│  {last:<26}│  {nxt:<26}│")
        print(  "└──────────────┴────────────────────────────┴────────────────────────────┘")


def _print_stats():
    stats = db.get_stats()
    print(f"""
  ┌─ DATABASE STATS ─────────────────────────────┐
  │  🎬 Movies        : {stats['total_movies']:<6}                      │
  │  🔴 Live Matches  : {stats['total_live_matches']:<6}                      │
  │  📺 TV Channels   : {stats['total_tv_channels']:<6}                      │
  └───────────────────────────────────────────────┘""", flush=True)

    if stats["movies_by_source"]:
        print("  📦 Movies by Source:")
        for src, cnt in stats["movies_by_source"].items():
            print(f"     • {src}: {cnt}")
    if stats["channels_by_group"]:
        print("  📺 Channels by Group:")
        for grp, cnt in stats["channels_by_group"].items():
            print(f"     • {grp}: {cnt}")
    if stats["live_by_league"]:
        print("  ⚽ Live Matches by League:")
        for lg, cnt in stats["live_by_league"].items():
            print(f"     • {lg}: {cnt}")
    print()


# ══════════════════════════════════════════════════════
#  ▶️  TASK RUNNERS
# ══════════════════════════════════════════════════════

def task_live_matches():
    _update_schedule("LIVE", "🔄 Running...")
    _log("LIVE", "🔄 Live match refresh শুরু হচ্ছে...")
    try:
        count = embedhd.run(db_insert=True)
        _update_schedule("LIVE", f"✅ {count} matches")
        _log("LIVE", f"✅ {count} live match DB-তে save হয়েছে।")
    except Exception as e:
        _update_schedule("LIVE", "❌ Error")
        _log("LIVE", f"❌ Error: {e}")


def task_movies():
    _update_schedule("MOVIE", "🔄 Running...")
    _log("MOVIE", "🎬 Movie scraper শুরু হচ্ছে...")
    total = 0
    try:
        for cat in FIBWATCH_CATEGORIES:
            total += fibwatch.run_category(**cat)
    except Exception as e:
        _log("MOVIE", f"❌ fibwatch category error: {e}")
    try:
        total += fibwatch.run_latest(max_pages=FIBWATCH_LATEST_PAGES, group_name="Fibwatch Latest", language="Multi")
    except Exception as e:
        _log("MOVIE", f"❌ fibwatch latest error: {e}")
    try:
        total += hdhub.run(max_pages=HDHUB_MAX_PAGES)
    except Exception as e:
        _log("MOVIE", f"❌ hdhub4u error: {e}")

    _update_schedule("MOVIE", f"✅ +{total} movies")
    _log("MOVIE", f"✅ মোট {total} movie DB-তে save হয়েছে।")
    _print_stats()


def task_channels():
    _update_schedule("IPTV", "🔄 Running...")
    _log("IPTV", "📺 TV channel sync শুরু হচ্ছে...")
    try:
        count = iptv.run()
        _update_schedule("IPTV", f"✅ {count} channels")
        _log("IPTV", f"✅ {count} channels DB-তে save হয়েছে।")
    except Exception as e:
        _update_schedule("IPTV", "❌ Error")
        _log("IPTV", f"❌ Error: {e}")
    _print_stats()


# ══════════════════════════════════════════════════════
#  🔁  SCHEDULER CORE — প্রতিটা task আলাদা thread-এ চলে
# ══════════════════════════════════════════════════════

def _run_every(task_fn, interval_seconds: int, task_name: str):
    """Task-টি চালায়, ঘুমায়, আবার চালায় — অসীম loop"""
    while True:
        try:
            task_fn()
        except Exception as e:
            _log(task_name, f"💥 Crash: {e}")

        next_dt = datetime.now() + timedelta(seconds=interval_seconds)
        _log(task_name, f"⏰ পরের run: {_fmt_time(next_dt)} ({interval_seconds // 60} মিনিট পরে)")
        _print_schedule_table()
        time.sleep(interval_seconds)


def _schedule_status_loop():
    """প্রতি 1 মিনিটে schedule table দেখায় (background thread)"""
    while True:
        time.sleep(60)
        _print_schedule_table()


def start_all_schedulers():
    _print_banner()
    _log("SYSTEM", "🚀 Server Mode চালু হচ্ছে — সব scraper auto হবে...")
    _log("SYSTEM", f"📅 Live: {LIVE_INTERVAL_MINUTES}m | Movies: {MOVIE_INTERVAL_HOURS}h | Channels: {CHANNEL_INTERVAL_HOURS}h")

    # Scheduler threads
    live_t = threading.Thread(
        target=_run_every,
        args=(task_live_matches, LIVE_INTERVAL_MINUTES * 60, "LIVE"),
        daemon=True, name="LiveThread"
    )
    movie_t = threading.Thread(
        target=_run_every,
        args=(task_movies, MOVIE_INTERVAL_HOURS * 3600, "MOVIE"),
        daemon=True, name="MovieThread"
    )
    channel_t = threading.Thread(
        target=_run_every,
        args=(task_channels, CHANNEL_INTERVAL_HOURS * 3600, "IPTV"),
        daemon=True, name="ChannelThread"
    )
    status_t = threading.Thread(
        target=_schedule_status_loop,
        daemon=True, name="StatusThread"
    )

    # Live match সবার আগে শুরু হয়
    live_t.start()
    _log("SYSTEM", "✅ Live Match thread চালু হয়েছে।")

    # ৩০ সেকেন্ড পর movie শুরু (live first load নিক)
    time.sleep(30)
    movie_t.start()
    _log("SYSTEM", "✅ Movie thread চালু হয়েছে।")

    # আরো ৩০ সেকেন্ড পর channel sync
    time.sleep(30)
    channel_t.start()
    _log("SYSTEM", "✅ TV Channel thread চালু হয়েছে।")

    status_t.start()

    _log("SYSTEM", "🟢 সব scheduler চালু! Ctrl+C দিয়ে বন্ধ করুন।")
    _print_schedule_table()

    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        print("\n")
        _log("SYSTEM", "🛑 User দ্বারা বন্ধ করা হয়েছে।")
        _print_stats()
        _print_schedule_table()
        sys.exit(0)


# ══════════════════════════════════════════════════════
#  🚪  ENTRY POINT
# ══════════════════════════════════════════════════════

def parse_args():
    p = argparse.ArgumentParser(description="Media Hub Auto Scraper")
    p.add_argument("--live",     action="store_true", help="শুধু live match auto-loop")
    p.add_argument("--movies",   action="store_true", help="শুধু movie auto-loop")
    p.add_argument("--channels", action="store_true", help="শুধু channel auto-loop")
    p.add_argument("--once",     action="store_true", help="একবার চালিয়ে বন্ধ (test mode)")
    p.add_argument("--stats",    action="store_true", help="DB stats দেখাও")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    db.init_db()

    if args.stats:
        _print_stats()
        _print_schedule_table()
        sys.exit(0)

    if args.once:
        _log("SYSTEM", "🧪 Test Mode — একবার রান করে বন্ধ হবে।")
        run_live = args.live or not (args.live or args.movies or args.channels)
        run_mov  = args.movies or not (args.live or args.movies or args.channels)
        run_ch   = args.channels or not (args.live or args.movies or args.channels)
        if run_live:   task_live_matches()
        if run_mov:    task_movies()
        if run_ch:     task_channels()
        _print_stats()
        sys.exit(0)

    if args.live or args.movies or args.channels:
        threads = []
        if args.live:
            threads.append(threading.Thread(target=_run_every,
                args=(task_live_matches, LIVE_INTERVAL_MINUTES * 60, "LIVE"), daemon=True))
        if args.movies:
            threads.append(threading.Thread(target=_run_every,
                args=(task_movies, MOVIE_INTERVAL_HOURS * 3600, "MOVIE"), daemon=True))
        if args.channels:
            threads.append(threading.Thread(target=_run_every,
                args=(task_channels, CHANNEL_INTERVAL_HOURS * 3600, "IPTV"), daemon=True))
        for t in threads:
            t.start()
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            _log("SYSTEM", "🛑 বন্ধ হয়েছে।")
            sys.exit(0)
    else:
        start_all_schedulers()
