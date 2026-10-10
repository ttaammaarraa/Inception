#!/bin/sh
set -eu

root_password=$(cat /run/secrets/mysql_root_password)
user_password=$(cat /run/secrets/mysql_password)

# The host-backed data directory can be created by the Makefile as any local
# user. Ensure the MySQL daemon (a different uid inside the container) can
# write to it regardless of its initial ownership.
mkdir -p /var/lib/mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

if [ ! -d /var/lib/mysql/mysql ]; then
    # Fresh volume: create the system tables.
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi

# Apply the project schema through a temporary local server. The statements
# are idempotent (CREATE ... IF NOT EXISTS), so this also heals datadirs
# that arrive pre-populated (e.g. files copied from the image layer when the
# volume is first mounted) instead of silently skipping initialization.
# NOTE: `mysqld --bootstrap` cannot be used here: on MariaDB 10.11 it runs
# with grant tables skipped and rejects every account-management statement
# (ALTER USER, CREATE USER, GRANT) with ERROR 1290.
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

# Root may authenticate via the unix_socket plugin (fresh system tables) or
# via the password from the secret (previously initialized datadir).
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