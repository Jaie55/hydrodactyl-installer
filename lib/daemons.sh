#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034 # SUMMARY_* globals are consumed by install.sh

# Daemon install mode: Pterodactyl Wings or pyrohost/elytra.

daemon_binary_url() {
    case "$ARCH" in
        amd64 | arm64) ;;
        *) die "$(t err_daemon_arch "$1" "$ARCH")" ;;
    esac
    local base
    case "$1" in
        wings) base="https://github.com/pterodactyl/wings" ;;
        elytra) base="https://github.com/pyrohost/elytra" ;;
        *) return 1 ;;
    esac
    if [[ -n "$DAEMON_VERSION" ]]; then
        printf '%s/releases/download/%s/%s_linux_%s' "$base" "$DAEMON_VERSION" "$1" "$ARCH"
    else
        printf '%s/releases/latest/download/%s_linux_%s' "$base" "$1" "$ARCH"
    fi
}

daemon_firewall_ports() {
    local port
    local -a ports=("$DAEMON_PORT" "$SFTP_PORT")
    local IFS=','
    for port in $NODE_PORTS; do
        ports+=("${port/-/:}")
    done
    printf '%s\n' "${ports[@]}"
}

detect_memory_mb() {
    awk '/^MemTotal:/ {printf "%d\n", $2 / 1024}' /proc/meminfo
}

detect_disk_mb() {
    df -m / | awk 'NR==2 {print $2}'
}

primary_ip() {
    ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}'
}

