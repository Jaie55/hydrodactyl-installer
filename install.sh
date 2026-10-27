#!/usr/bin/env bash
# hydrodactyl-installer - Copyright (C) 2026 Jaie55 and contributors
# SPDX-License-Identifier: GPL-3.0-only
# shellcheck disable=SC1091,SC2034 # libs are sourced at runtime and use these globals
set -Eeuo pipefail

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

INSTALLER_VERSION="0.8.0"
REPO_SLUG="Jaie55/hydrodactyl-installer"
SCRIPT_REF="main"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

# Minimal Ubuntu Server images ship without curl: install it when possible.
if ! command -v curl >/dev/null 2>&1; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        printf 'This installer must be run as root (curl is missing and has to be installed).\n' >&2
        exit 1
    fi
    printf 'curl not found; installing it...\n'
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -q &&
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q curl ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl ca-certificates
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm --needed curl ca-certificates
    fi
    if ! command -v curl >/dev/null 2>&1; then
        printf 'curl is required and could not be installed automatically.\n' >&2
        exit 1
    fi
fi

# One-liner support: when the script is piped or run from a process
# substitution, the sibling lib/ files are missing. Download the repository
# tarball and continue from there.
if [[ ! -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    BOOTSTRAP_DIR="$(mktemp -d)"
    trap 'rm -rf "$BOOTSTRAP_DIR"' EXIT
    printf 'Downloading %s (%s)...\n' "$REPO_SLUG" "$SCRIPT_REF"
    curl -fsSL "https://github.com/$REPO_SLUG/archive/refs/heads/$SCRIPT_REF.tar.gz" |
        tar -xz -C "$BOOTSTRAP_DIR" --strip-components=1 ||
        {
            printf 'Failed to download the installer.\n' >&2
            exit 1
        }
    SCRIPT_DIR="$BOOTSTRAP_DIR"
fi

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/i18n.sh
source "$SCRIPT_DIR/lib/i18n.sh"
# shellcheck source=lib/sources.sh
source "$SCRIPT_DIR/lib/sources.sh"
# shellcheck source=lib/modes/docker.sh
source "$SCRIPT_DIR/lib/modes/docker.sh"
# shellcheck source=lib/modes/native.sh
source "$SCRIPT_DIR/lib/modes/native.sh"
# shellcheck source=lib/daemons.sh
source "$SCRIPT_DIR/lib/daemons.sh"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/lib/maintenance.sh"

MODE=""
LANG_CHOICE=""
ACTION="install"
PURGE="0"
UPDATE_TARGET=""
UNINSTALL_TARGET=""
INSTALL_TYPE=""
INSTALL_PANEL="ask"
INSTALL_DAEMON="0"
DAEMON_TYPE=""
SOURCE="stable"
CUSTOM_REPO=""
CUSTOM_REF=""
PANEL_DIR="/var/www/hydrodactyl"
DOMAIN=""
SSL="0"
DB_KIND="mariadb"
ASSUME_YES="0"
VERIFY="1"
DEPLOY_ENV=""
LOCAL_INSTALL="0"
DAEMON_CONFIG=""
AUTO_NODE="1"
PANEL_URL=""
DETECTED_PANEL_URL=""
API_KEY=""
NODE_NAME=""
NODE_FQDN=""
NODE_MEMORY=""
NODE_DISK=""
NODE_PORTS=""
TIMEZONE="UTC"
APP_LOCALE="en-US"
HTTP_PORT="80"
PHP_VERSION="8.4"
DB_NAME="panel"
DB_USER="hydrodactyl"
DB_PASS=""
FIREWALL="0"
DAEMON_PORT="8080"
SFTP_PORT="2022"
NODE_SCHEME="http"
BEHIND_PROXY="0"
DAEMON_VERSION=""
SUMMARY_PANEL_URL=""
SUMMARY_PANEL_KIND=""
SUMMARY_REF=""
SUMMARY_DB=""
SUMMARY_SSL="0"
SUMMARY_DAEMON=""
SUMMARY_DAEMON_VERSION=""
SUMMARY_NODE=""
SUMMARY_NODE_FQDN=""
SUMMARY_AUTO_NODE="0"

usage() {
    cat <<EOF
Hydrodactyl installer ${INSTALLER_VERSION}

Usage: bash install.sh [options]

Panel
  --basic                   Basic install: defaults, no extra questions
  --custom                  Custom install: ask for every option
  --docker                  Install the panel with Docker
  --native                  Install the panel natively (Ubuntu/Debian)
  --environment=production|test
                            Strict mode for production, debug for test
  --source=stable|canary|custom
                            Panel source (default: stable)
  --repo=URL                Custom panel repository (implies --source=custom)
  --ref=BRANCH              Branch or tag for the custom repository
  --domain=DOMAIN           Panel domain
  --dir=PATH                Panel directory (default: /var/www/hydrodactyl)
  --db=mariadb|mysql        Database engine for the native install
  --db-name=NAME            Database name (default: panel)
  --db-user=USER            Database user (default: hydrodactyl)
  --db-password=PASS        Database password (default: generated)
  --php=8.3|8.4|8.5         PHP version for the native install (default: 8.4)
  --timezone=TZ             Application timezone (default: UTC)
  --locale=LOCALE           Application locale (default: en-US)
  --http-port=PORT          HTTP port (default: 80)
  --firewall                Configure ufw (SSH, HTTP, HTTPS and daemon ports)
  --no-firewall             Do not configure the firewall (default)

Daemon
  --daemon=wings|elytra     Install a daemon (native)
  --daemon-config=PATH      Node config file downloaded from the panel
  --daemon-version=TAG      Daemon release tag (default: latest)
  --daemon-port=PORT        Daemon listen port (default: 8080)
  --sftp-port=PORT          SFTP port (default: 2022)
  --node-scheme=http|https  Panel -> daemon scheme (default: http)
  --behind-proxy            The node is behind a proxy
  --panel-url=URL           Panel URL for automatic node setup
  --api-key=KEY             Panel application API key (asked if omitted)
  --node-name=NAME          Node name (default: hostname)
  --node-fqdn=HOST          Node FQDN/IP reachable from the panel
  --memory=MB               Node memory in MiB (default: detected)
  --disk=MB                 Node disk in MiB (default: detected)
  --ports=LIST              Allocations, comma separated
                            (default: 25565-25665,27015-27150)
  --no-node                 Do not create the node automatically
  --panel                   Install the panel too (used with --daemon)

Maintenance
  --check-updates           Show installed and latest versions
  --update                  Update the detected panel and daemons
  --update=panel|daemon     Update only the panel or the daemons
  --uninstall               Uninstall the detected panel and daemons
  --uninstall=panel|daemon|all|wings|elytra
                            Uninstall a specific target
  --purge                   With --uninstall, also delete the database and data

Other
  --local                   Local test install: test mode, localhost domain
  --ssl                     Request a Let's Encrypt certificate
  --no-verify               Skip the final check that the panel answers
  --lang=en|es              Interface language
  -y, --yes                 Non-interactive, assume yes
  -h, --help                Show this help
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --basic) INSTALL_TYPE=basic ;;
            --custom) INSTALL_TYPE=custom ;;
            --docker) MODE=docker ;;
            --native) MODE=native ;;
            --environment=*) DEPLOY_ENV="${1#*=}" ;;
            --panel) INSTALL_PANEL=1 ;;
            --daemon=*) INSTALL_DAEMON=1; DAEMON_TYPE="${1#*=}" ;;
            --daemon) INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
            --daemon-config=*) DAEMON_CONFIG="${1#*=}" ;;
            --panel-url=*) PANEL_URL="${1#*=}" ;;
            --api-key=*) API_KEY="${1#*=}" ;;
            --node-name=*) NODE_NAME="${1#*=}" ;;
            --node-fqdn=*) NODE_FQDN="${1#*=}" ;;
            --memory=*) NODE_MEMORY="${1#*=}" ;;
            --disk=*) NODE_DISK="${1#*=}" ;;
            --ports=*) NODE_PORTS="${1#*=}" ;;
            --no-node) AUTO_NODE=0 ;;
            --source=*) SOURCE="${1#*=}" ;;
            --repo=*) CUSTOM_REPO="${1#*=}"; SOURCE=custom ;;
            --ref=*) CUSTOM_REF="${1#*=}" ;;
            --domain=*) DOMAIN="${1#*=}" ;;
            --dir=*) PANEL_DIR="${1#*=}" ;;
            --db=*) DB_KIND="${1#*=}" ;;
            --db-name=*) DB_NAME="${1#*=}" ;;
            --db-user=*) DB_USER="${1#*=}" ;;
            --db-password=*) DB_PASS="${1#*=}" ;;
            --php=*) PHP_VERSION="${1#*=}" ;;
            --timezone=*) TIMEZONE="${1#*=}" ;;
            --locale=*) APP_LOCALE="${1#*=}" ;;
            --http-port=*) HTTP_PORT="${1#*=}" ;;
            --firewall) FIREWALL=1 ;;
            --no-firewall) FIREWALL=0 ;;
            --daemon-version=*) DAEMON_VERSION="${1#*=}" ;;
            --daemon-port=*) DAEMON_PORT="${1#*=}" ;;
            --sftp-port=*) SFTP_PORT="${1#*=}" ;;
            --node-scheme=*) NODE_SCHEME="${1#*=}" ;;
            --behind-proxy) BEHIND_PROXY=1 ;;
            --ssl) SSL=1 ;;
            --local) LOCAL_INSTALL=1; DEPLOY_ENV='test' ;;
            --check-updates) ACTION=check ;;
            --update) ACTION=update ;;
            --update=*) ACTION=update; UPDATE_TARGET="${1#*=}" ;;
            --uninstall) ACTION=uninstall ;;
            --uninstall=*) ACTION=uninstall; UNINSTALL_TARGET="${1#*=}" ;;
            --purge) PURGE=1 ;;
            --no-verify) VERIFY=0 ;;
            --lang=*) LANG_CHOICE="${1#*=}" ;;
            -y | --yes) ASSUME_YES=1 ;;
            -h | --help) usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    case "$SOURCE" in
        stable | canary | custom) ;;
        *) die "Invalid source: $SOURCE" ;;
    esac
    case "$DAEMON_TYPE" in
        '' | wings | elytra) ;;
        *) die "Invalid daemon: $DAEMON_TYPE" ;;
    esac
    case "$DB_KIND" in
        mariadb | mysql) ;;
        *) die "Invalid database: $DB_KIND" ;;
    esac
    case "$DEPLOY_ENV" in
        '' | production | test) ;;
        *) die "Invalid environment: $DEPLOY_ENV (use production or test)" ;;
    esac
    case "$INSTALL_TYPE" in
        '' | basic | custom) ;;
        *) die "Invalid install type: $INSTALL_TYPE (use basic or custom)" ;;
    esac
    case "$UPDATE_TARGET" in
        '' | panel | daemon) ;;
        *) die "Invalid update target: $UPDATE_TARGET (use panel or daemon)" ;;
    esac
    case "$UNINSTALL_TARGET" in
        '' | panel | daemon | all | wings | elytra) ;;
        *) die "Invalid uninstall target: $UNINSTALL_TARGET" ;;
    esac
    case "$PHP_VERSION" in
        8.3 | 8.4 | 8.5) ;;
        *) die "Invalid PHP version: $PHP_VERSION (use 8.3, 8.4 or 8.5)" ;;
    esac
    case "$NODE_SCHEME" in
        http | https) ;;
        *) die "Invalid node scheme: $NODE_SCHEME (use http or https)" ;;
    esac
    is_port "$HTTP_PORT" || die "Invalid HTTP port: $HTTP_PORT"
    is_port "$DAEMON_PORT" || die "Invalid daemon port: $DAEMON_PORT"
    is_port "$SFTP_PORT" || die "Invalid SFTP port: $SFTP_PORT"
    [[ "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || die "Invalid database name: $DB_NAME"
    [[ "$DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || die "Invalid database user: $DB_USER"
    if [[ -n "$DB_PASS" ]]; then
        [[ "$DB_PASS" =~ ^[A-Za-z0-9._-]+$ ]] ||
            die "Invalid database password (letters, digits, . _ - only)"
    fi
    if [[ -n "$DOMAIN" ]]; then
        [[ "$DOMAIN" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid domain: $DOMAIN"
    fi
    [[ "$TIMEZONE" =~ ^[A-Za-z0-9_+/-]+$ ]] || die "Invalid timezone: $TIMEZONE"
    [[ "$APP_LOCALE" =~ ^[A-Za-z0-9_-]+$ ]] || die "Invalid locale: $APP_LOCALE"
    [[ "$PANEL_DIR" =~ ^/[A-Za-z0-9/._-]+$ ]] || die "Invalid panel directory: $PANEL_DIR"
    [[ -z "$NODE_PORTS" || "$NODE_PORTS" =~ ^[0-9,-]+$ ]] || die "Invalid allocations: $NODE_PORTS"
    if [[ -n "$NODE_MEMORY" ]]; then
        [[ "$NODE_MEMORY" =~ ^[0-9]+$ ]] || die "Invalid memory: $NODE_MEMORY"
    fi
    if [[ -n "$NODE_DISK" ]]; then
        [[ "$NODE_DISK" =~ ^[0-9]+$ ]] || die "Invalid disk: $NODE_DISK"
    fi
    if [[ -n "$DAEMON_VERSION" ]]; then
        [[ "$DAEMON_VERSION" =~ ^[0-9] ]] && DAEMON_VERSION="v$DAEMON_VERSION"
        [[ "$DAEMON_VERSION" =~ ^v[0-9A-Za-z._-]+$ ]] ||
            die "Invalid daemon version: $DAEMON_VERSION"
    fi
}

choose_language() {
    if [[ -n "$LANG_CHOICE" || "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
        return
    fi

    init_i18n ""
    printf '\n%s%s%s\n' "$C_BOLD" "$(t lang_title)" "$C_RESET"
    printf '  1) English\n  2) Español\n'
    local choice=''
    read -r -p "$(t lang_prompt) [1/2]: " choice || true
    case "$choice" in
        2) LANG_CHOICE=es ;;
        *) LANG_CHOICE=en ;;
    esac
}

interactive_menu() {
    if [[ "$ACTION" != "install" ]]; then
        return
    fi
    if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
        return
    fi
    if [[ "$INSTALL_PANEL" != "ask" || "$INSTALL_DAEMON" == "1" ]]; then
        return
    fi

    printf '\n%s== Hydrodactyl installer ==%s\n\n' "$C_BOLD" "$C_RESET"
    printf '%s%s%s:\n' "$C_BOLD" "$(t menu_title)" "$C_RESET"
    printf '  1) %s\n' "$(t menu_panel_docker)"
    printf '  2) %s\n' "$(t menu_panel_native)"
    printf '  3) %s\n' "$(t menu_panel_docker_wings)"
    printf '  4) %s\n' "$(t menu_panel_docker_elytra)"
    printf '  5) %s\n' "$(t menu_panel_native_wings)"
    printf '  6) %s\n' "$(t menu_panel_native_elytra)"
    printf '  7) %s\n' "$(t menu_daemon_wings)"
    printf '  8) %s\n' "$(t menu_daemon_elytra)"
    printf '  9) %s\n' "$(t menu_check_updates)"
    printf ' 10) %s\n' "$(t menu_update)"
    printf ' 11) %s\n' "$(t menu_uninstall)"
    printf ' 12) %s\n\n' "$(t menu_quit)"

    local choice=''
    read -r -p "$(t menu_choice) [1]: " choice || true
    case "${choice:-1}" in
        1) INSTALL_PANEL=1; MODE=docker ;;
        2) INSTALL_PANEL=1; MODE=native ;;
        3) INSTALL_PANEL=1; MODE=docker; INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
        4) INSTALL_PANEL=1; MODE=docker; INSTALL_DAEMON=1; DAEMON_TYPE=elytra ;;
        5) INSTALL_PANEL=1; MODE=native; INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
        6) INSTALL_PANEL=1; MODE=native; INSTALL_DAEMON=1; DAEMON_TYPE=elytra ;;
        7) INSTALL_PANEL=0; INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
        8) INSTALL_PANEL=0; INSTALL_DAEMON=1; DAEMON_TYPE=elytra ;;
        9) ACTION=check ;;
        10) ACTION=update ;;
        11) ACTION=uninstall ;;
        12) exit 0 ;;
        *) die "$(t msg_invalid_choice)" ;;
    esac
}

