# Developer Notes

## Layout

```
Makefile                  entrypoint for build/up/down/clean, calls docker compose
secrets/                  gitignored secret files (see USER_DOC.md)
srcs/
  docker-compose.yml
  .env                    gitignored
  requirements/
    mariadb/  Dockerfile, conf/50-server.cnf, tools/entrypoint.sh
    wordpress/Dockerfile, conf/www.conf,       tools/entrypoint.sh
    nginx/    Dockerfile, conf/https.conf
```

## Why each container does what it does

### mariadb

`entrypoint.sh` only runs its setup once, gated on `/var/lib/mysql/mysql` not
existing (i.e. first boot on a fresh volume). It can't use `--bootstrap` for
`CREATE USER`/`GRANT` (no grant tables available in that mode), so instead it
starts a temporary `mariadbd` with `--skip-networking` on a unix socket, runs
the setup SQL as a normal client, then shuts it down before `exec`'ing the
real, foreground `mariadbd` as PID 1. No `tail -f`, no supervisor — the
database daemon itself is PID 1, restartable by Docker's `restart` policy.

### wordpress

Each step in `entrypoint.sh` is gated on its own precondition (file exists /
`wp core is-installed`), so a restart after a partial failure (e.g. MariaDB
not ready yet) resumes instead of redoing finished work. WordPress files are
installed straight into `/var/www/html` (the volume root) — this must match
the `root` directive in nginx's `https.conf`, or every request 404s.

php-fpm's pool config (`conf/www.conf`) is patched to listen on `0.0.0.0:9000`
instead of the default unix socket, since nginx is a separate container and
needs a TCP address to reach it.

### nginx

The self-signed cert is generated at build time via `ARG`s (`DOMAIN_NAME`,
`CERTS_KEY`, `CERTS_CRT`) baked into the image — passed from `.env` through
`docker-compose.yml`'s `build.args`. Because they're `ARG`s, Docker's build
cache is automatically invalidated when their values change, so editing
`.env` and rerunning `make up --build` (which `make up` always does) is
enough to pick up a new domain.

`ssl_protocols` is set at the `server` block level in `conf/https.conf`
(`TLSv1.2 TLSv1.3`) — this takes precedence over the value the Dockerfile
`sed`s into the top-level `nginx.conf`, which is effectively redundant but
harmless.

## Volumes

```yaml
volumes:
  mariadb:
    driver: local
    driver_opts: {type: none, o: bind, device: ${DATA_PATH}/mariadb}
```

This is a named volume (`docker volume ls` shows it, `docker-compose.yml`'s
`volumes:` top-level section defines it) whose data is physically backed by a
bind-mounted host directory. This is the standard way to satisfy both
constraints from the subject at once: "must be named volumes, not bind
mounts" *and* "data must end up in `/home/login/data` on the host". The
target directory must exist before `docker compose up`, or you'll get
`bind source path does not exist` — `make up` creates it first.

## Secrets

Passwords never appear in `docker-compose.yml`, Dockerfiles, or images — only
in `secrets/*.txt`, mounted read-only at `/run/secrets/<name>` and read at
container startup by the entrypoint scripts. `credentials.txt` packs both
WordPress passwords into one Docker secret (`sed -n 's/^KEY=//p'` extracts
each one by prefix) since Compose secrets are files, not key-value maps.

## Makefile

`-include srcs/.env` lets the Makefile read `DATA_PATH` without duplicating
it; `mkdir -p` runs before every `up` so the bind-mount targets always exist.
`fclean`'s `rm -rf` needs `sudo` because files inside the data directories are
owned by the container's internal UIDs (`mysql`, `www-data`), not the host
user.
