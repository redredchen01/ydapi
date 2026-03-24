# Multi-VPS Deployment

DexAPI supports deploying multiple instances sharing the same database for high availability.

## Architecture

```
                    ┌─── VPS 1 (Primary) ───┐
Client → DNS/LB →  │  DexAPI + PostgreSQL   │
                    │  + Redis              │
                    └───────────────────────┘
                    ┌─── VPS 2 (Replica) ───┐
                →   │  DexAPI               │
                    │  (connects to VPS1 DB) │
                    └───────────────────────┘
```

## Setup VPS 2 (Replica)

1. Copy `docker-compose.yml` and `.env` to VPS 2

2. Edit `.env` on VPS 2 — point to VPS 1's database:
```env
# Remove local postgres/redis, use VPS 1's
DATABASE_HOST=<VPS1_IP>
DATABASE_PORT=5432
REDIS_HOST=<VPS1_IP>
REDIS_PORT=6379
```

3. Use a minimal compose file (no postgres/redis):
```yaml
services:
  sub2api:
    image: dexapi:latest
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - DATABASE_HOST=${DATABASE_HOST}
      - DATABASE_PORT=${DATABASE_PORT}
      - DATABASE_USER=${POSTGRES_USER}
      - DATABASE_PASSWORD=${POSTGRES_PASSWORD}
      - DATABASE_DBNAME=${POSTGRES_DB}
      - REDIS_HOST=${REDIS_HOST}
      - REDIS_PORT=${REDIS_PORT}
      - AUTO_SETUP=false
      # ... copy other env vars from primary
```

4. On VPS 1, expose PostgreSQL and Redis to VPS 2:
```bash
# PostgreSQL: allow VPS2 IP in pg_hba.conf
# Redis: set requirepass and allow VPS2 IP
```

5. Use DNS round-robin or a load balancer (Cloudflare, nginx) to distribute traffic.

## Notes

- Both instances share the same database — all config changes are instant
- Redis is used for caching and concurrency control — must be shared
- Each instance maintains its own scheduler snapshot cache
- No sticky session required between LB and DexAPI instances