choose_environment() {
    if [[ -n "$DEPLOY_ENV" || "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
        DEPLOY_ENV="${DEPLOY_ENV:-production}"
        return
    fi

    printf '\n%s%s%s:\n' "$C_BOLD" "$(t env_title)" "$C_RESET"
    printf '  1) %s\n  2) %s\n' "$(t env_production)" "$(t env_test)"
    local choice=''
    read -r -p "$(t prompt_env_choice) [1]: " choice || true
    case "${choice:-1}" in
        1) DEPLOY_ENV='production' ;;
        2) DEPLOY_ENV='test' ;;
        *) die "$(t msg_invalid_choice)" ;;
    esac
}

detect_existing() {
    local found_panel=0 found_daemon=0
    local url ref bin ver status containers

    if [[ -f "$PANEL_DIR/artisan" ]]; then
        found_panel=1
        url=''
        if [[ -f "$PANEL_DIR/.env" ]]; then
            url="$(grep -E '^APP_URL=' "$PANEL_DIR/.env" | head -n1 | cut -d= -f2- || true)"
        fi
        DETECTED_PANEL_URL="$url"
        ref=''
        if [[ -d "$PANEL_DIR/.git" ]]; then
            ref="$(git -C "$PANEL_DIR" describe --tags --always 2>/dev/null || true)"
        fi
        info "$(t msg_existing_panel_native "$PANEL_DIR" "${ref:-?}" "${url:-?}")"
    fi

    if has_cmd docker && docker info >/dev/null 2>&1; then
        containers="$(docker ps --format '{{.Names}} ({{.Image}})' 2>/dev/null |
            grep -Ei 'hydrodactyl|pterodactyl' || true)"
        if [[ -n "$containers" ]]; then
            found_panel=1
            info "$(t msg_existing_panel_docker "$(printf '%s' "$containers" | tr '\n' ' ')")"
        fi
    fi
    if [[ "$found_panel" -eq 0 ]]; then
        info "$(t msg_no_panel_detected)"
    fi

    for bin in wings elytra; do
        if [[ -x "/usr/local/bin/$bin" ]]; then
            found_daemon=1
            ver="$("/usr/local/bin/$bin" version 2>/dev/null | head -n1 || true)"
            status="$(systemctl is-active "$bin" 2>/dev/null || true)"
            info "$(t msg_existing_daemon "$bin" "${ver:-?}" "${status:-unknown}")"
        fi
    done
    if [[ "$found_daemon" -eq 0 ]]; then
        info "$(t msg_no_daemon_detected)"
    fi
    if [[ "$found_panel" -eq 1 || "$found_daemon" -eq 1 ]]; then
        warn "$(t msg_existing_hint)"
    fi
}

