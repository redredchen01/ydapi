#!/bin/bash
# YDAPI 安全修復驗證腳本
# 用途: 驗證所有 P0 安全修復已正確應用
# 使用: bash verify-security-fixes.sh

set -e

ENV_FILE=".env"

echo "════════════════════════════════════════════════════════"
echo "YDAPI 安全修復驗證"
echo "════════════════════════════════════════════════════════"
echo ""

# 檢查 .env 文件
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 錯誤: .env 文件不存在"
  exit 1
fi

PASS=0
FAIL=0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 驗證 1: SSRF 防護已啟用
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔍 驗證 1: SSRF 防護設置"

if grep -q "^SECURITY_URL_ALLOWLIST_ENABLED=true" "$ENV_FILE"; then
  echo "  ✅ PASS: SECURITY_URL_ALLOWLIST_ENABLED=true"
  ((PASS++))
else
  echo "  ❌ FAIL: SECURITY_URL_ALLOWLIST_ENABLED 應為 true"
  ((FAIL++))
fi

if grep -q "^SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false" "$ENV_FILE"; then
  echo "  ✅ PASS: SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false"
  ((PASS++))
else
  echo "  ❌ FAIL: ALLOW_PRIVATE_HOSTS 應為 false"
  ((FAIL++))
fi

if grep -q "^SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false" "$ENV_FILE"; then
  echo "  ✅ PASS: SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false"
  ((PASS++))
else
  echo "  ❌ FAIL: ALLOW_INSECURE_HTTP 應為 false"
  ((FAIL++))
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 驗證 2: JWT Secret 已配置
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔍 驗證 2: JWT Secret"

JWT_SECRET=$(grep "^JWT_SECRET=" "$ENV_FILE" | cut -d'=' -f2)

if [ -n "$JWT_SECRET" ] && [ ${#JWT_SECRET} -ge 32 ]; then
  echo "  ✅ PASS: JWT_SECRET 已配置 (長度: ${#JWT_SECRET})"
  ((PASS++))
else
  echo "  ❌ FAIL: JWT_SECRET 未配置或太短"
  ((FAIL++))
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 驗證 3: Admin 密碼已配置
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔍 驗證 3: Admin 密碼"

ADMIN_PASSWORD=$(grep "^ADMIN_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)

if [ -n "$ADMIN_PASSWORD" ] && [ ${#ADMIN_PASSWORD} -ge 8 ]; then
  echo "  ✅ PASS: ADMIN_PASSWORD 已配置 (長度: ${#ADMIN_PASSWORD})"
  ((PASS++))
else
  echo "  ❌ FAIL: ADMIN_PASSWORD 未配置或太短"
  ((FAIL++))
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 摘要
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "════════════════════════════════════════════════════════"
echo "驗證結果: $PASS 通過, $FAIL 失敗"
echo "════════════════════════════════════════════════════════"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "✅ 所有安全修復已正確應用！"
  echo ""
  echo "📋 後續步驟:"
  echo "  1. 部署: docker-compose up -d --force-recreate ydapi"
  echo "  2. 驗證: docker-compose logs -f ydapi | head -50"
  echo ""
  exit 0
else
  echo "❌ 某些驗證失敗，請檢查 .env 文件"
  exit 1
fi
