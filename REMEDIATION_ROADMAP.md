# YDAPI 修復路線圖與實施計劃

**文檔日期:** 2026-03-26
**計劃週期:** 12 週（3 個季度）
**目標:** 解決全部審計發現，達到企業級安全與合規水準

---

## 優先級矩陣

```
    影響度
     高 │ P0 修復 │  P0 修復  │
        │ (立即)  │  (本週)   │
        │────────┼─────────│
    中 │ P1 修復 │ P1/P2   │
        │ (本月)  │ (本季)   │
        │────────┼─────────│
    低 │ P2 修復 │ P2/P3   │
        │ (本季)  │ (下季)   │
        └────────┴─────────┘
          低      中      高
            緊急度
```

---

## Week 1-2: 緊急安全修復 (P0)

### 🔴 Task 1: 啟用 SSRF 防護

**預估工作量:** 2-4 小時
**責任人:** DevOps / Backend Lead
**風險:** 無（向後兼容）

**實施步驟:**

```bash
# 步驟 1: 備份當前配置
cp .env .env.backup-20260326

# 步驟 2: 編輯 .env
cat >> .env << 'EOF'

# ========== SSRF 防護（CRITICAL 修復）==========
SECURITY_URL_ALLOWLIST_ENABLED=true
SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false
SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP=false
EOF

# 步驟 3: 驗證配置被應用
docker-compose up -d --force-recreate ydapi
sleep 10
docker-compose logs ydapi | grep -i "ssrf\|security\|urlallow"

# 步驟 4: 測試防護是否生效
# 應被拒絕 (返回 403/4xx)
curl -X POST http://localhost:8081/v1/messages \
  -H "Authorization: Bearer sk-test" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3","messages":[{"role":"user","content":"http://127.0.0.1:5432"}]}'
```

**驗證清單:**
- [ ] 私有 IP (127.0.0.1, 10.0.0.0/8) 被拒絕
- [ ] 公網 IP 允許
- [ ] 日誌無錯誤

**完成標誌:** 部署成功 + 測試通過

---

### 🔴 Task 2: 配置 JWT Secret

**預估工作量:** 10 分鐘
**責任人:** DevOps

**實施步驟:**

```bash
# 生成安全的 JWT Secret
JWT_SECRET=$(openssl rand -hex 32)
echo "JWT_SECRET=$JWT_SECRET" >> .env

# 驗證配置（不應重新生成）
docker-compose down && docker-compose up -d
sleep 10
docker-compose logs ydapi | grep -i "jwt\|secret"
# 預期: 「Using configured JWT_SECRET」而非「Generating random」
```

**驗證清單:**
- [ ] JWT_SECRET 已設置
- [ ] 容器重啟後 secret 保持一致
- [ ] 現有用戶會話仍然有效

**完成標誌:** JWT_SECRET 配置完成，重啟測試通過

---

### 🔴 Task 3: 設置 Admin 密碼

**預估工作量:** 5 分鐘
**責任人:** DevOps / Security

**實施步驟:**

```bash
# 生成強密碼（不建議使用此例，自行生成）
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '=' | cut -c1-16)
echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> .env

# 或手動設置
# ADMIN_PASSWORD=Y0urStr0ng!AdminP@ssw0rd_2026

docker-compose up -d --force-recreate ydapi

# 檢查日誌是否暴露密碼（不應暴露實際值）
docker-compose logs ydapi | grep -i "admin\|password" | grep -v "REDACTED"
# 預期: 無明文密碼輸出
```

**驗證清單:**
- [ ] Admin 密碼已設置
- [ ] 日誌未暴露明文密碼
- [ ] 首次登錄可使用設置的密碼

**完成標誌:** Admin 密碼安全配置完成

---

## Week 2: 數據隱私與合規 (P1)

### 🟠 Task 4: 發佈隱私政策

**預估工作量:** 4-6 小時
**責任人:** Legal / Product

**交付物:**

```markdown
# 路徑: /docs/PRIVACY_POLICY.md

## 隱私政策

1. 數據收集
   - 登錄郵箱和密碼
   - OAuth token（不存儲密碼）
   - API 使用日誌

2. 數據使用
   - 認證和會話管理
   - 計費和配額檢查
   - 服務改進和分析

3. 數據保留
   - API 使用日誌: 90 天
   - OAuth token: 30 天（失效後刪除）
   - 用戶帳戶: 直到刪除

4. 用戶權利 (GDPR/CCPA)
   - 訪問: GET /api/user/export
   - 刪除: DELETE /api/user/me
   - 糾正: PATCH /api/user/profile
```

