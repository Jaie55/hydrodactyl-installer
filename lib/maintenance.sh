#!/usr/bin/env bash
# shellcheck shell=bash

# Update and uninstall actions.

panel_native_installed() { [[ -f "$PANEL_DIR/artisan" ]]; }
panel_docker_installed() { [[ -f "$PANEL_DIR/docker-compose.yml" ]] && has_cmd docker; }
daemon_installed() { [[ -x "/usr/local/bin/$1" ]]; }

panel_current_ref() {
    git -C "$PANEL_DIR" describe --tags --always 2>/dev/null || printf '?'
}

panel_latest_tag() {
    git ls-remote --tags --refs "$PANEL_UPSTREAM_REPO" 'v*' |
        awk -F/ '{print $NF}' | sort -V | tail -n1
}

daemon_current_version() {
    "/usr/local/bin/$1" version 2>/dev/null | head -n1 | awk '{print $2}'
}

daemon_latest_tag() {
    local repo="pterodactyl/wings"
    [[ "$1" == "elytra" ]] && repo="pyrohost/elytra"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null |
        sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

native_php_bin() {
    local bin
    bin="$(find /usr/bin -maxdepth 1 -name 'php8.*' 2>/dev/null | sort -V | tail -n1)"
    if [[ -n "$bin" ]]; then printf '%s' "$bin"; else printf 'php'; fi
}

check_updates() {
    local current latest found=0 bin
    step "$(t upd_check)"

    if panel_native_installed; then
        found=1
        current="$(panel_current_ref)"
        latest="$(panel_latest_tag || true)"
        info "$(t upd_panel_versions "$current" "${latest:-?}")"
        if [[ -n "$latest" && "$current" == "$latest" ]]; then
            ok "$(t upd_panel_current)"
        else
            warn "$(t upd_panel_available)"
        fi
    fi
    if panel_docker_installed; then
        found=1
        info "$(t upd_panel_docker_check)"
    fi
    for bin in wings elytra; do
        if daemon_installed "$bin"; then
            found=1
            current="$(daemon_current_version "$bin")"
            latest="$(daemon_latest_tag "$bin" || true)"
            info "$(t upd_daemon_versions "$bin" "${current:-?}" "${latest:-?}")"
            if [[ -n "$current" && "$current" == "$latest" ]]; then
                ok "$(t upd_daemon_current "$bin")"
            else
                warn "$(t upd_daemon_available "$bin")"
            fi
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        warn "$(t msg_nothing_installed)"
    fi
}

update_panel_native() {
    local latest php_bin
    latest="$(panel_latest_tag || true)"
    if [[ -z "$latest" ]]; then
        warn "$(t err_no_tags)"
        return 1
    fi
    step "$(t upd_updating_panel "$latest")"
    git -C "$PANEL_DIR" fetch --depth=1 origin "$latest"
    git -C "$PANEL_DIR" reset --hard FETCH_HEAD
    (
        cd "$PANEL_DIR" || exit 1
        COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction \
            --prefer-dist --optimize-autoloader
        pnpm install --frozen-lockfile
        pnpm run build
    )
    php_bin="$(native_php_bin)"
    "$php_bin" "$PANEL_DIR/artisan" optimize:clear >/dev/null 2>&1 || true
    "$php_bin" "$PANEL_DIR/artisan" migrate --force
    "$php_bin" "$PANEL_DIR/artisan" optimize
    chown -R "$WEB_USER":"$WEB_USER" "$PANEL_DIR"
    systemctl reload "$(basename "$php_bin")-fpm" >/dev/null 2>&1 || true
    systemctl reload nginx >/dev/null 2>&1 || true
    systemctl restart pyroq.service >/dev/null 2>&1 || true
    ok "$(t upd_done)"
}

update_panel_docker() {
    step "$(t upd_updating_docker)"
    (cd "$PANEL_DIR" && docker compose pull && docker compose up -d)
    ok "$(t upd_done)"
}

update_daemon() {
    local bin="$1" saved="$DAEMON_VERSION"
    step "$(t upd_updating_daemon "$bin")"
    DAEMON_VERSION=""
    download "$(daemon_binary_url "$bin")" "/usr/local/bin/$bin"
    DAEMON_VERSION="$saved"
    chmod +x "/usr/local/bin/$bin"
    systemctl restart "$bin" >/dev/null 2>&1 || true
    ok "$(t upd_done)"
}

update_all() {
    local bin did=0
    if [[ -z "$UPDATE_TARGET" || "$UPDATE_TARGET" == "panel" ]]; then
        if panel_native_installed; then update_panel_native; did=1; fi
        if panel_docker_installed; then update_panel_docker; did=1; fi
    fi
    if [[ -z "$UPDATE_TARGET" || "$UPDATE_TARGET" == "daemon" ]]; then
        for bin in wings elytra; do
            if daemon_installed "$bin"; then update_daemon "$bin"; did=1; fi
        done
    fi
    if [[ "$did" -eq 0 ]]; then
        warn "$(t msg_nothing_installed)"
    fi
}

uninstall_panel_native() {
    local db_name db_user
    confirm "$(t confirm_uninstall_panel "$PANEL_DIR")" n || return 0

    db_name="panel"
    db_user="hydrodactyl"
    if [[ -f "$PANEL_DIR/.env" ]]; then
        db_name="$(grep -E '^DB_DATABASE=' "$PANEL_DIR/.env" | head -n1 | cut -d= -f2- || true)"
        db_user="$(grep -E '^DB_USERNAME=' "$PANEL_DIR/.env" | head -n1 | cut -d= -f2- || true)"
        [[ -n "$db_name" ]] || db_name=panel
        [[ -n "$db_user" ]] || db_user=hydrodactyl
    fi

    systemctl disable --now pyroq.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/pyroq.service
    systemctl daemon-reload
    rm -f /etc/nginx/sites-enabled/hydrodactyl.conf /etc/nginx/sites-available/hydrodactyl.conf
    systemctl reload nginx >/dev/null 2>&1 || true
    if crontab -l 2>/dev/null | grep -qF "artisan schedule:run"; then
        crontab -l 2>/dev/null | grep -vF "artisan schedule:run" | crontab - || true
    fi
    rm -rf "$PANEL_DIR"

    if [[ "$PURGE" -eq 1 ]]; then
        mysql -e "DROP DATABASE IF EXISTS \`$db_name\`; DROP USER IF EXISTS '$db_user'@'127.0.0.1';" ||
            warn "$(t msg_db_drop_failed)"
        ok "$(t uninst_panel_done)"
    else
        ok "$(t uninst_panel_done_keep_db)"
    fi
}

uninstall_panel_docker() {
    confirm "$(t confirm_uninstall_panel "$PANEL_DIR")" n || return 0
    (cd "$PANEL_DIR" && docker compose down)
    rm -rf "$PANEL_DIR"
    if [[ "$PURGE" -eq 1 ]]; then
        rm -rf /srv/pterodactyl
    fi
    ok "$(t uninst_panel_done)"
}

uninstall_daemon() {
    local bin="$1"
    confirm "$(t confirm_uninstall_daemon "$bin")" n || return 0
    systemctl disable --now "$bin" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/$bin.service"
    systemctl daemon-reload
    rm -f "/usr/local/bin/$bin"
    rm -f /etc/pterodactyl/config.yml
    if [[ "$PURGE" -eq 1 ]]; then
        rm -rf /var/lib/pterodactyl /etc/pterodactyl
    fi
    ok "$(t uninst_daemon_done "$bin")"
}

uninstall_all() {
    local target="$UNINSTALL_TARGET" bin choice=''
    if [[ -z "$target" ]]; then
        if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
            target=all
        else
            printf '\n%s%s%s:\n' "$C_BOLD" "$(t uninst_title)" "$C_RESET"
            printf '  1) %s\n  2) %s\n  3) %s\n' \
                "$(t uninst_choice_panel)" "$(t uninst_choice_daemon)" "$(t uninst_choice_all)"
            read -r -p "$(t prompt_uninst_choice) [1/2/3]: " choice || true
            case "${choice:-3}" in
                1) target=panel ;;
                2) target=daemon ;;
                3) target=all ;;
                *) die "$(t msg_invalid_choice)" ;;
            esac
        fi
    fi

    case "$target" in
        panel)
            panel_native_installed && uninstall_panel_native
            panel_docker_installed && uninstall_panel_docker
            ;;
        daemon)
            for bin in wings elytra; do
                daemon_installed "$bin" && uninstall_daemon "$bin"
            done
            ;;
        wings | elytra)
            daemon_installed "$target" && uninstall_daemon "$target"
            ;;
        all)
            panel_native_installed && uninstall_panel_native
            panel_docker_installed && uninstall_panel_docker
            for bin in wings elytra; do
                daemon_installed "$bin" && uninstall_daemon "$bin"
            done
            ;;
    esac
}
