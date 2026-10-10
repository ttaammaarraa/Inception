# Inception User Documentation

## Service Stack

The stack contains three services on the private `inception` Docker network:

- **nginx**: HTTPS entrypoint on host port `443`; serves WordPress files and forwards PHP requests to PHP-FPM.
- **wordpress**: WordPress with PHP-FPM listening on container port `9000`; no host port is published.
- **mariadb**: database server for WordPress; no host port is published.

Only NGINX is reachable from outside the Docker network.

## Start and Stop

From the repository root:

```sh
cp srcs/.env.example srcs/.env
# Review HOST_DATA_PATH in srcs/.env.
make
```

Common operations:

```sh
make up       # Build and start in the background
make ps       # Show current status
make logs     # Follow logs
make down     # Stop and remove containers
make restart  # Stop and start again
```

The first startup may take time while images and WordPress are downloaded. The generated certificate is self-signed, so the browser must accept the development certificate warning.

## Website and Administration

Visit `https://taabu-fe.42.fr`, or the value of `DOMAIN_NAME` in `srcs/.env`. The stack creates the WordPress site and administrator account on first startup.

Administration is available at `/wp-admin/`. The administrator username is `WP_ADMIN_USER` from `srcs/.env`, and its generated password is stored in `secrets/credentials.txt`.

## Credential Management

Run `make secrets` to create:

- `secrets/db_root_password.txt` for the MariaDB root account.
- `secrets/db_password.txt` for the WordPress database user.
- `secrets/credentials.txt` for the WordPress administrator account.

These files are ignored by Git and mounted only into the services that need them at `/run/secrets/`. Do not commit, publish, or paste their contents into `.env`, Dockerfiles, logs, or documentation. `make fclean` removes the generated local secret files.

The `srcs/.env` file contains only non-secret configuration such as the domain, database name, database username, and host data path. Local override files such as `srcs/.env.local` are ignored by Git.

## Health Checks

MariaDB has a Compose health check that runs `mariadb-admin ping` using the root secret. WordPress starts after MariaDB reports healthy and performs its own database readiness wait. NGINX starts after the WordPress service is created and serves the HTTPS endpoint.

Check service state with:

```sh
make ps
docker compose -f srcs/docker-compose.yml ps
```

Inspect failures with `make logs` or `docker compose -f srcs/docker-compose.yml logs <service>`.