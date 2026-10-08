*This project has been created as part of the 42 curriculum by taabu-fe.*

# Inception

## Description

Inception is a small, secure Docker infrastructure for serving WordPress. It is composed of three custom images built from Debian Bookworm:

- **NGINX** is the only public entrypoint and exposes HTTPS on port 443.
- **WordPress** runs PHP-FPM on the private Docker network and does not expose a host port.
- **MariaDB** stores the WordPress database and does not expose a host port.

The services communicate through the explicitly defined `inception` bridge network. TLS is limited to TLSv1.2 and TLSv1.3. Database passwords are supplied as Docker secrets rather than committed to the repository or placed in Dockerfiles.

## Instructions

Install Docker Engine with Compose support and OpenSSL, then run:

```sh
cp srcs/.env.example srcs/.env
# Adjust HOST_DATA_PATH in srcs/.env if needed.
make
```

The Makefile creates the configured data directories, generates local Docker secrets, creates a self-signed development certificate, builds the three custom images, and starts the stack. Open `https://taabu-fe.42.fr`. A browser warning is expected for the self-signed certificate.

Useful commands:

```sh
make build       # Build images without starting containers
make up          # Build and start the stack
make ps          # Show container status
make logs        # Follow service logs
make down        # Stop and remove containers
make clean       # Remove stopped containers
make fclean      # Remove containers, named volumes, secrets, and certificates
```

## Resources

The implementation was developed with the Docker Compose specification, Debian package documentation, MariaDB documentation, PHP-FPM documentation, NGINX documentation, and the WordPress deployment documentation as references.

AI was used as a development assistant to inspect the repository, draft Dockerfiles, Compose configuration, shell entrypoints, and documentation, and identify configuration issues. All generated material was reviewed against the 42 subject constraints. The final design decisions, commands, secret handling, and validation remain the responsibility of the project author.

Detailed functional checks for each container, TLS protocol, restart policy, persistence, and volume binding are documented in [GUIDELINE_TESTING.md](GUIDELINE_TESTING.md).

## Technical Comparisons

### Virtual Machines vs. Docker

Virtual machines emulate a complete hardware environment and run a separate guest kernel for every machine. They provide stronger isolation but require more memory, storage, and startup time. Docker containers share the host kernel and isolate processes, filesystems, networks, and resources at the operating-system level. Containers are lighter and start quickly, but their isolation depends on the host kernel and runtime configuration.

### Secrets vs. Environment Variables

Environment variables are convenient for non-sensitive configuration such as `DOMAIN_NAME`, database names, and usernames. They can be exposed through process inspection, Compose output, logs, or diagnostic tooling. Docker secrets are mounted as files under `/run/secrets/` and are used here for database passwords. This keeps confidential values out of Dockerfiles, the image history, and ordinary environment listings.

### Docker Network vs. Host Network

A user-defined Docker bridge network gives services private DNS-based communication through service names while limiting host exposure. In this project, WordPress reaches MariaDB through `mariadb:3306`, and NGINX reaches PHP-FPM through `wordpress:9000`. Host networking removes that network isolation and exposes container services directly on the host network namespace, so it is not used.

### Docker Volumes vs. Bind Mounts

Docker-managed named volumes are owned and tracked by Docker and are the normal choice for persistent application data. A bind mount directly maps an arbitrary host path and gives the container a more explicit dependency on host filesystem layout. This project uses named volumes for MariaDB and WordPress data, with the local volume driver configured to persist them under `${HOST_DATA_PATH}/mariadb` and `${HOST_DATA_PATH}/wordpress`.
