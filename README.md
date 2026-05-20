# limesurvey-docker

A self-contained Docker setup for [LimeSurvey Community Edition](https://community.limesurvey.org/) with a bundled MySQL 8 database. Runs on macOS (Apple Silicon and Intel) and Linux AMD64 servers.

## What's included

- **app** — Ubuntu 24.04 + Apache 2.4 + PHP 8.5 + LimeSurvey Community
- **db** — MySQL 8
- `setup.sh` — interactive first-time credential setup with validation; prints a field-by-field reference for the web installer
- `update.sh` — auto-detects new LimeSurvey releases and rebuilds
- `backup.sh` — snapshots `./data/` to `./backups/`, retains last 7
- `reset.sh` — wipes database/config (or full reset) with a guided export checklist to prevent data loss
- All data persisted to `./data/` via bind mounts — survives restarts, easy to back up and move between servers

## Requirements

- Docker
- Docker Compose

## Building

### macOS (Apple Silicon or Intel)

Docker Desktop on Mac handles the build natively. No extra configuration needed.

```bash
git clone https://github.com/ctrlaltdtl/limesurvey-docker.git
cd limesurvey-docker
./setup.sh
docker compose build
docker compose up -d
```

### Linux AMD64 server

Build directly on the server — no cross-platform build required.

```bash
git clone https://github.com/ctrlaltdtl/limesurvey-docker.git
cd limesurvey-docker
./setup.sh
docker compose build
docker compose up -d
```

> If moving from a Mac to a server, re-run `./setup.sh` on the server to generate a fresh `.env`. Copy your `./data/` directory across to preserve existing surveys and database.

## Getting started

```bash
# 1. Clone the repo
git clone https://github.com/ctrlaltdtl/limesurvey-docker.git
cd limesurvey-docker

# 2. Run setup — validates credentials, writes .env, creates ./data/ directories
./setup.sh

# 3. Build the app image
docker compose build

# 4. Start both containers
docker compose up -d

# 5. Open the installer in your browser
open http://localhost:8505/limesurvey/admin/
```

## First-run installer

On first start, LimeSurvey runs its web installer. Fill in the **Database configuration** screen:

| Field | Value |
|---|---|
| Database type | `MySQL` |
| MySQL database engine type | `InnoDB` _(change from default MyISAM — required for MySQL 8)_ |
| Database location | `db` |
| Database user | _(value you set in setup.sh)_ |
| Database password | _(value you set in setup.sh)_ |
| Database name | _(value you set in setup.sh)_ |
| Table prefix | `lime_` _(leave as default)_ |

> **Database location must be `db`** — not `localhost`. That is the Docker service name the app container uses to reach MySQL over the internal network.

Once the database is populated you will be taken to the **Administrator settings** screen:

| Field | Notes |
|---|---|
| Admin login name | Your LimeSurvey login username |
| Admin login password | Set a strong password — separate from MySQL |
| Administrator email | Your real email address |
| Site name | Displayed in the admin header — can be changed later |
| Default language | `English - English` unless you need another |

Hit **Next** to finalize. You will then be able to log in and create surveys at `http://localhost:8505/limesurvey/admin/`.

## Common commands

```bash
# Start containers
docker compose up -d

# Stop containers
docker compose down

# View logs
docker compose logs app
docker compose logs db

# Update LimeSurvey to a new release
./update.sh

# Snapshot ./data/ to ./backups/
./backup.sh

# Wipe and reconfigure (e.g. after a credential typo)
./reset.sh
```

## Updating LimeSurvey

Run `./update.sh` — it automatically checks for a new release, updates the Dockerfile, and offers to rebuild:

```bash
./update.sh
```

To rebuild manually with a specific URL:

1. Get the zip URL from [community.limesurvey.org/downloads](https://community.limesurvey.org/downloads/)
2. Update `ARG LIMESURVEY_URL` in `Dockerfile`
3. Run:

```bash
docker compose build --no-cache
docker compose up -d
```

## Backup

Run `./backup.sh` at any time to snapshot `./data/` into `./backups/`:

```bash
./backup.sh
```

Backups are timestamped `limesurvey_backup_YYYYMMDD_HHMMSS.tar.gz`. The script automatically removes the oldest backups beyond the last 7.

To restore, stop the containers and extract the archive:

```bash
docker compose down
tar -xzf backups/limesurvey_backup_<timestamp>.tar.gz
docker compose up -d
```

## Reset

Use `./reset.sh` to wipe and start fresh — for example if you made a credential typo during setup:

```bash
./reset.sh
```

The script will:
1. Warn you to export any surveys and responses from the LimeSurvey UI first
2. Offer to run `backup.sh` before wiping
3. Let you choose the reset scope:
   - **Database + config only** — wipes MySQL data and config, keeps uploads (use this for credential typos)
   - **Full reset** — also wipes uploads
4. Stop the containers, remove the selected directories, and offer to re-run `setup.sh`

> **Before resetting:** export survey structures (`.lss`) and responses from `Surveys → Export` in the LimeSurvey admin UI. Archived/inactive surveys should also be exported.

## Data

All persistent data lives in `./data/` (gitignored):

```
data/
├── mysql/    ← MySQL database files
├── upload/   ← LimeSurvey user uploads
└── config/   ← LimeSurvey config and installer output
```

Back up this directory to preserve your surveys and data. To move to a new server, copy `./data/` and re-run `./setup.sh` for a fresh `.env`.

## License

GPL v3 — see [LICENSE](LICENSE).
