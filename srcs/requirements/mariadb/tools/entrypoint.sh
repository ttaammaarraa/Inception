#!/bin/sh
set -eu

root_password=$(cat /run/secrets/mysql_root_password)
user_password=$(cat /run/secrets/mysql_password)

mkdir -p /var/lib/mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
    # Fresh volume: create the system tables.
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi

sock=/run/mysqld/mysqld.sock
mysqld --user=mysql --skip-networking --socket="$sock" &
tmp_pid=$!
trap 'kill "$tmp_pid" 2>/dev/null || true' EXIT HUP INT TERM

i=0
until mariadb-admin --socket="$sock" ping >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
        echo "mariadb: temporary server failed to start" >&2
        exit 1
    fi
    sleep 1
done

if mariadb --socket="$sock" -uroot -p"${root_password}" -e "SELECT 1;" >/dev/null 2>&1; then
    set -- -uroot -p"${root_password}"
else
    set -- -uroot
fi

mariadb --socket="$sock" "$@" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${user_password}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQL

mariadb-admin --socket="$sock" -uroot -p"${root_password}" shutdown
wait "$tmp_pid" 2>/dev/null || true
trap - EXIT HUP INT TERM

exec mysqld --user=mysql --console