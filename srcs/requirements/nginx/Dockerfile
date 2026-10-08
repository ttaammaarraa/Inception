FROM debian:bookworm-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /etc/nginx/certs

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/entrypoint.sh /usr/local/bin/nginx-entrypoint
RUN chmod 755 /usr/local/bin/nginx-entrypoint

EXPOSE 443
ENTRYPOINT ["/usr/local/bin/nginx-entrypoint"]
