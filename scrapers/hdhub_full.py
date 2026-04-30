"""
scrapers/hdhub_full.py — HDHub4u Full Scraper
Bollywood, Hollywood, Hindi Dubbed, South Hindi, Web Series (Season/Episode) সহ
curl_cffi Chrome impersonate + JS unpack decoder ব্যবহার করে real stream link বের করে
"""

import re
import json
import time
import concurrent.futures
from curl_cffi import requests as cffi_requests
from bs4 import BeautifulSoup

try:
    from database import upsert_movie, upsert_series, upsert_episode
except ImportError:
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from database import upsert_movie, upsert_series, upsert_episode

BASE_URL = "https://new7.hdhub4u.fo"
SOURCE   = "hdhub4u"

CATEGORIES = [
    {"slug": "bollywood-movies",  "group": "BollyWood",     "lang": "Hindi",         "is_series": False},
    {"slug": "hollywood-movies",  "group": "HollyWood",     "lang": "English",       "is_series": False},
    {"slug": "hindi-dubbed",      "group": "Hindi Dubbed",  "lang": "Hindi Dubbed",  "is_series": False},
    {"slug": "south-hindi-movies","group": "South Hindi",   "lang": "Hindi Dubbed",  "is_series": False},
    {"slug": "web-series",        "group": "Web Series",    "lang": "Multi",         "is_series": True},
]


# ══════════════════════════════════════════════════
#  JS UNPACKER
# ══════════════════════════════════════════════════

def _unpack(p, a, c, k):
    chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    def base_n(num, b):
        if num == 0:
            return "0"
        res = ""
        while num > 0:
            res = chars[num % b] + res
            num //= b
        return res

    for i in range(c - 1, -1, -1):
        if k[i]:
            p = re.sub(r"\b" + base_n(i, a) + r"\b", k[i], p)
    return p


def _extract_streams(html):
    """HTML থেকে m3u8/mp4 stream links বের করে"""
    streams = []

    # Method 1: JS packer decode
    m = re.search(
        r"return p}\('(.*?)',\s*(\d+),\s*(\d+),\s*'(.*?)'\.split\('\|'\)",
        html, re.DOTALL
    )
    if m:
        try:
            p = m.group(1).replace("\\'", "'").replace("\\\\", "\\")
            a, c = int(m.group(2)), int(m.group(3))
            k = m.group(4).split("|")
            unpacked = _unpack(p, a, c, k)
            found = re.findall(
                r"https?://[^\s'\"<>,\[\](){}]+?\.(?:m3u8|mp4|mkv)[^\s'\"<>,\[\](){}]*",
                unpacked
            )
            streams.extend(found)
        except Exception:
            pass

    # Method 2: Direct links in HTML
    direct = re.findall(
        r"https?://[^\s'\"<>,\[\](){}]+?\.(?:m3u8|mp4|mkv)[^\s'\"<>,\[\](){}]*",
        html
    )
    streams.extend(direct)

    # Method 3: embed iframe src
    iframes = re.findall(r'<iframe[^>]+src=["\']([^"\']+)["\']', html)
    streams.extend([u for u in iframes if any(k in u for k in ['embed', 'player', 'stream'])])

    # Deduplicate
    seen = set()
    result = []
    for s in streams:
        if s not in seen:
            seen.add(s)
            result.append(s)
    return result


def _get_session():
    return cffi_requests.Session(impersonate="chrome110", timeout=20)


# ══════════════════════════════════════════════════
#  MOVIE PROCESSING
# ══════════════════════════════════════════════════

def _scrape_movie_page(movie_url, session):
    """Movie detail page থেকে stream URL বের করে"""
    try:
        res = session.get(movie_url)
        html = res.text
        soup = BeautifulSoup(html, "html.parser")

        poster = ""
        og_img = soup.find("meta", property="og:image")
        if og_img:
            poster = og_img.get("content", "")

        # Watch/Download link খোঁজা
        content = soup.find("div", class_="entry-content") or soup
        watch_link = None
        for a in content.find_all("a", href=True):
            href = a["href"]
            text = a.get_text(strip=True).lower()
            if href and href != "#" and any(k in text or k in href.lower()
                                             for k in ["watch", "play", "stream", "online", "server"]):
                watch_link = href
                break

        if not watch_link:
            # Fallback: যেকোনো external link নাও
            for a in content.find_all("a", href=True):
                href = a["href"]
                if href and href.startswith("http") and BASE_URL not in href:
                    watch_link = href
                    break

        if not watch_link:
            return poster, []

        # Watch page থেকে stream extract
        try:
            watch_res = session.get(watch_link)
            streams = _extract_streams(watch_res.text)
            if streams:
                return poster, streams
        except Exception:
            pass

        # Direct streams from movie page
        streams = _extract_streams(html)
        return poster, streams

    except Exception as e:
        return "", []


