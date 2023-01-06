FROM docker.io/library/php:8.2-fpm

RUN dpkg-query -f '${Package}\n' -W | grep -e '-dev$' > /tmp/dev-packages.prev \
    && apt update \
    && apt install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng-dev libxpm-dev libwebp-dev libgmp-dev libicu-dev libldap2-dev libmagickwand-dev libpq-dev libtidy-dev libxslt1-dev libzip-dev zip unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-xpm --with-webp \
    && docker-php-ext-install -j$(nproc) bcmath bz2 calendar exif gd gettext gmp intl ldap mysqli pcntl pdo_mysql pdo_pgsql pgsql shmop soap sockets sysvmsg sysvsem sysvshm tidy xsl zip \
    && printf "\n" | pecl install APCu igbinary imagick msgpack redis xdebug xhprof \
    && docker-php-ext-enable apcu igbinary imagick msgpack opcache redis xdebug xhprof \
    && dpkg-query -f '${Package}\n' -W | grep -e '-dev$' > /tmp/dev-packages.post \
    && cat /tmp/dev-packages.post | fgrep -xvf /tmp/dev-packages.prev > /tmp/dev-packages.append \
    && apt remove -y $(cat /tmp/dev-packages.append) \
    && pecl clear-cache \
    && rm -rf /var/lib/apt/lists/* /tmp/pear/ /tmp/dev-packages.*
