#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034 # globals are consumed by install.sh

local_panel_available() {
    [[ -f "$PANEL_DIR/artisan" || -f "$PANEL_DIR/docker-compose.yml" ]]
}

panel_php_run() {
    local script="$SCRIPT_DIR/config/panel-key.php" rc=0
    if [[ "$MODE" == "docker" || -f "$PANEL_DIR/docker-compose.yml" ]]; then
        (cd "$PANEL_DIR" && docker compose exec -T -u nginx \
            -e "HYDRO_ADMIN_EMAIL=$PANEL_ADMIN_EMAIL" \
            -e "HYDRO_ADMIN_USER=$PANEL_ADMIN_USER" \
            -e "HYDRO_ADMIN_FIRST=$PANEL_ADMIN_FIRST" \
            -e "HYDRO_ADMIN_LAST=$PANEL_ADMIN_LAST" \
            -e "HYDRO_ADMIN_PASS=$PANEL_ADMIN_PASSWORD" \
            -e "HYDRO_AUTO_ADMIN=$AUTO_ADMIN" \
            panel php) <"$script" || rc=$?
    else
        local php_bin
        php_bin="${PANEL_PHP_BIN:-$(native_php_bin)}"
        (cd "$PANEL_DIR" && HYDRO_ADMIN_EMAIL="$PANEL_ADMIN_EMAIL" \
            HYDRO_ADMIN_USER="$PANEL_ADMIN_USER" \
            HYDRO_ADMIN_FIRST="$PANEL_ADMIN_FIRST" \
            HYDRO_ADMIN_LAST="$PANEL_ADMIN_LAST" \
            HYDRO_ADMIN_PASS="$PANEL_ADMIN_PASSWORD" \
            HYDRO_AUTO_ADMIN="$AUTO_ADMIN" \
            "$php_bin") <"$script" || rc=$?
        chown -R "${WEB_USER:-www-data}:${WEB_USER:-www-data}" \
            "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
    fi
    return "$rc"
}

ensure_panel_api_key() {
    local quiet="${1:-0}" out='' line='' key=''
    if [[ -n "$API_KEY" ]]; then
        return 0
    fi
    if ! local_panel_available; then
        return 1
    fi

    PANEL_ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
    PANEL_ADMIN_USER="${ADMIN_USERNAME:-admin}"
    PANEL_ADMIN_FIRST="${PANEL_ADMIN_FIRST:-Admin}"
    PANEL_ADMIN_LAST="${PANEL_ADMIN_LAST:-}"
    PANEL_ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(random_password 16)}"

    local rc=0
    out="$(panel_php_run 2>&1)" || rc=$?

    while IFS= read -r line; do
        case "$line" in
            key=*) key="${line#key=}" ;;
            user_id=*) PANEL_ADMIN_USER_ID="${line#user_id=}" ;;
            user_email=*) PANEL_ADMIN_EMAIL="${line#user_email=}" ;;
            created=*)
                if [[ "${line#created=}" == "1" ]]; then
                    PANEL_ADMIN_CREATED=1
                fi
                ;;
        esac
    done <<<"$out"

    if [[ "$PANEL_ADMIN_CREATED" == "1" ]]; then
        save_admin_credentials
    fi

    if [[ "$rc" -ne 0 ]]; then
        if [[ "$quiet" -eq 0 ]]; then
            warn "$(t msg_api_key_failed)"
            if [[ -n "$out" ]]; then
                printf '%s\n' "$out" >&2
            fi
        fi
        return 1
    fi

    if [[ -z "$key" ]]; then
        if [[ "$quiet" -eq 0 ]]; then
            warn "$(t msg_api_key_failed)"
            if [[ -n "$out" ]]; then
                printf '%s\n' "$out" >&2
            fi
        fi
        return 1
    fi

    API_KEY="$key"
    if [[ "$PANEL_ADMIN_CREATED" == "1" ]]; then
        info "$(t msg_admin_created "$PANEL_ADMIN_EMAIL")"
    fi
    info "$(t msg_api_key_created)"
    return 0
}

save_admin_credentials() {
    [[ "$PANEL_ADMIN_CREATED" -eq 1 ]] || return 0
    local file="${ADMIN_CREDENTIALS_FILE:-/root/hydrodactyl-admin.txt}"
    if (umask 077; printf 'email=%s\npassword=%s\n' "$PANEL_ADMIN_EMAIL" "$PANEL_ADMIN_PASSWORD" >"$file") 2>/dev/null; then
        info "$(t msg_admin_saved "$file")"
    else
        warn "$(t msg_admin_save_failed "$file")"
    fi
}

panel_test_server_allocation() {
    local alloc_json alloc_id
    alloc_json="$(panel_api GET \
        "/api/application/nodes/$NODE_ID/allocations?filter%5Bport%5D=$TEST_SERVER_PORT&per_page=100")" ||
        return 1
    alloc_id="$(printf '%s' "$alloc_json" |
        jq -r '.data[] | select(.attributes.assigned == false) | .attributes.id' | head -n1)"
    if [[ -z "$alloc_id" ]]; then
        panel_api POST "/api/application/nodes/$NODE_ID/allocations" \
            "$(jq -n --arg port "$TEST_SERVER_PORT" '{ip: "0.0.0.0", ports: [$port]}')" >/dev/null ||
            return 1
        alloc_json="$(panel_api GET \
            "/api/application/nodes/$NODE_ID/allocations?filter%5Bport%5D=$TEST_SERVER_PORT&per_page=100")" ||
            return 1
        alloc_id="$(printf '%s' "$alloc_json" |
            jq -r '.data[] | select(.attributes.assigned == false) | .attributes.id' | head -n1)"
    fi
    [[ -n "$alloc_id" ]] || return 1
    printf '%s' "$alloc_id"
}

