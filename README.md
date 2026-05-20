# limesurvey-docker

A Dockerized setup for [LimeSurvey Community Edition](https://community.limesurvey.org/) with a bundled MySQL 8 database.

## What this does

Spins up two containers:
- **app** — Apache 2 + PHP 8.5 + LimeSurvey (latest, pulled from GitHub at build time)
- **db** — MySQL 8

LimeSurvey is available at `http://localhost:8505/limesurvey/admin/` once running. All data (database, uploads, config) is persisted to `./data/` on the host via bind mounts so it survives container restarts and can be moved between servers.

## Requirements

- Docker
- Docker Compose

## Getting started

```bash
# 1. Clone the repo
git clone <repo-url>
cd limesurvey-docker

# 2. Run setup — validates credentials and writes .env
./setup.sh

# 3. Build the image
docker compose build

# 4. Start the containers
docker compose up -d

# 5. Open the LimeSurvey installer
open http://localhost:8505/limesurvey/admin/
```

## First-run installer

On first start, LimeSurvey will run its web installer. Fill in the database configuration screen as follows:

| Field | Value |
|---|---|
| Database type | `MySQL` |
| MySQL database engine type | `InnoDB` _(change from default MyISAM — required for MySQL 8)_ |
| Database location | `db` |
| Database user | _(value you set in setup.sh)_ |
| Database password | _(value you set in setup.sh)_ |
| Database name | _(value you set in setup.sh)_ |
| Table prefix | `lime_` _(leave as default)_ |

> **Database location must be `db`** — not `localhost`. That is the Docker service name the app container uses to reach MySQL over the internal network. Using `localhost` will fail to connect.

Once the database is populated you will be taken to the **Administrator settings** screen:

| Field | Notes |
|---|---|
| Admin login name | Your LimeSurvey login username |
| Admin login password | Set a strong password — this is separate from MySQL |
| Administrator email | Your real email address |
| Site name | Displayed in the admin header — can be changed later |
| Default language | `English - English` unless you need another |

Hit **Next** to finalize the install. You will then be able to log in and create surveys.

## Data

All persistent data lives in `./data/` and is gitignored:

```
data/
├── mysql/    ← MySQL database files
├── upload/   ← LimeSurvey user uploads
└── config/   ← LimeSurvey config.php (written by installer)
```

Back up this directory to preserve your surveys and data.

## Updating LimeSurvey

To pull the latest LimeSurvey release:

```bash
docker compose build --no-cache
docker compose up -d
```

## License

GPL v3 — see [LICENSE](LICENSE).
