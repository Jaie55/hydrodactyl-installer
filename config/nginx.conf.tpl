server {
    listen __HTTP_PORT__;
    listen [::]:__HTTP_PORT__;
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
        fastcgi_pass unix:/run/php/php__PHP_VERSION__-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
