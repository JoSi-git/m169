FROM moodlehq/moodle-php-apache:8.3

LABEL   Maintainer: Silas Gubler <silas.gubler@edu.gbssg.ch> \
        org.opencontainers.image.source="https://github.com/JoSi-git/m169"

# Berechtigungen setzen
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html
