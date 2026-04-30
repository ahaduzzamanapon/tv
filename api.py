"""
api.py — Media Hub Public REST API  v3.0
════════════════════════════════════════════════════════════
Public App API — Movies, Live Matches, TV Channels, App Version

Authentication: X-API-Key header (সব /api/v1/* endpoint-এ)
App version check: /api/v1/app/version (auth লাগে না)
Download page: / (HTML)

cPanel-এ চালাতে passenger_wsgi.py ব্যবহার করুন।
════════════════════════════════════════════════════════════
"""

import sys, io, os, json, secrets, sqlite3, argparse
from functools import wraps
from datetime import datetime

# Windows UTF-8 fix
if hasattr(sys.stdout, 'buffer') and sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from flask import Flask, jsonify, request, send_from_directory

BASE_DIR         = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)
import database as db
import pymysql

app = Flask(__name__, static_folder=None)
app.config['JSON_SORT_KEYS'] = False

API_KEYS_FILE    = os.path.join(BASE_DIR, "api_keys.txt")
APP_VERSION_FILE = os.path.join(BASE_DIR, "app_version.json")
STATIC_DIR       = os.path.join(BASE_DIR, "static")
DEFAULT_LIMIT    = 20
MAX_LIMIT        = 100


# ══════════════════════════════════════════════════
#  🔑 API KEY AUTH
# ══════════════════════════════════════════════════

def load_api_keys() -> set:
    if not os.path.exists(API_KEYS_FILE):
        return set()
    with open(API_KEYS_FILE, "r", encoding="utf-8") as f:
        return {l.strip() for l in f if l.strip() and not l.startswith("#")}


def generate_default_key() -> str:
    keys = load_api_keys()
    if keys:
        return list(keys)[0]
    key = "mhub_" + secrets.token_hex(24)
    with open(API_KEYS_FILE, "w", encoding="utf-8") as f:
        f.write("# Media Hub API Keys\n# নতুন key = নতুন line\n")
        f.write(f"{key}\n")
    return key


