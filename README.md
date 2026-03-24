# YDAPI

AI API Gateway for Agent-Driven Teams

Multi-account rotation with load balancing across Claude, GPT, Gemini — optimized for AI agent workloads.

## Agent Quick Setup

```bash
# Claude Code
bash scripts/setup-agent.sh claude sk-YOUR_KEY

# Codex CLI / OpenAI
bash scripts/setup-agent.sh openai sk-YOUR_KEY

# Gemini
bash scripts/setup-agent.sh gemini sk-YOUR_KEY
```

Or manually:

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://YOUR_SERVER
export ANTHROPIC_API_KEY=sk-YOUR_KEY

# Codex CLI
export OPENAI_BASE_URL=https://YOUR_SERVER/openai
export OPENAI_API_KEY=sk-YOUR_KEY
```

## Features

- Multi-account load balancing with weighted scheduling
- Sticky sessions for agent context continuity
- Auto-failover on account errors
- 10-minute proxy timeout for long agent tasks
- SSE streaming support
- Real-time ops monitoring
- Daily database backups
- Auto-upgrade from upstream

## Architecture

```
Agent (Claude Code / Codex / Cursor)
  ↓ HTTPS
YDAPI Gateway (OpenResty → sub2api)
  ↓ Load Balance
Account Pool (OAuth / API Key)
  ↓
Upstream AI APIs (Anthropic / OpenAI / Google)
```

## Team Onboarding

1. Team member registers at `https://YOUR_SERVER`
2. Admin promotes to admin: `bash scripts/promote-admin.sh user@email.com`
3. Member adds OAuth accounts via dashboard
4. Member creates API keys
5. Member runs `setup-agent.sh` to configure their tools

## Deployment

```bash
git clone https://github.com/redredchen01/dexapi.git
cd dexapi
cp .env.example .env  # Edit with your settings
bash deploy.sh
```

## Agent-Optimized Config

| Setting | Value | Purpose |
|---|---|---|
| `GATEWAY_MAX_CONNS_PER_HOST` | 4096 | High concurrency |
| `GATEWAY_SCHEDULING_STICKY_SESSION_WAIT_TIMEOUT` | 300s | Long agent sessions |
| `SERVER_H2C_MAX_CONCURRENT_STREAMS` | 200 | Parallel requests |
| `SERVER_MAX_REQUEST_BODY_SIZE` | 512MB | Large context windows |
| `GATEWAY_FORCE_CODEX_CLI` | true | Codex CLI compatibility |

## Management

```bash
docker compose logs -f sub2api   # View logs
docker compose restart sub2api   # Restart
docker compose up -d --force-recreate sub2api  # Apply config changes
```

## Automation

| Schedule | Task |
|---|---|
| Every 5 min | Health monitoring + Telegram alerts |
| Daily 03:00 | PostgreSQL backup (7-day retention) |
| Daily 14:00 | Auto-check upstream updates |
| Weekly Sun 04:00 | Docker image cleanup |

## License

Based on [Sub2API](https://github.com/Wei-Shaw/sub2api) — MIT License
