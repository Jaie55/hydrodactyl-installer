#!/usr/bin/env bash
# shellcheck shell=bash

# Update and uninstall actions.

panel_native_installed() { [[ -f "$PANEL_DIR/artisan" ]]; }
panel_docker_installed() { [[ -f "$PANEL_DIR/docker-compose.yml" ]] && has_cmd docker; }
daemon_installed() { [[ -x "/usr/local/bin/$1" ]]; }

panel_current_ref() {
    git -C "$PANEL_DIR" describe --tags --always 2>/dev/null || printf '?'
}

panel_current_branch() {
    git -C "$PANEL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true
}

panel_repo_url() {
    git -C "$PANEL_DIR" remote get-url origin 2>/dev/null || printf '%s' "$PANEL_UPSTREAM_REPO"
}

panel_latest_tag() {
    local repo="${1:-$PANEL_UPSTREAM_REPO}"
    git ls-remote --tags --refs "$repo" 'v*' |
        awk -F/ '{print $NF}' | sort -V | tail -n1
}

panel_update_ref() {
    local repo branch
    repo="$(panel_repo_url)"
    branch="$(panel_current_branch)"
    if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
        printf '%s' "$branch"
        return 0
    fi
    panel_latest_tag "$repo"
}

panel_latest_for_check() {
    local repo branch
    repo="$(panel_repo_url)"
    branch="$(panel_current_branch)"
    if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
        git ls-remote --heads "$repo" "refs/heads/$branch" 2>/dev/null | awk '{print $1}' | head -n1
    else
        panel_latest_tag "$repo"
    fi
}

panel_env_value() {
    local key="$1" value
    [[ -f "$PANEL_DIR/.env" ]] || return 0
    value="$(grep -E "^${key}=" "$PANEL_DIR/.env" | head -n1 | cut -d= -f2- || true)"
    value="${value%\"}"
    value="${value#\"}"
    printf '%s' "$value"
}

backup_panel_db() {
    local db user pass host file
    if [[ ! -f "$PANEL_DIR/.env" ]] || ! has_cmd mysqldump; then
        return 0
    fi
    db="$(panel_env_value DB_DATABASE)"; db="${db:-panel}"
    user="$(panel_env_value DB_USERNAME)"; user="${user:-hydrodactyl}"
    pass="$(panel_env_value DB_PASSWORD)"
    host="$(panel_env_value DB_HOST)"; host="${host:-127.0.0.1}"
    mkdir -p /var/backups
    file="/var/backups/hydrodactyl-$(date +%Y%m%d-%H%M%S).sql.gz"
    if MYSQL_PWD="$pass" mysqldump -h "$host" -u "$user" "$db" 2>/dev/null | gzip >"$file"; then
        chmod 600 "$file"
        ok "$(t msg_db_backup "$file")"
    else
        rm -f "$file"
        warn "$(t msg_db_backup_failed)"
    fi
}

daemon_current_version() {
    daemon_version_string "$1"
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
    local current latest found=0 bin branch local_head
    step "$(t upd_check)"

    if panel_native_installed; then
        found=1
        branch="$(panel_current_branch)"
        local_head="$(git -C "$PANEL_DIR" rev-parse HEAD 2>/dev/null || true)"
        current="$(panel_current_ref)"
        latest="$(panel_latest_for_check || true)"
        if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
            current="$branch@${local_head:0:7}"
            if [[ -n "$latest" && "$latest" == "$local_head" ]]; then
                latest="$current"
            else
                latest="$branch@${latest:0:7}"
            fi
        fi
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
    local ref php_bin
    ref="$(panel_update_ref || true)"
    if [[ -z "$ref" ]]; then
        warn "$(t err_no_tags)"
        return 1
    fi
    step "$(t upd_updating_panel "$ref")"
    php_bin="$(native_php_bin)"
    backup_panel_db
    "$php_bin" "$PANEL_DIR/artisan" down >/dev/null 2>&1 || true

    if ! (
        cd "$PANEL_DIR" || exit 1
        git fetch --depth=1 origin "$ref"
        git reset --hard FETCH_HEAD
        COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction \
            --prefer-dist --optimize-autoloader
        pnpm install --frozen-lockfile
        pnpm run build
        "$php_bin" artisan optimize:clear >/dev/null 2>&1 || true
        "$php_bin" artisan migrate --force
        "$php_bin" artisan optimize
    ); then
        "$php_bin" "$PANEL_DIR/artisan" up >/dev/null 2>&1 || true
        warn "$(t upd_failed)"
        return 1
    fi

    chown -R "$WEB_USER":"$WEB_USER" "$PANEL_DIR"
    systemctl reload "$(basename "$php_bin")-fpm" >/dev/null 2>&1 || true
    systemctl reload nginx >/dev/null 2>&1 || true
    systemctl restart pyroq.service >/dev/null 2>&1 || true
    "$php_bin" "$PANEL_DIR/artisan" up >/dev/null 2>&1 || true
    ok "$(t upd_done)"
}

update_panel_docker() {
    step "$(t upd_updating_docker)"
    warn "$(t warn_docker_backup)"
    (cd "$PANEL_DIR" && docker compose pull && docker compose up -d)
    ok "$(t upd_done)"
}

update_daemon() {
    local bin="$1" saved="$DAEMON_VERSION"
    step "$(t upd_updating_daemon "$bin")"
    DAEMON_VERSION=""
    has_cmd jq || pkg_install jq
    install_daemon_binary "$bin"
    DAEMON_VERSION="$saved"
    systemctl restart "$bin" >/dev/null 2>&1 || true
    ok "$(t upd_done)"
}

update_all() {
    local bin did=0 failed=0
    if [[ -z "$UPDATE_TARGET" || "$UPDATE_TARGET" == "panel" ]]; then
        if panel_native_installed; then update_panel_native || failed=1; did=1; fi
        if panel_docker_installed; then update_panel_docker || failed=1; did=1; fi
    fi
    if [[ -z "$UPDATE_TARGET" || "$UPDATE_TARGET" == "daemon" ]]; then
        for bin in wings elytra; do
            if daemon_installed "$bin"; then update_daemon "$bin" || failed=1; did=1; fi
        done
    fi
    if [[ "$did" -eq 0 ]]; then
        warn "$(t msg_nothing_installed)"
    fi
    [[ "$failed" -eq 0 ]]
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
    return 0
}
