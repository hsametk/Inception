#!/bin/sh
set -e

cd /var/www/html

# Each step checks its own precondition, so a restart after a partial failure
# (e.g. DB not reachable yet) resumes instead of re-doing finished work.

if [ ! -f wp-load.php ]; then
	echo "[entrypoint] Downloading WordPress core..."
	wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
	echo "[entrypoint] Writing wp-config.php..."
	wp config create --allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="$(cat /run/secrets/db_password)" \
		--dbhost="mariadb"
fi

if ! wp core is-installed --allow-root; then
	echo "[entrypoint] Installing WordPress..."
	wp core install --allow-root \
		--url="${WP_URL}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--admin_password="$(sed -n 's/^WP_ADMIN_PASSWORD=//p' /run/secrets/credentials)"

	wp user create --allow-root \
		"${WP_USER}" "${WP_USER_EMAIL}" \
		--role=author \
		--user_pass="$(sed -n 's/^WP_USER_PASSWORD=//p' /run/secrets/credentials)"
fi

chown -R www-data:www-data /var/www/html
exec "$@"
