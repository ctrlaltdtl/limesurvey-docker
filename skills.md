# LimeSurvey Docker — Skills / Design

## Goal

A single Docker Compose setup that runs LimeSurvey Community Edition with a bundled MySQL database, matching the default installation experience.

---

## Stack

Mirrors the manual installation process:

| Layer | Choice |
|---|---|
| Web server | Apache2 |
| PHP | 8.5+ |
| App | LimeSurvey Community (downloaded from community.limesurvey.org) |
| Database | MySQL |

---

## Skills (planned capabilities)

### 1. Spin up LimeSurvey + MySQL
- `docker compose up` brings up two services: `app` (Apache + PHP + LimeSurvey) and `db` (MySQL)
- MySQL uses LimeSurvey's default database/user/password conventions
- LimeSurvey files land at `/var/www/html` with correct permissions inside the container
- Apache is configured with a `limesurvey.conf` and site-enabled, matching the manual setup
- LimeSurvey is reachable in a browser after startup

### 2. Persist data across restarts
- MySQL data survives `docker compose down` via a named volume
- LimeSurvey uploads/config survives restarts via a named volume

---

## Custom Dockerfile — build steps (mirrors manual install)

All steps run as root inside the build — no `sudo` needed.

### 1. Base + PHP setup script
- Base image: `ubuntu:24.04` (or similar Debian-based)
- Add Ondřej Surý PPA (`ppa:ondrej/php`) to get PHP 8.5+ on Ubuntu — requires `software-properties-common`
- Install Apache2, PHP 8.5+, and all extensions using **version-pinned package names** to avoid mismatches (past issue with `php-curl8.4` was caused by generic package resolving to wrong version):
  ```
  php8.5
  libapache2-mod-php8.5
  php8.5-mysql
  php8.5-gd
  php8.5-zip
  php8.5-mbstring
  php8.5-xml
  php8.5-curl
  php8.5-intl
  php8.5-ldap
  php8.5-imap
  ```
  - To upgrade PHP, bump the version prefix in one place in the Dockerfile
  - `php-json` and `php-tokenizer` are built into PHP 8.x — no separate install needed
- Enable Apache modules: `a2enmod rewrite php8.5`
- PHP version is verified at build time via `php -v` (appears in build output)
- Copy `apache2.conf` into `/etc/apache2/apache2.conf`
- Copy `limesurvey.conf` into `/etc/apache2/sites-available/`
- Enable LimeSurvey site and disable default: `a2ensite limesurvey.conf && a2dissite 000-default`
- No `systemctl` — Apache starts via `CMD ["apache2ctl", "-D", "FOREGROUND"]`
- The `phpinfo()` test file is a one-time manual verification step after `docker compose up` — never leave it in place

### 2. MySQL setup
- MySQL 8.x runs in its own container
- The official MySQL image automatically creates the database and user on first start via env vars — no `init.sql` needed for basic setup:
  - `MYSQL_ROOT_PASSWORD`
  - `MYSQL_DATABASE` (e.g. `limesurvey_db`)
  - `MYSQL_USER` (e.g. `lime_user`)
  - `MYSQL_PASSWORD`
- All values come from `.env`, passed through `docker-compose.yml` — nothing hardcoded
- **Important**: user host must be `'%'` not `'localhost'` — in Docker, the app container connects over the internal network, not via a local socket. The official image sets `'%'` by default.
- MySQL port is **not** exposed externally — only the app container can reach it over the Docker network

#### `setup.sh` — first-time credential setup
A bash script that:
1. Prompts the user for `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`
2. Validates all inputs before writing anything (see rules below)
3. Writes a `.env` file with all values double-quoted (handles spaces and special chars safely)
4. Reminds the user that `.env` is gitignored and should never be committed

**Validation rules:**

| Field | Rules |
|---|---|
| `MYSQL_ROOT_PASSWORD` | Required; min 12 chars; no `'` or `\` (break MySQL SQL); no `#` (breaks .env parsing) |
| `MYSQL_PASSWORD` | Same as root password; confirmed by typing twice |
| `MYSQL_DATABASE` | Required; alphanumeric + underscores only; max 64 chars (MySQL limit) |
| `MYSQL_USER` | Required; alphanumeric + underscores only; max 32 chars (MySQL limit) |

**Why these restrictions:**
- `'` (single quote) and `\` (backslash) break the SQL that the MySQL image runs internally to create the user
- `#` in an unquoted `.env` value is treated as a comment — truncates the value silently
- `$` can cause shell variable expansion when `.env` is sourced
- All values are written double-quoted in `.env` to handle remaining edge cases safely

**Pre-flight checks (run before writing `.env`):**
1. Docker is installed and the daemon is running
2. Docker Compose is available
3. Port 8505 is not already in use on the host
4. `.env` does not already exist — if it does, warn and prompt before overwriting
5. Show a confirmation summary with masked passwords before writing

