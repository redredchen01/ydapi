# DexAPI

AI API Gateway for Team — powered by [Sub2API](https://github.com/Wei-Shaw/sub2api)

Multi-account rotation with load balancing across Claude, GPT, Gemini, and Antigravity.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/redredchen01/dexapi.git
cd dexapi

# 2. Configure
cp .env.example .env
# Edit .env with your settings

# 3. Deploy
bash deploy.sh
```

## Features

- Multi-platform support (Claude / GPT / Gemini / Antigravity)
- Automatic load balancing across accounts
- Sticky session support
- Per-account concurrency control
- Admin dashboard
- Backend mode (team-only, no public registration)

## Architecture

```
Client → DexAPI Gateway → Account Pool → Upstream AI APIs
              ↓
        Load Balancer
        (weighted random + sticky session)
```

## Configuration

| Env Variable | Description | Default |
|---|---|---|
| `SERVER_PORT` | Service port | `8080` |
| `POSTGRES_PASSWORD` | DB password | (required) |
| `JWT_SECRET` | JWT signing key | (auto-generated) |
| `TOTP_ENCRYPTION_KEY` | 2FA encryption key | (auto-generated) |
| `ADMIN_EMAIL` | Admin login email | `admin@sub2api.local` |
| `ADMIN_PASSWORD` | Admin password | (auto-generated, check logs) |
| `TZ` | Timezone | `Asia/Shanghai` |

See `.env.example` for all available options.

## Management

```bash
# View logs
docker compose logs -f sub2api

# Restart
docker compose restart sub2api

# Upgrade
docker compose pull && docker compose up -d

# Stop
docker compose down
```

## License

Based on [Sub2API](https://github.com/Wei-Shaw/sub2api) — MIT License
