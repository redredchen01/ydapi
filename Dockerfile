# YDAPI Custom Build
# Based on sub2api with simplified UI

ARG NODE_IMAGE=node:24-alpine
ARG GOLANG_IMAGE=golang:1.26.1-alpine
ARG ALPINE_IMAGE=alpine:3.21
ARG POSTGRES_IMAGE=postgres:18-alpine

# Stage 0: Apply patches
FROM ${NODE_IMAGE} AS patcher
RUN apk add --no-cache patch
WORKDIR /src
COPY sub2api/ sub2api/
COPY patches/ patches/
RUN for p in patches/*.patch; do [ -s "$p" ] && (cd sub2api && patch -p0 --no-backup-if-mismatch < "../$p" || true); done

# Stage 1: Frontend
FROM ${NODE_IMAGE} AS frontend-builder
WORKDIR /app/frontend
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY --from=patcher /src/sub2api/frontend/package.json /src/sub2api/frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY --from=patcher /src/sub2api/frontend/ ./
RUN pnpm run build

# Stage 2: Backend
FROM ${GOLANG_IMAGE} AS backend-builder
ARG VERSION=
ARG COMMIT=ydapi
ARG DATE
RUN apk add --no-cache git ca-certificates tzdata
WORKDIR /app/backend
COPY sub2api/backend/go.mod sub2api/backend/go.sum ./
RUN go mod download
COPY sub2api/backend/ ./
COPY --from=frontend-builder /app/backend/internal/web/dist ./internal/web/dist
RUN VERSION_VALUE="${VERSION}" && \
    if [ -z "${VERSION_VALUE}" ]; then VERSION_VALUE="$(tr -d '\r\n' < ./cmd/server/VERSION)"; fi && \
    DATE_VALUE="${DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" && \
    CGO_ENABLED=0 GOOS=linux go build \
    -tags embed \
    -ldflags="-s -w -X main.Version=${VERSION_VALUE} -X main.Commit=${COMMIT} -X main.Date=${DATE_VALUE} -X main.BuildType=release" \
    -trimpath \
    -o /app/ydapi \
    ./cmd/server

# Stage 3: pg_dump
FROM ${POSTGRES_IMAGE} AS pg-client

# Stage 4: Runtime
FROM ${ALPINE_IMAGE}
LABEL maintainer="YDAPI"
LABEL description="YDAPI - AI API Gateway for Team"

RUN apk add --no-cache ca-certificates tzdata su-exec libpq zstd-libs lz4-libs krb5-libs libldap libedit && rm -rf /var/cache/apk/*
COPY --from=pg-client /usr/local/bin/pg_dump /usr/local/bin/pg_dump
COPY --from=pg-client /usr/local/bin/psql /usr/local/bin/psql
COPY --from=pg-client /usr/local/lib/libpq.so.5* /usr/local/lib/

RUN addgroup -g 1000 ydapi && adduser -u 1000 -G ydapi -s /bin/sh -D ydapi
WORKDIR /app
COPY --from=backend-builder --chown=ydapi:ydapi /app/ydapi /app/ydapi
COPY --from=backend-builder --chown=ydapi:ydapi /app/backend/resources /app/resources
RUN mkdir -p /app/data && chown ydapi:ydapi /app/data
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -q -T 5 -O /dev/null http://localhost:${SERVER_PORT:-8080}/health || exit 1
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/ydapi"]
