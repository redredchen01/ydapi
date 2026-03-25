#!/bin/bash
# YDAPI settings initializer — run after deploy to restore brand settings
# Usage: bash init-settings.sh
# Auto-runs on reboot via cron

YDAPI_URL="${YDAPI_URL:-http://127.0.0.1:8080}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@ydapi.local}"
ADMIN_PASS="${ADMIN_PASS:-YDAPI@2026!Secure}"

# Wait for service
for i in $(seq 1 30); do
  curl -s "$YDAPI_URL/health" | grep -q ok && break
  sleep 2
done

# Login
TOKEN=$(curl -s -X POST "$YDAPI_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "[init-settings] Login failed"
  exit 1
fi

# Logo
LOGO_B64=$(python3 -c "
import base64
svg='<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 80 80\" width=\"80\" height=\"80\"><defs><linearGradient id=\"bg\" x1=\"0%%\" y1=\"0%%\" x2=\"100%%\" y2=\"100%%\"><stop offset=\"0%%\" style=\"stop-color:#0d9488;stop-opacity:1\"/><stop offset=\"100%%\" style=\"stop-color:#0f766e;stop-opacity:1\"/></linearGradient></defs><rect width=\"80\" height=\"80\" rx=\"18\" fill=\"url(#bg)\"/><text x=\"40\" y=\"54\" font-family=\"system-ui,-apple-system,sans-serif\" font-size=\"32\" font-weight=\"700\" fill=\"white\" text-anchor=\"middle\" letter-spacing=\"-1\">YD</text></svg>'
print(base64.b64encode(svg.encode()).decode())
")

# Apply
curl -s -X PUT "$YDAPI_URL/api/v1/admin/settings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"site_name\":\"YDAPI\",
    \"site_subtitle\":\"Turn Your AI Subscriptions into API Power\",
    \"site_logo\":\"data:image/svg+xml;base64,$LOGO_B64\",
    \"api_base_url\":\"https://187.77.133.54\",
    \"registration_enabled\":true,
    \"totp_enabled\":true,
    \"default_concurrency\":20,
    \"ops_monitoring_enabled\":true,
    \"ops_realtime_monitoring_enabled\":true,
    \"enable_model_fallback\":true,
    \"fallback_model_anthropic\":\"claude-sonnet-4-20250514\",
    \"fallback_model_openai\":\"gpt-4.1\",
    \"fallback_model_gemini\":\"gemini-2.5-pro\"
  }" > /dev/null 2>&1

echo "[$(date)] YDAPI settings applied"
