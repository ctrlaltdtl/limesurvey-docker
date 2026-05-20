#!/bin/bash
set -e

CONFIG_DIR=/var/www/html/limesurvey/application/config
TEMPLATE_DIR=/opt/limesurvey-config-template

# On first run the mounted volume is empty, hiding the source config files.
# Copy them in so LimeSurvey can boot. The installer will add config.php later.
if [ ! -f "${CONFIG_DIR}/internal.php" ]; then
    echo "[entrypoint] Initializing config directory from template..."
    cp -rp "${TEMPLATE_DIR}/." "${CONFIG_DIR}/"
    chown -R www-data:www-data "${CONFIG_DIR}"
    echo "[entrypoint] Config directory initialized"
fi

exec apache2ctl -D FOREGROUND
