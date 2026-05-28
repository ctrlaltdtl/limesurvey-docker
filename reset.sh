#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
die()   { error "$1"; exit 1; }

[[ -f "docker-compose.yml" ]] || die "Run this script from the limesurvey-docker repo root"

# ── Warning ──────────────────────────────────────────────────────────────────

echo
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                      ⚠  WARNING                              ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  This will wipe your LimeSurvey database and/or files.       ║${NC}"
echo -e "${RED}║  All surveys, responses, and settings will be lost.          ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN}Before continuing, make sure you have exported from LimeSurvey:${NC}"
echo
echo "  1. Survey structure files (.lss)"
echo "     Surveys → (each survey) → Export → Export survey structure"
echo
echo "  2. Survey responses (.csv or .xlsx)"
echo "     Surveys → (each survey) → Responses → Export responses"
echo
echo "  3. Any archived surveys"
echo "     Survey list → filter by 'Inactive' and export each one"
echo
echo "  LimeSurvey is at: http://localhost:8505/limesurvey/admin/"
echo

read -rp "Have you exported all surveys and responses you need to keep? [y/N] " confirmed || true
[[ "${confirmed:-}" =~ ^[Yy]$ ]] || { info "Aborted — nothing was changed"; exit 0; }

# ── Backup offer ─────────────────────────────────────────────────────────────

echo
read -rp "Run backup.sh first to snapshot ./data/ before wiping? [Y/n] " do_backup || true
if [[ ! "${do_backup:-}" =~ ^[Nn]$ ]]; then
    if [[ -f "./backup.sh" ]]; then
        bash ./backup.sh || warn "Backup encountered an issue — continuing anyway"
    else
        warn "backup.sh not found — skipping"
    fi
fi

# ── Reset scope ───────────────────────────────────────────────────────────────

echo
echo "What do you want to reset?"
echo
echo "  1) Database + config only  (keeps uploads — use for credential typos)"
echo "  2) Full reset              (wipes database, config, AND uploads)"
echo
read -rp "Enter 1 or 2: " scope || true

case "${scope:-}" in
    1)
        WIPE_DIRS=("data/mysql" "data/config")
        info "Scope: database + config"
        ;;
    2)
        WIPE_DIRS=("data/mysql" "data/config" "data/upload")
        warn "Scope: full reset — uploads will also be deleted"
        echo
        read -rp "Are you sure you want to delete uploads too? [y/N] " confirm_full || true
        [[ "${confirm_full:-}" =~ ^[Yy]$ ]] || { info "Aborted — nothing was changed"; exit 0; }
        ;;
    *)
        die "Invalid selection — nothing was changed"
        ;;
esac

# ── Stop containers ───────────────────────────────────────────────────────────

echo
info "Stopping containers..."
docker compose down

# ── Wipe selected directories ─────────────────────────────────────────────────

for dir in "${WIPE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        RM_EXIT=0
        rm -rf "$dir" 2>/dev/null || RM_EXIT=$?
        if [[ $RM_EXIT -ne 0 ]]; then
            warn "Some files are owned by Docker container users — retrying with sudo..."
            sudo rm -rf "$dir" || die "Failed to remove ${dir} — try: sudo rm -rf ${dir}"
        fi
        info "Removed ./${dir}/"
    fi
done

mkdir -p "${WIPE_DIRS[@]}"
info "Recreated empty directories"

# ── Credential reset offer ────────────────────────────────────────────────────

echo
read -rp "Run setup.sh now to set new credentials? [Y/n] " do_setup || true
if [[ ! "${do_setup:-}" =~ ^[Nn]$ ]]; then
    bash ./setup.sh
else
    warn "Skipped setup.sh — make sure .env exists before running docker compose up -d"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo
info "Reset complete. Run when ready:"
echo "  docker compose up -d"
echo
