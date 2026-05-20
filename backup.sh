#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
die()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/limesurvey_backup_${TIMESTAMP}.tar.gz"

[[ -f "docker-compose.yml" ]] || die "Run this script from the limesurvey-docker repo root"
[[ -d "data" ]]               || die "./data/ directory not found — nothing to back up"

mkdir -p "$BACKUP_DIR"

info "Backing up ./data/ to ${BACKUP_FILE}..."

tar -czf "$BACKUP_FILE" data/

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
info "Backup complete: ${BACKUP_FILE} (${SIZE})"

# ── Retention: keep last 7 backups ──────────────────────────────────────────

BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/limesurvey_backup_*.tar.gz 2>/dev/null | wc -l | tr -d ' ')

if [[ "$BACKUP_COUNT" -gt 7 ]]; then
    warn "More than 7 backups found — removing oldest..."
    ls -1t "${BACKUP_DIR}"/limesurvey_backup_*.tar.gz | tail -n +8 | xargs rm -f
    info "Retention: kept 7 most recent backups"
fi

echo
info "To restore: tar -xzf ${BACKUP_FILE}"
echo
