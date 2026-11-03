FROM php:8.4-apache-bookworm

ENV APP_ENV=production APP_DEBUG=false LOG_CHANNEL=stderr PORT=8080
WORKDIR /var/www/html

RUN apt-get update && apt-get install -y --no-install-recommends \
    git unzip libpq-dev libsqlite3-dev libicu-dev libzip-dev libonig-dev \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql pdo_sqlite gd intl zip mbstring bcmath exif pcntl opcache \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY . .
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --optimize-autoloader \
    && php artisan package:discover --ansi \
    && chown -R www-data:www-data storage bootstrap/cache

COPY deploy/apache.conf /etc/apache2/sites-available/000-default.conf
RUN printf 'Listen ${PORT}\n' > /etc/apache2/ports.conf
EXPOSE 8080
CMD ["sh", "deploy/start.sh"]
