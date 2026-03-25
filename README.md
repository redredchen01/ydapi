# YDAPI

Turn multiple free OAuth accounts into one API key.

Bind your free Claude / GPT / Gemini OAuth subscriptions, YDAPI pools them behind a single API key with automatic rotation and load balancing.

## How It Works

```
You bind N free OAuth accounts (Claude Pro, ChatGPT Plus, Gemini...)
  ↓
YDAPI pools them together
  ↓
You get 1 API key
  ↓
Your agents use it like a normal API — YDAPI auto-rotates accounts behind the scenes
```

## Quick Start

```bash
git clone https://github.com/redredchen01/ydapi.git
cd ydapi
cp .env.example .env  # Edit with your settings
bash deploy.sh
```

Then:
1. Login at `https://YOUR_SERVER`
2. Add your OAuth accounts (Claude / GPT / Gemini)
3. Create an API key
4. Point your agent at YDAPI:

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://YOUR_SERVER
export ANTHROPIC_API_KEY=sk-YOUR_KEY

# Codex CLI / OpenAI
export OPENAI_BASE_URL=https://YOUR_SERVER/openai
export OPENAI_API_KEY=sk-YOUR_KEY
```

Or use the setup script:

```bash
bash scripts/setup-agent.sh claude sk-YOUR_KEY
bash scripts/setup-agent.sh openai sk-YOUR_KEY
bash scripts/setup-agent.sh gemini sk-YOUR_KEY
```

## Features

- **OAuth account pooling** — bind multiple free accounts, use as one
- **Auto-rotation** — requests spread across accounts with load balancing
- **Auto-failover** — if one account hits a limit, seamlessly switch to the next
- **Sticky sessions** — agent conversations stay on the same account
- **SSE streaming** — full streaming support for all providers
- **Real-time monitoring** — see account status, usage, and errors live

## Architecture

```
Agent (Claude Code / Codex / Cursor)
  ↓ HTTPS
YDAPI Gateway
  ↓ Auto-Rotate
OAuth Account Pool (Claude Pro / ChatGPT Plus / Gemini)
  ↓
Upstream AI APIs (Anthropic / OpenAI / Google)
```

## Management

```bash
docker compose logs -f ydapi   # View logs
docker compose restart ydapi   # Restart
docker compose up -d --force-recreate ydapi  # Apply config changes
```

## License

MIT License
