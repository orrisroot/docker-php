FROM docker.io/library/php:8.3-fpm

RUN dpkg-query -f '${Package}\n' -W | grep -e '-dev$' > /tmp/dev-packages.prev \
    && apt update \
    && apt install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng-dev libxpm-dev libwebp-dev libavif-dev libgmp-dev libicu-dev libldap2-dev libmagickwand-dev libpq-dev liblz4-dev liblzf-dev libzstd-dev libtidy-dev libxslt1-dev libzip-dev zip unzip \
    && printf "\n" | pecl install APCu igbinary msgpack xdebug xhprof \
    && pecl download imagick \
    && curl -OL https://github.com/Imagick/imagick/pull/641/commits/7088edc353f53c4bc644573a79cdcd67a726ae16.diff \
    && tar zxf imagick-3.7.0.tgz \
    && patch ./imagick-3.7.0/Imagick.stub.php ./7088edc353f53c4bc644573a79cdcd67a726ae16.diff \
    && sed -i -e 's/c2fb6a7536cf6c934cbb3882d8c4abf2/38db527227c9f89c638b97d754d3b076/' package.xml \
    && tar czf imagick-3.7.0-patch01.tgz imagick-3.7.0 package.xml \
    && print "\n" | pecl install ./imagick-3.7.0-patch01.tgz \
    && rm -rf ./7088edc353f53c4bc644573a79cdcd67a726ae16.diff ./imagick-3.7.0 ./imagick-3.7.0-patch01.tgz ./imagick-3.7.0.tgz ./package.xml \
    && docker-php-ext-enable apcu igbinary imagick msgpack opcache xdebug xhprof \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-xpm --with-webp --with-avif \
    && pecl bundle -d /usr/src/php/ext redis \
    && docker-php-ext-configure redis --enable-redis-session --enable-redis-igbinary --enable-redis-msgpack --enable-redis-lzf --with-liblzf --enable-redis-zstd --with-libzstd --enable-redis-lz4 --with-liblz4 \
    && docker-php-ext-install -j$(nproc) bcmath bz2 calendar exif gd gettext gmp intl ldap mysqli pcntl pdo_mysql pdo_pgsql pgsql redis shmop soap sockets sysvmsg sysvsem sysvshm tidy xsl zip \
    && dpkg-query -f '${Package}\n' -W | grep -e '-dev$' > /tmp/dev-packages.post \
    && cat /tmp/dev-packages.post | fgrep -xvf /tmp/dev-packages.prev > /tmp/dev-packages.append \
    && apt remove -y $(cat /tmp/dev-packages.append) \
    && pecl clear-cache \
    && rm -rf /var/lib/apt/lists/* /tmp/pear/ /tmp/dev-packages.*
