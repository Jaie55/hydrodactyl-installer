#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034 # DISTRO_VERSION and ARCH are exported for callers

# Shared helpers for every installer mode.

C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
DIE_CALLED=0
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
fi

LOG_FILE="${LOG_FILE:-/var/log/hydrodactyl-installer.log}"

init_log() {
    [[ -n "${LOG_FILE:-}" ]] || return 0
    if [[ -e "$LOG_FILE" || -w "$(dirname "$LOG_FILE")" ]]; then
        touch "$LOG_FILE" 2>/dev/null && chmod 600 "$LOG_FILE" 2>/dev/null || true
    fi
}

_log() {
    local level="$1"
    shift
    local msg="$*"
    if { [[ -e "$LOG_FILE" && -w "$LOG_FILE" ]] || [[ -w "$(dirname "$LOG_FILE")" ]]; } 2>/dev/null; then
        printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >>"$LOG_FILE" 2>/dev/null || true
    fi
}

info() {
    _log INFO "$*"
    printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

step() {
    _log INFO "$*"
    printf '\n%s%s>>%s %s%s\n' "$C_BOLD" "$C_BLUE" "$C_RESET" "$C_BOLD" "$*$C_RESET"
}

ok() {
    _log OK "$*"
    printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

warn() {
    _log WARN "$*"
    printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
}

error() {
    _log ERROR "$*"
    printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}

die() {
    DIE_CALLED=1
    error "$*"
    exit 1
}

on_error() {
    local rc=$? line="${BASH_LINENO[0]:-?}"
    if [[ "${DIE_CALLED:-0}" -eq 1 ]]; then
        return 0
    fi
    printf '%s\n' "$(t msg_unexpected_error "$rc" "$line")" >&2
    if [[ -r "${LOG_FILE:-}" ]]; then
        printf '%s\n' "$(t msg_log_tail "$LOG_FILE")" >&2
        tail -n 20 "$LOG_FILE" >&2 2>/dev/null || true
    fi
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        die "$(t msg_root_required)"
    fi
}

detect_os() {
    [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
    # shellcheck disable=SC1091
    . /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
    DISTRO_VERSION="${VERSION_ID:-}"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"

    case "$DISTRO_ID" in
        ubuntu | debian | linuxmint | pop) FAMILY=debian ;;
        rhel | centos | rocky | almalinux | fedora | ol) FAMILY=rhel ;;
        arch | manjaro) FAMILY=arch ;;
        *) FAMILY=unknown ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) ARCH=amd64 ;;
        aarch64 | arm64) ARCH=arm64 ;;
        armv7l) ARCH=armv7 ;;
        *) die "Unsupported architecture: $(uname -m)" ;;
    esac
}

pkg_update() {
    case "$FAMILY" in
        debian) DEBIAN_FRONTEND=noninteractive apt-get update -q ;;
        rhel) dnf makecache -q ;;
        arch) pacman -Sy --noconfirm ;;
        *) die "Unsupported package manager for $DISTRO_NAME" ;;
    esac
}

pkg_install() {
    case "$FAMILY" in
        debian) DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$@" ;;
        rhel) dnf install -y -q "$@" ;;
        arch) pacman -S --noconfirm --needed "$@" ;;
        *) die "Unsupported package manager for $DISTRO_NAME" ;;
    esac
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

service_reload() {
    systemctl daemon-reload
}

service_enable_now() {
    systemctl enable --now "$1"
}

service_restart() {
    systemctl restart "$1"
}

# ask VAR "Prompt: " [default]
ask() {
    local __var="$1" __prompt="$2" __default="${3:-}" __answer=''
    if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
        printf -v "$__var" '%s' "$__default"
        return 0
    fi
    if [[ -t 0 ]]; then
        if [[ -n "$__default" ]]; then
            read -r -p "$__prompt [$__default]: " __answer || true
        else
            read -r -p "$__prompt: " __answer || true
        fi
    fi
    printf -v "$__var" '%s' "${__answer:-$__default}"
}

# ask_secret VAR "Prompt: "
ask_secret() {
    local __var="$1" __prompt="$2" __answer=''
    if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
        printf -v "$__var" '%s' ''
        return 0
    fi
    if [[ -t 0 ]]; then
        read -r -s -p "$__prompt: " __answer || true
        printf '\n'
    fi
    printf -v "$__var" '%s' "$__answer"
}

# confirm "Question?" [y|n] -> 0 yes, 1 no. Always yes with --yes.
confirm() {
    local __msg="$1" __default="${2:-n}" __answer=''
    if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        [[ "$__default" == "y" ]]
        return
    fi
    if [[ "$__default" == "y" ]]; then
        read -r -p "$__msg [Y/n]: " __answer || true
        [[ -z "$__answer" || "$__answer" =~ ^[Yy] ]]
    else
        read -r -p "$__msg [y/N]: " __answer || true
        [[ "$__answer" =~ ^[Yy] ]]
    fi
}

download() {
    local url="$1" dest="$2"
    info "$(t msg_downloading "$url")"
    curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url" || die "$(t err_download "$url")"
}

random_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-24}" || true
}

escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

# is_local_domain DOMAIN -> 0 for localhost, reserved test TLDs, IPs and
# private ranges (Let's Encrypt cannot issue certificates for those).
is_local_domain() {
    local d="${1,,}"
    [[ "$d" == localhost || "$d" == *.local || "$d" == *.test || "$d" == *.localhost ]] && return 0
    [[ "$d" != *.* ]] && return 0
    [[ "$d" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && return 0
    [[ "$d" =~ ^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]] && return 0
    return 1
}

is_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 > 0 && 10#$1 <= 65535))
}

# panel_app_url SCHEME DOMAIN [PORT]
panel_app_url() {
    local scheme="$1" domain="$2" port="${3:-80}"
    if [[ "$scheme" == "https" ]]; then
        printf 'https://%s' "$domain"
    elif [[ "$port" == "80" ]]; then
        printf 'http://%s' "$domain"
    else
        printf 'http://%s:%s' "$domain" "$port"
    fi
}

# configure_firewall PORT... -> allow SSH and the given ports with ufw.
configure_firewall() {
    [[ "${FIREWALL:-0}" -eq 1 ]] || return 0
    has_cmd ufw || pkg_install ufw
    ufw allow 22/tcp >/dev/null 2>&1 || true
    local port
    for port in "$@"; do
        [[ -n "$port" ]] || continue
        ufw allow "${port}/tcp" >/dev/null 2>&1 || true
    done
    local out
    if out="$(ufw --force enable 2>&1)"; then
        info "$(t msg_firewall_enabled)"
    else
        warn "$(t msg_firewall_failed)"
        printf '%s\n' "$out" >&2
    fi
}

# set_env KEY VALUE [FILE] -> idempotent KEY=VALUE upsert in a dotenv file.
set_env() {
    local key="$1" value="$2" file="${3:-.env}"
    if grep -qE "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=$(escape_sed "$value")|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}
