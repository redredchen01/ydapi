#!/bin/bash
# YDAPI 安全修復腳本
# 用途: 自動應用 P0 安全修復 (SSRF、JWT Secret、Admin 密碼)
# 使用: bash apply-security-patches.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/.env"

echo "════════════════════════════════════════════════════════"
echo "YDAPI 安全修復腳本 (P0 - CRITICAL)"
echo "════════════════════════════════════════════════════════"
echo ""

# 檢查 .env 文件存在
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 錯誤: .env 文件不存在"
  echo "請先執行: cp .env.example .env"
  exit 1
fi

# 備份原始文件
BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$ENV_FILE" "$BACKUP_FILE"
echo "✓ 備份已創建: $BACKUP_FILE"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 修復 1: 啟用 SSRF 防護
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "⚙️ 修復 1/3: 啟用 SSRF 防護..."

# 檢查目前狀態
if grep -q "^SECURITY_URL_ALLOWLIST_ENABLED=false" "$ENV_FILE"; then
  sed -i '' 's/^SECURITY_URL_ALLOWLIST_ENABLED=false/SECURITY_URL_ALLOWLIST_ENABLED=true/' "$ENV_FILE"
  echo "  ✓ 已啟用 SECURITY_URL_ALLOWLIST_ENABLED"
elif grep -q "^SECURITY_URL_ALLOWLIST_ENABLED=true" "$ENV_FILE"; then
  echo "  ✓ SECURITY_URL_ALLOWLIST_ENABLED 已啟用（跳過）"
else
  echo "  ⚠️ 找不到 SECURITY_URL_ALLOWLIST_ENABLED，跳過"
fi

# 禁用私有主機訪問
if grep -q "^SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=true" "$ENV_FILE"; then
  sed -i '' 's/^SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=true/SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false/' "$ENV_FILE"
  echo "  ✓ 已禁用 SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS"
fi

# 禁用不安全的 HTTP
if grep -q "^SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=true" "$ENV_FILE"; then
  sed -i '' 's/^SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=true/SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false/' "$ENV_FILE"
  echo "  ✓ 已禁用 SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 修復 2: 配置 JWT Secret
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "⚙️ 修復 2/3: 配置 JWT Secret..."

# 檢查是否已配置
CURRENT_JWT=$(grep "^JWT_SECRET=" "$ENV_FILE" | cut -d'=' -f2)

if [ -z "$CURRENT_JWT" ]; then
  # 生成新的 JWT Secret
  JWT_SECRET=$(openssl rand -hex 32)

  # 檢查是否需要添加或更新
  if grep -q "^JWT_SECRET=$" "$ENV_FILE"; then
    sed -i '' "s/^JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" "$ENV_FILE"
    echo "  ✓ JWT_SECRET 已生成並設置"
    echo "     值: $JWT_SECRET (已儲存在 .env)"
  fi
else
  echo "  ✓ JWT_SECRET 已存在（使用現有值）"
  echo "     值: $(echo $CURRENT_JWT | head -c 16)... (前 16 字符)"
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 修復 3: 設置 Admin 密碼
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "⚙️ 修復 3/3: 設置 Admin 密碼..."

CURRENT_ADMIN_PASS=$(grep "^ADMIN_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)

if [ -z "$CURRENT_ADMIN_PASS" ]; then
  echo ""
  echo "⚠️ 警告: ADMIN_PASSWORD 為空"
  echo ""
  echo "選項 A: 自動生成強密碼"
  echo "  bash apply-security-patches.sh --auto-admin-password"
  echo ""
  echo "選項 B: 手動設置 (推薦)"
  echo "  1. 編輯 .env 文件"
  echo "  2. 設置 ADMIN_PASSWORD=YourSecurePassword123!"
  echo "  3. 保存並運行: bash apply-security-patches.sh"
  echo ""

  # 檢查是否有 --auto-admin-password 標誌
  if [[ "$*" == *"--auto-admin-password"* ]]; then
    ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '=' | cut -c1-16)
    sed -i '' "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$ADMIN_PASSWORD/" "$ENV_FILE"
    echo "  ✓ Admin 密碼已生成並設置"
    echo "     值: $ADMIN_PASSWORD (已儲存在 .env)"
  else
    echo "❌ 跳過 Admin 密碼設置（請手動配置或使用 --auto-admin-password）"
    exit 1
  fi
else
  echo "  ✓ ADMIN_PASSWORD 已設置（使用現有值）"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ 所有安全修復已應用！"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 後續步驟:"
echo ""
echo "1️⃣  重新部署容器:"
echo "    docker-compose down"
echo "    docker-compose up -d --force-recreate ydapi"
echo ""
echo "2️⃣  等待啟動完成:"
echo "    docker-compose logs -f ydapi"
echo ""
echo "3️⃣  驗證 SSRF 防護:"
echo "    # 應被拒絕 (403 或 error)"
echo "    curl -X POST http://localhost:8081/v1/messages \\"
echo "      -H 'Authorization: Bearer sk-test' \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"model\":\"claude-3\"}'"
echo ""
echo "4️⃣  檢查日誌是否暴露敏感信息:"
echo "    docker-compose logs ydapi | grep -i 'password\|secret\|token'"
echo "    # 不應看到明文密碼"
echo ""
echo "🔐 備份位置: $BACKUP_FILE"
echo ""
