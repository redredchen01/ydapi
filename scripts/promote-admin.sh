#!/bin/bash
# Promote a registered user to admin and generate API keys for all groups
# Usage: bash promote-admin.sh <user_email>
#
# Requires: DEXAPI_URL and ADMIN_TOKEN env vars, or edit defaults below

set -e

DEXAPI_URL="${DEXAPI_URL:-https://187.77.133.54}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sub2api.local}"
ADMIN_PASS="${ADMIN_PASS:-DexApi@2026!Secure}"
CURL="curl -sk"

EMAIL="$1"
if [ -z "$EMAIL" ]; then
  echo "Usage: $0 <user_email>"
  exit 1
fi

# Login as admin
TOKEN=$($CURL -X POST "$DEXAPI_URL/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# Find user by email
USER_ID=$($CURL "$DEXAPI_URL/api/v1/admin/users?search=$EMAIL" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "
import sys,json
users=json.load(sys.stdin)['data']['items']
match=[u for u in users if u['email']=='$EMAIL']
if match: print(match[0]['id'])
else: print('NOT_FOUND')
")

if [ "$USER_ID" = "NOT_FOUND" ]; then
  echo "User $EMAIL not found"
  exit 1
fi

echo "Found user ID: $USER_ID ($EMAIL)"

# Promote to admin
$CURL -X PUT "$DEXAPI_URL/api/v1/admin/users/$USER_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"role":"admin","concurrency":10}' > /dev/null

echo "Promoted to admin"

# Generate API keys for all groups
USER_TOKEN=$($CURL -X POST "$DEXAPI_URL/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"__SKIP__\"}" 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('access_token',''))" 2>/dev/null || echo "")

if [ -z "$USER_TOKEN" ]; then
  echo ""
  echo "API Keys need to be created by the user after login."
  echo "Or run as admin:"
  echo "  The user should log in at $DEXAPI_URL and go to 'API Keys' to create keys."
else
  echo ""
  echo "API Keys:"
  for gid in 1 2 3 4; do
    case $gid in
      1) gname="claude" ;;
      2) gname="openai" ;;
      3) gname="gemini" ;;
      4) gname="antigravity" ;;
    esac
    KEY=$($CURL -X POST "$DEXAPI_URL/api/v1/keys" \
      -H "Authorization: Bearer $USER_TOKEN" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"$gname\",\"group_id\":$gid}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])")
    echo "  $gname: $KEY"
  done
fi

echo ""
echo "Done! User $EMAIL is now admin."
echo "Next: They should log in at $DEXAPI_URL → 账号管理 → 添加账号 → OAuth 授权"
