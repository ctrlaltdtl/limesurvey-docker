#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
die()   { error "$1"; exit 1; }

DOCKERFILE="Dockerfile"
DOWNLOADS_PAGE="https://community.limesurvey.org/downloads/"

# ── Pre-flight ───────────────────────────────────────────────────────────────

[[ -f "$DOCKERFILE" ]] || die "Run this script from the limesurvey-docker repo root"

command -v curl &>/dev/null || die "curl is required but not installed"

# ── Show current version ─────────────────────────────────────────────────────

CURRENT_URL=$(sed -n 's/^ARG LIMESURVEY_URL=//p' "$DOCKERFILE" | tr -d '"' || true)

echo
echo -e "${CYAN}Current LimeSurvey URL:${NC}"
echo "  ${CURRENT_URL:-[not found in Dockerfile]}"
echo

# ── Auto-detect new URL ──────────────────────────────────────────────────────

info "Checking $DOWNLOADS_PAGE for latest release..."

DETECTED_URL=$(curl -sf --max-time 15 "$DOWNLOADS_PAGE" \
    | grep -oE 'https://download\.limesurvey\.org/latest-master/limesurvey[^"<> ]+\.zip' \
    | head -1 || true)

if [[ -n "$DETECTED_URL" ]]; then
    echo
    echo -e "${CYAN}Detected URL:${NC}"
    echo "  ${DETECTED_URL}"

    if [[ "$DETECTED_URL" == "$CURRENT_URL" ]]; then
        echo
        info "Already on the latest version. Nothing to update."
        exit 0
    fi

    echo
    read -rp "Use this URL? [y/N] " confirm || true
    if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
        NEW_URL="$DETECTED_URL"
    else
        DETECTED_URL=""
    fi
fi

if [[ -z "${DETECTED_URL:-}" ]]; then
    warn "Could not auto-detect URL (page layout may have changed)."
    echo "  Get the zip URL from: $DOWNLOADS_PAGE"
    echo
    read -rp "  Paste the new LimeSurvey zip URL: " NEW_URL || true
    NEW_URL="${NEW_URL:-}"
fi

# ── Validate URL ─────────────────────────────────────────────────────────────

[[ -n "$NEW_URL" ]] || die "No URL provided — nothing updated"

# Must match expected pattern
[[ "$NEW_URL" =~ ^https://download\.limesurvey\.org/.*\.zip$ ]] \
    || die "URL does not look like a LimeSurvey download: $NEW_URL"

info "Verifying URL is reachable..."
HTTP_STATUS=$(curl -sL --max-time 15 -o /dev/null -w "%{http_code}" "$NEW_URL")

[[ "$HTTP_STATUS" == "200" ]] \
    || die "URL returned HTTP ${HTTP_STATUS:-unknown} — check the URL and try again"

info "URL verified (HTTP 200)"

# ── Update Dockerfile ────────────────────────────────────────────────────────

# Escape replacement-special chars for sed: \, &, and the | delimiter
ESCAPED_URL=$(printf '%s\n' "$NEW_URL" | sed 's/[\\&|]/\\&/g')

sed -i.bak "s|ARG LIMESURVEY_URL=.*|ARG LIMESURVEY_URL=${ESCAPED_URL}|" "$DOCKERFILE" \
    && rm "${DOCKERFILE}.bak"

info "Dockerfile updated"
echo
echo "  Old: ${CURRENT_URL}"
echo "  New: ${NEW_URL}"

# ── Offer to rebuild ─────────────────────────────────────────────────────────

echo
read -rp "Rebuild and restart containers now? [y/N] " rebuild || true

if [[ "${rebuild:-}" =~ ^[Yy]$ ]]; then
    echo
    info "Building..."
    docker compose build --no-cache || die "Build failed"
    info "Restarting containers..."
    docker compose up -d || die "Failed to start containers"
    echo
    info "Done. LimeSurvey is updating at http://localhost:8505/limesurvey/admin/"
else
    echo
    info "Dockerfile updated. Run when ready:"
    echo "  docker compose build --no-cache && docker compose up -d"
fi

echo
