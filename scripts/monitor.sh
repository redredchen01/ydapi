#!/bin/bash
# YDAPI Health Monitor with Telegram alerts
# Usage: Add to cron: */5 * * * * /opt/ydapi/scripts/monitor.sh
#
# Required env vars (set in /opt/ydapi/.env.monitor):
#   TELEGRAM_BOT_TOKEN=your_bot_token
#   TELEGRAM_CHAT_ID=your_chat_id
#   YDAPI_URL=http://127.0.0.1:8080
#   YDAPI_TOKEN=your_admin_jwt_token (optional, for account checks)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env.monitor"
STATE_FILE="/tmp/ydapi-monitor-state"

# Only source env file if it exists and is owned by current user with safe permissions
if [ -f "$ENV_FILE" ]; then
  PERMS=$(stat -f '%Lp' "$ENV_FILE" 2>/dev/null || stat -c '%a' "$ENV_FILE" 2>/dev/null)
  OWNER=$(stat -f '%u' "$ENV_FILE" 2>/dev/null || stat -c '%u' "$ENV_FILE" 2>/dev/null)
  if [ "$OWNER" = "$(id -u)" ] && [ "$PERMS" = "600" ] || [ "$PERMS" = "640" ]; then
    source "$ENV_FILE"
  else
    echo "[$(date)] WARNING: Skipping $ENV_FILE — fix permissions: chmod 600 $ENV_FILE"
  fi
fi

YDAPI_URL="${YDAPI_URL:-http://127.0.0.1:8080}"

send_alert() {
    local msg="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="🚨 YDAPI Alert
$msg" \
            -d parse_mode="HTML" > /dev/null 2>&1
    fi
    echo "[$(date)] ALERT: $msg"
}

send_recovery() {
    local msg="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="✅ YDAPI Recovery
$msg" \
            -d parse_mode="HTML" > /dev/null 2>&1
    fi
    echo "[$(date)] RECOVERY: $msg"
}

# Health check
HEALTH=$(curl -s --connect-timeout 5 "${YDAPI_URL}/health" 2>/dev/null)
PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "ok")

if echo "$HEALTH" | grep -q '"ok"'; then
    if [ "$PREV_STATE" = "down" ]; then
        send_recovery "Service is back online"
    fi
    echo "ok" > "$STATE_FILE"
else
    if [ "$PREV_STATE" != "down" ]; then
        send_alert "Service is DOWN! Health check failed."
    fi
    echo "down" > "$STATE_FILE"
    exit 1
fi

# Account error check (if token provided)
if [ -n "$YDAPI_TOKEN" ]; then
    ERROR_ACCOUNTS=$(curl -s "${YDAPI_URL}/api/v1/admin/accounts" \
        -H "Authorization: Bearer $YDAPI_TOKEN" 2>/dev/null | \
        python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    errors=[a['name'] for a in d['data']['items'] if a.get('status')=='error']
    if errors: print(','.join(errors))
except: pass
" 2>/dev/null)

    if [ -n "$ERROR_ACCOUNTS" ]; then
        PREV_ERRORS=$(cat "${STATE_FILE}.errors" 2>/dev/null)
        if [ "$ERROR_ACCOUNTS" != "$PREV_ERRORS" ]; then
            send_alert "Account errors: $ERROR_ACCOUNTS"
        fi
        echo "$ERROR_ACCOUNTS" > "${STATE_FILE}.errors"
    else
        rm -f "${STATE_FILE}.errors"
    fi
fi
