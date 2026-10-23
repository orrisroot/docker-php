# General purpose PHP docker/podman image
This image adds the following PHP extensions to the PHP Docker Official Images.
* apcu, bcmath, bz2, calendar, exif, gd, gettext, gmp, igbinary, imagick, intl, ldap, msgpack, mysqli, opcache, pcntl, pdo_mysql, pdo_pgsql, pgsql, redis, shmop, soap, sockets, sysvmsg, sysvsem, sysvshm, tidy, xdebug, xhprof, xsl, zip

## Build
The scripts default to [podman](https://podman.io), which runs in rootless (user) mode by default. Verify rootless mode with `podman info` (look for `rootless: true`); if needed, use a storage driver that supports rootless overlay (`overlay`/`fuse-overlayfs`).

Docker can be used instead by setting `ENGINE=docker`(either inline or exported). Images are tagged with the fully qualified name `docker.io/orrisroot/php:...`, so they can be pushed as is with either engine.

Build a single image:
    ./build.sh 8.3 apache
    ENGINE=docker ./build.sh 8.3 apache

Build all versions and flavors:
    ./build-all.sh
    ENGINE=docker ./build-all.sh

Build logs are written to `logs/`.

### Behavior
* `build.sh` only pulls the base image when it changed (`--pull=newer`),
  checks the Docker Hub rate limit before building, and retries transient
  Docker Hub auth errors.
* Parallel builds race on Docker Hub token requests, so `build-all.sh`
  runs serially by default (`MAX_PARALLEL=1`); set `MAX_PARALLEL` higher
  to parallelize.
* Same-target builds are serialized with `flock` (see `.locks/`), so
  overlapping invocations never build the same target concurrently.
* A target is skipped when nothing changed since its last successful build
  (fingerprint kept under `.state/`). Use `SKIP_IF_UNCHANGED=0` or
  `PULL_POLICY=always` to force a rebuild.
* Tunables: `MIN_REMAINING`, `RETRIES`, `RETRY_DELAY`, `SKIP_RATE_CHECK`,
  `LOCK_TIMEOUT`, `SKIP_IF_UNCHANGED`, `PULL_POLICY`.

## Push
To push the built images to Docker Hub:
    podman login          # or: docker login
    ./push-all.sh         # pushes every local orrisroot/php tag

`push-all.sh` skips a tag when the copy on Docker Hub is newer than the
local build. Options: `ONLY_MAJOR=1`, `ONLY_VERSIONED=1`, `DRY_RUN=1`,
`FORCE=1`, `SKIP_STALE_CHECK=1`.

Check whether the built images need updating:
    ./check.sh
