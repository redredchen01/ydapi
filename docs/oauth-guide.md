# YDAPI OAuth 授权指南

## 概览

YDAPI 通过 OAuth 将你的 AI 订阅帐号（Claude Pro / ChatGPT Plus / Gemini Advanced）转换为 API 额度。

```
你的订阅帐号 → OAuth 授权 → YDAPI 获取 Token → API 可用
```

## 使用流程

### 1. 注册 YDAPI

访问 https://YOUR_SERVER → 注册帐号 → 等待管理员升级为 Admin

### 2. 添加 OAuth 帐号

登入后台 → 账号管理 → 添加账号 → 选择平台和 OAuth 类型

---

## 各平台 OAuth 设置

### Claude (Anthropic)

**帐号类型：** OAuth
**需要：** Claude Pro / Team / Enterprise 订阅

添加帐号时：
1. 平台选 `Anthropic`
2. 类型选 `OAuth`
3. 填入 session key（从浏览器获取）

**获取 Session Key：**
1. 登入 https://claude.ai
2. 打开浏览器 DevTools (F12) → Application → Cookies
3. 复制 `sessionKey` 的值

---

### ChatGPT / OpenAI

**帐号类型：** OAuth
**需要：** ChatGPT Plus / Team / Enterprise 订阅

添加帐号时：
1. 平台选 `OpenAI`
2. 类型选 `OAuth`
3. 填入 access_token 和 refresh_token

**获取方式：**
1. 登入 https://chatgpt.com
2. 访问 https://chatgpt.com/api/auth/session
3. 复制 `accessToken` 值

---

### Gemini (Google)

**帐号类型：** OAuth
**需要：** Gemini Advanced / Google One AI Premium 订阅

两种模式：
- **Code Assist OAuth** — 需要 GCP 项目，使用内建客户端
- **AI Studio OAuth** — 需要自建 OAuth Client

详细设置参考后台「添加账号」页面的引导。

---

### Antigravity

**帐号类型：** OAuth
**需要：** Antigravity 订阅

添加帐号时选 `Antigravity` 平台 + `OAuth` 类型，按引导完成授权。

---

## 3. 生成 API Key

账号添加成功后：
1. 进入「API 密钥」页面
2. 点击「创建密钥」
3. 选择分组（对应平台）
4. 复制 API Key

## 4. 配置 Agent

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://YOUR_SERVER
export ANTHROPIC_API_KEY=sk-YOUR_KEY

# Codex CLI
export OPENAI_BASE_URL=https://YOUR_SERVER/openai
export OPENAI_API_KEY=sk-YOUR_KEY
```

## 常见问题

**Q: Token 多久过期？**
A: 各平台不同。OpenAI access_token 约 10 天，Claude session key 较长。系统会在账号管理页显示过期时间。

**Q: 一个订阅帐号能给多少 API 额度？**
A: 取决于你的订阅方案。Claude Pro 有独立的 token 限制，ChatGPT Plus 有 GPT-4 的使用上限。

**Q: 多个帐号有什么好处？**
A: 分散限流压力。一个帐号被限流时自动切换到其他帐号，不影响 Agent 工作。
