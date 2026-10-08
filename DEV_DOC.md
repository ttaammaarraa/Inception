# Inception Developer Documentation

## Environment Setup From Scratch

Install Docker Engine with the `docker-compose` command available, OpenSSL, and Git. Clone the repository and enter it:

```sh
git clone <repository-url> Inception
cd Inception
cp srcs/.env.example srcs/.env
```

Review `srcs/.env` before starting:

```dotenv
DOMAIN_NAME=taabu-fe.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
HOST_DATA_PATH=/home/taabu-fe/data
```

The configured host path must be writable by the current user. `make data` creates its `mariadb` and `wordpress` subdirectories.

## Project Layout

- `srcs/docker-compose.yml`: service, network, volume, secret, and restart configuration.
- `requirements/mariadb`: MariaDB image, configuration, and initialization entrypoint.
- `requirements/wordpress`: WordPress download, PHP-FPM configuration, and initialization entrypoint.
- `requirements/nginx`: NGINX configuration, TLS setup, and foreground entrypoint.
- `secrets/`: locally generated secret files; ignored by Git.
- `srcs/certs/`: local development certificate and key; generated files are ignored by Git.

## Makefile and Compose Commands

The Makefile always invokes `docker-compose -f srcs/docker-compose.yml`:

```sh
make secrets   # Create database secret files
make certs     # Create a self-signed certificate
make data      # Create host-backed volume directories
make build     # Build all custom images
make up        # Build and start all services
make ps        # List services
make logs      # Follow all logs
make down      # Stop and remove containers
make restart   # Recreate the stack
make clean     # Remove stopped containers
make fclean    # Remove containers, named volumes, secrets, and certificates
```

Equivalent direct Compose commands are:

```sh
docker-compose -f srcs/docker-compose.yml config
docker-compose -f srcs/docker-compose.yml build
docker-compose -f srcs/docker-compose.yml up -d
docker-compose -f srcs/docker-compose.yml down
```

Each image is built locally from Debian Bookworm. No ready-made WordPress, NGINX, or MariaDB service image is used.

## Container and Volume Management

Service and image names are both `nginx`, `wordpress`, and `mariadb`. Useful inspection commands include:

```sh
docker-compose -f srcs/docker-compose.yml ps
docker inspect nginx
docker volume ls
docker volume inspect inception_wordpress_data
docker volume inspect inception_mariadb_data
```

Do not remove the named volumes during routine updates. Removing them deletes the persistent database and website state. `make fclean` intentionally performs that destructive cleanup and should only be used when a complete reset is wanted.

## Persistence Paths

The Compose file declares two named volumes:

- `inception_mariadb_data` maps to `/var/lib/mysql` in MariaDB and persists under `${HOST_DATA_PATH}/mariadb` on the host.
- `inception_wordpress_data` maps to `/var/www/html` in WordPress and is mounted read-only at the same path in NGINX; it persists under `${HOST_DATA_PATH}/wordpress` on the host.

The local volume driver uses the configured host data path while the application still consumes named Docker volumes. Certificates and Docker secrets are separate local project files and are not stored in these application volumes.