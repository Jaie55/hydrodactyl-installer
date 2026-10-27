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

daemon_binary_digest() {
    local bin="$1" repo api name
    case "$bin" in
        wings) repo="pterodactyl/wings" ;;
        elytra) repo="pyrohost/elytra" ;;
        *) return 1 ;;
    esac
    name="${bin}_linux_${ARCH}"
    if [[ -n "$DAEMON_VERSION" ]]; then
        api="https://api.github.com/repos/$repo/releases/tags/$DAEMON_VERSION"
    else
        api="https://api.github.com/repos/$repo/releases/latest"
    fi
    has_cmd jq || return 1
    curl -fsSL -H 'User-Agent: hydrodactyl-installer' "$api" 2>/dev/null |
        jq -r --arg name "$name" '.assets[] | select(.name == $name) | .digest // empty' 2>/dev/null |
        sed -n 's/^sha256://p' | head -n1
}

install_daemon_binary() {
    local bin="$1" url digest
    url="$(daemon_binary_url "$bin")"
    digest="$(daemon_binary_digest "$bin" || true)"
    download "$url" "/usr/local/bin/$bin"
    if [[ -n "$digest" ]]; then
        if ! printf '%s  %s\n' "$digest" "/usr/local/bin/$bin" | sha256sum -c - >/dev/null 2>&1; then
            rm -f "/usr/local/bin/$bin"
            die "$(t err_checksum "$bin")"
        fi
    else
        warn "$(t warn_no_checksum "$bin")"
    fi
    chmod +x "/usr/local/bin/$bin"
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

daemon_version_string() {
    "/usr/local/bin/$1" version 2>/dev/null | head -n1 |
        sed -E -e 's/^[^ ]+ +//' -e 's/^vv/v/' || true
}

daemon_check() {
    local bin="$1" port="$2" i
    for i in 1 2 3 4 5; do
        if systemctl is-active --quiet "$bin"; then
            if ! has_cmd ss || ss -ltn 2>/dev/null | grep -q ":$port "; then
                return 0
            fi
        fi
        sleep 1
    done
    warn "$(t warn_daemon_not_listening "$bin" "$port" "$bin")"
    journalctl -u "$bin" -n 20 --no-pager 2>/dev/null || true
    return 1
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

ensure_node_allocations() {
    local node_id="$1" alloc_json port item start end p
    local -a missing=() ranges=()
    local -A have=()

    if ! alloc_json="$(panel_api GET "/api/application/nodes/$node_id/allocations?per_page=1000")"; then
        warn "$(t msg_alloc_failed)"
        return 0
    fi

    while IFS= read -r port; do
        if [[ -n "$port" ]]; then
            have["$port"]=1
        fi
    done < <(printf '%s' "$alloc_json" | jq -r '.data[].attributes.port')

    local IFS=','
    for item in $NODE_PORTS; do
        if [[ "$item" == *-* ]]; then
            start="${item%-*}"
            end="${item#*-}"
            if [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]]; then
                for ((p=start; p<=end; p++)); do
                    if [[ -z "${have[$p]:-}" ]]; then
                        missing+=("$p")
                        have["$p"]=2
                    fi
                done
            fi
        elif [[ -n "$item" && -z "${have[$item]:-}" ]]; then
            missing+=("$item")
            have["$item"]=2
        fi
    done

    [[ ${#missing[@]} -gt 0 ]] || return 0

    start=''
    end=''
    for p in "${missing[@]}"; do
        if [[ -z "$start" ]]; then
            start="$p"
            end="$p"
            continue
        fi
        if (( p == end + 1 )); then
            end="$p"
        else
            if [[ "$start" == "$end" ]]; then
                ranges+=("$start")
            else
                ranges+=("$start-$end")
            fi
            start="$p"
            end="$p"
        fi
    done
    if [[ -n "$start" ]]; then
        if [[ "$start" == "$end" ]]; then
            ranges+=("$start")
        else
            ranges+=("$start-$end")
        fi
    fi

    local ports_array payload
    ports_array="$(printf '%s\n' "${ranges[@]}" | jq -R . | jq -s '.')" || return 0
    payload="$(jq -n --argjson ports "$ports_array" '{ip: "0.0.0.0", ports: $ports}')" || return 0
    if panel_api POST "/api/application/nodes/$node_id/allocations" "$payload" >/dev/null; then
        info "$(t msg_alloc_created "${#ranges[@]}")"
    else
        warn "$(t msg_alloc_failed)"
    fi
}

# Create a location, a node and its allocations through the panel API, then
# let the daemon fetch and write its own configuration.
auto_configure_node() {
    local type="$1" bin="$2"
    step "$(t msg_node_setup)"

    has_cmd jq || pkg_install jq
    has_cmd ip || pkg_install iproute2

    if [[ -z "$PANEL_URL" ]]; then
        local default_panel_url="${SUMMARY_PANEL_URL:-${DETECTED_PANEL_URL:-http://127.0.0.1}}"
        if [[ -n "$SUMMARY_PANEL_URL" || -n "$DETECTED_PANEL_URL" ]]; then
            PANEL_URL="$default_panel_url"
        else
            ask PANEL_URL "$(t prompt_panel_url)" "$default_panel_url"
        fi
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
        if [[ -n "$SUMMARY_PANEL_URL" || -n "$DETECTED_PANEL_URL" ]]; then
            NODE_FQDN="$default_fqdn"
        else
            ask NODE_FQDN "$(t prompt_node_fqdn)" "$default_fqdn"
        fi
    fi
    [[ -n "$NODE_FQDN" ]] || NODE_FQDN="$default_fqdn"

    [[ -n "$NODE_NAME" ]] || NODE_NAME="$(hostname -s)"
    [[ -n "$NODE_MEMORY" ]] || NODE_MEMORY="$(detect_memory_mb)"
    [[ -n "$NODE_DISK" ]] || NODE_DISK="$(detect_disk_mb)"
    [[ -n "$NODE_PORTS" ]] || NODE_PORTS="25565-25665,27015-27150"

    local response location_id payload node_id existing_node
    node_id=''
    location_id=''

    if response="$(panel_api GET "/api/application/nodes?per_page=1000")"; then
        existing_node="$(printf '%s' "$response" | jq -c --arg fqdn "$NODE_FQDN" \
            '.data[] | select(.attributes.fqdn == $fqdn)' | head -n1)"
    else
        existing_node=''
    fi

    if [[ -n "$existing_node" ]]; then
        node_id="$(printf '%s' "$existing_node" | jq -r '.attributes.id')"
        location_id="$(printf '%s' "$existing_node" | jq -r '.attributes.location_id // empty')"
        info "$(t msg_node_reused "$node_id")"
    fi

    if [[ -z "$location_id" ]]; then
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
    fi

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

    if [[ -n "$node_id" ]]; then
        if ! response="$(panel_api PATCH "/api/application/nodes/$node_id" "$payload")"; then
            warn "$(t msg_api_failed)"
            return 1
        fi
    else
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
    fi
    NODE_ID="$node_id"

    ensure_node_allocations "$node_id"

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
    local type="$1" name bin
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
    else
        systemctl enable --now docker >/dev/null 2>&1 || true
    fi
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        docker info >/dev/null 2>&1 && break
        sleep 1
    done
    if ! docker info >/dev/null 2>&1; then
        warn "$(t warn_docker_not_ready)"
    fi
    pkg_update
    pkg_install ca-certificates curl

    mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes /var/lib/pterodactyl/archives

    step "$(t msg_daemon_binary "$name")"
    has_cmd jq || pkg_install jq
    install_daemon_binary "$type"
    SUMMARY_DAEMON="$name"
    SUMMARY_DAEMON_VERSION="$(daemon_version_string "$bin")"

    if [[ -n "$DAEMON_CONFIG" ]]; then
        [[ -f "$DAEMON_CONFIG" ]] || die "$(t err_daemon_config_missing "$DAEMON_CONFIG")"
        cp "$DAEMON_CONFIG" /etc/pterodactyl/config.yml
    fi

    step "$(t msg_daemon_service)"
    cat >"/etc/systemd/system/$bin.service" <<EOF
[Unit]
Description=$name Server Management Daemon
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service
PartOf=docker.service

[Service]
User=root
Group=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
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
        daemon_check "$bin" "$DAEMON_PORT" || true
        mapfile -t fw_ports < <(daemon_firewall_ports)
        configure_firewall "${fw_ports[@]}"
        ok "$(t msg_daemon_started "$bin")"
        return
    fi

    if [[ "$AUTO_NODE" -eq 1 ]] && { [[ -n "$API_KEY" ]] || confirm "$(t confirm_auto_node)" y; }; then
        if auto_configure_node "$type" "$bin"; then
            systemctl enable --now "$bin"
            daemon_check "$bin" "$DAEMON_PORT" || true
            mapfile -t fw_ports < <(daemon_firewall_ports)
            configure_firewall "${fw_ports[@]}"
            ok "$(t msg_daemon_started "$bin")"
            return
        fi
    fi

    warn "$(t msg_daemon_config_hint "/etc/pterodactyl/config.yml" "$bin")"
}
