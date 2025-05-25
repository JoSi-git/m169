FROM moodlehq/moodle-php-apache:8.2

# System-Paketliste aktualisieren und nötige Tools installieren
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      wget \
      unzip \
      zip \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Moodle klonen (Branch anpassen nach Bedarf)
RUN git clone --branch MOODLE_500_STABLE https://github.com/moodle/moodle.git /var/www/html

COPY config.php /var/www/html/config.php
# Unser eigenes php.ini-Snippet kopieren
COPY php.ini /usr/local/etc/php/conf.d/99-moodle.ini

# Besitz- und Rechtevergabe
RUN chown -R www-data:www-data /var/www/html /var/www/moodledata \
 && chmod -R 755 /var/www/html \
 && chmod -R 0777 /var/www/moodledata