"""
scrapers/hdhub.py — hdhub4u South Hindi Dubbed Scraper
curl_cffi Chrome impersonate + JS unpack decoder ব্যবহার করে real stream link বের করে
"""

from curl_cffi import requests
from bs4 import BeautifulSoup
import re
import concurrent.futures
from database import upsert_movie

BASE_URL = "https://new5.hdhub4u.fo"
CATEGORY_URL = f"{BASE_URL}/category/south-hindi-movies/page/"
SOURCE = "hdhub4u"
GROUP_NAME = "South Hindi Dubbed"
LANGUAGE = "Hindi Dubbed"
MAX_PAGES = 3  # টেস্টে ৩ পেজ, বাড়াতে হলে বাড়ানো যাবে


def _unpack(p, a, c, k):
    """JS eval(p,a,c,k) packer decoder — obfuscated JS থেকে real code বের করে"""
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


def _get_stream_from_watch_page(watch_url, session):
    """Watch পেজের obfuscated JS থেকে m3u8/mp4 stream link বের করে"""
    try:
        res = session.get(watch_url)
        html = res.text

        m = re.search(
            r"return p}\('(.*?)',\s*(\d+),\s*(\d+),\s*'(.*?)'\.split\('\|'\)",
            html, re.DOTALL
        )
        if not m:
            return None, None

        p = m.group(1).replace("\\'", "'").replace("\\\\", "\\")
        a, c = int(m.group(2)), int(m.group(3))
        k = m.group(4).split("|")
        unpacked = _unpack(p, a, c, k)

        video_links = re.findall(
            r"https?://[^\s'\"<>,\[\]()\}]+?\.(?:m3u8|mp4)[^\s'\"<>,\[\]()\}]*",
            unpacked
        )
        sub_links = re.findall(
            r"https?://[^\s'\"<>,\[\]()\}]+?\.(?:vtt|srt)[^\s'\"<>,\[\]()\}]*",
            unpacked
        )
        video = video_links[0] if video_links else None
        sub = sub_links[0] if sub_links else None
        return video, sub

    except Exception:
        return None, None


def _process_movie(movie_data):
    """একটা movie পেজ process করে DB-তে save করে"""
    title, movie_url, poster = movie_data
    try:
        session = requests.Session(impersonate="chrome110", timeout=15)
        res = session.get(movie_url)
        soup = BeautifulSoup(res.text, "html.parser")

        content = soup.find("div", class_="entry-content") or soup
        links = content.find_all("a", href=True)

        # Watch/Play লিংক খোঁজা
        watch_link = None
        for a in links:
            href = a["href"]
            text = a.get_text(strip=True).lower()
            if re.search(r"(watch|play|stream|online|player)", text) or \
               re.search(r"(watch|play|stream|online|player)", href):
                if href != "#":
                    watch_link = href
                    break

        if not watch_link:
            return None

        video_url, sub_url = _get_stream_from_watch_page(watch_link, session)

        if not video_url:
            return None

        result = upsert_movie(
            title=title,
            quality="1080p",
            stream_url=video_url,
            poster_url=poster,
            group_name=GROUP_NAME,
            language=LANGUAGE,
            source=SOURCE,
        )
        return (title, result)

    except Exception:
        return None


def run(max_pages: int = MAX_PAGES) -> int:
    print(f"\n{'='*55}")
    print(f"🎬 [HDHUB4U] South Hindi Scraper চালু হচ্ছে... ({max_pages} পেজ)")
    print(f"{'='*55}")

    session = requests.Session(impersonate="chrome110", timeout=15)
    all_movies = []
    page = 1

    while page <= max_pages:
        print(f"  ⏳ Page {page} স্ক্যান হচ্ছে...")
        try:
            res = session.get(f"{CATEGORY_URL}{page}/")
            soup = BeautifulSoup(res.text, "html.parser")
            items = soup.find_all("li", class_="thumb")

            if not items:
                print(f"  ✅ শেষ পেজে পৌঁছানো হয়েছে ({page-1} পেজ স্ক্যান সম্পন্ন).")
                break

            for item in items:
                p_tag = item.find("p")
                a_tag = item.find("a")
                img_tag = item.find("img")
                if a_tag and img_tag:
                    link = a_tag["href"]
                    if link.startswith("/"):
                        link = f"{BASE_URL}{link}"
                    all_movies.append((
                        p_tag.text.strip() if p_tag else "Unknown",
                        link,
                        img_tag.get("src", "")
                    ))
            page += 1
        except Exception as e:
            print(f"  ⚠️ Page {page} error: {e}")
            break

    print(f"\n  🎬 {len(all_movies)} movie পাওয়া গেছে। Stream extraction শুরু (30 threads)...")

    saved = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=30) as ex:
        futures = {ex.submit(_process_movie, m): m for m in all_movies}
        for f in concurrent.futures.as_completed(futures):
            res = f.result()
            if res:
                saved += 1
                print(f"  ⚡ [{res[1].upper()}] {res[0][:55]}")
            else:
                movie = futures[f]
                print(f"  ⚠️ Skipped: {movie[0][:50]}")

    print(f"\n  ✅ {saved} movies DB-তে save হয়েছে (HDHub4u).")
    return saved
