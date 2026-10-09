# Inception Testing Guidelines

This guide verifies the mandatory Inception requirements for the `taabu-fe` deployment. Run the commands from the repository root after Docker Engine and `docker-compose` are installed.

## 1. Prepare the Environment

Confirm the expected configuration and create the local runtime files:

```sh
grep -E '^(DOMAIN_NAME|HOST_DATA_PATH)=' srcs/.env
make secrets
make certs
make data
```

Expected values are:

```text
DOMAIN_NAME=taabu-fe.42.fr
HOST_DATA_PATH=/home/taabu-fe/data
```

Check that credentials are protected and ignored by Git:

```sh
chmod 600 secrets/*.txt
stat -c '%a %n' secrets/*.txt
git check-ignore secrets/credentials.txt secrets/db_password.txt secrets/db_root_password.txt
```

No secret file should be tracked or displayed in normal Compose configuration output.

## 2. Build and Start the Stack

Validate the fully interpolated Compose file before building:

```sh
docker-compose -f srcs/docker-compose.yml config
make build
make up
```

Check that exactly three containers are running:

```sh
docker-compose -f srcs/docker-compose.yml ps
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

The expected containers and images are named `mariadb`, `wordpress`, and `nginx`. Only `nginx` should publish a host port, and that port must be `443`.

## 3. Test MariaDB

Confirm the MariaDB container is healthy:

```sh
docker inspect --format '{{.State.Health.Status}}' mariadb
docker compose -f srcs/docker-compose.yml logs mariadb
```

The result should be `healthy`. Verify the database and application user without exposing passwords in the command line:

```sh
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/mysql_root_password)" -e "SHOW DATABASES;"'
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/mysql_root_password)" -e "SELECT User,Host FROM mysql.user;"'
```

The database `wordpress` and user `wpuser` must exist. The WordPress administrator is an application account, not a forbidden database username such as `admin` or `administrator`.

## 4. Test WordPress and PHP-FPM

Confirm PHP-FPM is listening on the private Docker network and is not published on the host:

```sh
docker exec wordpress sh -c 'php-fpm8.2 -tt'
docker exec wordpress sh -c 'php -m | grep -E "mysqli|curl|gd|intl|mbstring|xml|zip"'
docker compose -f srcs/docker-compose.yml port wordpress 9000
```

The last command should produce no host binding. Check the application and administrator setup:

```sh
docker exec wordpress sh -c 'test -f /var/www/html/wp-config.php'
docker exec wordpress wp option get siteurl --path=/var/www/html --allow-root
docker exec wordpress wp user list --path=/var/www/html --allow-root
```

The PHP-FPM process must remain in the foreground as PID 1 or the direct child launched by the entrypoint, rather than using a loop or a background placeholder.

## 5. Test NGINX and HTTPS

Verify that NGINX is the only public service:

```sh
docker port nginx
docker compose -f srcs/docker-compose.yml port wordpress 9000
docker compose -f srcs/docker-compose.yml port mariadb 3306
```

Only `0.0.0.0:443` should be published. Test the site and certificate:

```sh
curl -kI --resolve taabu-fe.42.fr:443:127.0.0.1 https://taabu-fe.42.fr/
openssl s_client -connect 127.0.0.1:443 -servername taabu-fe.42.fr -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -servername taabu-fe.42.fr -tls1_3 </dev/null
```

Both TLS commands must complete with a negotiated protocol. TLS 1.0 and TLS 1.1 must be rejected:

```sh
openssl s_client -connect 127.0.0.1:443 -servername taabu-fe.42.fr -tls1 </dev/null
openssl s_client -connect 127.0.0.1:443 -servername taabu-fe.42.fr -tls1_1 </dev/null
```

The HTTP-only endpoint must not be exposed:

```sh
curl -I --max-time 3 http://127.0.0.1:80/
```

A connection failure is expected. The self-signed certificate generated for local testing will require `-k` or a local trust exception.

## 6. Test Restart Policies

Confirm restart policies are configured:

```sh
docker inspect --format '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' mariadb wordpress nginx
```

Each result should contain `unless-stopped`. Simulate a crash on one service and wait for Docker to recreate it:

```sh
docker kill wordpress
sleep 5
docker-compose -f srcs/docker-compose.yml ps
```

The WordPress container should be running again. Repeat only when needed for MariaDB and NGINX, and inspect logs if a service does not recover.

## 7. Test Database Persistence

Create a marker table, restart the stack, and verify the table remains:

```sh
docker exec mariadb sh -c 'mariadb -uwpuser -p"$(cat /run/secrets/mysql_password)" wordpress -e "CREATE TABLE IF NOT EXISTS persistence_check (id INT PRIMARY KEY);"'
make down
make up
docker exec mariadb sh -c 'mariadb -uwpuser -p"$(cat /run/secrets/mysql_password)" wordpress -e "SHOW TABLES LIKE '\''persistence_check'\'';"'
```

Do not run `make fclean` before this test. `fclean` deliberately removes the named volumes and destroys persistent data.

## 8. Verify Named Volumes and Host Paths

Confirm that the application mounts are named volumes, not direct bind mounts in the service definitions:

```sh
docker volume inspect inception_mariadb_data
docker volume inspect inception_wordpress_data
docker inspect mariadb --format '{{json .Mounts}}'
docker inspect wordpress --format '{{json .Mounts}}'
```

The volume driver options should resolve to:

```text
/home/taabu-fe/data/mariadb
/home/taabu-fe/data/wordpress
```

The Compose file must show `mariadb_data:/var/lib/mysql` and `wordpress_data:/var/www/html`; the host paths are configured by the named volume driver, not as direct application bind mounts.

## 9. Cleanup

Stop the stack without deleting data:

```sh
make down
```

Remove stopped containers while retaining volumes:

```sh
make clean
```

Perform a complete reset only when data loss is intentional:

```sh
make fclean
```

## 10. WordPress Browser & UI Verification

Perform these checks from a browser during the defense. They verify that NGINX serves the configured WordPress site over HTTPS, that the administrator account is valid, that a regular user can interact with the site, and that WordPress writes changes to MariaDB.

### 10.1 Open the HTTPS Website

1. Confirm the stack is running with `make ps`.
2. Open `https://taabu-fe.42.fr` in the browser.
3. If the browser displays a certificate warning, inspect that the certificate is for the local development deployment and continue through the browser's advanced option, such as **Advanced** followed by **Proceed to taabu-fe.42.fr**. The exact wording depends on the browser.
4. Confirm that the page loads over HTTPS and that the address bar remains on `https://taabu-fe.42.fr`. Do not use an HTTP URL or port 80.

