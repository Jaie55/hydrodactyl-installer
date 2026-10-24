#!/usr/bin/env bash
# shellcheck shell=bash

# Daemon install mode: Pterodactyl Wings or pyrohost/elytra.

daemon_binary_url() {
    case "$ARCH" in
        amd64 | arm64) ;;
        *) die "$(t err_daemon_arch "$1" "$ARCH")" ;;
    esac
    case "$1" in
        wings) printf '%s' "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${ARCH}" ;;
        elytra) printf '%s' "https://github.com/pyrohost/elytra/releases/latest/download/elytra_linux_${ARCH}" ;;
        *) return 1 ;;
    esac
}

install_daemon() {
    local type="$1" name bin url
    case "$type" in
        wings) name="Wings"; bin="wings" ;;
        elytra) name="Elytra"; bin="elytra" ;;
        *) die "Unknown daemon: $type" ;;
    esac

    if [[ "$FAMILY" != "debian" ]]; then
        die "$(t msg_native_only_debian "$DISTRO_NAME")"
    fi

    step "$(t msg_daemon_installing "$name")"

    if ! has_cmd docker; then
        step "$(t msg_proc_docker)"
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
    pkg_install ca-certificates curl

    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes /var/lib/pterodactyl/archives

    step "$(t msg_daemon_binary "$name")"
    url="$(daemon_binary_url "$type")"
    download "$url" "/usr/local/bin/$bin"
    chmod +x "/usr/local/bin/$bin"

    if [[ -n "$DAEMON_CONFIG" ]]; then
        [[ -f "$DAEMON_CONFIG" ]] || die "$(t err_daemon_config_missing "$DAEMON_CONFIG")"
        cp "$DAEMON_CONFIG" /etc/pterodactyl/config.yml
    fi

    step "$(t msg_daemon_service)"
    cat >"/etc/systemd/system/$bin.service" <<EOF
[Unit]
Description=$name Server Management Daemon

[Service]
User=root
Group=root
Restart=always
ExecStart=/usr/local/bin/$bin --config /etc/pterodactyl/config.yml
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload

    if [[ -f /etc/pterodactyl/config.yml ]]; then
        systemctl enable --now "$bin"
        ok "$(t msg_daemon_started "$bin")"
    else
        warn "$(t msg_daemon_config_hint "/etc/pterodactyl/config.yml" "$bin")"
    fi
}
