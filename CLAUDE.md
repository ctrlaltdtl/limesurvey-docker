# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Dockerized setup for LimeSurvey Community Edition with a bundled MySQL 8 database. Designed to run locally or on an AMD64 server (built directly on the target machine — no cross-platform build needed).

## Stack

| Layer | Choice |
|---|---|
| Web server | Apache 2.4 + `mpm_prefork` |
| PHP | 8.5 via Ondřej Surý PPA (`ppa:ondrej/php`) |
| App | LimeSurvey Community (pinned URL in `Dockerfile`) |
| Database | MySQL 8 (official Docker image) |

## Common Commands

```bash
# First-time setup — generates .env and ./data/ directories
./setup.sh

# Build the app image
docker compose build

# Start all containers
docker compose up -d

# Stop all containers
docker compose down

# Update LimeSurvey to a new release
./update.sh

# View logs
docker compose logs app
docker compose logs db
```

## Architecture

Two containers wired via an internal Docker network (`limesurvey_net`):

- **app** — Ubuntu 24.04 + Apache + PHP 8.5 + LimeSurvey files at `/var/www/html/limesurvey/`
- **db** — MySQL 8; not port-exposed externally; only reachable from `app` as hostname `db`

Port `8505` on the host maps to port `80` inside `app`. LimeSurvey is at `http://localhost:8505/limesurvey/admin/`.

### Data persistence

All persistent data lives in `./data/` (gitignored) via bind mounts:

```
data/
├── mysql/    → /var/lib/mysql
├── upload/   → /var/www/html/limesurvey/upload
└── config/   → /var/www/html/limesurvey/application/config
```

### First-run entrypoint

`docker-entrypoint.sh` runs before Apache starts. On first run, the `config/` bind mount is empty and would hide LimeSurvey's source config files. The entrypoint copies them from `/opt/limesurvey-config-template/` into the mounted directory, then starts Apache. Subsequent starts skip the copy.

### Updating LimeSurvey

`update.sh` tries to auto-detect the latest zip URL from `community.limesurvey.org/downloads/`, falls back to prompting for a URL manually, validates it (HTTP 200), updates the `ARG LIMESURVEY_URL` line in `Dockerfile`, and offers to rebuild.

## Key Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the app image; `ARG LIMESURVEY_URL` controls which version is downloaded |
| `docker-compose.yml` | Wires app + db; reads credentials from `.env` |
| `apache2.conf` | Global Apache config — logs to stdout/stderr, no directory listing |
| `limesurvey.conf` | Apache vhost for LimeSurvey |
| `docker-entrypoint.sh` | Initializes config dir on first run, then starts Apache |
| `setup.sh` | Interactive first-time setup — validates credentials, writes `.env`, creates `./data/` |
| `update.sh` | Updates LimeSurvey version in Dockerfile and optionally rebuilds |
| `.env.example` | Documents required env vars; copy to `.env` or run `setup.sh` |

## Secrets

- `.env` is gitignored — contains MySQL credentials, never commit it
- `./data/` is gitignored — contains live database and user files
- Run `setup.sh` on each new machine; back up `.env` securely
