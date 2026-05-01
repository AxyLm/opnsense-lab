#!/bin/bash
# OPNsense API helper for this Terraform-managed QEMU lab.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
find_project_root() {
    local dir="$SKILL_DIR"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/terrform" && -f "$dir/AGENTS.md" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT="$(find_project_root)"
TF_DIR="${TF_DIR:-$PROJECT_ROOT/terrform}"
TERRAFORM="${TERRAFORM:-terraform}"

OPNSENSE_API_BASE_URL="${OPNSENSE_API_BASE_URL:-}"
OPNSENSE_KEY="${OPNSENSE_KEY:-}"
OPNSENSE_SECRET="${OPNSENSE_SECRET:-}"
OPNSENSE_INSECURE="${OPNSENSE_INSECURE:-true}"

tf_output() {
    "$TERRAFORM" -chdir="$TF_DIR" output -raw "$1" 2>/dev/null || true
}

load_lab_defaults() {
    if [[ -z "$OPNSENSE_API_BASE_URL" ]]; then
        OPNSENSE_API_BASE_URL="$(tf_output api_base_url)"
    fi

    local key_file="${OPNSENSE_API_KEY_FILE:-}"
    if [[ -z "$key_file" ]]; then
        key_file="$(tf_output apikey_path)"
    fi
    if [[ -z "$key_file" ]]; then
        key_file="$PROJECT_ROOT/secrets/OPNsense.internal_root_apikey.txt"
    fi

    if [[ -z "$OPNSENSE_KEY" && -f "$key_file" ]]; then
        OPNSENSE_KEY="$(grep '^key=' "$key_file" | cut -d= -f2-)"
    fi
    if [[ -z "$OPNSENSE_SECRET" && -f "$key_file" ]]; then
        OPNSENSE_SECRET="$(grep '^secret=' "$key_file" | cut -d= -f2-)"
    fi

    if [[ -z "$OPNSENSE_API_BASE_URL" ]]; then
        OPNSENSE_API_BASE_URL="https://192.168.60.254"
    fi
}

show_help() {
    cat << EOF
OPNsense API Helper

Usage: $0 [options] <command> [args]

Options:
    --secure             Enable SSL certificate validation
    --insecure, -k       Disable SSL certificate validation

Commands:
    get <endpoint>              Make GET request to endpoint
    post <endpoint> [data]      Make POST request with JSON data
    status                      Get system status
    firmware-status             Get firmware status
    interfaces                  List interface configuration
    firewall-stats              Get firewall statistics
    suricata-status             Get Suricata status
    unbound-stats               Get Unbound DNS statistics
    reboot                      Reboot system
    version                     Show OPNsense version
    lab                         Show lab API defaults
    help                        Show this help

Lab defaults:
    TF_DIR                      $TF_DIR
    OPNSENSE_API_BASE_URL       Terraform output api_base_url
    OPNSENSE_API_KEY_FILE       Terraform output apikey_path
    OPNSENSE_INSECURE           true for the local self-signed lab certificate

Examples:
    $0 status
    $0 lab
    $0 get /api/core/system/status
    $0 post /api/core/system/reboot
EOF
}

print_response() {
    local response="$1"
    if command -v jq >/dev/null 2>&1 && printf '%s' "$response" | jq . >/dev/null 2>&1; then
        printf '%s' "$response" | jq .
    else
        printf '%s\n' "$response"
    fi
}

make_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    if [[ -z "$OPNSENSE_KEY" || -z "$OPNSENSE_SECRET" ]]; then
        echo "Error: API credentials are missing" >&2
        echo "Expected key= and secret= in $(tf_output apikey_path)" >&2
        exit 1
    fi

    local curl_flags=(-sS -u "${OPNSENSE_KEY}:${OPNSENSE_SECRET}" -H "Accept: application/json")
    if [[ "$OPNSENSE_INSECURE" == "true" ]]; then
        curl_flags=(-k "${curl_flags[@]}")
    fi

    local url="${OPNSENSE_API_BASE_URL%/}${endpoint}"
    local response
    if [[ "$method" == "GET" ]]; then
        response="$(curl "${curl_flags[@]}" "$url")"
    else
        response="$(curl "${curl_flags[@]}" -H "Content-Type: application/json" -X POST -d "$data" "$url")"
    fi
    print_response "$response"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --secure)
            OPNSENSE_INSECURE="false"
            shift
            ;;
        --insecure|-k)
            OPNSENSE_INSECURE="true"
            shift
            ;;
        *)
            break
            ;;
    esac
done

load_lab_defaults

case "${1:-}" in
    get)
        make_request "GET" "${2:?endpoint required}"
        ;;
    post)
        make_request "POST" "${2:?endpoint required}" "${3:-}"
        ;;
    status)
        make_request "GET" "/api/core/system/status"
        ;;
    firmware-status)
        make_request "GET" "/api/core/firmware/status"
        ;;
    interfaces)
        make_request "GET" "/api/diagnostics/interface/getInterfaceConfig"
        ;;
    firewall-stats)
        make_request "GET" "/api/diagnostics/firewall/pfstatists"
        ;;
    suricata-status)
        make_request "GET" "/api/ids/service/status"
        ;;
    unbound-stats)
        make_request "GET" "/api/unbound/diagnostics/stats"
        ;;
    reboot)
        echo "Rebooting OPNsense..."
        make_request "POST" "/api/core/system/reboot"
        ;;
    version)
        make_request "GET" "/api/core/firmware/status" | grep -o '"version":"[^"]*"' || echo "Version unknown"
        ;;
    lab)
        printf 'project_root=%s\n' "$PROJECT_ROOT"
        printf 'tf_dir=%s\n' "$TF_DIR"
        printf 'api_base_url=%s\n' "$OPNSENSE_API_BASE_URL"
        printf 'insecure=%s\n' "$OPNSENSE_INSECURE"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: ${1:-}" >&2
        show_help
        exit 1
        ;;
esac