**驗證清單:**
- [ ] 政策涵蓋上述 4 個主要部分
- [ ] 發佈在 `/docs` 和網站首頁
- [ ] 法務審核通過

---

### 🟠 Task 5: 實施日誌敏感信息屏蔽

**預估工作量:** 3-4 小時
**責任人:** Backend Lead

**實施代碼示例:**

```go
// internal/pkg/logger/redactor.go
package logger

import (
  "regexp"
  "strings"
)

type LogRedactor struct {
  rules []RedactRule
}

type RedactRule struct {
  pattern string  // regex
  replace string  // replacement (e.g., "sk-****")
}

func NewLogRedactor() *LogRedactor {
  return &LogRedactor{
    rules: []RedactRule{
      {pattern: `sk-[a-zA-Z0-9]+`, replace: "sk-****"},
      {pattern: `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b`, replace: "user@**.com"},
      {pattern: `Bearer [a-zA-Z0-9\-._~+/]+=*`, replace: "Bearer [REDACTED]"},
    },
  }
}

func (r *LogRedactor) Redact(msg string) string {
  for _, rule := range r.rules {
    re := regexp.MustCompile(rule.pattern)
    msg = re.ReplaceAllString(msg, rule.replace)
  }
  return msg
}

// 在日誌初始化時使用
func InitLogger(cfg *config.Config) {
  redactor := NewLogRedactor()
  // 將 redactor 注入到所有日誌調用
  logger.SetRedactor(redactor)
}
```

**驗證清單:**
- [ ] Email 地址屏蔽為 user@**.com
- [ ] OAuth token 屏蔽為 sk-****
- [ ] API Key 屏蔽為 sk-**** (前 4 字元)
- [ ] 日誌測試通過（無敏感信息泄露）

**測試用例:**
```bash
# 測試日誌篩選
ADMIN_EMAIL=admin@example.com \
ADMIN_PASSWORD=SuperSecurePassword123 \
docker-compose up -d

docker-compose logs ydapi | grep -E "@|sk-|Bearer"
# 預期: 全部被屏蔽
```

---

### 🟠 Task 6: 實施自動數據清理

**預估工作量:** 3-4 小時
**責任人:** Backend Lead + DBA

**實施步驟:**

```sql
-- 步驟 1: 添加數據保留配置表
CREATE TABLE IF NOT EXISTS data_retention_policies (
  id SERIAL PRIMARY KEY,
  table_name VARCHAR(255) NOT NULL,
  retention_days INT NOT NULL,
  auto_cleanup BOOLEAN DEFAULT true,
  last_cleanup_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO data_retention_policies (table_name, retention_days) VALUES
  ('usage_logs', 90),
  ('oauth_token_logs', 30),
  ('user_audit_logs', 365);

-- 步驟 2: 添加清理任務定時執行
-- 使用 Kubernetes CronJob 或 PostgreSQL pg_cron
SELECT cron.schedule('cleanup-usage-logs', '0 2 * * *',
  'DELETE FROM usage_logs WHERE created_at < NOW() - INTERVAL ''90 days''');
```

**.env 配置:**
```bash
DATA_RETENTION_ENABLED=true
USAGE_LOGS_RETENTION_DAYS=90
OAUTH_LOGS_RETENTION_DAYS=30
AUDIT_LOGS_RETENTION_DAYS=365
AUTO_CLEANUP_SCHEDULE="0 2 * * *"  # 每天 2am UTC
```

**驗證清單:**
- [ ] 清理任務已創建並運行
- [ ] 驗證 90 天前的日誌已刪除
- [ ] 監控清理任務的執行日誌

---

## Week 3-4: 測試與監控 (P1)

### 🟠 Task 7: 添加 E2E 測試

**預估工作量:** 8-12 小時
**責任人:** QA / Test Engineer

**新增測試清單:**

```go
// internal/integration/gateway_handler_test.go

func TestGatewayHandler_ValidAPIKey(t *testing.T) {
  // 測試: 有效的 API Key → 轉發請求
}

func TestGatewayHandler_InvalidAPIKey(t *testing.T) {
  // 測試: 無效的 API Key → 401
}

func TestGatewayHandler_RateLimitExceeded(t *testing.T) {
  // 測試: 超過限額 → 429
}

func TestGatewayHandler_SSRFPrevention(t *testing.T) {
  // 測試: 私有 IP 被拒絕 (啟用防護後)
}

func TestGatewayHandler_AutoFailover(t *testing.T) {
  // 測試: 帳戶限流 → 自動切換下一個帳戶
}

func TestGatewayHandler_TokenRefresh(t *testing.T) {
  // 測試: Token 過期 → 自動刷新
}

func TestGatewayHandler_StickySession(t *testing.T) {
  // 測試: 同一 conversation_id 使用同一帳戶
}
```

