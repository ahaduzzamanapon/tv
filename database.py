"""
database.py — MySQL Database Manager
সব টেবিল তৈরি করে এবং Insert/Update/Query ফাংশন দেয়।
Database: tv (localhost, root)
"""

import sys
import io
import json
from datetime import datetime

if hasattr(sys.stdout, 'buffer') and sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import pymysql
import pymysql.cursors

# config.py থেকে DB settings নেওয়া হচ্ছে
try:
    from config import DB_CONFIG
except ImportError:
    DB_CONFIG = {
        "host":     "localhost",
        "user":     "root",
        "password": "",
        "database": "tv",
        "charset":  "utf8mb4",
        "autocommit": True,
    }


# ══════════════════════════════════════════════════
#  CONNECTION
# ══════════════════════════════════════════════════

def get_connection():
    """MySQL connection তৈরি করে — প্রতিটা call-এ নতুন connection"""
    conn = pymysql.connect(
        host      = DB_CONFIG["host"],
        user      = DB_CONFIG["user"],
        password  = DB_CONFIG["password"],
        database  = DB_CONFIG["database"],
        charset   = DB_CONFIG.get("charset", "utf8mb4"),
        autocommit= DB_CONFIG.get("autocommit", True),
        cursorclass = pymysql.cursors.DictCursor,
    )
    return conn


def _exec(sql, params=None, fetchone=False, fetchall=False):
    """Helper — connection খুলে query চালায়, বন্ধ করে"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            if fetchone:
                return cur.fetchone()
            if fetchall:
                return cur.fetchall()
            return cur.lastrowid
    finally:
        conn.close()


def now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ══════════════════════════════════════════════════
#  INIT — Tables তৈরি করে (প্রথমবার)
# ══════════════════════════════════════════════════

def init_db():
    """সব টেবিল create করে — প্রতিবার run করা safe"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:

            # ── MOVIES ──
            cur.execute("""
                CREATE TABLE IF NOT EXISTS movies (
                    id          INT AUTO_INCREMENT PRIMARY KEY,
                    title       VARCHAR(500) NOT NULL,
                    quality     VARCHAR(50)  DEFAULT '',
                    stream_url  VARCHAR(700) NOT NULL,
                    poster_url  TEXT,
                    group_name  VARCHAR(200) DEFAULT '',
                    language    VARCHAR(100) DEFAULT '',
                    source      VARCHAR(200) NOT NULL,
                    added_at    DATETIME     NOT NULL,
                    updated_at  DATETIME     NOT NULL,
                    UNIQUE KEY uq_stream_url (stream_url(500))
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)

            # ── LIVE MATCHES ──
            cur.execute("""
                CREATE TABLE IF NOT EXISTS live_matches (
                    id              INT AUTO_INCREMENT PRIMARY KEY,
                    match_title     VARCHAR(500) NOT NULL,
                    league          VARCHAR(200) DEFAULT '',
                    team1           VARCHAR(200) DEFAULT '',
                    team2           VARCHAR(200) DEFAULT '',
                    team1_logo      TEXT,
                    team2_logo      TEXT,
                    stream_urls     LONGTEXT     NOT NULL,
                    match_status    VARCHAR(50)  DEFAULT 'Upcoming',
                    start_time_bd   VARCHAR(100) DEFAULT '',
                    poster_url      TEXT,
                    source          VARCHAR(200) NOT NULL,
                    added_at        DATETIME     NOT NULL,
                    updated_at      DATETIME     NOT NULL,
                    UNIQUE KEY uq_match (match_title(300), source(100))
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)

            # ── TV CHANNELS ──
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tv_channels (
                    id           INT AUTO_INCREMENT PRIMARY KEY,
                    channel_name VARCHAR(300) NOT NULL,
                    group_name   VARCHAR(100) DEFAULT 'OTHERS',
                    logo_url     TEXT,
                    stream_url   VARCHAR(700) NOT NULL,
                    source       VARCHAR(200) NOT NULL,
                    added_at     DATETIME     NOT NULL,
                    updated_at   DATETIME     NOT NULL,
                    UNIQUE KEY uq_stream_url (stream_url(500))
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)

        conn.commit()
        print("✅ MySQL Database initialized: tv")

    except pymysql.Error as e:
        print(f"❌ MySQL Error during init: {e}")
        raise
    finally:
        conn.close()


# ══════════════════════════════════════════════════
#  MOVIES
# ══════════════════════════════════════════════════

def upsert_movie(title, quality, stream_url, poster_url, group_name, language, source):
    """Movie insert — stream_url duplicate হলে update করে"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO movies
                    (title, quality, stream_url, poster_url, group_name, language, source, added_at, updated_at)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    title      = VALUES(title),
                    quality    = VALUES(quality),
                    poster_url = VALUES(poster_url),
                    group_name = VALUES(group_name),
                    language   = VALUES(language),
                    source     = VALUES(source),
                    updated_at = VALUES(updated_at)
            """, (title, quality, stream_url, poster_url, group_name, language, source, now(), now()))
        conn.commit()
        return "upserted"
    except pymysql.Error as e:
        print(f"❌ upsert_movie error: {e}")
        return "error"
    finally:
        conn.close()


def count_movies():
    row = _exec("SELECT COUNT(*) AS cnt FROM movies", fetchone=True)
    return row["cnt"] if row else 0


# ══════════════════════════════════════════════════
#  LIVE MATCHES
# ══════════════════════════════════════════════════

