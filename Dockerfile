# PHP-FPM comum ao EC2 (produção) e ao UNRAID (dev/homologação).
# Base: imagem oficial, reconstruída no dia de cada release de segurança.
# O Dependabot abre PR quando o digest de php:8.5-fpm-alpine muda; o merge
# dispara o CI, que publica ghcr.io/edalcin/php-fpm:latest.
FROM php:8.5-fpm-alpine@sha256:f1bf3e9358dcde762d06df6d54fb213344491a2b31db0aef456ffe6274c91dc6

# Extensões usadas pelos sites (além das que já vêm na base: pdo_sqlite,
# curl, mbstring, iconv, dom, simplexml, sodium, opcache):
#   gd (+freetype/jpeg/webp: imagettf*, imagecreatefromjpeg), mysqli e
#   pdo_mysql (dashboards → mariadb), intl (transliterator_*), bcmath, exif.
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
      freetype-dev libjpeg-turbo-dev libpng-dev libwebp-dev icu-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j"$(nproc)" gd mysqli pdo_mysql intl bcmath exif \
 && apk add --no-cache freetype libjpeg-turbo libpng libwebp icu-libs \
 && apk del .build-deps

# php.ini de produção (display_errors=Off etc.) + limites herdados da imagem
# antiga (tangramor/nginx-php8-fpm).
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
 && printf '%s\n' 'expose_php = Off' 'cgi.fix_pathinfo = 0' \
      'upload_max_filesize = 100M' 'post_max_size = 100M' 'memory_limit = 128M' \
      > "$PHP_INI_DIR/conf.d/docker-vars.ini"

# Não-root por padrão; cada host pode trocar pelo uid dono dos dados
# (--user / user:). FPM escuta em :9000 (zz-docker.conf da base).
USER www-data
