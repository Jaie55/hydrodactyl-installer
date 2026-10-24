#!/usr/bin/env bash
# shellcheck shell=bash

declare -A MSG=()
I18N="${I18N:-en}"

init_i18n() {
    local want="${1:-}"

    if [[ -z "$want" ]]; then
        case "${LC_ALL:-${LANG:-}}" in
            es* | *_ES* | *.ES*) want=es ;;
            *) want=en ;;
        esac
    fi

    case "$want" in
        en | es) ;;
        *) want=en ;;
    esac

    I18N="$want"

    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lang/$want.sh"
}

# t KEY [ARG1 ARG2 ...] -> replaces %s placeholders in order
t() {
    local key="$1"
    shift
    local text="${MSG[$key]:-}"
    [[ -n "$text" ]] || text="$key"
    local arg
    for arg in "$@"; do
        text="${text/\%s/$arg}"
    done
    printf '%s' "$text"
}