def upsert_live_match(match_title, league, team1, team2, team1_logo, team2_logo,
                      stream_urls_list, match_status, start_time_bd, poster_url, source):
    """Live match insert — (match_title, source) duplicate হলে update করে"""
    stream_urls_json = json.dumps(stream_urls_list, ensure_ascii=False)
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO live_matches
                    (match_title, league, team1, team2, team1_logo, team2_logo,
                     stream_urls, match_status, start_time_bd, poster_url, source, added_at, updated_at)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    league        = VALUES(league),
                    team1         = VALUES(team1),
                    team2         = VALUES(team2),
                    team1_logo    = VALUES(team1_logo),
                    team2_logo    = VALUES(team2_logo),
                    stream_urls   = VALUES(stream_urls),
                    match_status  = VALUES(match_status),
                    start_time_bd = VALUES(start_time_bd),
                    poster_url    = VALUES(poster_url),
                    updated_at    = VALUES(updated_at)
            """, (match_title, league, team1, team2, team1_logo, team2_logo,
                  stream_urls_json, match_status, start_time_bd, poster_url, source, now(), now()))
        conn.commit()
        return "upserted"
    except pymysql.Error as e:
        print(f"❌ upsert_live_match error: {e}")
        return "error"
    finally:
        conn.close()


def clear_live_matches():
    """প্রতি রানে পুরানো live match মুছে নতুন করে ভরা হয়"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM live_matches")
        conn.commit()
    finally:
        conn.close()


def count_live_matches():
    row = _exec("SELECT COUNT(*) AS cnt FROM live_matches", fetchone=True)
    return row["cnt"] if row else 0


# ══════════════════════════════════════════════════
#  TV CHANNELS
# ══════════════════════════════════════════════════

def upsert_channel(channel_name, group_name, logo_url, stream_url, source):
    """TV channel insert — stream_url duplicate হলে update করে"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO tv_channels
                    (channel_name, group_name, logo_url, stream_url, source, added_at, updated_at)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    channel_name = VALUES(channel_name),
                    group_name   = VALUES(group_name),
                    logo_url     = VALUES(logo_url),
                    source       = VALUES(source),
                    updated_at   = VALUES(updated_at)
            """, (channel_name, group_name, logo_url, stream_url, source, now(), now()))
        conn.commit()
        return "upserted"
    except pymysql.Error as e:
        print(f"❌ upsert_channel error: {e}")
        return "error"
    finally:
        conn.close()


def count_channels():
    row = _exec("SELECT COUNT(*) AS cnt FROM tv_channels", fetchone=True)
    return row["cnt"] if row else 0


# ══════════════════════════════════════════════════
#  STATS / QUERY
# ══════════════════════════════════════════════════

def get_stats():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS cnt FROM movies")
            total_movies = cur.fetchone()["cnt"]

            cur.execute("SELECT COUNT(*) AS cnt FROM live_matches")
            total_live = cur.fetchone()["cnt"]

            cur.execute("SELECT COUNT(*) AS cnt FROM tv_channels")
            total_channels = cur.fetchone()["cnt"]

            cur.execute("SELECT source, COUNT(*) AS cnt FROM movies GROUP BY source")
            movies_by_source = {r["source"]: r["cnt"] for r in cur.fetchall()}

            cur.execute("SELECT group_name, COUNT(*) AS cnt FROM tv_channels GROUP BY group_name")
            channels_by_group = {r["group_name"]: r["cnt"] for r in cur.fetchall()}

            cur.execute("SELECT league, COUNT(*) AS cnt FROM live_matches GROUP BY league")
            live_by_league = {r["league"]: r["cnt"] for r in cur.fetchall()}

        return {
            "total_movies":       total_movies,
            "total_live_matches": total_live,
            "total_tv_channels":  total_channels,
            "movies_by_source":   movies_by_source,
            "channels_by_group":  channels_by_group,
            "live_by_league":     live_by_league,
        }
    finally:
        conn.close()


# ══════════════════════════════════════════════════
#  API QUERY HELPERS (for api.py)
# ══════════════════════════════════════════════════

def query_movies(where="", params=(), order_by="added_at DESC", limit=20, offset=0):
    sql = f"SELECT * FROM movies {where} ORDER BY {order_by} LIMIT %s OFFSET %s"
    return _exec(sql, list(params) + [limit, offset], fetchall=True) or []


def count_table(table, where="", params=()):
    row = _exec(f"SELECT COUNT(*) AS cnt FROM {table} {where}", params, fetchone=True)
    return row["cnt"] if row else 0


def query_live(where="", params=(), order_by="match_status ASC, start_time_bd ASC"):
    sql = f"SELECT * FROM live_matches {where} ORDER BY {order_by}"
    rows = _exec(sql, params, fetchall=True) or []
    for r in rows:
        try:
            r["stream_urls"] = json.loads(r["stream_urls"])
        except Exception:
            r["stream_urls"] = []
    return rows


def query_channels(where="", params=(), order_by="group_name ASC, channel_name ASC", limit=50, offset=0):
    sql = f"SELECT * FROM tv_channels {where} ORDER BY {order_by} LIMIT %s OFFSET %s"
    return _exec(sql, list(params) + [limit, offset], fetchall=True) or []


def distinct_values(table, column):
    rows = _exec(
        f"SELECT DISTINCT `{column}` AS v FROM `{table}` WHERE `{column}` != '' AND `{column}` IS NOT NULL ORDER BY `{column}`",
        fetchall=True
    ) or []
    return [r["v"] for r in rows]
