"""
scrapers/fibwatch.py — fibwatch.art Full Scraper
All categories (Bengali, Hindi, English, Tamil, etc.) — cloudscraper Cloudflare bypass
"""

import cloudscraper
from bs4 import BeautifulSoup
import re
import concurrent.futures
from database import upsert_movie

BASE_URL = "https://fibwatch.art"
SOURCE = "fibwatch.art"

# সব available categories — cat_id: (group_name, language)
ALL_CATEGORIES = {
    "1":  ("Bengali Dubbed",    "Bengali"),
    "2":  ("Bangla Movie",      "Bangla"),
    "3":  ("Hindi",             "Hindi"),
    "4":  ("English",           "English"),
    "5":  ("Tamil Dubbed",      "Tamil"),
    "6":  ("Telugu Dubbed",     "Telugu"),
    "7":  ("South Hindi",       "Hindi Dubbed"),
    "8":  ("Animation",         "Multi"),
    "9":  ("Korean",            "Korean"),
    "10": ("Action",            "Multi"),
    "11": ("Comedy",            "Multi"),
    "12": ("Drama",             "Multi"),
}


def _make_scraper():
    return cloudscraper.create_scraper(
        browser={"browser": "chrome", "platform": "windows", "mobile": False}
    )


def _extract_actual_link(watch_soup) -> str | None:
    """ওয়াচ পেজ থেকে .mkv / .mp4 লিংক বের করে"""
    for a in watch_soup.find_all("a", href=True):
        href = a["href"]
        if "urlshortlink.top" in href and "url=" in href:
            m = re.search(r"url=(.*)", href)
            if m:
                decoded = m.group(1).replace("%3A", ":").replace("%2F", "/")
                if ".mkv" in decoded or ".mp4" in decoded:
                    return decoded
        elif (".mkv" in href or ".mp4" in href) and "urlshortlink.top" not in href:
            link = href
            if link.startswith("/"):
                link = f"{BASE_URL}{link}"
            return link
    return None


def _process_movie(base_name, watch_link, quality, scraper, group_name, language):
    """একটা movie পেজ থেকে real stream link বের করে DB-তে save করে"""
    try:
        res = scraper.get(watch_link, timeout=15)
        soup = BeautifulSoup(res.text, "html.parser")
        actual_link = _extract_actual_link(soup)

        if not actual_link:
            return None

        # Poster
        poster_tag = soup.find("meta", property="og:image")
        poster = poster_tag["content"] if poster_tag else ""

        # Title clean করা
        file_name = actual_link.split("/")[-1]
        file_name = re.sub(r"\[Fibwatch\.Com\]", "", file_name, flags=re.IGNORECASE)
        file_name = re.sub(r"\.mkv|\.mp4", "", file_name, flags=re.IGNORECASE)
        file_name = file_name.replace(".", " ").strip()

        # Quality detect
        q_match = re.search(r"(\d{3,4})p", watch_link)
        quality_str = f"{quality}p" if quality else ""

        result = upsert_movie(
            title=file_name,
            quality=quality_str,
            stream_url=actual_link,
            poster_url=poster,
            group_name=group_name,
            language=language,
            source=SOURCE,
        )
        return (file_name, result)

    except Exception:
        return None


# ──────────────────────────────────────────
#  স্ক্যানার: Category-based
# ──────────────────────────────────────────

def _scan_category_page(cat_id, page_num, scraper):
    url = f"{BASE_URL}/videos/category/{cat_id}?page_id={page_num}"
    found = []
    try:
        res = scraper.get(url, timeout=15)
        soup = BeautifulSoup(res.text, "html.parser")
        watch_links = [
            a["href"] for a in soup.find_all("a", href=True)
            if "/watch/" in a["href"] and a["href"].endswith(".html")
        ]
        for link in set(watch_links):
            full = link if link.startswith("http") else f"{BASE_URL}{link}"
            bm = re.search(r"/watch/(.*?)(?:-\d{3,4}p_|_)", full)
            base = bm.group(1) if bm else full.split("/")[-1]
            qm = re.search(r"(\d{3,4})p", full)
            quality = int(qm.group(1)) if qm else 0
            found.append((base, full, quality))
    except Exception:
        pass
    return found


