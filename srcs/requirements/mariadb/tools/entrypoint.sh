#!/bin/sh
# Runs as PID 1's parent (root), initialises the database on first boot,
# then `exec`s into the command from CMD (mariadbd) so the daemon becomes PID 1.
set -eu

DATADIR="/var/lib/mysql"

# --- Read passwords from Docker secrets (never from ENV / Dockerfile) ----------
if [ -f /run/secrets/db_root_password ]; then
    DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
else
    echo "[entrypoint] FATAL: /run/secrets/db_root_password is missing" >&2
    exit 1
fi
if [ -f /run/secrets/db_password ]; then
    DB_PASSWORD="$(cat /run/secrets/db_password)"
else
    echo "[entrypoint] FATAL: /run/secrets/db_password is missing" >&2
    exit 1
fi

: "${MYSQL_DATABASE:?MYSQL_DATABASE is not set}"
: "${MYSQL_USER:?MYSQL_USER is not set}"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld "$DATADIR"

# --- First boot only: the data directory has no system tables yet --------------
if [ ! -d "$DATADIR/mysql" ]; then
    echo "[entrypoint] Fresh volume detected - initialising MariaDB..."
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --skip-test-db \
        --auth-root-authentication-method=normal >/dev/null

    # SQL applied once, offline, via --bootstrap (no network, no socket).
    INIT_SQL="$(mktemp)"
    cat > "$INIT_SQL" <<EOF
USE mysql;

-- lock down the default accounts
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.global_priv WHERE User='';
DROP DATABASE IF EXISTS test;

-- project database + application user (reachable from the wordpress container)
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
EOF

    mariadbd --user=mysql --bootstrap --skip-networking=1 --datadir="$DATADIR" < "$INIT_SQL"
    rm -f "$INIT_SQL"
    echo "[entrypoint] Initialisation done."
else
    echo "[entrypoint] Existing data directory - skipping initialisation."
fi

echo "[entrypoint] Starting: $*"
exec "$@"
