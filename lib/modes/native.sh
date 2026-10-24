#!/usr/bin/env bash
# shellcheck shell=bash

# Native install mode (Ubuntu/Debian).

WEB_USER="www-data"
PHP_BIN="/usr/bin/php8.4"

install_panel_native() {
    if [[ "$FAMILY" != "debian" ]]; then
        die "$(t msg_native_only_debian "$DISTRO_NAME")"
    fi

    step "$(t menu_panel_native)"

    step "$(t msg_apt_deps)"
    pkg_update
    pkg_install ca-certificates curl gnupg git unzip lsb-release software-properties-common \
        nginx redis-server "${DB_KIND}-server"

    step "$(t msg_php_ppa)"
    if [[ "$DISTRO_ID" == "debian" ]]; then
        if [[ ! -f /etc/apt/sources.list.d/php.list ]]; then
            curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg
            printf 'deb https://packages.sury.org/php/ %s main\n' "$(lsb_release -sc)" \
                >/etc/apt/sources.list.d/php.list
            pkg_update
        fi
    elif ! grep -rqs "ondrej/php" /etc/apt/sources.list.d/; then
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        pkg_update
    fi

    step "$(t msg_php)"
    pkg_install php8.4-cli php8.4-fpm php8.4-common php8.4-gd php8.4-mysql php8.4-mbstring \
        php8.4-bcmath php8.4-xml php8.4-curl php8.4-zip php8.4-intl php8.4-sqlite3 php8.4-redis

    step "$(t msg_node)"
    if ! has_cmd node || ! has_cmd pnpm; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        pkg_install nodejs
    fi
    if ! has_cmd pnpm; then
        corepack enable || true
        corepack prepare pnpm@latest --activate || true
    fi
    has_cmd pnpm || npm install -g pnpm

    step "$(t msg_composer)"
    if ! has_cmd composer; then
        curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
        "$PHP_BIN" /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm -f /tmp/composer-setup.php
    fi

    fetch_panel

    local use_ssl="$SSL"
    if [[ "$use_ssl" -eq 1 ]] && is_local_domain "$DOMAIN"; then
        warn "$(t msg_ssl_local "$DOMAIN")"
        use_ssl=0
    fi

    if [[ "$DEPLOY_ENV" == "production" ]]; then
        if is_local_domain "$DOMAIN"; then
            warn "$(t warn_prod_local "$DOMAIN")"
            confirm "$(t confirm_prod_local)" n || exit 0
        fi
        [[ "$use_ssl" -eq 1 ]] || warn "$(t warn_prod_nossl)"
    fi

    step "$(t msg_db_creating)"
    systemctl enable --now "${DB_KIND}"
    local dbpass
    if [[ -f "$PANEL_DIR/.env" ]] && grep -qE '^DB_PASSWORD=.+' "$PANEL_DIR/.env"; then
        dbpass="$(grep -E '^DB_PASSWORD=' "$PANEL_DIR/.env" | head -n1 | cut -d= -f2-)"
    else
        dbpass="$(random_password)"
    fi
    mysql -e "CREATE DATABASE IF NOT EXISTS panel;
        CREATE USER IF NOT EXISTS 'hydrodactyl'@'127.0.0.1' IDENTIFIED BY '${dbpass}';
        ALTER USER 'hydrodactyl'@'127.0.0.1' IDENTIFIED BY '${dbpass}';
        GRANT ALL PRIVILEGES ON panel.* TO 'hydrodactyl'@'127.0.0.1';
        FLUSH PRIVILEGES;"

    step "$(t msg_env)"
    local appurl
    if [[ "$use_ssl" -eq 1 ]]; then appurl="https://$DOMAIN"; else appurl="http://$DOMAIN"; fi

    cd "$PANEL_DIR" || die "Cannot enter $PANEL_DIR"
    [[ -f .env ]] || cp .env.example .env

    set_env APP_ENV production
    set_env APP_URL "$appurl"
    set_env APP_TIMEZONE UTC
    set_env APP_SERVICE_AUTHOR "noreply@$DOMAIN"
    set_env DB_CONNECTION mysql
    set_env DB_HOST 127.0.0.1
    set_env DB_PORT 3306
    set_env DB_DATABASE panel
    set_env DB_USERNAME hydrodactyl
    set_env DB_PASSWORD "$dbpass"
    set_env CACHE_STORE database
    set_env REDIS_HOST 127.0.0.1
    if [[ "$DEPLOY_ENV" == "test" ]]; then
        set_env APP_DEBUG true
    else
        set_env APP_DEBUG false
    fi

    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
    pnpm install --frozen-lockfile
    pnpm run build

    step "$(t msg_key)"
    "$PHP_BIN" artisan key:generate --force

    step "$(t msg_migrate)"
    "$PHP_BIN" artisan migrate --seed --force

    if [[ "$DEPLOY_ENV" == "production" ]]; then
        "$PHP_BIN" artisan optimize
    else
        "$PHP_BIN" artisan optimize:clear
    fi

    step "$(t msg_perms)"
    mkdir -p "$PANEL_DIR"/storage/{app/public,framework/{cache/data,sessions,views},logs}
    chown -R "$WEB_USER":"$WEB_USER" "$PANEL_DIR"
    chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
    "$PHP_BIN" artisan storage:link || true

    step "$(t msg_nginx)"
    local vhost=/etc/nginx/sites-available/hydrodactyl.conf
    sed -e "s|__DOMAIN__|$DOMAIN|g" -e "s|__PANEL_DIR__|$PANEL_DIR|g" \
        "$SCRIPT_DIR/config/nginx.conf.tpl" >"$vhost"
    ln -sf "$vhost" /etc/nginx/sites-enabled/hydrodactyl.conf
    rm -f /etc/nginx/sites-enabled/default
    nginx -t || die "nginx configuration test failed"
    systemctl reload nginx
    systemctl enable --now php8.4-fpm

    step "$(t msg_cron)"
    if ! crontab -l 2>/dev/null | grep -qF "artisan schedule:run"; then
        (crontab -l 2>/dev/null || true
            echo "* * * * * $PHP_BIN $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab -
    fi

    step "$(t msg_queue)"
    sed -e "s|__WEB_USER__|$WEB_USER|g" -e "s|__PHP_BIN__|$PHP_BIN|g" -e "s|__PANEL_DIR__|$PANEL_DIR|g" \
        "$SCRIPT_DIR/config/pyroq.service.tpl" >/etc/systemd/system/pyroq.service
    systemctl daemon-reload
    systemctl enable --now pyroq.service

    if [[ "$use_ssl" -eq 1 ]]; then
        step "$(t msg_ssl)"
        local le_email=''
        ask le_email "$(t prompt_le_email)"
        pkg_install certbot python3-certbot-nginx
        if [[ -n "$le_email" ]]; then
            certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$le_email" --redirect ||
                warn "certbot failed; the panel is still available over HTTP."
        else
            warn "No email provided, skipping Let's Encrypt."
        fi
    fi

    step "$(t msg_verify)"
    "$PHP_BIN" artisan --version >/dev/null || die "artisan does not run"
    if [[ "$VERIFY" -eq 0 ]]; then
        info "$(t msg_verify_skipped)"
        return
    fi
    local i
    # shellcheck disable=SC2034 # loop counter only
    for i in $(seq 1 20); do
        if curl -fsS -o /dev/null --resolve "$DOMAIN:80:127.0.0.1" "http://$DOMAIN/auth/login"; then
            ok "$(t msg_panel_url "$appurl")"
            return
        fi
        sleep 3
    done
    warn "$(t msg_verify_hint "$appurl")"
}
