FROM trafex/php-nginx:latest

COPY index.php /var/www/html/
COPY blue-favicon.png /var/www/html/
COPY green-favicon.png /var/www/html/

ENV foobar=barfur
