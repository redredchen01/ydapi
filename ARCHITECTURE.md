# YDAPI 系統架構

## 概述

YDAPI 是一個 **OAuth Account Pooling 網關**，聚合多個免費 AI API 帳戶（Claude、ChatGPT、Gemini）為單一統一的 API Key。

### 核心功能
- **帳戶池化** — 綁定多個 OAuth 帳戶，自動負載均衡
- **自動輪換** — 請求分散到不同帳戶，避免單點限流
- **自動故障轉移** — 帳戶限流或失敗時自動切換
- **粘性會話** — 同一對話保持在同一帳戶以保證上下文
- **流式轉發** — 支持 SSE / WebSocket 流式響應
- **監控儀表板** — 實時觀察帳戶狀態、使用量、錯誤

---

## 整體架構

```
┌─────────────────────────────────────────────────────────────────┐
│ Client (Claude Code / Codex / Cursor / Custom Agent)             │
│ POST /v1/messages                                                │
│ Authorization: Bearer sk-xxx                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTPS
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   YDAPI Gateway (Go + Gin)                        │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ HTTP Handlers                                                 │ │
│ │  - Gateway Handler (转发请求)                               │ │
│ │  - Auth Handler (登录/注册)                                 │ │
│ │  - API Key Handler (key 管理)                               │ │
│ │  - Admin Handler (管理员)                                   │ │
│ └──────────┬───────────────────────────────────────────────────┘ │
│            │                                                       │
│ ┌──────────▼───────────────────────────────────────────────────┐ │
│ │ Service Layer                                                 │ │
│ │  - Gateway Service (请求路由、账号选择、转发逻辑)           │ │
│ │  - OAuth Service (token 刷新、账号认证)                     │ │
│ │  - Token Provider (各平台 token 管理)                       │ │
│ │  - Auth Service (用户注册、登录)                            │ │
│ │  - API Key Service (key 生成、验证、限流)                  │ │
│ │  - Account Service (账号绑定、管理)                         │ │
│ │  - Proxy Service (代理服务配置)                             │ │
│ │  - Rate Limiter Service (请求速率限制)                      │ │
│ │  - Usage Service (使用量统计、计费)                         │ │
│ └──────────┬───────────────────────────────────────────────────┘ │
│            │                                                       │
│ ┌──────────▼───────────────────────────────────────────────────┐ │
│ │ Repository Layer (Data Access)                                │ │
│ │  - API Key Repo (key 存储/查询)                             │ │
│ │  - Account Repo (账号存储)                                  │ │
│ │  - User Repo (用户数据)                                     │ │
│ │  - Usage Log Repo (使用日志)                                │ │
│ │  - Token Cache (Redis)                                        │ │
│ │  - HTTP Upstream (HTTP 客户端池)                            │ │
│ └──────────┬───────────────────────────────────────────────────┘ │
│            │                                                       │
│ ┌──────────▼───────────────────────────────────────────────────┐ │
│ │ Infrastructure                                                │ │
│ │  - PostgreSQL (主数据库)                                     │ │
│ │  - Redis (token cache、sessions、rate limit)               │ │
│ │  - HTTP Client Pools (连接复用)                             │ │
│ └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    Claude API      OpenAI API      Gemini API
    (Anthropic)     (OpenAI)        (Google)
```

---

## 主要组件

### 1. Gateway Handler (HTTP Entry Point)

**职责：** 接收客户端请求，验证 API Key，路由转发

**关键路由：**
```
POST   /v1/messages              → 转发至 Claude 或兼容 API
POST   /openai/*                 → OpenAI API 兼容端点
GET    /health                   → 健康检查
GET    /v1/models                → 列出支持的模型
WebSocket /ws/*                  → WebSocket 连接（实验性）
```

**请求流程：**
```
1. 接收请求 (Content-Type: application/json)
2. 验证 Authorization 头 (Bearer sk-xxx)
3. 查询数据库 → API Key 实体
4. 调用 Gateway Service → 选择账号 + 构建上游请求
5. 转发至上游 API (Claude/OpenAI/Gemini)
6. 流式返回响应体 (SSE)
```

