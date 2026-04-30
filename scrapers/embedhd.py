"""
scrapers/embedhd.py — Live Sports Scraper (embedhd.org)
embedhd.org API → live matches → DB তে save করে
"""

import requests
import base64
import urllib.parse
from datetime import datetime, timezone, timedelta
from database import upsert_live_match, clear_live_matches

SOURCE = "embedhd.org"
API_URL = "https://embedhd.org/api-event.php"
BD_TZ = timezone(timedelta(hours=6))

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "application/json"
}

VERCEL_PLAYER_URL = "https://data-2.vercel.app/"


def _encrypt_url(url: str) -> str:
    """Base64 encode করে reverse করে — Vercel player URL বানায়"""
    encoded = base64.b64encode(url.encode("utf-8")).decode("utf-8")
    return encoded[::-1]


def run(db_insert=True) -> int:
    """embedhd.org থেকে live match ডেটা আনে এবং DB-তে save করে"""
    print("\n" + "="*55)
    print("📡 [LIVE SPORTS] embedhd.org scraper চালু হচ্ছে...")
    print("="*55)

    try:
        response = requests.get(API_URL, headers=HEADERS, timeout=15)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print(f"  ❌ API Error: {e}")
        return 0

    days = data.get("days", [])
    matches = []

    for day in days:
        for match in day.get("items", []):
            try:
                title = match.get("title", "Unknown Match")
                league = match.get("league", "Sports").upper()
                status = match.get("status", "Upcoming").capitalize()

                # টিম নাম বের করা
                team1, team2 = "", ""
                formatted_title = title
                if " - " in title:
                    parts = title.split(" - ", 1)
                    team1 = parts[0].strip()
                    team2 = parts[1].strip()
                    formatted_title = f"{team1} VS {team2}"

                # সময় কনভার্ট (UTC → BD)
                ts_et = match.get("ts_et", 0)
                start_time_bd = ""
                if ts_et:
                    dt = datetime.fromtimestamp(float(ts_et), tz=timezone.utc).astimezone(BD_TZ)
                    start_time_bd = dt.strftime("%I:%M %p | %d %b %Y")

                # Poster URL
                encoded_title = urllib.parse.quote(formatted_title)
                poster = f"https://placehold.co/800x450/0d1b2a/ffffff.png?text={encoded_title}&font=Oswald"

                # Stream URLs encrypt করা
                stream_urls = []
                for stream in match.get("streams", []):
                    original = stream.get("link")
                    if original:
                        enc_id = _encrypt_url(original)
                        stream_urls.append(f"{VERCEL_PLAYER_URL}?id={enc_id}")

                if not stream_urls:
                    continue

                matches.append({
                    "match_title":    formatted_title,
                    "league":         league,
                    "team1":          team1,
                    "team2":          team2,
                    "team1_logo":     "",
                    "team2_logo":     "",
                    "stream_urls_list": stream_urls,
                    "match_status":   status,
                    "start_time_bd":  start_time_bd,
                    "poster_url":     poster,
                    "source":         SOURCE,
                })
            except Exception:
                pass

    # Live গুলো আগে সাজানো
    matches.sort(key=lambda x: (0 if x["match_status"].upper() == "LIVE" else 1))

    if db_insert:
        clear_live_matches()
        saved = 0
        for m in matches:
            upsert_live_match(**m)
            saved += 1
            status_icon = "🔴" if m["match_status"].upper() == "LIVE" else "🕐"
            print(f"  {status_icon} [{m['match_status'].upper()}] {m['match_title']} — {m['league']}")

        print(f"\n  ✅ Total {saved} live match DB-তে save হয়েছে।")
        return saved

    return len(matches)
