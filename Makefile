NAME := inception
COMPOSE := docker compose -f srcs/docker-compose.yml
HOST_DATA_ROOT := $(shell grep '^HOST_DATA_PATH=' srcs/.env 2>/dev/null | head -n1 | cut -d= -f2)

.PHONY: all build up down restart logs ps clean fclean secrets certs data

all: up

build: secrets certs data
	$(COMPOSE) build

up: secrets certs data
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

secrets:
	@mkdir -p secrets
	@test -s secrets/db_root_password.txt || openssl rand -base64 32 > secrets/db_root_password.txt
	@test -s secrets/db_password.txt || openssl rand -base64 32 > secrets/db_password.txt
	@test -s secrets/credentials.txt || openssl rand -base64 32 > secrets/credentials.txt
	@chmod 600 secrets/*.txt

certs:
	@mkdir -p srcs/certs
	@test -s srcs/certs/server.crt -a -s srcs/certs/server.key || openssl req -x509 -nodes -newkey rsa:4096 -days 365 \
		-keyout srcs/certs/server.key -out srcs/certs/server.crt \
		-subj "/C=XX/ST=Local/L=Local/O=Inception/CN=$(shell grep '^DOMAIN_NAME=' srcs/.env 2>/dev/null | cut -d= -f2 || echo localhost)"
	@chmod 600 srcs/certs/server.key

data:
	@test -n "$(HOST_DATA_ROOT)" || { echo "error: srcs/.env is missing or has no HOST_DATA_PATH" >&2; exit 1; }
	@mkdir -p "$(HOST_DATA_ROOT)/mariadb" "$(HOST_DATA_ROOT)/wordpress"

clean: down
	$(COMPOSE) rm -f

fclean: clean
	@test -n "$(HOST_DATA_ROOT)" || { echo "error: srcs/.env is missing or has no HOST_DATA_PATH" >&2; exit 1; }
	docker volume rm $(NAME)_wordpress_data $(NAME)_mariadb_data 2>/dev/null || true
	rm -rf srcs/certs/server.crt srcs/certs/server.key secrets/*.txt
	rm -rf "$(HOST_DATA_ROOT)/mariadb" "$(HOST_DATA_ROOT)/wordpress" 2>/dev/null || true
	@if [ -e "$(HOST_DATA_ROOT)/mariadb" ] || [ -e "$(HOST_DATA_ROOT)/wordpress" ]; then \
		echo "info: data dirs are owned by another uid, removing via helper container"; \
		docker run --rm --entrypoint /bin/rm -v "$(HOST_DATA_ROOT):/data" inception-wordpress -rf /data/mariadb /data/wordpress \
		|| { echo "error: cannot remove $(HOST_DATA_ROOT)/{mariadb,wordpress}; remove them manually (e.g. with sudo)" >&2; exit 1; }; \
	fi