The certificate is self-signed for local testing, so the warning is expected. The NGINX configuration must still negotiate TLSv1.2 or TLSv1.3 as verified in Section 5.

### 10.2 Log In as the Administrator

1. Open `https://taabu-fe.42.fr/wp-admin/`.
2. Enter the administrator username `siteowner`.
3. Retrieve the generated administrator password from `secrets/credentials.txt` on the local evaluation machine. Never commit or publish this value.
4. Confirm that WordPress opens the Administration Dashboard.
5. Point out that `siteowner` contains neither `admin` nor `administrator`, satisfying the subject's forbidden-username rule.

The login page and dashboard must be served through HTTPS. The password is generated by the Makefile and passed to WordPress through the Docker secret mounted at `/run/secrets/wp_admin_password`.

### 10.3 Create and Use a Regular User

If no regular user exists yet, create one while signed in as `siteowner`:

1. In the dashboard, open **Users** and choose **Add New**.
2. Create a non-administrator account such as `reader` with a valid email address and a separate test password.
3. Assign the **Subscriber** role, then save the account.
4. Open a private/incognito browser window and visit `https://taabu-fe.42.fr/wp-login.php`.
5. Log in as `reader` and verify that the account cannot access administrator-only settings.
6. Open the public site in that window and confirm that visitor-facing WordPress content is available.

Do not use `admin`, `administrator`, or a username containing those forbidden words for this test account. The `reader` account is only a regular WordPress user and is separate from the MariaDB user `wpuser`.

### 10.4 Add a Comment and Verify the Database Interaction

1. As the regular user or an unauthenticated visitor, open a published post or page with comments enabled.
2. Scroll to the comments form, enter a short test comment such as `Inception comment verification`, and submit it.
3. Confirm that WordPress accepts the comment. Depending on the discussion settings, it may appear immediately or show a moderation message.
4. Return to the administrator dashboard and open **Comments**.
5. Confirm that the submitted comment is present, then approve it if moderation is enabled.
6. Reload the public post/page and verify that the approved comment is visible.

This check demonstrates a write through WordPress to MariaDB rather than only serving static files. To confirm persistence independently, repeat the check after `make down` and `make up`, without running `make fclean`.

### 10.5 Edit Content and Verify the Live Site

1. In the administrator dashboard, open **Pages** or **Posts**.
2. Edit an existing page/post, or create a small test page if the site has no published content.
3. Change a visible title or sentence to a distinctive value such as `Inception live update verification`.
4. Publish or update the content.
5. Open the public page from a separate browser window, or use **View Page** from the dashboard.
6. Confirm the new title or sentence appears at `https://taabu-fe.42.fr`.
7. Refresh the page and confirm the change remains visible after a new request.

This is the evaluation-sheet check that a dashboard edit is reflected on the live website. If the old content remains, inspect `make logs`, verify the WordPress volume is mounted at `/var/www/html`, and confirm that the MariaDB container is healthy before repeating the test.