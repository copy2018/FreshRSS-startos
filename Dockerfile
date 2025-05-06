FROM node:18-alpine AS build

# Set timezone and change the shell for better error handling
ENV TZ=UTC
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Install necessary packages for Apache, PHP, and Git
RUN apk add --no-cache \
    tzdata \
    git \
    apache2 php-apache2 \
    php php-curl php-gmp php-intl php-mbstring php-xml php-zip \
    php-ctype php-dom php-fileinfo php-iconv php-json php-opcache php-openssl php-phar php-session php-simplexml php-xmlreader php-xmlwriter php-xml php-tokenizer php-zlib \
    php-pdo_sqlite php-pdo_mysql php-pdo_pgsql

# Create the necessary directories
RUN mkdir -p /var/www/FreshRSS /run/apache2/

# Set the working directory
WORKDIR /var/www/FreshRSS

# Clone the repository directly into the working directory
RUN git clone https://github.com/FreshRSS/FreshRSS.git .

# Use the files from the cloned 'Docker' directory for configuration
RUN cp Docker/*.Apache.conf /etc/apache2/conf.d/

# Arguments for versioning and metadata (optional)
ARG FRESHRSS_VERSION
ARG SOURCE_COMMIT

# Add metadata labels to the resulting Docker image
LABEL \
    org.opencontainers.image.authors="Alkarex" \
    org.opencontainers.image.description="A self-hosted RSS feed aggregator" \
    org.opencontainers.image.documentation="https://freshrss.github.io/FreshRSS/" \
    org.opencontainers.image.licenses="AGPL-3.0" \
    org.opencontainers.image.revision="${SOURCE_COMMIT}" \
    org.opencontainers.image.source="https://github.com/FreshRSS/FreshRSS" \
    org.opencontainers.image.title="FreshRSS" \
    org.opencontainers.image.url="https://freshrss.org/" \
    org.opencontainers.image.vendor="FreshRSS" \
    org.opencontainers.image.version="$FRESHRSS_VERSION"

# Clean up unnecessary Apache configuration files and disable features
RUN rm -f /etc/apache2/conf.d/languages.conf /etc/apache2/conf.d/info.conf \
        /etc/apache2/conf.d/status.conf /etc/apache2/conf.d/userdir.conf && \
    sed -r -i "/^\s*LoadModule .*mod_(alias|autoindex|negotiation|status).so$/s/^/#/" \
        /etc/apache2/httpd.conf && \
    sed -r -i "/^\s*#\s*LoadModule .*mod_(deflate|expires|filter|headers|mime|remoteip|setenvif).so$/s/^\s*#//" \
        /etc/apache2/httpd.conf && \
    sed -r -i "/^\s*(CustomLog|ErrorLog|Listen) /s/^/#/" \
        /etc/apache2/httpd.conf && \
    # Disable built-in updates when using Docker
    sed -r -i "\\#disable_update#s#^.*#\t'disable_update' => true,#" ./config.default.php && \
    touch /var/www/FreshRSS/Docker/env.txt && \
    echo "27,57 * * * * . /var/www/FreshRSS/Docker/env.txt; \
        su apache -s /bin/sh -c 'php /var/www/FreshRSS/app/actualize_script.php' \
        2>> /proc/1/fd/2 > /tmp/FreshRSS.log" > /etc/crontab.freshrss.default

# Set environment variables for runtime
ENV COPY_LOG_TO_SYSLOG=On
ENV COPY_SYSLOG_TO_STDERR=On
ENV CRON_MIN=''
ENV DATA_PATH=''
ENV FRESHRSS_ENV=''
ENV LISTEN=''
ENV OIDC_ENABLED=''
ENV TRUSTED_PROXY=''

# Provide an entrypoint to start services
ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]

# Expose the HTTP port (default for Apache)
EXPOSE 80

# Start the cron and Apache server in foreground
CMD ([ -z "$CRON_MIN" ] || crond -d 6) && \
    exec httpd -D FOREGROUND $([ -n "$OIDC_ENABLED" ] && [ "$OIDC_ENABLED" -ne 0 ] && echo '-D OIDC_ENABLED')
