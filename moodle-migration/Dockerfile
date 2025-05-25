FROM moodlehq/moodle-php-apache:7.4

# Maintainer information
LABEL maintainer="Jonas Sieber (JoSi-git) <jonas.sieber@edu.gbssg.ch>"

# Update system package list and install required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      wget \
      unzip \
      zip \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Clone Moodle (adjust branch as needed)
RUN git clone --branch MOODLE_500_STABLE https://github.com/moodle/moodle.git /var/www/html

# Copy preconfigured config.php (contains DB and Moodle settings)
COPY config.php /var/www/html/config.php

# Copy our custom php.ini snippet
COPY php.ini /usr/local/etc/php/conf.d/99-moodle.ini

# Set ownership and permissions
RUN chown -R www-data:www-data /var/www/html /var/www/moodledata \
 && chmod -R 755 /var/www/html \
 && chmod -R 0777 /var/www/moodledata
