# Penultimate stable Debian (today: trixie=13 stable -> bookworm=12 penultimate)
FROM debian:bookworm

# mariadb-server = daemon, mariadb-client = the CLI used during bootstrap.
# --no-install-recommends + cleaning the apt cache keeps the image small.
RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-server \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Our server config (replaces Debian's default that binds to 127.0.0.1 only).
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Init script: creates the DB + users on first boot, then hands over to mariadbd.
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN rm -rf /var/lib/mysql/* \
    && mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Documentation only (no port is published to the host - NGINX is the only entrypoint).
EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# PID 1 = mariadbd in the foreground, running as the mysql user. No wrapper, no tail -f.
CMD ["mariadbd", "--user=mysql"]
