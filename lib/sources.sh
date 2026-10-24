#!/usr/bin/env bash
# shellcheck shell=bash

PANEL_UPSTREAM_REPO="https://github.com/blueprintframework/hydrodactyl"

# Resolve PANEL_REPO and PANEL_REF from SOURCE.
resolve_panel_ref() {
    case "$SOURCE" in
        stable)
            local tag
            tag="$(git ls-remote --tags --refs "$PANEL_UPSTREAM_REPO" 'v*' | awk -F/ '{print $NF}' | sort -V | tail -n1)"
            [[ -n "$tag" ]] || die "$(t err_no_tags)"
            PANEL_REPO="$PANEL_UPSTREAM_REPO"
            PANEL_REF="$tag"
            info "$(t msg_source_stable "$tag")"
            ;;
        canary)
            PANEL_REPO="$PANEL_UPSTREAM_REPO"
            PANEL_REF="main"
            info "$(t msg_source_canary)"
            ;;
        custom)
            PANEL_REPO="${CUSTOM_REPO%/}"
            PANEL_REF="${CUSTOM_REF:-main}"
            [[ -n "$PANEL_REPO" ]] || die "$(t prompt_repo_url)"
            info "$(t msg_source_custom "$PANEL_REPO" "$PANEL_REF")"
            ;;
    esac
}

# Fetch (or refresh) the panel checkout at PANEL_DIR.
fetch_panel() {
    resolve_panel_ref
    has_cmd git || die "git is required"

    if [[ -d "$PANEL_DIR/.git" ]]; then
        info "Updating existing checkout in $PANEL_DIR"
        git -C "$PANEL_DIR" remote set-url origin "$PANEL_REPO"
        git -C "$PANEL_DIR" fetch --depth=1 origin "$PANEL_REF"
        git -C "$PANEL_DIR" reset --hard FETCH_HEAD
        return
    fi

    mkdir -p "$(dirname "$PANEL_DIR")"
    rm -rf "$PANEL_DIR"
    git clone --depth=1 --branch "$PANEL_REF" "$PANEL_REPO" "$PANEL_DIR" ||
        {
            git clone --depth=1 "$PANEL_REPO" "$PANEL_DIR" &&
                git -C "$PANEL_DIR" checkout "$PANEL_REF"
        }
}

# Fetch a file from the selected panel source (e.g. docker-compose.example.yml).
fetch_repo_file() {
    local path="$1" dest="$2" base
    case "$SOURCE" in
        canary) base="$PANEL_UPSTREAM_REPO/raw/main" ;;
        *) base="$PANEL_REPO/raw/$PANEL_REF" ;;
    esac
    download "$base/$path" "$dest"
}
