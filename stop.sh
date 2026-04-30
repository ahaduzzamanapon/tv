#!/bin/bash
# stop.sh — Media Hub বন্ধ করার script

PID_FILE="/tmp/mediahub.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm "$PID_FILE"
        echo "🛑 Media Hub বন্ধ হয়েছে (PID: $PID)"
    else
        echo "⚠️  Process আর চলছে না।"
        rm "$PID_FILE"
    fi
else
    echo "⚠️  PID file পাওয়া যায়নি। হয়তো আগেই বন্ধ আছে।"
fi
