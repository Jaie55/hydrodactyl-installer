#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2015,SC2034,SC2329
set -Eeuo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=../install.sh
source install.sh

if command -v jq >/dev/null 2>&1; then
    JQ_BIN="$(command -v jq)"
    jq() { "$JQ_BIN" "$@" | tr -d '\r'; }
fi

fail=0
pass() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
assert_eq() {
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        bad "$1 (got [$2] want [$3])"
    fi
}

info() { :; }
warn() { :; }
t() {
    if [[ "$1" == "test_server_name" ]]; then
        printf 'Minecraft Test'
    else
        printf '%s' "$1"
    fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

is_port 80 && pass "is_port 80" || bad "is_port 80"
is_port 65535 && pass "is_port 65535" || bad "is_port 65535"
if is_port 0; then bad "is_port 0"; else pass "is_port 0"; fi
if is_port 65536; then bad "is_port 65536"; else pass "is_port 65536"; fi
if is_port abc; then bad "is_port abc"; else pass "is_port abc"; fi

assert_eq "panel_app_url http" "$(panel_app_url http panel.example.com 80)" "http://panel.example.com"
assert_eq "panel_app_url port" "$(panel_app_url http panel.example.com 8080)" "http://panel.example.com:8080"
assert_eq "panel_app_url https" "$(panel_app_url https panel.example.com 443)" "https://panel.example.com"

is_local_domain localhost && pass "local localhost" || bad "local localhost"
is_local_domain 127.0.0.1 && pass "local 127.0.0.1" || bad "local 127.0.0.1"
is_local_domain 192.168.1.10 && pass "local private ip" || bad "local private ip"
if is_local_domain panel.example.com; then bad "public domain"; else pass "public domain"; fi

CUSTOM_REPO=""
CUSTOM_REF=""
normalize_custom_repo "https://github.com/Jaie55/hydrodactyl/tree/fix/egg-change-variables"
assert_eq "normalize repo" "$CUSTOM_REPO" "https://github.com/Jaie55/hydrodactyl"
assert_eq "normalize ref" "$CUSTOM_REF" "fix/egg-change-variables"
CUSTOM_REF=""
normalize_custom_repo "https://github.com/user/repo/tree/main/"
assert_eq "normalize trailing slash" "$CUSTOM_REF" "main"
normalize_custom_repo "https://github.com/user/repo.git"
assert_eq "normalize .git" "$CUSTOM_REPO" "https://github.com/user/repo"
CUSTOM_REF="explicit"
normalize_custom_repo "https://github.com/user/repo/tree/main"
assert_eq "normalize keeps explicit ref" "$CUSTOM_REF" "explicit"

ARCH=amd64
DAEMON_VERSION="v1.2.3"
assert_eq "daemon url tag" "$(daemon_binary_url wings)" \
    "https://github.com/pterodactyl/wings/releases/download/v1.2.3/wings_linux_amd64"
DAEMON_VERSION=""
assert_eq "daemon url latest" "$(daemon_binary_url wings)" \
    "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"

parse_args --native --basic --environment=test --domain=localhost \
    --test-server --test-server-port=25566 --test-server-memory=2048 \
    --test-server-disk=8192 --test-server-egg=paper \
    --admin-email=admin@example.com --admin-username=admin2 --dry-run
assert_eq "parse mode" "$MODE" "native"
assert_eq "parse test server port" "$TEST_SERVER_PORT" "25566"
assert_eq "parse test server memory" "$TEST_SERVER_MEMORY" "2048"
assert_eq "parse test server disk" "$TEST_SERVER_DISK" "8192"
assert_eq "parse test server egg" "$TEST_SERVER_EGG" "paper"
assert_eq "parse admin email" "$ADMIN_EMAIL" "admin@example.com"
assert_eq "parse admin username" "$ADMIN_USERNAME" "admin2"
assert_eq "parse dry run" "$DRY_RUN" "1"

NODE_PORTS="25565-25567,27015"
panel_api() {
    local method="$1" data="${3:-}"
    if [[ "$method" == "GET" ]]; then
        printf '%s' '{"data":[{"attributes":{"port":25565}},{"attributes":{"port":25566}},{"attributes":{"port":27015}}]}'
    else
        printf '%s' "$data" >"$tmp/alloc.json"
    fi
}
ensure_node_allocations 1
assert_eq "allocation payload" "$(jq -c . "$tmp/alloc.json")" '{"ip":"0.0.0.0","ports":["25567"]}'

API_KEY="test-key"
PANEL_URL="http://localhost"
NODE_ID="1"
NODE_FQDN="192.168.10.129"
PANEL_ADMIN_USER_ID=""
TEST_SERVER_PORT="25565"
TEST_SERVER_EGG="vanilla"
TEST_SERVER_MEMORY="1024"
TEST_SERVER_DISK="5120"
SUMMARY_TEST_SERVER=""
SUMMARY_TEST_SERVER_URL=""

panel_api() {
    local method="$1" path="$2" data="${3:-}"
    case "$method $path" in
        "GET /api/application/servers?filter%5Bexternal_id%5D=hydrodactyl-test-25565&per_page=1")
            printf '%s' '{"meta":{"total":0}}'
            ;;
        "GET /api/application/users?per_page=100")
            printf '%s' '{"data":[{"attributes":{"id":1,"root_admin":true}}]}'
            ;;
        "GET /api/application/nodes/1/allocations?filter%5Bport%5D=25565&per_page=100")
            printf '%s' '{"data":[{"attributes":{"id":42,"port":25565,"assigned":false}}]}'
            ;;
        "GET /api/application/nests?per_page=100")
            printf '%s' '{"data":[{"attributes":{"id":1,"name":"Minecraft"}}]}'
            ;;
        "GET /api/application/nests/1/eggs?per_page=100&include=variables")
            printf '%s' '{"data":[{"attributes":{"id":7,"name":"Vanilla Minecraft","docker_image":"ghcr.io/pterodactyl/yolks:java_21","docker_images":{"Java 21":"ghcr.io/pterodactyl/yolks:java_21"},"startup":"java -jar {{SERVER_JARFILE}}","relationships":{"variables":{"data":[{"attributes":{"env_variable":"SERVER_JARFILE","default_value":"server.jar"}},{"attributes":{"env_variable":"VANILLA_VERSION","default_value":"latest"}}]}}}}]}'
            ;;
        "POST /api/application/servers")
            printf '%s' "$data" >"$tmp/server.json"
            printf '%s' '{"attributes":{"name":"Minecraft Test"}}'
            ;;
        *)
            printf 'unexpected panel_api call: %s %s\n' "$method" "$path" >&2
            return 1
            ;;
    esac
}

create_test_server
assert_eq "test server name" "$SUMMARY_TEST_SERVER" "Minecraft Test"
assert_eq "test server url" "$SUMMARY_TEST_SERVER_URL" "192.168.10.129:25565"
assert_eq "test server allocation" "$(jq -r '.allocation.default' "$tmp/server.json")" "42"
assert_eq "test server image" "$(jq -r '.docker_image' "$tmp/server.json")" "ghcr.io/pterodactyl/yolks:java_21"
assert_eq "test server environment" "$(jq -c '.environment' "$tmp/server.json")" '{"SERVER_JARFILE":"server.jar","VANILLA_VERSION":"latest"}'
assert_eq "test server external id" "$(jq -r '.external_id' "$tmp/server.json")" "hydrodactyl-test-25565"

if [[ "$fail" -ne 0 ]]; then
    exit 1
fi
printf 'All tests passed.\n'
