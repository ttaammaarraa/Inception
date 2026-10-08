FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mariadb-server mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/my.cnf /etc/mysql/mariadb.conf.d/60-inception.cnf
COPY tools/entrypoint.sh /usr/local/bin/mariadb-entrypoint
RUN chmod 755 /usr/local/bin/mariadb-entrypoint

EXPOSE 3306
ENTRYPOINT ["/usr/local/bin/mariadb-entrypoint"]
