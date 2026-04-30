#!/bin/bash
# ════════════════════════════════════════════════════════
#  run.sh — Media Hub Server Startup Script
#  ব্যবহার: bash run.sh
# ════════════════════════════════════════════════════════

# এই script-এর নিজের ফোল্ডারে যাও (যেখানে main.py আছে)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "════════════════════════════════════════════"
echo "  🎬 Media Hub Auto Scraper — Starting Up"
echo "  📁 Working Dir: $SCRIPT_DIR"
echo "════════════════════════════════════════════"

# Python আছে কি না চেক
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 পাওয়া যায়নি! আগে install করুন:"
    echo "   sudo apt install python3 python3-pip -y"
    exit 1
fi

# Requirements install (প্রথমবার)
if [ ! -f ".deps_installed" ]; then
    echo "📦 Dependencies install হচ্ছে..."
    pip3 install -r requirements.txt
    touch .deps_installed
    echo "✅ Dependencies installed!"
fi

# পুরানো process চলছে কি না চেক
PID_FILE="/tmp/mediahub.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "⚠️  আগের process (PID: $OLD_PID) এখনো চলছে। বন্ধ করা হচ্ছে..."
        kill "$OLD_PID"
        sleep 2
    fi
fi

# Main script চালাও এবং log file-এ output save করো
LOG_FILE="$SCRIPT_DIR/mediahub.log"
echo "📝 Log file: $LOG_FILE"
echo "🚀 main.py চালু হচ্ছে..."

nohup python3 main.py >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "✅ Process started! PID: $(cat $PID_FILE)"
echo ""
echo "📋 Log দেখতে: tail -f $LOG_FILE"
echo "🛑 বন্ধ করতে: bash stop.sh"
