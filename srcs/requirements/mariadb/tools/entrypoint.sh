#!/bin/sh
set -e

SOCK=/run/mysqld/mysqld.sock

# Only on the first boot: the volume has no system tables yet.
if [ ! -d "/var/lib/mysql/mysql" ]; then
	chown -R mysql:mysql /var/lib/mysql
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
		--skip-test-db --auth-root-authentication-method=normal >/dev/null

	# --bootstrap can't run CREATE USER/GRANT/ALTER USER (no grant tables in
	# that mode). So: start a temporary, network-isolated server, set it up
	# like a normal SQL client, then stop it before starting the real one.
	mariadbd --user=mysql --skip-networking --socket="$SOCK" &
	temp_pid=$!
	sleep 3

	DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
	mariadb --socket="$SOCK" -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.global_priv WHERE User='' OR (User='root' AND Host!='localhost');
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '$(cat /run/secrets/db_password)';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

	mariadb-admin --socket="$SOCK" -uroot -p"${DB_ROOT_PASSWORD}" shutdown
	wait "$temp_pid" 2>/dev/null || true
fi

exec "$@"
