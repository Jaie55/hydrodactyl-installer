#!/usr/bin/env bash
# shellcheck shell=bash

# Docker install mode: uses the official docker-compose file.

install_panel_docker() {
    step "$(t menu_panel_docker)"

    if [[ "$SOURCE" != "stable" ]]; then
        warn "$(t msg_docker_source_ignored)"
    fi

    if ! has_cmd docker || ! docker compose version >/dev/null 2>&1; then
        warn "$(t msg_docker_missing)"
        confirm "$(t confirm_install_docker)" y || die "$(t msg_docker_missing)"
        step "$(t msg_docker_installing)"
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi

    has_cmd git || pkg_install git

    mkdir -p /srv/pterodactyl/{database,var,nginx,certs,logs,storage}
    mkdir -p "$PANEL_DIR"

    if [[ -f "$PANEL_DIR/docker-compose.yml" ]]; then
        info "$(t msg_docker_reuse "$PANEL_DIR/docker-compose.yml")"
    else
        step "$(t msg_docker_compose)"
        resolve_panel_ref
        local tmpdir
        tmpdir="$(mktemp -d)"

        fetch_repo_file docker-compose.example.yml "$tmpdir/docker-compose.yml"

        step "$(t msg_docker_filling)"
        local dbpass rootpass appurl le_email=''
        dbpass="$(random_password)"
        rootpass="$(random_password)"
        if [[ "$SSL" -eq 1 ]]; then
            appurl="https://$DOMAIN"
            ask le_email "$(t prompt_le_email)"
        else
            appurl="http://$DOMAIN"
        fi

        sed -i \
            -e "s|'CHANGE_ME_TOO'|'$(escape_sed "$rootpass")'|" \
            -e "s|'CHANGE_ME'|'$(escape_sed "$dbpass")'|" \
            -e "s|'http://example.com'|'$(escape_sed "$appurl")'|" \
            -e "s|'noreply@example.com'|'noreply@$DOMAIN'|g" \
            "$tmpdir/docker-compose.yml"

        if [[ -n "$le_email" ]]; then
            sed -i -e "s|# LE_EMAIL: \"\"|LE_EMAIL: \"$(escape_sed "$le_email")\"|" "$tmpdir/docker-compose.yml"
        fi

        cp "$tmpdir/docker-compose.yml" "$PANEL_DIR/docker-compose.yml"
        rm -rf "$tmpdir"
    fi

    step "$(t msg_docker_starting)"
    (cd "$PANEL_DIR" && docker compose up -d)

    step "$(t msg_verify)"
    local i url appurl
    appurl="http://$DOMAIN"
    [[ "$SSL" -eq 1 ]] && appurl="https://$DOMAIN"
    url="http://$DOMAIN/auth/login"
    for i in $(seq 1 30); do
        if curl -fsS -o /dev/null "$url"; then
            ok "$(t msg_panel_url "$appurl")"
            return
        fi
        sleep 5
    done
    warn "The panel did not answer yet. Check: docker compose -f $PANEL_DIR/docker-compose.yml logs"
}
