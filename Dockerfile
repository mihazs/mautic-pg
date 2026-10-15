# syntax=docker/dockerfile:1
FROM node:24.22.0-bookworm-slim AS node
FROM composer:2 AS composer
FROM php:8.3-apache-bookworm AS runtime

COPY --from=ghcr.io/mlocati/php-extension-installer:2.12.1 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions bcmath curl gd imap intl mbstring opcache pdo_mysql pdo_pgsql sockets zip \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main' > /etc/apt/sources.list.d/postgresql.list \
    && apt-get update && apt-get install -y --no-install-recommends postgresql-client-18 default-mysql-client \
    && rm -rf /var/lib/apt/lists/* \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && a2enmod rewrite headers
COPY docker/apache.conf /etc/apache2/conf-enabled/mautic.conf
COPY docker/php.ini /usr/local/etc/php/conf.d/mautic.ini
ENV APP_ENV=prod APP_DEBUG=0
WORKDIR /var/www/html

FROM runtime AS build
COPY --from=node /usr/local/ /usr/local/
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
RUN apt-get update && apt-get install -y --no-install-recommends git unzip && rm -rf /var/lib/apt/lists/*
COPY . .
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts --optimize-autoloader \
    && composer check-platform-reqs --no-dev \
    && npm ci --no-audit \
    && npx patch-package \
    && composer gjs-build \
    && composer generate-assets \
    && rm -rf node_modules plugins/GrapesJsBuilderBundle/node_modules var/cache/* var/logs/*

FROM runtime AS final
RUN install-php-extensions amqp exif mysqli
ARG VCS_REF=unknown
LABEL org.opencontainers.image.source="https://github.com/mihazs/mautic-pg" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.revision="$VCS_REF"
COPY --from=build --chown=www-data:www-data /var/www/html /var/www/html
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/mautic-entrypoint
ENTRYPOINT ["mautic-entrypoint"]
CMD ["apache2-foreground"]