**驗證清單:**
- [ ] 7+ 新 E2E 測試編寫
- [ ] 測試通過率 100%
- [ ] CI/CD 管道集成

---

### 🟠 Task 8: 配置 Prometheus 監控

**預估工作量:** 4-6 小時
**責任人:** DevOps

**Prometheus metrics 公開:**

```go
// internal/pkg/metrics/metrics.go

var (
  // 快取指標
  cacheHitsTotal = prometheus.NewCounterVec(
    prometheus.CounterOpts{
      Name: "ydapi_cache_hits_total",
      Help: "Total cache hits",
    },
    []string{"cache_type"},
  )

  // 背景任務健康度
  backgroundJobStatus = prometheus.NewGaugeVec(
    prometheus.GaugeOpts{
      Name: "ydapi_background_job_status",
      Help: "Background job status (1=healthy, 0=failed)",
    },
    []string{"job_name"},
  )

  // API 延遲
  apiLatencySeconds = prometheus.NewHistogramVec(
    prometheus.HistogramOpts{
      Name: "ydapi_api_latency_seconds",
      Help: "API request latency",
      Buckets: []float64{0.01, 0.05, 0.1, 0.5, 1, 5},
    },
    []string{"endpoint"},
  )
)
```

**Prometheus 抓取配置:**
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ydapi'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
```

**Grafana 儀表板:**
- 快取命中率趨勢圖
- 背景任務健康度狀態
- API P95/P99 延遲
- 錯誤率分布

**驗證清單:**
- [ ] /metrics 端點公開
- [ ] Prometheus 成功抓取指標
- [ ] Grafana 儀表板已創建

---

## Week 4-8: 功能完善 (P1/P2)

### 🟠 Task 9: 實施用戶數據導出

**預估工作量:** 2-3 小時
**責任人:** Backend Engineer

**API 端點:**

```go
// GET /api/user/export?format=json
// 返回用戶的所有個人數據，包括:
// - 帳戶信息
// - API Keys 列表
// - OAuth 綁定信息
// - 使用歷史
// - 日期範圍內的請求日誌

func (h *UserHandler) ExportUserData(c *gin.Context) {
  userID := c.GetInt64("user_id")
  format := c.DefaultQuery("format", "json") // json 或 csv

  data := h.userService.ExportUserData(c, userID)

  // 返回文件或 JSON
  c.Header("Content-Disposition", "attachment; filename=user_data.json")
  c.JSON(200, data)
}
```

**驗證清單:**
- [ ] API 端點實現
- [ ] 返回完整的用戶數據
- [ ] 支持 JSON 和 CSV 格式
- [ ] 日期範圍篩選

---

### 🟠 Task 10: 實施完全刪除帳戶

**預估工作量:** 3-4 小時
**責任人:** Backend Engineer + DBA

**API 端點:**

```go
// DELETE /api/user/me?confirm=true
// 刪除用戶的所有數據，包括:
// - 用戶帳戶
// - 所有 API Keys
// - 所有綁定的 OAuth 帳戶
// - 所有使用日誌

func (h *UserHandler) DeleteAccount(c *gin.Context) {
  userID := c.GetInt64("user_id")
  confirm := c.Query("confirm")

  if confirm != "true" {
    c.JSON(400, gin.H{"error": "confirm=true required"})
    return
  }

  err := h.userService.DeleteAccountCompletely(c, userID)
  if err != nil {
    c.JSON(500, gin.H{"error": err.Error()})
    return
  }

  c.JSON(200, gin.H{"message": "account deleted"})
}
```

**刪除流程:**
```sql
BEGIN TRANSACTION;
  DELETE FROM usage_logs WHERE api_key_id IN (...);
  DELETE FROM api_keys WHERE user_id = $1;
  DELETE FROM oauth_accounts WHERE user_id = $1;
  DELETE FROM users WHERE id = $1;
