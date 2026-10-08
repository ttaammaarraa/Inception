FROM debian:bookworm-slim

ARG WORDPRESS_VERSION=6.8.2

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl mariadb-client php8.2-fpm php8.2-mysql php8.2-curl \
       php8.2-gd php8.2-intl php8.2-mbstring php8.2-xml php8.2-zip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/src/wordpress \
    && curl -fsSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" | tar -xz -C /tmp \
    && cp -a /tmp/wordpress/. /usr/src/wordpress/ \
    && rm -rf /tmp/wordpress \
     && chown -R www-data:www-data /usr/src/wordpress \
     && curl -fsSL "https://github.com/wp-cli/wp-cli/releases/download/v2.11.0/wp-cli-2.11.0.phar" \
         -o /usr/local/bin/wp \
     && chmod 755 /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/wordpress-entrypoint
RUN chmod 755 /usr/local/bin/wordpress-entrypoint \
    && mkdir -p /run/php

EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint"]
CMD ["php-fpm8.2", "-F"]