print_summary() {
    printf '\n%s== %s ==%s\n' "$C_BOLD$C_GREEN" "$(t summary_title)" "$C_RESET"

    if [[ -n "$SUMMARY_PANEL_URL" ]]; then
        ok "$(t summary_panel_url "$SUMMARY_PANEL_URL")"
        info "$(t summary_panel "$(t "summary_kind_$SUMMARY_PANEL_KIND")" "${SUMMARY_REF:-?}")"
        info "$(t summary_env "$(t "env_$DEPLOY_ENV")" "$TIMEZONE" "$APP_LOCALE")"
        if [[ -n "$SUMMARY_DB" ]]; then
            info "$(t summary_db "$SUMMARY_DB")"
        fi
        if [[ "$SUMMARY_SSL" -eq 1 ]]; then
            info "$(t summary_ssl_yes)"
        else
            info "$(t summary_ssl_no)"
        fi
        if [[ "$FIREWALL" -eq 1 ]]; then
            info "$(t summary_fw_yes)"
        else
            info "$(t summary_fw_no)"
        fi
    fi

    if [[ -n "$SUMMARY_DAEMON" ]]; then
        info "$(t summary_daemon "$SUMMARY_DAEMON" "${SUMMARY_DAEMON_VERSION:-?}")"
        if [[ "$SUMMARY_AUTO_NODE" -eq 1 ]]; then
            info "$(t summary_node "$SUMMARY_NODE" "$SUMMARY_NODE_FQDN" "$DAEMON_PORT" "$SFTP_PORT")"
        else
            info "$(t summary_node_manual)"
        fi
    fi
}