COMMIT;
```

**驗證清單:**
- [ ] API 端點實現
- [ ] 級聯刪除所有相關數據
- [ ] 審計日誌記錄刪除操作
- [ ] 用戶登出後無法訪問

---

## Week 8-12: 合規性驗證 (P2)

### 🟡 Task 11: 第三方 DPA 簽署

**預估工作量:** 2-4 週（取決於律師）
**責任人:** Legal / Procurement

**需簽署的 DPA:**
- [ ] Anthropic (Claude API)
- [ ] OpenAI (ChatGPT API)
- [ ] Google (Gemini API)
- [ ] PostgreSQL 託管提供商（如使用 RDS/Cloud SQL）
- [ ] Redis 託管提供商

**合規性檢查:**
- [ ] DPA 涵蓋數據處理目的
- [ ] 標準化合同條款 (SCCs) 用於跨國轉移
- [ ] 數據洩露通知程序
- [ ] 子處理器名單

---

### 🟡 Task 12: SOC 2 合規性準備 (可選)

**預估工作量:** 8-12 週
**責任人:** Security / Compliance

**SOC 2 Type II 要求:**
- [ ] 訪問控制 (AA)
- [ ] 數據安全 (S)
- [ ] 可用性 (A)
- [ ] 處理完整性 (PI)
- [ ] 隱私 (C)

**先決條件:**
- [ ] 安全政策文檔化
- [ ] 日誌記錄和監控
- [ ] 事件響應計劃
- [ ] 變更管理流程
- [ ] 員工背景調查

---

## 交付物清單

### 文檔
- [x] ARCHITECTURE.md — 系統設計文檔
- [x] SECURITY_AUDIT.md — 安全審計報告
- [x] PERFORMANCE_AND_COMPLIANCE_AUDIT.md — 性能與合規性審計
- [ ] PRIVACY_POLICY.md — 隱私政策
- [ ] DATA_RETENTION_POLICY.md — 數據保留政策
- [ ] INCIDENT_RESPONSE_PLAN.md — 事件響應計劃
- [ ] DEPLOYMENT_CHECKLIST.md — 部署清單

### 代碼變更
- [ ] SSRF 防護配置
- [ ] JWT Secret 配置
- [ ] Admin 密碼配置
- [ ] 日誌敏感信息屏蔽
- [ ] 自動數據清理任務
- [ ] Prometheus metrics
- [ ] 用戶數據導出 API
- [ ] 帳戶完全刪除 API
- [ ] E2E 測試 (7+)

### 配置變更
- [ ] .env 更新（安全設置）
- [ ] docker-compose.yml 更新（監控容器）
- [ ] Kubernetes 部署文件 (若使用 K8s)

---

## 進度追蹤

### 計分機制

```
Week  1: 60% (SSRF + JWT + Admin 密碼 完成)
Week  2: 75% (隱私政策 + 日誌屏蔽 + 數據清理)
Week  4: 85% (E2E 測試 + Prometheus 監控)
Week  8: 95% (用戶導出 + 帳戶刪除 + DPA)
Week 12: 100% (全部完成，SOC2 準備)
```

### 關鍵里程碑

- **3 月 27 日 (Week 1):** P0 安全修復完成 ✅ 目標
- **4 月 3 日 (Week 2):** 隱私政策發佈 ✅ 目標
- **4 月 10 日 (Week 3):** E2E 測試合併 ✅ 目標
- **5 月 1 日 (Week 5):** 功能實施完成 ✅ 目標
- **5 月 30 日 (Week 9):** SOC 2 審計啟動 ✅ 目標

---

## 風險與緩解

| 風險 | 概率 | 影響 | 緩解 |
|------|------|------|------|
| 上游 API 集成變更 | 中 | 高 | 定期檢查 API 變更日誌 |
| 法務審批延遲 | 中 | 中 | 提前準備草稿 |
| 性能退化 | 低 | 中 | 壓力測試驗證 |
| 用戶反抗刪除帳戶 | 低 | 低 | 完整的數據導出流程 |

---

## 資源需求

| 角色 | 周數 | 主要任務 |
|------|------|--------|
| DevOps | 3-4 | 配置管理、部署、監控 |
| Backend Engineer | 8-12 | 代碼實現、API、數據處理 |
| QA / Test Engineer | 4-6 | E2E 測試、驗證 |
| DBA | 2-3 | 數據庫配置、清理任務 |
| Security / Compliance | 4-8 | 隱私政策、合規性驗證、DPA |
| Legal | 2-4 | 隱私政策審核、合同簽署 |

---

## 成功標準

✅ **所有 P0 修復完成且驗證通過**
✅ **隱私政策發佈，用戶可訪問**
✅ **數據導出與刪除 API 實現並測試**
✅ **SSRF 防護啟用且驗證無誤報**
✅ **E2E 測試覆蓋率達到 >80%**
✅ **Prometheus 監控運行正常**
✅ **第三方 DPA 已簽署**
✅ **無未解決的 CRITICAL 級別問題**

---

**文檔版本:** 1.0
**最後更新:** 2026-03-26
**下次評估:** 2026-06-26
