*This project has been created as part of the 42 curriculum by hakotu.*

# Inception

## Description

Inception is a 42 School project whose goal is to learn the fundamentals of
Docker and Docker Compose by building a small, realistic web infrastructure
from scratch: a WordPress site served over TLS, backed by its own database,
with every image built from a hand-written Dockerfile rather than pulled
ready-made from a registry.

The result is three containers working together:

```
NGINX (443, TLS)  --fastcgi/9000-->  WordPress (php-fpm)  --3306-->  MariaDB
```

- **NGINX** — the single entrypoint into the infrastructure, TLSv1.2/1.3 only, port 443.
- **WordPress** — php-fpm only (no bundled web server), reachable only from nginx over the internal network.
- **MariaDB** — the WordPress database, reachable only from the wordpress container, no port exposed to the host.

## Project description

### Docker and the sources of this project

Everything is orchestrated by [srcs/docker-compose.yml](srcs/docker-compose.yml),
launched through the [Makefile](Makefile) at the repo root (`make` builds the
images and starts the stack). Each service has its own directory under
`srcs/requirements/<service>/`, containing:

- a `Dockerfile`, built `FROM debian:bookworm` (the penultimate stable Debian release) — no other image is pulled from a registry;
- a `conf/` directory with the service's configuration file(s);
- a `tools/entrypoint.sh` (mariadb, wordpress) that idempotently bootstraps the
  service on first boot (creating the database/users, downloading and
  installing WordPress) before handing off to the real daemon as PID 1 —
  no `tail -f`, no supervisor process, no infinite-loop shell script.

Credentials never appear in a Dockerfile or in `docker-compose.yml`: they are
read at container startup from files mounted under `/run/secrets/` (see
[secrets vs environment variables](#secrets-vs-environment-variables) below).
Non-sensitive configuration (database name, domain name, WordPress titles and
usernames, TLS cert paths) is passed through `srcs/.env`, referenced from
`docker-compose.yml` and, for nginx, from `build.args` at image build time.

### Main design choices

- **One named volume per persistent dataset** (`mariadb`, `wordpress`),
  configured with the `local` driver's `o=bind` option so their data
  physically lives under `${DATA_PATH}` on the host, while still being a
  Docker-managed named volume rather than a bind mount declared directly in a
  service's `volumes:` list (the subject requires the former, not the latter).
- **A single custom bridge network** (`inception`) connects all three
  containers; services address each other by container/service name
  (`mariadb`, `wordpress`) rather than by IP.
- **`restart: unless-stopped` / `always`** on every service, so a crashed
  container comes back without manual intervention.
- **Idempotent entrypoints**: each setup step in the mariadb/wordpress
  entrypoints checks its own precondition before running, so restarting a
  container that partially failed on its first boot resumes instead of
  reprocessing already-completed steps.

### Virtual Machines vs Docker

A VM virtualizes an entire machine — its own kernel, its own device drivers —
managed by a hypervisor. That gives very strong isolation but at a real cost:
each VM is gigabytes in size and takes tens of seconds (or more) to boot.
Docker containers share the host's kernel and isolate processes with
namespaces and cgroups instead of virtualizing hardware, so they're
megabytes in size and start in a fraction of a second — at the cost of a
thinner isolation boundary (a kernel exploit can affect every container on
the host). This project actually uses both, at different layers: it runs
inside one virtual machine (as the subject requires), and *inside* that VM,
Docker gives each of the three services its own lightweight, disposable
environment without needing three separate VMs.

### Secrets vs Environment Variables

Environment variables set in `docker-compose.yml`/`.env` end up in plain text
inside the container's environment — visible to `docker inspect`, to
`/proc/<pid>/environ`, and to anyone who can read `docker-compose.yml`. That's
fine for non-sensitive settings (a domain name, a database name), but not for
passwords. Docker secrets, by contrast, are mounted as read-only files under
`/run/secrets/<name>` inside the container, backed by tmpfs, and never appear
in `docker inspect`, in the image layers, or in `docker-compose config`. This
project keeps every password (`db_password`, `db_root_password`, the
WordPress admin/user passwords) as a Docker secret sourced from a file in
[secrets/](secrets/), and only non-sensitive configuration as environment
variables.

### Docker Network vs Host Network

`network: host` drops all network isolation: the container shares the host's
network namespace directly, sees every host interface, and can bind any port
the host itself hasn't already taken — which is exactly why the subject
forbids it. This project instead defines a private bridge network
(`inception`) that only its three containers join. Containers reach each
other by service name over Docker's internal DNS, and the host can reach the
containers only through whatever ports are explicitly published — here, only
nginx's 443. MariaDB and WordPress publish no ports to the host at all.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary, pre-existing host path straight into a
container; it's simple, but the container becomes coupled to that exact host
path, and Docker doesn't manage the mount's lifecycle at all (no
`docker volume ls`, no `docker volume rm`, nothing prevents the directory
from silently not existing). A named volume is managed by Docker — created,
listed, and removed as a first-class object — and by default lives wherever
Docker's storage driver decides, decoupling the container from any specific
host path. This project needs both properties at once: the subject requires
named volumes, but the data must still land at a predictable
`/home/<login>/data` path on the host. The `local` driver's `type: none,
o: bind` options bridge the two — `mariadb` and `wordpress` remain genuine
named volumes from Docker's point of view, while being backed by a bind
mount under the hood.

## Instructions

### Prerequisites

- Docker and Docker Compose v2.
- `/etc/hosts` pointing your domain at the local machine:

  ```sh
  echo "127.0.0.1 hakotu.42.fr" | sudo tee -a /etc/hosts
  ```

### Setup

Create `srcs/.env` and three files in `secrets/` (none of these are tracked
in git). See [USER_DOC.md](USER_DOC.md) for the exact variables and file
formats expected by the entrypoints.

### Build and run

```sh
make            # builds the three images and starts the stack
make ps         # check container status
make logs       # follow logs
```

Then open `https://hakotu.42.fr` (the certificate is self-signed, so the
browser will warn on first visit — that's expected).

```sh
make down       # stop and remove containers, keep images and data
make clean      # down + remove the built images
make fclean     # clean + delete the host data directories (irreversible)
make re         # fclean + make
```

More detail on day-to-day usage and troubleshooting: [USER_DOC.md](USER_DOC.md).
Implementation notes and rationale for each service: [DEV_DOC.md](DEV_DOC.md).

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Docker Compose secrets](https://docs.docker.com/compose/use-secrets/)
- [Docker volumes documentation](https://docs.docker.com/storage/volumes/)
- [MariaDB server documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI documentation](https://wp-cli.org/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- Article: [About PID 1 and container init systems](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/)

**AI usage**: The Dockerfiles, entrypoint scripts, and `docker-compose.yml`
are my own work. I asked Claude for help mainly when `docker compose up`
wouldn't run (blank env vars, an nginx build error, a 404 on every page, a
WordPress duplicate-email error) — I checked each fix against the actual
file before applying it and re-tested with `docker logs`/`curl` afterwards.
It also wrote the `Makefile` and a first draft of this README, which I went
through afterwards to make sure I could explain it myself. For the
theoretical parts (VM vs Docker, secrets vs env vars, network, volumes) I
asked Claude questions to understand the concepts rather than just taking
the written paragraphs as-is.
