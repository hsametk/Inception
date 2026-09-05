# User Guide

## Prerequisites

- Docker + Docker Compose v2.
- A host directory for persistent data: `$HOME/data` (created automatically by `make up`).
- `/etc/hosts` entry pointing your domain at the local machine:

  ```sh
  echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
  ```

## Required files (not tracked in git)

### `srcs/.env`

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user

WP_TITLE=Inception
WP_URL=https://<login>.42.fr
WP_ADMIN_USER=<admin username, must NOT contain "admin">
WP_ADMIN_EMAIL=<your email>
WP_USER=<second wp user>
WP_USER_EMAIL=<a DIFFERENT email than WP_ADMIN_EMAIL>

DOMAIN_NAME=<login>.42.fr
CERTS_KEY=/etc/ssl/private/inception.key
CERTS_CRT=/etc/ssl/certs/inception.crt

DATA_PATH=/home/<login>/data
```

`DATA_PATH` must match the actual home directory of the account running the
containers (e.g. on the 42 iMacs, `/home/<your-intra-login>/data`).

### `secrets/`

Three plain-text files, one secret per line, `chmod 600`:

- `db_password.txt` — password for the WordPress MySQL user.
- `db_root_password.txt` — MariaDB root password.
- `credentials.txt` — WordPress account passwords, in this exact format:

  ```
  WP_ADMIN_PASSWORD=...
  WP_USER_PASSWORD=...
  ```

`WP_ADMIN_EMAIL` and `WP_USER_EMAIL` must be different — WordPress rejects a
second account with a duplicate email.

## Running it

```sh
make            # builds all three images and starts the stack
make ps         # check container status
make logs       # follow logs of all services
```

Then open `https://<login>.42.fr` in a browser (the cert is self-signed, so
the browser will warn on first visit — that's expected).

## Stopping / cleaning up

```sh
make down       # stop and remove containers, keep images and data
make stop       # just stop the containers, no removal
make start      # start them again
make clean      # down + remove the built images
make fclean     # clean + delete the host data directories (irreversible)
make re         # fclean + make
```

## Troubleshooting

- **Variables show up blank in `docker compose` warnings**: `srcs/.env` is
  missing or incomplete — compose reads it from the same directory as
  `docker-compose.yml`.
- **`bind source path does not exist`**: the `${DATA_PATH}/mariadb` or
  `${DATA_PATH}/wordpress` directory doesn't exist yet; `make up` creates them,
  but if you call `docker compose` directly you need to `mkdir -p` them first.
- **nginx container restarts in a loop with `invalid number of arguments in
  "server_name"`**: `DOMAIN_NAME` was empty when the nginx image was built.
  Fix `.env` and rebuild with `make up` (it always rebuilds).
- **404 on every page**: check that `nginx/conf/https.conf`'s `root` matches
  where WordPress is actually installed inside the shared volume
  (`/var/www/html`, not a subdirectory).