def _process_movie_entry(data):
    """একটা movie entry process করে"""
    title, url, poster_hint, group, lang = data
    try:
        session = _get_session()
        poster, streams = _scrape_movie_page(url, session)
        if not poster:
            poster = poster_hint
        if not streams:
            return None

        stream_url = streams[0]
        result = upsert_movie(
            title=title,
            quality=_detect_quality(title + url),
            stream_url=stream_url,
            poster_url=poster,
            group_name=group,
            language=lang,
            source=SOURCE,
            content_type='movie'
        )
        return (title, result)
    except Exception:
        return None


# ══════════════════════════════════════════════════
#  SERIES PROCESSING
# ══════════════════════════════════════════════════

def _scrape_series_page(series_url, session):
    """Series page থেকে season/episode structure বের করে"""
    try:
        res = session.get(series_url)
        html = res.text
        soup = BeautifulSoup(html, "html.parser")

        poster = ""
        og_img = soup.find("meta", property="og:image")
        if og_img:
            poster = og_img.get("content", "")

        episodes = []  # list of (season_num, ep_num, ep_title, stream_url)

        content = soup.find("div", class_="entry-content") or soup
        links = content.find_all("a", href=True)

        # Episode links খোঁজা — pattern: "EP 1", "Episode 1", "E01" etc.
        ep_pattern = re.compile(r'(?:ep(?:isode)?\.?\s*|e)(\d{1,3})', re.IGNORECASE)
        season_pattern = re.compile(r'season\s*(\d+)', re.IGNORECASE)

        current_season = 1
        ep_counter = 1

        # Season heading খোঁজা
        for tag in content.find_all(['h2', 'h3', 'h4', 'strong', 'p']):
            text = tag.get_text(strip=True)
            sm = season_pattern.search(text)
            if sm:
                current_season = int(sm.group(1))

        # Episodes from links
        for a in links:
            href = a["href"]
            text = a.get_text(strip=True)
            if not href or href == "#":
                continue

            # Episode link detection
            em = ep_pattern.search(text) or ep_pattern.search(href)
            sm = season_pattern.search(text) or season_pattern.search(href)

            if em or any(k in text.lower() for k in ['episode', 'ep.', ' ep ']):
                ep_num = int(em.group(1)) if em else ep_counter
                season = int(sm.group(1)) if sm else current_season
                ep_title = text.strip() or f"Episode {ep_num}"

                # Stream from watch page
                try:
                    watch_res = session.get(href)
                    streams = _extract_streams(watch_res.text)
                    stream_url = streams[0] if streams else href
                except Exception:
                    stream_url = href

                episodes.append((season, ep_num, ep_title, stream_url))
                ep_counter += 1

        # যদি কোনো episode না পাওয়া যায়, সব external links নাও
        if not episodes:
            for i, a in enumerate(links, 1):
                href = a["href"]
                text = a.get_text(strip=True)
                if href and href.startswith("http") and BASE_URL not in href:
                    episodes.append((1, i, text or f"Episode {i}", href))

        seasons = max((e[0] for e in episodes), default=1) if episodes else 1
        return poster, episodes, seasons

    except Exception:
        return "", [], 1


def _process_series_entry(data):
    """একটা series entry process করে"""
    title, url, poster_hint, group, lang = data
    try:
        session = _get_session()
        poster, episodes, total_seasons = _scrape_series_page(url, session)
        if not poster:
            poster = poster_hint

        series_id = upsert_series(
            title=title,
            poster_url=poster,
            group_name=group,
            language=lang,
            source=SOURCE,
            total_seasons=total_seasons
        )
        if not series_id:
            return None

        ep_count = 0
        for season_num, ep_num, ep_title, stream_url in episodes:
            if stream_url:
                upsert_episode(series_id, season_num, ep_num, ep_title, stream_url)
                ep_count += 1

        return (title, f"{total_seasons}S/{ep_count}EP")
    except Exception:
        return None


# ══════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════

def _detect_quality(text):
    m = re.search(r'(4K|2160p|1080p|720p|480p|360p)', text, re.IGNORECASE)
    return m.group(1) if m else "HD"