def require_api_key(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        key = request.headers.get("X-API-Key") or request.args.get("api_key")
        if not key:
            return _error("API key missing. X-API-Key header দিন।", 401)
        if key not in load_api_keys():
            return _error("Invalid API key.", 403)
        return f(*args, **kwargs)
    return decorated


# ══════════════════════════════════════════════════
#  🛠️ HELPERS
# ══════════════════════════════════════════════════

def _conn():
    """MySQL connection — DictCursor সহ"""
    return db.get_connection()


def _page_params():
    try:
        page  = max(1, int(request.args.get("page", 1)))
        limit = min(MAX_LIMIT, max(1, int(request.args.get("limit", DEFAULT_LIMIT))))
    except ValueError:
        page, limit = 1, DEFAULT_LIMIT
    return page, limit, (page - 1) * limit


def _ok(data, **meta):
    return jsonify({"success": True, **meta, "data": data})


def _error(msg, code=400):
    return jsonify({"success": False, "error": msg}), code


def _ver(v):
    """'1.2.3' → (1,2,3) — packaging module ছাড়াই version compare"""
    try:
        return tuple(int(x) for x in str(v).strip().split('.'))
    except Exception:
        return (0, 0, 0)


# ══════════════════════════════════════════════════
#  🌐 WELCOME PAGE (HTML Download Page)
# ══════════════════════════════════════════════════

@app.route("/")
def welcome():
    html_file = os.path.join(STATIC_DIR, "index.html")
    if os.path.exists(html_file):
        return send_from_directory(STATIC_DIR, "index.html")
    return _ok({"name": "Media Hub API", "version": "3.0"})


@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory(STATIC_DIR, filename)


# ══════════════════════════════════════════════════
#  📱 APP VERSION CHECK — Auth লাগে না
# ══════════════════════════════════════════════════

@app.route("/api/v1/app/version")
def app_version():
    """
    App startup-এ প্রথমেই এই endpoint hit করবে।
    Auth লাগে না — app install হওয়ার পরপরই call করতে হবে।

    Query: ?v=1.0.0  (app-এর current version পাঠাও)

    Response actions:
      "none"     → সব ঠিক, চলো
      "notify"   → নতুন version আছে, user-কে জানাও (optional)
      "block"    → force update বা maintenance — app বন্ধ করো
    """
    cfg = {}
    if os.path.exists(APP_VERSION_FILE):
        with open(APP_VERSION_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)

    if not cfg:
        return _ok({"action": "none", "status": "ok"})

    # Maintenance চেক
    if cfg.get("maintenance_mode", False):
        return _ok({
            "action":       "block",
            "status":       "maintenance",
            "message":      cfg.get("maintenance_message", "সিস্টেম রক্ষণাবেক্ষণ চলছে।"),
            "support_url":  cfg.get("support_url", ""),
        })

    app_v  = request.args.get("v", "0.0.0")
    curr_v = cfg.get("current_version",      "1.0.0")
    min_v  = cfg.get("min_required_version", "1.0.0")

    is_outdated      = _ver(app_v) < _ver(min_v)
    update_available = _ver(app_v) < _ver(curr_v)
    force_update     = cfg.get("force_update", False) or is_outdated

    if force_update:
        return _ok({
            "action":          "block",
            "status":          "update_required",
            "message":         cfg.get("update_message", "আপডেট করুন।"),
            "your_version":    app_v,
            "latest_version":  curr_v,
            "download_url":    cfg.get("download_url", ""),
            "play_store_url":  cfg.get("play_store_url", ""),
            "apk_size":        cfg.get("apk_size", ""),
            "changelog":       cfg.get("changelog", []),
        })

    return _ok({
        "action":          "notify" if update_available else "none",
        "status":          "ok",
        "your_version":    app_v,
        "latest_version":  curr_v,
        "update_available": update_available,
        "update_message":  cfg.get("update_message", "") if update_available else "",
        "download_url":    cfg.get("download_url", "") if update_available else "",
        "play_store_url":  cfg.get("play_store_url", "") if update_available else "",
        "apk_size":        cfg.get("apk_size", "") if update_available else "",
        "changelog":       cfg.get("changelog", []) if update_available else [],
        "support_url":     cfg.get("support_url", ""),
    })


@app.route("/api/v1/app/version", methods=["PATCH"])
@require_api_key
def update_app_version():
    """Admin — app_version.json update করে। যেকোনো field পাঠান।"""
    cfg = {}
    if os.path.exists(APP_VERSION_FILE):
        with open(APP_VERSION_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
    body = request.get_json(silent=True) or {}
    if not body:
        return _error("JSON body দিন।", 400)
    cfg.update(body)
    with open(APP_VERSION_FILE, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    return _ok(cfg, message="Version updated!")


# ══════════════════════════════════════════════════
#  🔴 LIVE MATCHES
# ══════════════════════════════════════════════════

@app.route("/api/v1/live")
@require_api_key
def get_live():
    """
    Query: league, status (LIVE/Upcoming), team, search
    """
    league = request.args.get("league", "").strip()
    status = request.args.get("status", "").strip()
    team   = request.args.get("team",   "").strip()
    search = request.args.get("search", "").strip()

    conn   = _conn()
    where  = "WHERE 1=1"
    params = []

    if league:
        where += " AND UPPER(league) LIKE ?"
        params.append(f"%{league.upper()}%")
    if status:
        where += " AND UPPER(match_status) = ?"
        params.append(status.upper())
    if team:
        where += " AND (team1 LIKE ? OR team2 LIKE ?)"
        params.extend([f"%{team}%", f"%{team}%"])
    if search:
        where += " AND match_title LIKE ?"
        params.append(f"%{search}%")

    order = "ORDER BY CASE WHEN UPPER(match_status)='LIVE' THEN 0 ELSE 1 END, start_time_bd"
    rows  = conn.execute(f"SELECT * FROM live_matches {where} {order}", params).fetchall()
    total = conn.execute(f"SELECT COUNT(*) FROM live_matches {where}", params).fetchone()[0]

    # Filter dropdowns
    leagues   = [r[0] for r in conn.execute("SELECT DISTINCT league FROM live_matches WHERE league!='' ORDER BY league").fetchall()]
    statuses  = [r[0] for r in conn.execute("SELECT DISTINCT match_status FROM live_matches ORDER BY match_status").fetchall()]
    conn.close()

    matches = []
    for r in rows:
        m = dict(r)
        try:
            m["stream_urls"] = json.loads(m["stream_urls"])
        except Exception:
            m["stream_urls"] = []
        matches.append(m)

    live_count     = sum(1 for m in matches if m["match_status"].upper() == "LIVE")
    upcoming_count = len(matches) - live_count

    return _ok(matches,
        total=total,
        live_count=live_count,
        upcoming_count=upcoming_count,
        filters_applied={"league": league or None, "status": status or None,
                         "team": team or None, "search": search or None},
        available_filters={"leagues": leagues, "statuses": statuses}
    )


@app.route("/api/v1/live/<int:match_id>")
@require_api_key
def get_live_single(match_id):
    conn = _conn()
    row  = conn.execute("SELECT * FROM live_matches WHERE id=?", (match_id,)).fetchone()
    conn.close()
    if not row:
        return _error("Match not found", 404)
    m = dict(row)
    try:
        m["stream_urls"] = json.loads(m["stream_urls"])
    except Exception:
        m["stream_urls"] = []
    return _ok(m)


# ══════════════════════════════════════════════════
#  🎬 MOVIES
# ══════════════════════════════════════════════════

@app.route("/api/v1/movies")
@require_api_key
def get_movies():
    """
    Query: search, category (group_name), language, quality, source
           sort (newest/oldest/title_asc/title_desc), page, limit
    """
    page, limit, offset = _page_params()
    search   = request.args.get("search",   "").strip()
    category = request.args.get("category", "").strip()
    language = request.args.get("language", "").strip()
    quality  = request.args.get("quality",  "").strip()
    source   = request.args.get("source",   "").strip()
    sort     = request.args.get("sort",     "newest").strip()

    sort_map = {
        "newest":     "added_at DESC",
        "oldest":     "added_at ASC",
        "title_asc":  "title COLLATE NOCASE ASC",
        "title_desc": "title COLLATE NOCASE DESC",
    }
    order_by = sort_map.get(sort, "added_at DESC")

    conn   = _conn()
    where  = "WHERE 1=1"
    params = []

    if search:
        where += " AND title LIKE ?"
        params.append(f"%{search}%")
    if category:
        where += " AND group_name LIKE ?"
        params.append(f"%{category}%")
    if language:
        where += " AND language LIKE ?"
        params.append(f"%{language}%")
    if quality:
        where += " AND quality LIKE ?"
        params.append(f"%{quality}%")
    if source:
        where += " AND source LIKE ?"
        params.append(f"%{source}%")

    total = conn.execute(f"SELECT COUNT(*) FROM movies {where}", params).fetchone()[0]
    rows  = conn.execute(f"SELECT * FROM movies {where} ORDER BY {order_by} LIMIT ? OFFSET ?",
                         params + [limit, offset]).fetchall()

    # Filter dropdowns
    categories = [r[0] for r in conn.execute("SELECT DISTINCT group_name FROM movies WHERE group_name!='' ORDER BY group_name").fetchall()]
    languages  = [r[0] for r in conn.execute("SELECT DISTINCT language FROM movies WHERE language!='' ORDER BY language").fetchall()]
    qualities  = [r[0] for r in conn.execute("SELECT DISTINCT quality FROM movies WHERE quality!='' ORDER BY quality").fetchall()]
    conn.close()

    return _ok(
        [dict(r) for r in rows],
        total=total,
        page=page,
        limit=limit,
        total_pages=(total + limit - 1) // limit if total > 0 else 0,
        filters_applied={"search": search or None, "category": category or None,
                         "language": language or None, "quality": quality or None,
                         "source": source or None, "sort": sort},
        available_filters={"categories": categories, "languages": languages,
                           "qualities": qualities,
                           "sort_options": ["newest", "oldest", "title_asc", "title_desc"]}
    )


@app.route("/api/v1/movies/<int:movie_id>")
@require_api_key
def get_movie_single(movie_id):
    conn = _conn()
    row  = conn.execute("SELECT * FROM movies WHERE id=?", (movie_id,)).fetchone()
    conn.close()
    if not row:
        return _error("Movie not found", 404)
    return _ok(dict(row))


# ══════════════════════════════════════════════════
#  📺 TV CHANNELS
# ══════════════════════════════════════════════════

@app.route("/api/v1/channels")
@require_api_key
def get_channels():
    """
    Query: group (SPORTS/NEWS/BANGLA TV/MOVIES/OTHERS), search, source
           sort (name_asc/name_desc/group_asc), page, limit
    """
    page, limit, offset = _page_params()
    group  = request.args.get("group",  "").strip().upper()
    search = request.args.get("search", "").strip()
    source = request.args.get("source", "").strip()
    sort   = request.args.get("sort",   "group_asc").strip()

    sort_map = {
        "name_asc":  "channel_name COLLATE NOCASE ASC",
        "name_desc": "channel_name COLLATE NOCASE DESC",
        "group_asc": "group_name ASC, channel_name ASC",
    }
    order_by = sort_map.get(sort, "group_name ASC, channel_name ASC")

    conn   = _conn()
    where  = "WHERE 1=1"
    params = []

    if group:
        where += " AND UPPER(group_name) = ?"
        params.append(group)
    if search:
        where += " AND channel_name LIKE ?"
        params.append(f"%{search}%")
    if source:
        where += " AND source LIKE ?"
        params.append(f"%{source}%")

    total = conn.execute(f"SELECT COUNT(*) FROM tv_channels {where}", params).fetchone()[0]
    rows  = conn.execute(f"SELECT * FROM tv_channels {where} ORDER BY {order_by} LIMIT ? OFFSET ?",
                         params + [limit, offset]).fetchall()

    # Filter dropdowns
    groups = [r[0] for r in conn.execute("SELECT DISTINCT group_name FROM tv_channels WHERE group_name!='' ORDER BY group_name").fetchall()]
    conn.close()

    return _ok(
        [dict(r) for r in rows],
        total=total,
        page=page,
        limit=limit,
        total_pages=(total + limit - 1) // limit if total > 0 else 0,
        filters_applied={"group": group or None, "search": search or None, "source": source or None},
        available_filters={"groups": groups, "sort_options": ["name_asc", "name_desc", "group_asc"]}
    )


@app.route("/api/v1/channels/<int:channel_id>")
@require_api_key
def get_channel_single(channel_id):
    conn = _conn()
    row  = conn.execute("SELECT * FROM tv_channels WHERE id=?", (channel_id,)).fetchone()
    conn.close()
    if not row:
        return _error("Channel not found", 404)
    return _ok(dict(row))


# ══════════════════════════════════════════════════
#  ❌ ERROR HANDLERS
# ══════════════════════════════════════════════════

@app.errorhandler(404)
def not_found(e):
    return _error("Endpoint not found", 404)

@app.errorhandler(405)
def method_not_allowed(e):
    return _error("Method not allowed", 405)

@app.errorhandler(500)
def server_error(e):
    return _error(f"Server error: {str(e)}", 500)


# ══════════════════════════════════════════════════
#  🚀 STARTUP (direct run)
# ══════════════════════════════════════════════════

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port",  type=int, default=5000)
    parser.add_argument("--host",  type=str, default="0.0.0.0")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    db.init_db()
    api_key = generate_default_key()

    print(f"""
╔══════════════════════════════════════════════════════════════╗
║          🎬  MEDIA HUB PUBLIC API  v3.0                      ║
╠══════════════════════════════════════════════════════════════╣
║  URL     : http://{args.host}:{args.port}
║  API Key : {api_key}
╠══════════════════════════════════════════════════════════════╣
║  GET  /                        Download page (HTML)          ║
║  GET  /api/v1/app/version      App version check (no auth)   ║
║  PATCH /api/v1/app/version     Update version (auth req.)    ║
║  GET  /api/v1/live             Live matches                  ║
║  GET  /api/v1/movies           Movies                        ║
║  GET  /api/v1/channels         TV Channels                   ║
╚══════════════════════════════════════════════════════════════╝
""")
    app.run(host=args.host, port=args.port, debug=args.debug)
