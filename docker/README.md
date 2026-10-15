# PostgreSQL container

This image builds the fork's locked PHP dependencies, CKEditor, GrapesJS and production assets from source. It runs Apache with PHP 8.3 and PostgreSQL 18 client tools, supporting PostgreSQL 16 and 18 servers. It contains no database or site credentials. Startup prepares writable directories; installation and migrations are explicit operations.

## Start a new site

Create `docker/.env` with strong, independently generated values:

```dotenv
POSTGRES_PASSWORD=replace-with-a-random-password
MAUTIC_SECRET_KEY=replace-with-a-random-secret
POSTGRES_MAJOR=18
```

Run from the repository root:

```sh
docker compose --env-file docker/.env -f docker/compose.yaml up -d
```

Open `http://localhost:8080/installer`, select PostgreSQL and use host `postgres`, port `5432`, database/user `mautic`, and your `POSTGRES_PASSWORD`. Create the administrator account in the installer, then sign in at `/s/login`. For PostgreSQL 16, set `POSTGRES_MAJOR=16` before creating the database volume. Never change the major version against an existing database volume; use PostgreSQL's supported backup/restore or upgrade process.

Run console commands as the web user:

```sh
docker compose --env-file docker/.env -f docker/compose.yaml exec --user www-data mautic php bin/console list
```

The example binds HTTP to localhost. For public deployments, configure HTTPS through your reverse proxy, set Mautic's site URL and trusted proxies, configure mail delivery and schedule the [required Mautic cron jobs](https://docs.mautic.org/en/7.0/configuration/cron_jobs.html). Run scheduled console commands as `www-data` in the same container, or a separate container sharing its environment and volumes. Cron and queue workers are not started by the web image.

Named volumes retain site configuration, uploaded files/images, logs and mail spool across container replacement. Compiled caches stay within the container so each replacement starts clean. Back up these volumes and the database before updates. After replacing the image, explicitly run the applicable Mautic update/migration commands; startup never migrates the database automatically. See [PostgreSQL compatibility](../POSTGRESQL.md) for server requirements and documented comparison/regex limits.

## Build locally

```sh
docker build --build-arg VCS_REF="$(git rev-parse HEAD)" -t mautic-pg:local .
MAUTIC_IMAGE=mautic-pg:local docker compose --env-file docker/.env -f docker/compose.yaml up -d
```

The build context excludes local configuration, dependencies, database dumps and private keys. Builds use committed Composer and npm lockfiles; base image tags receive upstream maintenance updates. Pin the published GHCR image by digest for repeatable deployments.