**安全检查：**
- ✓ API Key 格式验证
- ✓ Rate Limit (API Key 级别)
- ✗ **SSRF 防护未启用** (see Finding #1)

---

### 2. Gateway Service (业务逻辑核心)

**职责：** 账号选择算法、令牌管理、请求构建、错误处理

**核心算法：**
```
SelectAccount(apiKey, request) {
  1. 获取用户绑定的所有账号
  2. 过滤活跃/有效的账号（token 未过期）
  3. 应用粘性会话：同一 conversation_id 用同一账号
  4. 负载均衡：轮询或最少使用计数
  5. 获取该账号的有效 Token
  6. 返回 (Account, Token)
}
```

**令牌管理：**
- 缓存: Redis (TTL = token 过期时间 - 缓冲 5 分钟)
- 刷新: 后台定时任务 (TokenRefresher)
- 故障转移: Token 过期 → 自动刷新或切换账号

**请求转发逻辑：**
```go
// Pseudo-code
func ForwardRequest(ctx, apiKey, body) {
  account := SelectAccount(apiKey)
  token := GetToken(account)  // 优先使用缓存

  upstreamReq := BuildRequest(body, token)

  // 重试逻辑
  for attempt := 0; attempt < maxRetries; attempt++ {
    resp, err := httpClient.Do(upstreamReq)
    if err == TokenExpired {
      token = RefreshToken(account)
      continue
    }
    if err == RateLimited {
      account = SelectNextAccount()
      continue
    }
    return resp
  }
}
```

**代理配置：** 支持通过 HTTP/SOCKS5 代理转发请求（用于突破地理限制）

---

### 3. OAuth & Token Management

**支持的 OAuth 提供商：**
| 提供商 | 认证方式 | Token 刷新 | 备注 |
|--------|---------|-----------|------|
| Claude (Anthropic) | OAuth 2.0 | 自动 | 需要 Claude Pro |
| ChatGPT (OpenAI) | OAuth 2.0 | Cookie-based | ChatGPT Plus |
| Gemini (Google) | OAuth 2.0 | 自动 | Google One |
| Sora (OpenAI) | OAuth 2.0 | 自动 | 实验性 |

**Token 缓存策略：**
```
Redis Hash: account:{accountID}:token
  - value: JWT token
  - ttl: min(tokenExpiry - 5min, 1h)

缓存失效:
  - 显式过期 (accountID 删除时)
  - TTL 过期
  - Token 使用失败 (401) 时
```

---

### 4. Rate Limiting & Quota

**多层限流：**
| 层级 | 限制维度 | 周期 | 用途 |
|------|---------|------|------|
| API Key | `api_key_id` | 5h / 1d / 7d | 用户配额 |
| Account | `account_id` | 实时 | 平台限制 |
| IP | 源 IP | 1h | DDoS 防护 |

**实现方式：**
- **Token Bucket** (API Key): Redis 计数器 + 窗口滑动
- **Leaky Bucket** (Account): 平台原生限流 (429 响应)
- **IP 限流**: Middleware (可选)

---

### 5. 数据库模型

**核心实体：**
```sql
-- 用户账户
users {
  id, email, password_hash, created_at, ...
}

-- API Keys (客户端凭证)
api_keys {
  id, user_id, key, name, quota_used, quota_limit,
  rate_limit_5h, rate_limit_1d, rate_limit_7d,
  created_at, last_used_at, ...
}

-- 绑定的 OAuth 账号 (Claude/ChatGPT/Gemini)
accounts {
  id, user_id, platform, oauth_token, refresh_token,
  token_expires_at, account_name, ...
}

-- 使用日志 (计费用)
usage_logs {
  id, api_key_id, account_id, model, tokens_used,
  cost_usd, created_at, ...
}
```

---

## 数据流

### 请求处理流程

```
Client Request
     │
     ▼
┌─────────────────────────────────────────────┐
│ 1. Parse & Validate                         │
│    - 提取 Authorization 头                  │
│    - 验证 JSON 格式                         │
│    - 检查 Content-Type                      │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 2. API Key Auth                             │
│    - 查询数据库: api_keys.key = sk-xxx     │
│    - 检查是否已删除/禁用                    │
│    - 验证所有权 (user_id match)            │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 3. Account Selection (算法核心)             │
│    - 获取用户绑定的账号列表                │
│    - 过滤有效账号 (token 未过期)           │
│    - 粘性会话检查 (conversation_id)        │
│    - 负载均衡选择                          │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 4. Token Acquisition                        │
│    - Redis 查询缓存                         │
│    - 如不存在 → 刷新 token                  │
│    - 如失败 → 切换账号重试                  │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 5. Rate Limit Check                         │
│    - API Key 5h/1d/7d 限额                 │
│    - 账号平台限制 (429 预检查)             │
│    - 返回 429 if 超限                       │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 6. Upstream Request Build                   │
│    - 注入 Authorization 头 (account token) │
│    - 修改 User-Agent (如需)                │
│    - 设置超时和代理                        │
│    - 应用 TLS Fingerprint (反侦测)         │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 7. HTTP Forwarding                          │
│    - 通过 HTTP Client Pool 发送            │
│    - 支持代理转发                          │
│    - 记录请求元数据到 Ops Log              │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 8. Response Streaming                       │
│    - 接收上游响应 (通常是 SSE)            │
│    - 流式转发给客户端                      │
│    - 计算 token 使用量                      │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ 9. Usage Logging (后台异步)                │
│    - 插入 usage_logs 记录                   │
│    - 更新 api_keys.quota_used              │
│    - 更新 rate limit 窗口                   │
└─────────────────────────────────────────────┘
```

---

## 并发与性能优化

### 连接池管理
```go
httpUpstreamService {
  clients: map[string]*upstreamClientEntry  // 按 (proxy, account, poolKey) 缓存

  // LRU 淘汰策略
  - 最大缓存数: 5000 客户端
  - 空闲 TTL: 15 分钟
  - 活跃请求计数: 防止中断进行中的请求
}
```

### 缓存层次
| 缓存 | 位置 | TTL | 用途 |
|------|------|-----|------|
| Token Cache | Redis | token 生命周期 | OAuth token |
| API Key Cache | Redis + 本地 | 1h | Key 元数据 |
| Account Cache | 本地内存 | 5m | 账号列表 |

### 异步任务
- **Token Refresher** — 后台定时刷新将过期的 token
- **Usage Logger** — 异步写入使用日志避免阻塞
- **Account Scheduler** — 定时检查账号状态

---

## 安全边界

### 信任边界

```
┌──────────────────────────────────────────────┐
│ UNTRUSTED (Internet)                         │
│  - 客户端请求 (可能带恶意输入)              │
│  - 上游 API 响应 (信任但可能被篡改)         │
└────────────┬─────────────────────────────────┘
             │ HTTPS + API Key 验证
             ▼
┌──────────────────────────────────────────────┐
│ TRUSTED (YDAPI Process)                      │
│  - 数据库连接 (本地 PostgreSQL)             │
│  - Redis 连接 (本地)                        │
│  - OAuth token (来自平台)                    │
└──────────────────────────────────────────────┘
```

### 关键安全检查

| 检查点 | 实现状态 | 风险 |
|--------|---------|------|
| API Key 验证 | ✓ 实现 | 低 |
| Rate Limiting | ✓ 实现 | 低 |
| SSRF 防护 | ✗ 未启用 | **🔴 CRITICAL** |
| JWT Secret 固定 | ✗ 未配置 | **🔴 CRITICAL** |
| Admin 密码管理 | ✗ 自动生成 | **🔴 CRITICAL** |
| SQL Injection | ✓ 使用 ORM | 低 |
| XSS (UI) | ✓ React 转义 | 低 |
| Token 过期检查 | ✓ 实现 | 低 |

---

## 扩展性考量

### 水平扩展
- **无状态设计** — 多实例间无亲和性要求
- **Redis 共享** — 多实例共享 token cache + session
- **数据库连接池** — 每实例 256 连接

### 垂直扩展
- **HTTP/2 多路复用** — 单连接支持多并发请求
- **Connection Pool** — 默认 240 max 连接 / 主机
- **异步任务队列** — 使用 goroutines，可配置 worker 池

### 监控指标
```
- Gateway: 请求延迟 P50/P99, 成功率, 错误分布
- Accounts: 活跃比例, token 刷新失败率, 使用量分布
- Database: 连接池状态, 查询延迟, 慢查询
- Redis: 键过期率, 缓存命中率, 内存使用
```

---

## 已知限制 & 未来工作

### 当前限制
1. **SSRF 防护未启用** (P0 修复)
2. **粘性会话** 基于 conversation_id，不支持其他维度
3. **WebSocket** 仅支持部分提供商
4. **账号切换延迟** ≈ 100-500ms (OAuth token 刷新)

### 开发路线图
- [ ] 启用 SSRF 防护并白名单化上游 API IP
- [ ] 实现 WebSocket 完整支持
- [ ] 添加账号优先级/权重配置
- [ ] 支持私有部署模式 (移除 SaaS 功能)
- [ ] Kubernetes Operator

---

## 参考资源

- **代码结构** — `sub2api/backend/internal/{handler,service,repository}`
- **配置** — `docker-compose.yml`, `.env.example`
- **安全审计** — `/path/to/audit-report.md`
- **测试覆盖** — `*_test.go` 文件遍布各层

---

**最后更新:** 2026-03-26
**架构设计者:** YDAPI Team
**维护者:** DevOps / Infrastructure Team
