#!/usr/bin/env bash
# hydrodactyl-installer - Copyright (C) 2026 Jaie55 and contributors
# SPDX-License-Identifier: GPL-3.0-only
# shellcheck disable=SC1091,SC2034 # libs are sourced at runtime and use these globals
set -Eeuo pipefail

INSTALLER_VERSION="0.1.0"
REPO_SLUG="Jaie55/hydrodactyl-installer"
SCRIPT_REF="main"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

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

MODE=""
LANG_CHOICE=""
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
DAEMON_CONFIG=""

usage() {
    cat <<EOF
Hydrodactyl installer ${INSTALLER_VERSION}

Usage: bash install.sh [options]

Panel
  --docker                  Install the panel with Docker
  --native                  Install the panel natively (Ubuntu/Debian)
  --source=stable|canary|custom
                            Panel source (default: stable)
  --repo=URL                Custom panel repository (implies --source=custom)
  --ref=BRANCH              Branch or tag for the custom repository
  --domain=DOMAIN           Panel domain
  --dir=PATH                Panel directory (default: /var/www/hydrodactyl)
  --db=mariadb|mysql        Database engine for the native install

Daemon
  --daemon=wings|elytra     Install a daemon (native)
  --daemon-config=PATH      Node config file downloaded from the panel
  --panel                   Install the panel too (used with --daemon)

Other
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
            --docker) MODE=docker ;;
            --native) MODE=native ;;
            --panel) INSTALL_PANEL=1 ;;
            --daemon=*) INSTALL_DAEMON=1; DAEMON_TYPE="${1#*=}" ;;
            --daemon) INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
            --daemon-config=*) DAEMON_CONFIG="${1#*=}" ;;
            --source=*) SOURCE="${1#*=}" ;;
            --repo=*) CUSTOM_REPO="${1#*=}"; SOURCE=custom ;;
            --ref=*) CUSTOM_REF="${1#*=}" ;;
            --domain=*) DOMAIN="${1#*=}" ;;
            --dir=*) PANEL_DIR="${1#*=}" ;;
            --db=*) DB_KIND="${1#*=}" ;;
            --ssl) SSL=1 ;;
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
    printf '  3) %s\n' "$(t menu_panel_daemon)"
    printf '  4) %s\n' "$(t menu_daemon_wings)"
    printf '  5) %s\n' "$(t menu_daemon_elytra)"
    printf '  6) %s\n\n' "$(t menu_quit)"

    local choice=''
    read -r -p "$(t menu_choice) [1]: " choice || true
    case "${choice:-1}" in
        1) INSTALL_PANEL=1; MODE=docker ;;
        2) INSTALL_PANEL=1; MODE=native ;;
        3) INSTALL_PANEL=1; MODE=docker; INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
        4) INSTALL_PANEL=0; INSTALL_DAEMON=1; DAEMON_TYPE=wings ;;
        5) INSTALL_PANEL=0; INSTALL_DAEMON=1; DAEMON_TYPE=elytra ;;
        6) exit 0 ;;
        *) die "$(t msg_invalid_choice)" ;;
    esac
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

    interactive_menu

    if [[ "$INSTALL_PANEL" == "ask" && "$INSTALL_DAEMON" == "0" ]]; then
        usage
        die "$(t msg_nothing_to_do)"
    fi

    if [[ "$INSTALL_PANEL" == "1" ]]; then
        [[ -n "$MODE" ]] || die "$(t err_mode_required)"
        choose_source
        if [[ -z "$DOMAIN" ]]; then ask DOMAIN "$(t prompt_domain)"; fi
        if [[ -z "$PANEL_DIR" ]]; then ask PANEL_DIR "$(t prompt_panel_dir)" "/var/www/hydrodactyl"; fi
        confirm "$(t confirm_install)" y || exit 0

        case "$MODE" in
            docker) install_panel_docker ;;
            native) install_panel_native ;;
        esac
    fi

    if [[ "$INSTALL_DAEMON" == "1" ]]; then
        install_daemon "${DAEMON_TYPE:-wings}"
    fi

    printf '\n%s%s%s\n' "$C_GREEN$C_BOLD" "$(t msg_done)" "$C_RESET"
    info "$(t msg_log "$LOG_FILE")"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi