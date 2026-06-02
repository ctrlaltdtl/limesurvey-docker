FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites and PHP 8.5 from Ondrej PPA
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    unzip \
    ca-certificates \
    wkhtmltopdf \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y \
    apache2 \
    php8.5 \
    libapache2-mod-php8.5 \
    php8.5-mysql \
    php8.5-gd \
    php8.5-zip \
    php8.5-mbstring \
    php8.5-xml \
    php8.5-curl \
    php8.5-intl \
    php8.5-ldap \
    php8.5-imap \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Enable required Apache modules
# mpm_prefork required for libapache2-mod-php (not thread-safe, incompatible with mpm_event)
RUN a2dismod mpm_event && a2enmod mpm_prefork rewrite php8.5

# Apply Apache configuration
COPY apache2.conf /etc/apache2/apache2.conf
COPY limesurvey.conf /etc/apache2/sites-available/limesurvey.conf
RUN a2ensite limesurvey.conf && a2dissite 000-default

# To update LimeSurvey: change LIMESURVEY_URL to the new zip from https://community.limesurvey.org/downloads/
# then run: docker compose build --no-cache && docker compose up -d
ARG LIMESURVEY_URL=https://download.limesurvey.org/latest-master/limesurvey7.0.0+260526.zip

# Download and install LimeSurvey
# -f fails loudly on HTTP errors, -L follows redirects
RUN echo "Downloading LimeSurvey from: ${LIMESURVEY_URL}" \
    && curl -fL "${LIMESURVEY_URL}" -o /tmp/limesurvey.zip \
    && unzip -q /tmp/limesurvey.zip -d /tmp/ \
    && rm /tmp/limesurvey.zip \
    && mv /tmp/limesurvey /var/www/html/limesurvey \
    && chmod -R 755 /var/www/html/limesurvey/tmp \
    && chmod -R 755 /var/www/html/limesurvey/upload \
    && chmod -R 755 /var/www/html/limesurvey/application/config \
    && chown -R www-data:www-data /var/www/html/limesurvey \
    && cp -rp /var/www/html/limesurvey/application/config /opt/limesurvey-config-template

# Apply patches to LimeSurvey source
COPY patches/ /patches/
RUN php /patches/fix_statistics_listcolumn.php

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["-D", "FOREGROUND"]
