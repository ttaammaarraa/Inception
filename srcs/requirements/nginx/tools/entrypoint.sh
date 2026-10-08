#!/bin/sh
set -eu

if [ ! -s /etc/nginx/certs/server.crt ] || [ ! -s /etc/nginx/certs/server.key ]; then
    mkdir -p /etc/nginx/certs
    openssl req -x509 -nodes -newkey rsa:4096 -days 365 \
        -keyout /etc/nginx/certs/server.key \
        -out /etc/nginx/certs/server.crt \
        -subj "/C=XX/ST=Local/L=Local/O=Inception/CN=${DOMAIN_NAME}"
fi

sed -i "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/g" /etc/nginx/nginx.conf
exec nginx -g 'daemon off;'
