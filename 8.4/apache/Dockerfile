FROM docker.io/library/php:8.4-apache

RUN dpkg-query -f '${Package}\n' -W | grep -e '-dev$' > /tmp/dev-packages.prev \
    && apt update \
    && apt install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng-dev libxpm-dev libwebp-dev libavif-dev libgmp-dev libicu-dev libldap2-dev libmagickwand-dev libpq-dev liblz4-dev liblzf-dev libzstd-dev libtidy-dev libxslt1-dev libzip-dev zip unzip \
    && printf "\n" | pecl install APCu igbinary msgpack xdebug xhprof \
    && pecl download imagick \
    && curl -OL https://github.com/Imagick/imagick/pull/641/commits/7088edc353f53c4bc644573a79cdcd67a726ae16.diff \
    && curl -OL https://github.com/Imagick/imagick/pull/674/commits/3d4d0086bd37e24eaf6800a7c992d2b9fd6d49a2.diff \
    && curl -OL https://github.com/Imagick/imagick/pull/690/commits/65e27f2bc02e7e8f1bf64e26e359e42a1331fca1.diff \
    && tar zxf imagick-3.7.0.tgz \
    && cd imagick-3.7.0 \
    && patch -p1 < ../7088edc353f53c4bc644573a79cdcd67a726ae16.diff \
    && patch -p1 < ../3d4d0086bd37e24eaf6800a7c992d2b9fd6d49a2.diff \
    && patch -p1 < ../65e27f2bc02e7e8f1bf64e26e359e42a1331fca1.diff \
    && cd .. \
    && sed -i -e 's/c2fb6a7536cf6c934cbb3882d8c4abf2/1c87b97bdd653210aa25c80e11a85d46/' -e 's/175640d781b0610d056ce31064301a3e/2c10ce82f569f1baa2b7a5dcc3409121/' -e 's/c3edae5f9afeb059a99aa36ed8952eb8/4641ebb24a1597b2158c4f0e9d9bff61/' package.xml \
    && tar czf imagick-3.7.0-patch01.tgz imagick-3.7.0 package.xml \
    && print "\n" | pecl install ./imagick-3.7.0-patch01.tgz \
    && rm -rf ./7088edc353f53c4bc644573a79cdcd67a726ae16.diff ./3d4d0086bd37e24eaf6800a7c992d2b9fd6d49a2.diff ./65e27f2bc02e7e8f1bf64e26e359e42a1331fca1.diff ./imagick-3.7.0 ./imagick-3.7.0-patch02.tgz ./imagick-3.7.0.tgz ./package.xml \
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