panel_test_server_egg() {
    local pattern="$1" nests nest eggs egg_json
    nests="$(panel_api GET "/api/application/nests?per_page=100")" || return 1
    egg_json=''
    while IFS= read -r nest; do
        eggs="$(panel_api GET "/api/application/nests/$nest/eggs?per_page=100&include=variables")" || continue
        egg_json="$(printf '%s' "$eggs" | jq -c --arg pattern "$pattern" \
            '.data[] | select(.attributes.name | test($pattern; "i"))' | head -n1)"
        if [[ -n "$egg_json" ]]; then
            break
        fi
    done < <(printf '%s' "$nests" | jq -r '.data[].attributes.id')
    [[ -n "$egg_json" ]] || return 1
    printf '%s' "$egg_json"
}

create_test_server() {
    if [[ -z "$API_KEY" || -z "$PANEL_URL" || -z "$NODE_ID" ]]; then
        return 1
    fi
    has_cmd jq || pkg_install jq

    local external_id="hydrodactyl-test-$TEST_SERVER_PORT" existing
    if existing="$(panel_api GET \
        "/api/application/servers?filter%5Bexternal_id%5D=$external_id&per_page=1")"; then
        if [[ "$(printf '%s' "$existing" | jq -r '.meta.total // 0')" -gt 0 ]]; then
            SUMMARY_TEST_SERVER="$(printf '%s' "$existing" | jq -r '.data[0].attributes.name // empty')"
            if [[ -z "$SUMMARY_TEST_SERVER" ]]; then
                SUMMARY_TEST_SERVER="$(t test_server_name)"
            fi
            SUMMARY_TEST_SERVER_URL="${NODE_FQDN:-$(primary_ip)}:${TEST_SERVER_PORT}"
            info "$(t msg_test_server_exists "$SUMMARY_TEST_SERVER")"
            return 0
        fi
    fi

    if [[ -z "$PANEL_ADMIN_USER_ID" ]]; then
        local users
        users="$(panel_api GET "/api/application/users?per_page=100")" || return 1
        PANEL_ADMIN_USER_ID="$(printf '%s' "$users" | jq -r \
            '.data[] | select(.attributes.root_admin == true) | .attributes.id' | head -n1)"
        if [[ -z "$PANEL_ADMIN_USER_ID" ]]; then
            PANEL_ADMIN_USER_ID="$(printf '%s' "$users" | jq -r '.data[0].attributes.id // empty')"
        fi
    fi
    [[ -n "$PANEL_ADMIN_USER_ID" ]] || return 1

    local alloc_id egg_json egg_id image startup env_json payload response
    alloc_id="$(panel_test_server_allocation)" || return 1
    egg_json="$(panel_test_server_egg "$TEST_SERVER_EGG")" || return 1

    egg_id="$(printf '%s' "$egg_json" | jq -r '.attributes.id')"
    image="$(printf '%s' "$egg_json" | jq -r \
        '.attributes.docker_images // {} | to_entries[]? | select(.key | test("java 21"; "i")) | .value' |
        head -n1)"
    if [[ -z "$image" ]]; then
        image="$(printf '%s' "$egg_json" | jq -r '.attributes.docker_image')"
    fi
    startup="$(printf '%s' "$egg_json" | jq -r '.attributes.startup')"
    env_json="$(printf '%s' "$egg_json" | jq -c \
        '[.attributes.relationships.variables.data[]? | {key: .attributes.env_variable, value: (.attributes.default_value // "")}] | from_entries')"

    payload="$(jq -n \
        --arg name "$(t test_server_name)" \
        --arg external "$external_id" \
        --argjson user "$PANEL_ADMIN_USER_ID" \
        --argjson egg "$egg_id" \
        --arg image "$image" \
        --arg startup "$startup" \
        --argjson env "$env_json" \
        --argjson alloc "$alloc_id" \
        --argjson memory "$TEST_SERVER_MEMORY" \
        --argjson disk "$TEST_SERVER_DISK" \
        '{name: $name, external_id: $external, user: $user, egg: $egg,
          docker_image: $image, startup: $startup, environment: $env,
          limits: {memory: $memory, swap: 0, disk: $disk, io: 500, cpu: 100, threads: 0},
          feature_limits: {databases: 0, allocations: 0, backups: 0, backup_storage_mb: 0},
          allocation: {default: $alloc}, start_on_completion: true}')" || return 1

    if ! response="$(panel_api POST /api/application/servers "$payload")"; then
        return 1
    fi

    SUMMARY_TEST_SERVER="$(printf '%s' "$response" | jq -r '.attributes.name // empty')"
    if [[ -z "$SUMMARY_TEST_SERVER" ]]; then
        SUMMARY_TEST_SERVER="$(t test_server_name)"
    fi
    SUMMARY_TEST_SERVER_URL="${NODE_FQDN:-$(primary_ip)}:${TEST_SERVER_PORT}"
    info "$(t msg_test_server_created "$SUMMARY_TEST_SERVER" "${NODE_FQDN:-$(primary_ip)}" "$TEST_SERVER_PORT")"
    return 0
}