# panel_api METHOD PATH [JSON] -> curl against the panel application API.
panel_api() {
    local method="$1" path="$2" data="${3:-}" host port
    local -a args=(-fsS -X "$method"
        -H "Authorization: Bearer $API_KEY"
        -H "Accept: Application/vnd.pterodactyl.v1+json")
    if [[ -n "$data" ]]; then
        args+=(-H "Content-Type: application/json" -d "$data")
    fi
    host="${PANEL_URL#*://}"
    host="${host%%/*}"
    host="${host%%:*}"
    if [[ ! "$host" =~ ^[0-9.]+$ ]] && is_local_domain "$host"; then
        port=80
        [[ "$PANEL_URL" == https://* ]] && port=443
        args+=(--resolve "$host:$port:127.0.0.1")
    fi
    curl "${args[@]}" "${PANEL_URL}${path}"
}

ports_json() {
    local IFS=',' port out=''
    for port in $NODE_PORTS; do
        out+="${out:+,}\"$port\""
    done
    printf '[%s]' "$out"
}

# Create a location, a node and its allocations through the panel API, then
# let the daemon fetch and write its own configuration.
auto_configure_node() {
    local type="$1" bin="$2"
    step "$(t msg_node_setup)"

    has_cmd jq || pkg_install jq
    has_cmd ip || pkg_install iproute2

    if [[ -z "$PANEL_URL" ]]; then
        ask PANEL_URL "$(t prompt_panel_url)" "http://127.0.0.1"
    fi
    [[ "$PANEL_URL" == *://* ]] || PANEL_URL="http://$PANEL_URL"
    PANEL_URL="${PANEL_URL%/}"

    if [[ -z "$API_KEY" ]]; then
        for _ in 1 2 3; do
            ask_secret API_KEY "$(t prompt_api_key)"
            [[ -n "$API_KEY" ]] && break
            warn "$(t msg_api_key_required)"
        done
    fi
    if [[ -z "$API_KEY" ]]; then
        warn "$(t msg_node_skipped)"
        return 1
    fi

    local default_fqdn
    default_fqdn="$(primary_ip)"
    [[ -n "$default_fqdn" ]] || default_fqdn="$(hostname -f 2>/dev/null || hostname)"
    if [[ -z "$NODE_FQDN" ]]; then
        ask NODE_FQDN "$(t prompt_node_fqdn)" "$default_fqdn"
    fi
    [[ -n "$NODE_FQDN" ]] || NODE_FQDN="$default_fqdn"

    [[ -n "$NODE_NAME" ]] || NODE_NAME="$(hostname -s)"
    [[ -n "$NODE_MEMORY" ]] || NODE_MEMORY="$(detect_memory_mb)"
    [[ -n "$NODE_DISK" ]] || NODE_DISK="$(detect_disk_mb)"
    [[ -n "$NODE_PORTS" ]] || NODE_PORTS="25565-25665,27015-27150"

    local response location_id payload node_id
    if ! response="$(panel_api GET /api/application/locations)"; then
        warn "$(t msg_api_failed)"
        return 1
    fi

    location_id="$(printf '%s' "$response" | jq -r '.data[0].attributes.id // empty')"
    if [[ -z "$location_id" ]]; then
        payload="$(jq -n '{short: "default", long: "Default"}')"
        if ! response="$(panel_api POST /api/application/locations "$payload")"; then
            warn "$(t msg_api_failed)"
            return 1
        fi
        location_id="$(printf '%s' "$response" | jq -r '.attributes.id // empty')"
    fi
    if [[ -z "$location_id" ]]; then
        warn "$(t msg_api_failed)"
        return 1
    fi
    info "$(t msg_node_location "$location_id")"

    if [[ "$NODE_SCHEME" == "https" ]]; then
        warn "$(t warn_node_https)"
    fi

    payload="$(jq -n \
        --arg name "$NODE_NAME" \
        --arg fqdn "$NODE_FQDN" \
        --arg type "$type" \
        --arg scheme "$NODE_SCHEME" \
        --argjson behind "$BEHIND_PROXY" \
        --argjson location "$location_id" \
        --argjson memory "$NODE_MEMORY" \
        --argjson disk "$NODE_DISK" \
        --argjson daemon_port "$DAEMON_PORT" \
        --argjson sftp_port "$SFTP_PORT" \
        '{name: $name, description: "Created by hydrodactyl-installer",
          location_id: $location, fqdn: $fqdn, scheme: $scheme,
          behind_proxy: ($behind == 1), public: true, memory: $memory,
          memory_overallocate: 0, disk: $disk, disk_overallocate: 0,
          upload_size: 100, daemon_listen: $daemon_port, daemon_sftp: $sftp_port,
          maintenance_mode: false, daemon_type: $type}')" || return 1

    if ! response="$(panel_api POST /api/application/nodes "$payload")"; then
        warn "$(t msg_api_failed)"
        return 1
    fi
    node_id="$(printf '%s' "$response" | jq -r '.attributes.id // empty')"
    if [[ -z "$node_id" ]]; then
        warn "$(t msg_api_failed)"
        return 1
    fi
    info "$(t msg_node_created "$node_id")"

    payload="$(jq -n --argjson ports "$(ports_json)" '{ip: "0.0.0.0", ports: $ports}')"
    panel_api POST "/api/application/nodes/${node_id}/allocations" "$payload" >/dev/null ||
        warn "$(t msg_alloc_failed)"

    if [[ -f /etc/pterodactyl/config.yml ]]; then
        cp -a /etc/pterodactyl/config.yml "/etc/pterodactyl/config.yml.bak.$(date +%s)"
    fi

    "/usr/local/bin/$bin" configure \
        --panel-url "$PANEL_URL" --token "$API_KEY" --node "$node_id" --override ||
        {
            warn "$(t msg_api_failed)"
            return 1
        }

    ok "$(t msg_node_configured "$NODE_NAME")"
    SUMMARY_NODE="$NODE_NAME"
    SUMMARY_NODE_FQDN="$NODE_FQDN"
    SUMMARY_AUTO_NODE=1
    return 0
}

install_daemon() {
    local type="$1" name bin url
    local -a fw_ports
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
    pkg_update
    pkg_install ca-certificates curl

    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes /var/lib/pterodactyl/archives

    step "$(t msg_daemon_binary "$name")"
    url="$(daemon_binary_url "$type")"
    download "$url" "/usr/local/bin/$bin"
    chmod +x "/usr/local/bin/$bin"
    SUMMARY_DAEMON="$name"
    SUMMARY_DAEMON_VERSION="$("/usr/local/bin/$bin" version 2>/dev/null | head -n1 || true)"

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
        mapfile -t fw_ports < <(daemon_firewall_ports)
        configure_firewall "${fw_ports[@]}"
        ok "$(t msg_daemon_started "$bin")"
        return
    fi

    if [[ "$AUTO_NODE" -eq 1 ]] && confirm "$(t confirm_auto_node)" y; then
        if auto_configure_node "$type" "$bin"; then
            systemctl enable --now "$bin"
            mapfile -t fw_ports < <(daemon_firewall_ports)
            configure_firewall "${fw_ports[@]}"
            ok "$(t msg_daemon_started "$bin")"
            return
        fi
    fi

    warn "$(t msg_daemon_config_hint "/etc/pterodactyl/config.yml" "$bin")"
}
