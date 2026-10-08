#!/bin/sh
set -eu

password=$(cat /run/secrets/mysql_password)
admin_password=$(cat /run/secrets/wp_admin_password)

until mariadb-admin ping -h mariadb -u"${MYSQL_USER}" -p"${password}" --silent; do
    sleep 1
done

if [ ! -f /var/www/html/index.php ]; then
    cp -a /usr/src/wordpress/. /var/www/html/
    chown -R www-data:www-data /var/www/html
fi

if [ ! -f /var/www/html/wp-config.php ]; then
    cat > /var/www/html/wp-config.php <<PHP
<?php
define('DB_NAME', '${MYSQL_DATABASE}');
define('DB_USER', '${MYSQL_USER}');
define('DB_PASSWORD', '${password}');
define('DB_HOST', 'mariadb:3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
\$table_prefix = 'wp_';
define('WP_DEBUG', false);
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
PHP
    chown www-data:www-data /var/www/html/wp-config.php
    chmod 640 /var/www/html/wp-config.php
fi

if ! wp core is-installed --path=/var/www/html --allow-root >/dev/null 2>&1; then
    wp core install \
        --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${admin_password}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
fi

exec "$@"
