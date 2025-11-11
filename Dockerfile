FROM php:8.3-fpm-alpine3.22

RUN apk add --no-cache \
    libzip-dev \
    libstdc++ \
    libgcc \
    libpng-dev \
    postgresql-dev \
    nodejs \
    npm \
    $PHPIZE_DEPS

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN docker-php-ext-install pdo pgsql pdo_pgsql gd bcmath zip \
    && pecl install redis \
    && docker-php-ext-enable redis

WORKDIR /var/www/html

# Copy composer files
COPY composer.json composer.lock ./

# Install PHP dependencies (production only)
RUN sed 's_@php artisan package:discover_/bin/true_;' -i composer.json \
    && composer install --ignore-platform-req=php --no-dev --optimize-autoloader \
    && composer clear-cache

# Copy and install Node dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy app source code
COPY . .

RUN npm run build

RUN set -eux; \
    mkdir -p storage/framework/{sessions,views,cache} bootstrap/cache; \
    chown -R www-data:www-data storage bootstrap/cache; \
    chmod -R 755 storage bootstrap/cache; \
    chmod 600 storage/oauth-*.key || true

CMD ["php-fpm"]
