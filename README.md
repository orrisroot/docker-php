# General purpose PHP docker/podman image

This image adds common PHP extensions to the PHP Docker Official Images.

- Docker Hub: [`orrisroot/php`](https://hub.docker.com/r/orrisroot/php)
- Base images: `php:<version>-apache`, `php:<version>-fpm` (`8.2`, `8.3`, `8.4`, `8.5`)
- Platform: `linux/amd64`

## Tags

| Tag | Description |
|---|---|
| `<minor>-apache` (e.g. `8.4-apache`) | Latest patch release of PHP `<minor>` (Apache) |
| `<minor>-fpm` (e.g. `8.4-fpm`) | Latest patch release of PHP `<minor>` (FPM) |
| `<patch>-apache` (e.g. `8.4.x-apache`) | Specific PHP patch release (Apache) |
| `<patch>-fpm` (e.g. `8.4.x-fpm`) | Specific PHP patch release (FPM) |

Images are rebuilt automatically via Renovate and GitHub Actions when an updated base image is released. Tags are overwritten on rebuild, so pulling the same tag again picks up base image and PHP extension updates.

## Included extensions

* apcu, bcmath, bz2, calendar, exif, gd, gettext, gmp, igbinary, imagick, intl, ldap, msgpack, mysqli, opcache, pcntl, pdo_mysql, pdo_pgsql, pgsql, redis, shmop, soap, sockets, sysvmsg, sysvsem, sysvshm, tidy, xdebug, xhprof, xsl, zip

## Build

The scripts default to [podman](https://podman.io), which runs in rootless (user) mode by default. Docker can be used instead by setting `ENGINE=docker`. Images are tagged as `docker.io/orrisroot/php:<minor>-<flavor>` and `docker.io/orrisroot/php:<patch>-<flavor>`.

Build a single image:

```sh
./build.sh 8.3 apache
ENGINE=docker ./build.sh 8.3 apache
```

Build all versions and flavors:

```sh
./build-all.sh
ENGINE=docker ./build-all.sh
```
