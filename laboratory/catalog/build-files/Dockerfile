FROM debian:bullseye-slim

ENV PHP_INI_DIR=/usr/local/etc/php
ENV PHPIZE_DEPS=autoconf
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:${PATH}"


RUN set -e && apt update -y && apt install -y build-essential autoconf libtool bison re2c pkg-config &&\
    export PHP_URL=https://github.com/php/php-src/archive/c730aa26bd52829a49f2ad284b181b7e82a68d7d.tar.gz &&\
    /bin/sh -c set -eux && \ 
    mkdir -p $PHP_INI_DIR/conf.d && \
    savedAptMark="$(apt-mark showmanual)" && \
    apt-get update  &&  \
    apt-get install -y --no-install-recommends  ${PHPIZE_DEPS} ca-certificates curl wget \
    libargon2-dev libcurl4-openssl-dev libedit-dev libonig-dev libsodium-dev \
    libsqlite3-dev libssl-dev libxml2-dev zlib1g-dev \
    default-libmysqlclient-dev libmariadb-dev redis-server && \
    mkdir -p /usr/src && \
    cd /usr/src   && \
    curl -#SL ${PHP_URL} | tar xz --strip-components=1 && \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" && \ 
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" && \
    if [ ! -d /usr/include/curl ]; then ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; fi &&  \
    mkdir -p /usr/src/php/ext/redis && \
    curl -L https://github.com/phpredis/phpredis/archive/5.3.7.tar.gz | tar xz -C /usr/src/php/ext/redis --strip-components=1 && \
    ./buildconf && \
    ./configure --build="$gnuArch" --with-config-file-path="$PHP_INI_DIR" --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --enable-option-checking=fatal \
    --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data \
    --with-mhash --with-pic --enable-ftp --enable-mbstring --enable-mysqlnd \
    --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-password-argon2 \
    --with-sodium=shared --with-pdo-sqlite=/usr --with-sqlite3=/usr --with-curl --with-libedit --with-openssl --with-zlib \
      $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') --with-libdir="lib/$debMultiarch" && \
    make -j "$(nproc)" && \
    make install && \
    # Compile Redis extension separately
    cd /usr/src/php/ext/redis && \
    /usr/local/bin/phpize && \
    ./configure --with-php-config=/usr/local/bin/php-config && \
    make && make install && \
    # Enable Redis extension
    echo "extension=redis.so" > $PHP_INI_DIR/conf.d/redis.ini


COPY code/ /var/www/html/

WORKDIR /var/www/html

RUN chown -R www-data:www-data /var/www/html

RUN mkdir -p /usr/local/etc/ && \
    echo '[www]' > /usr/local/etc/php-fpm.conf && \
    echo 'user = www-data' >> /usr/local/etc/php-fpm.conf && \
    echo 'group = www-data' >> /usr/local/etc/php-fpm.conf && \
    echo 'listen = 0.0.0.0:9000' >> /usr/local/etc/php-fpm.conf && \
    echo 'pm = dynamic' >> /usr/local/etc/php-fpm.conf && \
    echo 'pm.max_children = 5' >> /usr/local/etc/php-fpm.conf && \
    echo 'pm.start_servers = 2' >> /usr/local/etc/php-fpm.conf && \
    echo 'pm.min_spare_servers = 1' >> /usr/local/etc/php-fpm.conf && \
    echo 'pm.max_spare_servers = 3' >> /usr/local/etc/php-fpm.conf


RUN useradd -m web && \
    mkdir -p /home/web && \
    chown -R web:web /home/web && \
    chmod 777 /home/web && \
    echo 'Extreme{a2c7b36a1ac465add901aee890849f96330b29bc}' > /home/web/flag.txt

EXPOSE 9000

CMD ["php-fpm", "-F"]