**Post-write:**
- `chmod 600 .env` immediately after writing — owner read/write only

---

## Security hardening

### Secrets & file permissions
- `.env` — `chmod 600` (owner only)
- `config.php` (written by LimeSurvey installer, contains DB credentials) — `chmod 640`, owned by `www-data`
- `application/config/` — `chmod 750` after installer runs

### MySQL
- Port 3306 is **not** exposed externally in `docker-compose.yml` — MySQL is only reachable from the app container over the internal Docker network
- `lime_user` is granted minimum required privileges only — not `ALL PRIVILEGES`:
  ```sql
  GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
  ON limesurvey_db.* TO 'lime_user'@'%';
  ```

### Runtime stability
- MySQL healthcheck defined in `docker-compose.yml` using `mysqladmin ping`
- App container uses `depends_on: condition: service_healthy` — Docker will not start Apache until MySQL passes its healthcheck, preventing connection errors on first-run installer

Equivalent SQL (for reference only — handled automatically by the MySQL image):
```sql
CREATE DATABASE limesurvey_db;
CREATE USER 'lime_user'@'%' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON limesurvey_db.* TO 'lime_user'@'%';
FLUSH PRIVILEGES;
```

### 3. LimeSurvey install script
- Fetch latest release tag via GitHub Releases API
- Download and unzip the LimeSurvey zip
- Move files into place and set permissions:
  ```sh
  mv limesurvey /var/www/html/limesurvey
  chmod -R 755 /var/www/html/limesurvey/tmp
  chmod -R 755 /var/www/html/limesurvey/upload
  chmod -R 755 /var/www/html/limesurvey/application/config
  chown -R www-data:www-data /var/www/html/limesurvey
  ```

### 4. Apache configuration
- `apache2.conf` is committed to the repo and copied into the image at build time
- Copy `limesurvey.conf` into `/etc/apache2/sites-available/` and enable via `a2ensite`
- Entrypoint starts Apache in the foreground (`apache2ctl -D FOREGROUND`)

Key settings in `limesurvey.conf`:
- `ServerName localhost` — matches Docker local access
- `Options -Indexes FollowSymLinks` — explicit directory listing prevention
- `Require all granted` — explicit (not relying on inheritance from `apache2.conf`)
- Logs routed to stdout/stderr for `docker logs` support

Key settings in `apache2.conf`:
- `ServerTokens Prod` + `ServerSignature Off` — hides Apache version from headers/error pages
- `Options -Indexes` on `/var/www/` — directory listing disabled
- `AllowOverride All` on `/var/www/` — required for LimeSurvey's `.htaccess`
- Logs routed to stdout/stderr (`/proc/self/fd/1` and `/proc/self/fd/2`) for `docker logs` support

---

## Access

- LimeSurvey files live at `/var/www/html/limesurvey/` inside the container, so the URL path is `/limesurvey/`
- Host port **8505** maps to container port 80 — avoids conflicts with any existing service on port 80
- URL: `http://localhost:8505/limesurvey/admin/`
- On first start, the LimeSurvey web installer runs in the browser — the user completes the DB connection step there
- After that first-run install, subsequent starts go straight to the LimeSurvey login

---

## Resolved decisions

| Decision | Choice |
|---|---|
| LimeSurvey version | Always pull latest from community.limesurvey.org/downloads/ at build time |
| MySQL version | 8.x |
| DB credentials | `.env` file (gitignored); a `.env.example` is committed showing structure |

---

## Secrets & security

- `.env` is already in `.gitignore` — never committed
- `.env.example` is committed with placeholder values so the required vars are documented
- `docker-compose.yml` references env vars (e.g. `${MYSQL_PASSWORD}`) — no hardcoded secrets
- MySQL container is configured via standard env vars: `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`
- MySQL service is **not** port-exposed externally; only the `app` container can reach it over the internal Docker network
- For GitHub: add a `.env.example` note in README; for CI/CD use GitHub Secrets (not `.env`)

---

## LimeSurvey download strategy

LimeSurvey does not publish formal GitHub releases. Their download server directory listing is blocked (403). The Dockerfile uses an `ARG LIMESURVEY_URL` with the current zip URL hardcoded as the default:

```
ARG LIMESURVEY_URL=https://download.limesurvey.org/latest-master/limesurvey6.17.3+260512.zip
```

To update LimeSurvey: get the new zip URL from https://community.limesurvey.org/downloads/, update the `ARG` line in the Dockerfile, then:
```bash
docker compose build --no-cache && docker compose up -d
```

The zip extracts to a directory named `limesurvey/` inside `/tmp/`.

---

## Open design questions

- **More to come** — additional requirements TBD
