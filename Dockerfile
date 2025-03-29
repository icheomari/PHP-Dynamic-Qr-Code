##############################
# Stage 1: Builder
##############################
FROM php:8.3-cli AS builder

# (Optional) Adjust Debian sources for Debian 9 if needed.
RUN if [ "$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"')" -eq "9" ]; then \
      sed -i -e 's/deb.debian.org/archive.debian.org/g' \
             -e 's/security.debian.org/archive.debian.org/g' \
             -e '/stretch-updates/d' /etc/apt/sources.list; \
    fi

# Install build dependencies
RUN apt-get update -q && \
    apt-get install -qq -y \
      curl \
      git \
      libzip-dev \
      libjpeg62-turbo-dev \
      libpng-dev \
      libfreetype6-dev \
      unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download docker-php-extension-installer and make it executable
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions

# Install PHP extensions (build-time)
RUN install-php-extensions \
      amqp \
      bcmath \
      bz2 \
      calendar \
      event \
      exif \
      gd \
      gettext \
      intl \
      ldap \
      memcached \
      mysqli \
      opcache \
      pdo_mysql \
      pdo_pgsql \
      pgsql \
      redis \
      soap \
      sockets \
      xsl \
      zip \
      # Install Imagick using a specific tarball for PHP>=8.3:
      https://api.github.com/repos/Imagick/imagick/tarball/28f27044e435a2b203e32675e942eb8de620ee58

# Install Composer (Composer 2)
RUN curl -sSL https://getcomposer.org/installer -o composer-setup.php && \
    curl -sSL https://composer.github.io/installer.sha384sum -o composer-setup.sha384sum && \
    sha384sum --check composer-setup.sha384sum && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer --2 && \
    rm composer-setup.php composer-setup.sha384sum

# Prepare application files: Clone php-qrcode repository and copy needed files.
WORKDIR /opt
RUN git clone https://github.com/chillerlan/php-qrcode.git && \
    chmod -R 777 php-qrcode && \
    cp php-qrcode/composer.json /var/www/html/composer.json && \
    mkdir -p /var/www/html/test && chmod 777 /var/www/html/test && \
    cp php-qrcode/examples/image.php /var/www/html/test/image.php && \
    cp -R php-qrcode/src /var/www/html/

# Copy your application source code (assumed to be in ./src relative to the Dockerfile)
WORKDIR /var/www/html
COPY ./src ./ 
RUN composer update --no-dev --optimize-autoloader

# Ensure proper permissions for application files
RUN chmod -R 755 /var/www/html

##############################
# Stage 2: Final Runtime Image
##############################
FROM php:8.3-cli

# Install runtime dependencies and required libraries.
RUN apt-get update -q && \
    apt-get install -qq -y \
      libzip-dev \
      libjpeg62-turbo-dev \
      libpng-dev \
      libfreetype6-dev \
      unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install only the PHP extensions needed at runtime.
RUN docker-php-ext-install \
      pdo_mysql \
      zip \
      exif \
      pcntl \
      gd \
      mysqli \
      gettext \
      sockets && \
    docker-php-ext-enable mysqli gettext sockets

WORKDIR /var/www/html

# Copy the built application from the builder stage.
COPY --from=builder /var/www/html /var/www/html

EXPOSE 80

# Use PHP's built-in server to run the application.
CMD ["php", "-S", "0.0.0.0:80"]
