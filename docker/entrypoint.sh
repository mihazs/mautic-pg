#!/bin/sh
set -eu

if [ "$(id -u)" = 0 ]; then
    for directory in config media/files media/images var; do
        mkdir -p "/var/www/html/$directory"
        chown -R www-data:www-data "/var/www/html/$directory"
    done
fi

exec docker-php-entrypoint "$@"
