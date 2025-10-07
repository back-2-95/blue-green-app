FROM trafex/php-nginx

COPY index.php /var/www/html/
COPY blue-favicon.png /var/www/html/
COPY green-favicon.png /var/www/html/
