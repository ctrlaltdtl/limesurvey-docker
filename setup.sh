#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
die()   { error "$1"; exit 1; }
mask()  { printf '%*s' "${#1}" '' | tr ' ' '*'; }

# ── Validation ──────────────────────────────────────────────────────────────

validate_password() {
    local pw="$1" label="$2"
    [[ ${#pw} -ge 12 ]]   || { error "$label must be at least 12 characters";              return 1; }
    [[ "$pw" != *"'"*  ]] || { error "$label cannot contain single quotes (')";            return 1; }
    [[ "$pw" != *'\\'* ]] || { error "$label cannot contain backslashes (\\)";             return 1; }
    [[ "$pw" != *'"'*  ]] || { error "$label cannot contain double quotes (\")";           return 1; }
    [[ "$pw" != *'#'*  ]] || { error "$label cannot contain # (breaks .env parsing)";     return 1; }
    [[ "$pw" != *'$'*  ]] || { error "$label cannot contain \$ (causes shell expansion)"; return 1; }
    return 0
}

validate_identifier() {
    local val="$1" label="$2" max="$3"
    [[ -n "$val" ]]                  || { error "$label cannot be empty";                                    return 1; }
    [[ "$val" =~ ^[a-zA-Z0-9_]+$ ]] || { error "$label can only contain letters, numbers, and underscores"; return 1; }
    [[ ${#val} -le $max ]]           || { error "$label cannot exceed $max characters";                      return 1; }
    return 0
}

prompt_password() {
    local label="$1" varname="$2"
    local pw pw2
    while true; do
        read -rsp "  $label: " pw || true; echo
        validate_password "$pw" "$label" || continue
        read -rsp "  Confirm $label: " pw2 || true; echo
        [[ "$pw" == "$pw2" ]] || { error "Passwords do not match"; continue; }
        printf -v "$varname" '%s' "$pw"
        break
    done
}

prompt_identifier() {
    local label="$1" max="$2" varname="$3"
    local val
    while true; do
        read -rp "  $label: " val || true
        validate_identifier "$val" "$label" "$max" || continue
        printf -v "$varname" '%s' "$val"
        break
    done
}

# ── Pre-flight checks ───────────────────────────────────────────────────────

echo
info "Running pre-flight checks..."

[[ -f "docker-compose.yml" ]] \
    || die "Run this script from the limesurvey-docker repo root"

command -v docker &>/dev/null \
    || die "Docker is not installed"

docker info &>/dev/null 2>&1 \
    || die "Docker daemon is not running — start Docker and try again"

docker compose version &>/dev/null 2>&1 \
    || die "Docker Compose is not available"

if (echo > /dev/tcp/localhost/8505) 2>/dev/null; then
    die "Port 8505 is already in use — free it before continuing"
fi

if [[ -f ".env" ]]; then
    warn ".env already exists."
    read -rp "  Overwrite it? [y/N] " confirm || true
    [[ "${confirm:-}" =~ ^[Yy]$ ]] || { info "Aborted — existing .env unchanged"; exit 0; }
fi

info "All pre-flight checks passed"

# ── Collect credentials ─────────────────────────────────────────────────────

echo
echo "Enter MySQL credentials."
echo "Passwords must be at least 12 characters and cannot contain: ' \\ \" # \$"
echo

prompt_password   "MySQL Root Password"   MYSQL_ROOT_PASSWORD
echo
prompt_identifier "MySQL Database Name" 64 MYSQL_DATABASE
prompt_identifier "MySQL Username"      32 MYSQL_USER
echo
prompt_password   "MySQL User Password"   MYSQL_PASSWORD

# ── Confirmation summary ────────────────────────────────────────────────────

echo
echo "────────────────────────────────────────"
echo "  Configuration Summary"
echo "────────────────────────────────────────"
printf "  %-22s %s\n" "MYSQL_ROOT_PASSWORD:" "$(mask "$MYSQL_ROOT_PASSWORD")"
printf "  %-22s %s\n" "MYSQL_DATABASE:"      "$MYSQL_DATABASE"
printf "  %-22s %s\n" "MYSQL_USER:"          "$MYSQL_USER"
printf "  %-22s %s\n" "MYSQL_PASSWORD:"      "$(mask "$MYSQL_PASSWORD")"
echo "────────────────────────────────────────"
echo

read -rp "Write .env with these values? [y/N] " confirm || true
[[ "${confirm:-}" =~ ^[Yy]$ ]] || { info "Aborted — no files written"; exit 0; }

# ── Write .env ──────────────────────────────────────────────────────────────

cat > .env <<EOF
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
MYSQL_DATABASE="${MYSQL_DATABASE}"
MYSQL_USER="${MYSQL_USER}"
MYSQL_PASSWORD="${MYSQL_PASSWORD}"
EOF

chmod 600 .env
info ".env written and locked (chmod 600)"

# ── Create data directories ─────────────────────────────────────────────────

mkdir -p data/mysql data/upload data/config
info "Created ./data/ directories for bind mounts"

# ── Done ────────────────────────────────────────────────────────────────────

echo
info "Setup complete. Next steps:"
echo
echo "  1. docker compose build"
echo "  2. docker compose up -d"
echo "  3. Open http://localhost:8505/limesurvey/admin/"
echo "  4. Complete the LimeSurvey web installer using:"
echo "     → Database host: db"
echo "     → Database name: ${MYSQL_DATABASE}"
echo "     → Username:      ${MYSQL_USER}"
echo "     → Password:      (the one you just set)"
echo
warn ".env is gitignored — back it up securely. Losing it means reconfiguring MySQL."
echo