def run_category(cat_id: str, group_name: str, language: str, max_pages: int = 150) -> int:
    print(f"\n{'='*55}")
    print(f"🎬 [FIBWATCH] Category {cat_id} — {group_name} চালু হচ্ছে...")
    print(f"{'='*55}")

    scraper = _make_scraper()
    best_qualities = {}
    best_links = {}

    print(f"  ⏳ {max_pages} পেজ concurrent স্ক্যান হচ্ছে (30 threads)...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
        futures = {ex.submit(_scan_category_page, cat_id, p, scraper): p for p in range(1, max_pages + 1)}
        for f in concurrent.futures.as_completed(futures):
            for base, link, q in f.result():
                if q > best_qualities.get(base, 0):
                    best_qualities[base] = q
                    best_links[base] = link

    print(f"  ✅ {len(best_links)} unique movie পাওয়া গেছে।")
    print(f"  🔗 Link extraction শুরু (30 threads)...")

    saved = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
        futures = {
            ex.submit(_process_movie, b, l, best_qualities[b], scraper, group_name, language): b
            for b, l in best_links.items()
        }
        for f in concurrent.futures.as_completed(futures):
            res = f.result()
            if res:
                saved += 1
                print(f"  ⚡ [{res[1].upper()}] {res[0][:50]}")

    print(f"\n  ✅ {saved} movies DB-তে save হয়েছে ({group_name}).")
    return saved


def run_all_categories(max_pages: int = 50) -> int:
    """সব fibwatch categories scrape করে"""
    total = 0
    for cat_id, (group, lang) in ALL_CATEGORIES.items():
        try:
            saved = run_category(cat_id, group, lang, max_pages=max_pages)
            total += saved
        except Exception as e:
            print(f"  ⚠️ Category {cat_id} error: {e}")
    print(f"\n✅ Fibwatch total saved: {total}")
    return total


# ──────────────────────────────────────────
#  স্ক্যানার: Latest Section
# ──────────────────────────────────────────

def _scan_latest_page(page_num, scraper):
    url = f"{BASE_URL}/videos/latest?page_id={page_num}"
    found = []
    try:
        res = scraper.get(url, timeout=15)
        soup = BeautifulSoup(res.text, "html.parser")
        watch_links = [
            a["href"] for a in soup.find_all("a", href=True)
            if "/watch/" in a["href"] and a["href"].endswith(".html")
        ]
        if not watch_links:
            return []
        for link in set(watch_links):
            full = link if link.startswith("http") else f"{BASE_URL}{link}"
            bm = re.search(r"/watch/(.*?)(?:-\d{3,4}p_|_)", full)
            base = bm.group(1) if bm else full.split("/")[-1]
            qm = re.search(r"(\d{3,4})p", full)
            quality = int(qm.group(1)) if qm else 0
            found.append((base, full, quality))
    except Exception:
        pass
    return found


def run_latest(max_pages: int = 500, group_name: str = "Fibwatch Latest", language: str = "Multi") -> int:
    print(f"\n{'='*55}")
    print(f"🎬 [FIBWATCH] Latest Section — {max_pages} পেজ স্ক্যান হচ্ছে...")
    print(f"{'='*55}")

    scraper = _make_scraper()
    best_qualities = {}
    best_links = {}

    print(f"  ⏳ {max_pages} পেজ concurrent স্ক্যান (30 threads)...")
    with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
        futures = {ex.submit(_scan_latest_page, p, scraper): p for p in range(1, max_pages + 1)}
        for count, f in enumerate(concurrent.futures.as_completed(futures), 1):
            for base, link, q in f.result():
                if q > best_qualities.get(base, 0):
                    best_qualities[base] = q
                    best_links[base] = link
            if count % 100 == 0:
                print(f"    [+] {count}/{max_pages} পেজ স্ক্যান সম্পন্ন...")

    print(f"  ✅ {len(best_links)} unique movie পাওয়া গেছে।")

    saved = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
        futures = {
            ex.submit(_process_movie, b, l, best_qualities[b], scraper, group_name, language): b
            for b, l in best_links.items()
        }
        for f in concurrent.futures.as_completed(futures):
            res = f.result()
            if res:
                saved += 1
                print(f"  ⚡ [{res[1].upper()}] {res[0][:50]}")

    print(f"\n  ✅ {saved} movies DB-তে save হয়েছে (Latest).")
    return saved
