[Unit]
Description=Hydrodactyl Queue Worker

[Service]
User=__WEB_USER__
Group=__WEB_USER__
Restart=always
ExecStart=__PHP_BIN__ __PANEL_DIR__/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
