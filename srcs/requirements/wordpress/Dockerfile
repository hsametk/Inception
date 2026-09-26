FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm \
    php-mysqli \
    php-gd \
    php-curl \
    php-xml \
    php-mbstring \
    php-zip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html
WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["php-fpm8.2", "-F"]