choose_install_type() {
    if [[ -n "$INSTALL_TYPE" ]]; then
        return
    fi
    if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
        INSTALL_TYPE=basic
        return
    fi

    printf '\n%s%s%s:\n' "$C_BOLD" "$(t install_type_title)" "$C_RESET"
    printf '  1) %s\n  2) %s\n' "$(t install_type_basic)" "$(t install_type_custom)"
    local choice=''
    read -r -p "$(t prompt_install_type) [1]: " choice || true
    case "${choice:-1}" in
        1) INSTALL_TYPE=basic ;;
        2) INSTALL_TYPE=custom ;;
        *) die "$(t msg_invalid_choice)" ;;
    esac
}

choose_advanced() {
    [[ "$INSTALL_TYPE" == "custom" ]] || return 0
    if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
        return
    fi

    if [[ "$INSTALL_PANEL" == "1" ]]; then
        ask TIMEZONE "$(t prompt_timezone)" "UTC"
        ask APP_LOCALE "$(t prompt_locale)" "en-US"
        ask HTTP_PORT "$(t prompt_http_port)" "80"
        if [[ "$MODE" == "native" ]]; then
            ask PHP_VERSION "$(t prompt_php_version)" "8.4"
        fi
        if confirm "$(t prompt_firewall)" n; then FIREWALL=1; fi
    fi
    if [[ "$INSTALL_DAEMON" == "1" ]]; then
        ask DAEMON_VERSION "$(t prompt_daemon_version)" ""
        ask DAEMON_PORT "$(t prompt_daemon_port)" "8080"
        ask SFTP_PORT "$(t prompt_sftp_port)" "2022"
        ask NODE_SCHEME "$(t prompt_node_scheme)" "http"
        if confirm "$(t prompt_behind_proxy)" n; then BEHIND_PROXY=1; fi
        ask NODE_NAME "$(t prompt_node_name)" "$(hostname -s)"
        ask NODE_FQDN "$(t prompt_node_fqdn)" "$(primary_ip)"
        ask NODE_MEMORY "$(t prompt_memory)" "$(detect_memory_mb)"
        ask NODE_DISK "$(t prompt_disk)" "$(detect_disk_mb)"
        ask NODE_PORTS "$(t prompt_ports)" "25565-25665,27015-27150"
        if confirm "$(t prompt_firewall)" n; then FIREWALL=1; fi
    fi

    is_port "$HTTP_PORT" || die "Invalid HTTP port: $HTTP_PORT"
    is_port "$DAEMON_PORT" || die "Invalid daemon port: $DAEMON_PORT"
    is_port "$SFTP_PORT" || die "Invalid SFTP port: $SFTP_PORT"
    case "$PHP_VERSION" in
        8.3 | 8.4 | 8.5) ;;
        *) die "Invalid PHP version: $PHP_VERSION (use 8.3, 8.4 or 8.5)" ;;
    esac
    case "$NODE_SCHEME" in
        http | https) ;;
        *) die "Invalid node scheme: $NODE_SCHEME (use http or https)" ;;
    esac
    if [[ "$INSTALL_DAEMON" == "1" ]]; then
        [[ "$NODE_MEMORY" =~ ^[0-9]+$ ]] || die "Invalid memory: $NODE_MEMORY"
        [[ "$NODE_DISK" =~ ^[0-9]+$ ]] || die "Invalid disk: $NODE_DISK"
        [[ "$NODE_PORTS" =~ ^[0-9,-]+$ ]] || die "Invalid allocations: $NODE_PORTS"
        if [[ -n "$DAEMON_VERSION" ]]; then
            [[ "$DAEMON_VERSION" =~ ^[0-9] ]] && DAEMON_VERSION="v$DAEMON_VERSION"
            [[ "$DAEMON_VERSION" =~ ^v[0-9A-Za-z._-]+$ ]] ||
                die "Invalid daemon version: $DAEMON_VERSION"
        fi
    fi
}

