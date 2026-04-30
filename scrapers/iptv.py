"""
scrapers/iptv.py — IPTV Live TV Channel Merger
একাধিক GitHub M3U সোর্স → Clean + Normalize + Dedup → DB-তে save করে
"""

import requests
import re
import random
from database import upsert_channel

SOURCE = "iptv-merger"

SOURCES = [
    {"url": "https://raw.githubusercontent.com/srhady/tapmad-bd/refs/heads/main/tapmad_bd.m3u",         "label": "Tapmad BD"},
    {"url": "https://raw.githubusercontent.com/srhady/Fancode-bd/refs/heads/main/main_playlist.m3u",    "label": "Fancode BD"},
    {"url": "https://raw.githubusercontent.com/srhady/CricketLive/refs/heads/main/playlist.m3u",        "label": "CricketLive"},
    {"url": "https://raw.githubusercontent.com/sm-monirulislam/AynaOTT-auto-update-playlist/refs/heads/main/AynaOTT.m3u", "label": "AynaOTT"},
    {"url": "https://iptv-org.github.io/iptv/languages/ben.m3u",                                        "label": "iptv-org Bengali"},
]

BANNED_KEYWORDS = ["playz tv"]
BANNED_LINKS    = ["playztv.pages.dev"]
DEFAULT_LOGO    = "https://bdixiptvbd.com/logo.png"


def _normalize_group(raw: str) -> str:
    raw = raw.upper()
    if any(x in raw for x in ["SPORTS", "CRICKET", "FANCODE", "TAPMAD"]):
        return "SPORTS"
    if any(x in raw for x in ["BANGLA", "BD", "AYNA"]):
        return "BANGLA TV"
    if any(x in raw for x in ["NEWS", "খবর"]):
        return "NEWS"
    if any(x in raw for x in ["MOVIE", "FILM"]):
        return "MOVIES"
    return "OTHERS"


def _clean_name(name: str) -> str:
    for junk in ["| High Quality", "| BDIX", "| VIP", "SD", "HD", "FHD", "(Backup)", "Premium"]:
        name = name.replace(junk, "")
    return name.strip()


def run() -> int:
    print(f"\n{'='*55}")
    print("📺 [IPTV] Channel Merger চালু হচ্ছে...")
    print(f"{'='*55}")

    seen_links = set()
    saved = 0

    for src in SOURCES:
        print(f"\n  🔄 Syncing: {src['label']}")
        try:
            res = requests.get(src["url"], timeout=25)
            if res.status_code != 200:
                print(f"  ⚠️ Failed (HTTP {res.status_code})")
                continue

            lines = res.text.splitlines()
            i = 0
            source_count = 0

            while i < len(lines):
                line = lines[i].strip()
                if line.startswith("#EXTINF"):
                    if (i + 1) < len(lines):
                        ch_url = lines[i + 1].strip()

                        # ব্যান চেক
                        banned = any(bk in line.lower() for bk in BANNED_KEYWORDS) or \
                                 any(bl in ch_url.lower() for bl in BANNED_LINKS)
                        if banned:
                            i += 2
                            continue

                        if ch_url.startswith("http") and ch_url not in seen_links:
                            # Group
                            gm = re.search(r'group-title="([^"]+)"', line)
                            raw_group = gm.group(1) if gm else "OTHERS"
                            final_group = _normalize_group(raw_group)

                            # Logo
                            lm = re.search(r'tvg-logo="([^"]+)"', line)
                            logo = lm.group(1) if (lm and lm.group(1)) else DEFAULT_LOGO

                            # Name
                            name = _clean_name(line.split(",")[-1])

                            result = upsert_channel(
                                channel_name=name,
                                group_name=final_group,
                                logo_url=logo,
                                stream_url=ch_url,
                                source=f"{SOURCE}:{src['label']}",
                            )
                            seen_links.add(ch_url)
                            source_count += 1
                            saved += 1

                        i += 2
                    else:
                        i += 1
                else:
                    i += 1

            print(f"  ✅ {source_count} channels DB-তে save হয়েছে ({src['label']}).")

        except Exception as e:
            print(f"  ❌ Error: {e}")

    print(f"\n  ✅ মোট {saved} TV channels DB-তে save হয়েছে।")
    return saved
