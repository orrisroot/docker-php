# General purpose PHP docker/podman image
This image adds the following PHP extensions to the PHP Docker Official Images.
* apcu, bcmath, bz2, calendar, exif, gd, gettext, gmp, igbinary, imagick, intl, ldap, msgpack, mysqli, opcache, pcntl, pdo_mysql, pdo_pgsql, pgsql, redis, shmop, soap, sockets, sysvmsg, sysvsem, sysvshm, tidy, xdebug, xhprof, xsl, zip

## Build
The scripts default to [podman](https://podman.io), which runs in rootless (user) mode by default. Verify rootless mode with `podman info` (look for `rootless: true`); if needed, use a storage driver that supports rootless overlay (`overlay`/`fuse-overlayfs`).

Docker can be used instead by setting `ENGINE=docker`(either inline or exported). Images are tagged with the fully qualified name `docker.io/orrisroot/php:...`, so they can be pushed as is with either engine.

Build a single image:
    ./build.sh 8.3 apache
    ENGINE=docker ./build.sh 8.3 apache

Build all versions and flavors in parallel:
    ./build-all.sh
    ENGINE=docker ./build-all.sh

Build logs are written to `logs/`.

To push the built images to Docker Hub:
    podman login          # or: docker login
    podman push docker.io/orrisroot/php:8.3-apache

Check whether the built images need updating:
    ./check.sh
