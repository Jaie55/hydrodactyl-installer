server {
    listen 80;
    listen [::]:80;
    server_name __DOMAIN__;

    root __PANEL_DIR__/public;
    index index.php;

    client_max_body_size 100m;
    fastcgi_read_timeout 300;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
