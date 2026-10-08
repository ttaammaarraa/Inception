#!/bin/sh
set -eu

root_password=$(cat /run/secrets/mysql_root_password)
user_password=$(cat /run/secrets/mysql_password)

auto_init=false
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
    mysqld --user=mysql --bootstrap --skip-networking <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${user_password}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL
fi

exec mysqld --user=mysql --console
