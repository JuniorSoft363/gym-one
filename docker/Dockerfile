FROM php:8.2-apache

# Extensiones que el proyecto necesita:
#   mysqli    -> toda la capa de base de datos (new mysqli(...))
#   gd        -> recorte/redimensionado de las fotos de perfil en register/
#   zip       -> mpdf y el auto-updater de admin/updater/
#   curl      -> comprobacion de version contra api.gymoneglobal.com (ya viene en la imagen)
#   mbstring  -> mpdf (ya viene en la imagen)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libwebp-dev \
        libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" gd mysqli zip \
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/*

# El .htaccess del repo usa sintaxis Apache 2.2 (Order deny,allow), que solo
# funciona con mod_access_compat. Lo habilitamos y ademas protegemos .env en la
# config del servidor, para no depender solo de ese fichero.
RUN a2enmod access_compat rewrite

COPY apache/gymone.conf /etc/apache2/conf-available/gymone.conf
RUN a2enconf gymone

# Nota sobre permisos: el panel reescribe .env y admin/boss/rule/rule.html, y
# register/ guarda fotos en assets/img/profiles/. En Windows no hace falta
# ajustar UIDs: Docker Desktop expone los bind mounts con permisos amplios.
# En Linux/macOS puede que necesites un "chown -R 33:33" sobre esas rutas.

COPY php/gymone.ini /usr/local/etc/php/conf.d/gymone.ini