choose_source() {
    if [[ "$SOURCE" == "custom" ]]; then
        if [[ -z "$CUSTOM_REPO" ]]; then ask CUSTOM_REPO "$(t prompt_repo_url)"; fi
        if [[ -z "$CUSTOM_REF" ]]; then ask CUSTOM_REF "$(t prompt_repo_ref)" "main"; fi
        [[ -n "$CUSTOM_REPO" ]] || die "$(t prompt_repo_url)"
        return
    fi

    if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then
        return
    fi

    printf '\n%s%s%s:\n' "$C_BOLD" "$(t source_title)" "$C_RESET"
    printf '  1) %s\n  2) %s\n  3) %s\n' "$(t source_stable)" "$(t source_canary)" "$(t source_custom)"
    local choice=''
    read -r -p "$(t prompt_source_choice) [1]: " choice || true
    case "${choice:-1}" in
        1) SOURCE=stable ;;
        2) SOURCE=canary ;;
        3)
            SOURCE=custom
            ask CUSTOM_REPO "$(t prompt_repo_url)"
            ask CUSTOM_REF "$(t prompt_repo_ref)" "main"
            ;;
        *) die "$(t msg_invalid_choice)" ;;
    esac
}

main() {
    parse_args "$@"

    detect_os
    detect_arch

    init_i18n "$LANG_CHOICE"
    require_root
    info "$(t msg_os "$DISTRO_NAME" "$DISTRO_VERSION" "$ARCH")"
    info "$(t msg_family "$FAMILY")"

    choose_language
    init_i18n "$LANG_CHOICE"

    detect_existing

    interactive_menu

    case "$ACTION" in
        check)
            check_updates
            exit 0
            ;;
        update)
            update_all
            exit 0
            ;;
        uninstall)
            uninstall_all
            exit 0
            ;;
    esac

    if [[ "$INSTALL_PANEL" == "ask" && "$INSTALL_DAEMON" == "0" ]]; then
        usage
        die "$(t msg_nothing_to_do)"
    fi

    choose_install_type

    if [[ "$INSTALL_PANEL" == "1" ]]; then
        [[ -n "$MODE" ]] || die "$(t err_mode_required)"
        choose_source
        choose_environment
        if [[ "$DEPLOY_ENV" == "test" ]]; then
            info "$(t msg_env_test)"
        else
            info "$(t msg_env_production)"
        fi
        if [[ -z "$DOMAIN" ]]; then
            if [[ "$LOCAL_INSTALL" -eq 1 || "$DEPLOY_ENV" == "test" ]]; then
                ask DOMAIN "$(t prompt_domain_test)" "localhost"
            else
                ask DOMAIN "$(t prompt_domain)"
            fi
        fi
        [[ -n "$DOMAIN" ]] || die "$(t err_domain_required)"
        if [[ -z "$PANEL_DIR" ]]; then ask PANEL_DIR "$(t prompt_panel_dir)" "/var/www/hydrodactyl"; fi
        choose_advanced
        confirm "$(t confirm_install)" y || exit 0

        case "$MODE" in
            docker) install_panel_docker ;;
            native) install_panel_native ;;
        esac
    fi

    if [[ "$INSTALL_PANEL" == "1" && "$INSTALL_DAEMON" == "1" && "$AUTO_NODE" -eq 1 &&
        "$ASSUME_YES" -eq 0 && -t 0 ]]; then
        info "$(t msg_finish_setup)"
        read -r -p "$(t msg_press_enter) " _ || true
    fi

    if [[ "$INSTALL_PANEL" != "1" && "$INSTALL_DAEMON" == "1" ]]; then
        choose_advanced
    fi

    if [[ "$INSTALL_DAEMON" == "1" ]]; then
        install_daemon "${DAEMON_TYPE:-wings}"
    fi

    print_summary
    printf '\n%s%s%s\n' "$C_GREEN$C_BOLD" "$(t msg_done)" "$C_RESET"
    info "$(t msg_log "$LOG_FILE")"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi