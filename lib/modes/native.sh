#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2153 # DB_* and the other globals are set in install.sh

# Native install mode (Ubuntu/Debian).

WEB_USER="www-data"

install_panel_native() {
    if [[ "$FAMILY" != "debian" ]]; then
        die "$(t msg_native_only_debian "$DISTRO_NAME")"
    fi

    local PHP_BIN="/usr/bin/php${PHP_VERSION}"
    local codename="$DISTRO_CODENAME"
    local use_sury=0
    step "$(t step_panel_native)"

    # ondrej/php no longer publishes for every Ubuntu release (e.g. 26.04):
    # fall back to packages.sury.org and drop a broken PPA entry if present.
    if [[ "$DISTRO_ID" == "debian" ]]; then
        use_sury=1
    elif [[ -n "$codename" ]] && ! curl -fsI \
        "https://ppa.launchpadcontent.net/ondrej/php/ubuntu/dists/${codename}/Release" \
        >/dev/null 2>&1; then
        use_sury=1
    fi
    if [[ "$use_sury" -eq 1 ]]; then
        rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.sources \
            /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list
    fi

    step "$(t msg_apt_deps)"
    pkg_update
    pkg_install ca-certificates curl gnupg git unzip lsb-release software-properties-common \
        nginx redis-server "${DB_KIND}-server"

    step "$(t msg_php_ppa)"
    if [[ "$use_sury" -eq 1 ]]; then
        if [[ "$DISTRO_ID" != "debian" ]]; then
            warn "$(t msg_php_repo_fallback "$codename")"
        fi
        curl -fsSL https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg
        printf 'deb https://packages.sury.org/php/ %s main\n' "$codename" \
            >/etc/apt/sources.list.d/php.list
        pkg_update
    elif ! grep -rqs "ondrej/php" /etc/apt/sources.list.d/; then
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        pkg_update
    fi

    step "$(t msg_php)"
    pkg_install "php${PHP_VERSION}-cli" "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-common" \
        "php${PHP_VERSION}-gd" "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-bcmath" "php${PHP_VERSION}-xml" "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-zip" "php${PHP_VERSION}-intl" "php${PHP_VERSION}-sqlite3" \
        "php${PHP_VERSION}-redis"

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
    if [[ "$use_ssl" -eq 1 && "$HTTP_PORT" != "80" ]]; then
        warn "$(t warn_ssl_port "$HTTP_PORT")"
    fi

    local scheme="http"
    [[ "$use_ssl" -eq 1 ]] && scheme="https"
    local appurl
    appurl="$(panel_app_url "$scheme" "$DOMAIN" "$HTTP_PORT")"

    step "$(t msg_db_creating)"
    systemctl enable --now "${DB_KIND}"
    systemctl enable --now redis-server || true
    local dbpass="$DB_PASS"
    if [[ -f "$PANEL_DIR/.env" ]] && grep -qE '^DB_PASSWORD=.+' "$PANEL_DIR/.env"; then
        dbpass="$(grep -E '^DB_PASSWORD=' "$PANEL_DIR/.env" | head -n1 | cut -d= -f2-)"
    fi
    [[ -n "$dbpass" ]] || dbpass="$(random_password)"
    mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
        CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${dbpass}';
        ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${dbpass}';
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
        FLUSH PRIVILEGES;"

    step "$(t msg_env)"
    cd "$PANEL_DIR" || die "Cannot enter $PANEL_DIR"
    [[ -f .env ]] || cp .env.example .env

    set_env APP_ENV production
    set_env APP_URL "$appurl"
    set_env APP_TIMEZONE "$TIMEZONE"
    set_env APP_LOCALE "$APP_LOCALE"
    set_env APP_SERVICE_AUTHOR "noreply@$DOMAIN"
    set_env DB_CONNECTION mysql
    set_env DB_HOST 127.0.0.1
    set_env DB_PORT 3306
    set_env DB_DATABASE "$DB_NAME"
    set_env DB_USERNAME "$DB_USER"
    set_env DB_PASSWORD "$dbpass"
    set_env CACHE_STORE file
    set_env REDIS_HOST 127.0.0.1
    if [[ "$DEPLOY_ENV" == "test" ]]; then
        set_env APP_DEBUG true
    else
        set_env APP_DEBUG false
    fi

    # The panel boots the encrypter early, so artisan cannot run without a
    # key. Write one here instead of relying on artisan key:generate.
    step "$(t msg_key)"
    if ! grep -qE '^APP_KEY=base64:.+' .env; then
        set_env APP_KEY "base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
    fi

    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader
    pnpm install --frozen-lockfile
    pnpm run build

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
    sed -e "s|__DOMAIN__|$DOMAIN|g" \
        -e "s|__PANEL_DIR__|$PANEL_DIR|g" \
        -e "s|__HTTP_PORT__|$HTTP_PORT|g" \
        -e "s|__PHP_VERSION__|$PHP_VERSION|g" \
        "$SCRIPT_DIR/config/nginx.conf.tpl" >"$vhost"
    ln -sf "$vhost" /etc/nginx/sites-enabled/hydrodactyl.conf
    rm -f /etc/nginx/sites-enabled/default
    nginx -t || die "nginx configuration test failed"
    systemctl enable --now "php${PHP_VERSION}-fpm"
    systemctl reload nginx

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
            if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$le_email" --redirect; then
                set_env APP_URL "https://$DOMAIN"
                appurl="https://$DOMAIN"
                if [[ "$DEPLOY_ENV" == "production" ]]; then
                    "$PHP_BIN" artisan optimize >/dev/null
                else
                    "$PHP_BIN" artisan optimize:clear >/dev/null
                fi
            else
                warn "$(t msg_certbot_failed)"
            fi
        else
            warn "$(t msg_no_email)"
        fi
    fi

    configure_firewall "$HTTP_PORT" 443

    step "$(t msg_verify)"
    "$PHP_BIN" artisan --version >/dev/null || die "artisan does not run"
    if [[ "$VERIFY" -eq 0 ]]; then
        info "$(t msg_verify_skipped)"
        return
    fi
    local i
    # shellcheck disable=SC2034 # loop counter only
    for i in $(seq 1 20); do
        if curl -fsS -o /dev/null --resolve "$DOMAIN:${HTTP_PORT}:127.0.0.1" \
            "http://${DOMAIN}:${HTTP_PORT}/auth/login"; then
            ok "$(t msg_panel_url "$appurl")"
            return
        fi
        sleep 3
    done
    warn "$(t msg_verify_hint "$appurl")"
}