def _parse_title(raw_title):
    """Title থেকে noise সরিয়ে clean করে"""
    title = raw_title
    # Remove quality markers
    title = re.sub(r'\s*(4K|WEB-DL|WEBRip|BluRay|HDRip|HDTC|HEVC|x264|x265|DD\d\.\d|ESubs|DS4K)\s*', ' ', title, flags=re.IGNORECASE)
    # Remove resolution
    title = re.sub(r'\s*(4K|1080p|720p|480p)\s*', ' ', title, flags=re.IGNORECASE)
    # Remove brackets content (quality info)
    title = re.sub(r'\[.*?\]', '', title)
    # Remove trailing pipe and quality info
    title = re.sub(r'\|.*$', '', title)
    title = title.strip()
    # Remove trailing year if isolated
    title = re.sub(r'\s+\(\d{4}\)\s*$', '', title)
    return title.strip() or raw_title.strip()


# ══════════════════════════════════════════════════
#  CATEGORY SCRAPER
# ══════════════════════════════════════════════════

def _scrape_category_page(cat_slug, page_num, session):
    """একটা category পেজ থেকে সব item তুলে আনে"""
    url = f"{BASE_URL}/category/{cat_slug}/page/{page_num}/"
    items = []
    try:
        res = session.get(url)
        if res.status_code == 404:
            return [], True  # last page
        soup = BeautifulSoup(res.text, "html.parser")

        # Article cards
        articles = soup.find_all("article")
        if not articles:
            # Try li.thumb
            articles = soup.find_all("li", class_="thumb")

        if not articles:
            return [], True

        for art in articles:
            a_tag = art.find("a", href=True)
            img_tag = art.find("img")
            title_tag = art.find(["h2", "h3", "p"])

            if not a_tag:
                continue

            link = a_tag["href"]
            if not link.startswith("http"):
                link = BASE_URL + link

            title = ""
            if title_tag:
                title = title_tag.get_text(strip=True)
            elif img_tag:
                title = img_tag.get("alt", "")
            if not title:
                title = link.split("/")[-2].replace("-", " ").title()

            poster = img_tag.get("src", "") if img_tag else ""

            items.append((title, link, poster))

        return items, False
    except Exception:
        return [], False


def run(categories=None, max_pages=5, workers=10):
    """
    Main entry point.
    categories: list of category slugs to scrape, None = all
    max_pages: pages per category
    workers: concurrent threads
    """
    cats_to_run = [c for c in CATEGORIES if categories is None or c["slug"] in categories]

    total_saved = 0

    for cat in cats_to_run:
        print(f"\n{'='*60}")
        print(f"📂 [{cat['group'].upper()}] Scraping শুরু ({max_pages} pages)...")
        print(f"{'='*60}")

        session = _get_session()
        all_items = []

        for page in range(1, max_pages + 1):
            print(f"  ⏳ Page {page}/{max_pages}...")
            items, is_last = _scrape_category_page(cat["slug"], page, session)
            if items:
                all_items.extend(items)
            if is_last:
                print(f"  ✅ শেষ পেজ পৌঁছেছে ({page})")
                break
            time.sleep(0.5)

        print(f"  📊 {len(all_items)} items পাওয়া গেছে। Processing শুরু ({workers} threads)...")

        saved = 0
        process_fn = _process_series_entry if cat["is_series"] else _process_movie_entry
        tasks = [(title, url, poster, cat["group"], cat["lang"]) for title, url, poster in all_items]

        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
            futures = {ex.submit(process_fn, t): t for t in tasks}
            for f in concurrent.futures.as_completed(futures):
                res = f.result()
                if res:
                    saved += 1
                    label = res[1] if isinstance(res[1], str) else res[1].upper()
                    print(f"  ✅ [{label}] {res[0][:55]}")
                else:
                    t = futures[f]
                    print(f"  ⚠️  Skipped: {t[0][:50]}")

        print(f"\n  🎬 {saved}/{len(all_items)} saved [{cat['group']}]")
        total_saved += saved

    print(f"\n{'='*60}")
    print(f"✅ Total saved: {total_saved}")
    return total_saved


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--cats", nargs="*", help="Category slugs (default: all)")
    parser.add_argument("--pages", type=int, default=5, help="Max pages per category")
    parser.add_argument("--workers", type=int, default=10, help="Concurrent workers")
    args = parser.parse_args()
    run(categories=args.cats, max_pages=args.pages, workers=args.workers)
