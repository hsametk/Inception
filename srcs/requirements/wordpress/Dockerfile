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

# wp-cli: the tool the entrypoint uses to download/configure/install WordPress.
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Pool config: makes php-fpm listen on 0.0.0.0:9000 instead of the default 127.0.0.1 socket,
# so the nginx container (a different container = a different "host") can reach it.
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Init script: downloads/installs WordPress into the volume on first boot, then runs php-fpm.
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html
WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# -F = stay in the foreground (no daemonizing) -> php-fpm is PID 1.
CMD ["php-fpm8.2", "-F"]
