#!/bin/bash
# Timestamped OPNsense config backups for this Terraform-managed QEMU lab.

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
BACKUP_DIR="${BACKUP_DIR:-$SKILL_DIR/backups}"
KEEP_DAYS="${KEEP_DAYS:-30}"
CONFIG_ONLY=false

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
OPNsense Configuration Backup

Usage: $0 [options]

Options:
    -d, --dir <path>        Backup directory (default: $SKILL_DIR/backups)
    -k, --keep <days>       Keep backups for N days (default: 30)
    -c, --config-only       Download config.xml only
    --secure                Enable SSL certificate validation
    --insecure              Disable SSL certificate validation
    -h, --help              Show this help

Lab defaults:
    OPNSENSE_API_BASE_URL   Terraform output api_base_url
    OPNSENSE_API_KEY_FILE   Terraform output apikey_path
    OPNSENSE_INSECURE       true for the local self-signed lab certificate

Examples:
    $0
    $0 --config-only
    $0 --dir "$PROJECT_ROOT/backups/opnsense" --keep 90
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -k|--keep)
            KEEP_DAYS="$2"
            shift 2
            ;;
        -c|--config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --secure)
            OPNSENSE_INSECURE="false"
            shift
            ;;
        --insecure)
            OPNSENSE_INSECURE="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

load_lab_defaults

if [[ -z "$OPNSENSE_KEY" || -z "$OPNSENSE_SECRET" ]]; then
    echo "Error: API credentials are missing" >&2
    echo "Expected key= and secret= in $(tf_output apikey_path)" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/opnsense_backup_${TIMESTAMP}.xml"
ENDPOINT="/api/core/backup/backup"
if [[ "$CONFIG_ONLY" != "true" ]]; then
    ENDPOINT="${ENDPOINT}?rrd=true"
fi

curl_flags=(-sS -u "${OPNSENSE_KEY}:${OPNSENSE_SECRET}")
if [[ "$OPNSENSE_INSECURE" == "true" ]]; then
    curl_flags=(-k "${curl_flags[@]}")
fi

echo "Creating OPNsense backup..."
echo "  API: $OPNSENSE_API_BASE_URL"
echo "  Destination: $BACKUP_FILE"
echo "  Config only: $CONFIG_ONLY"
echo "  SSL validation: $([[ "$OPNSENSE_INSECURE" == "true" ]] && echo disabled || echo enabled)"

curl "${curl_flags[@]}" "${OPNSENSE_API_BASE_URL%/}${ENDPOINT}" -o "$BACKUP_FILE"

if [[ -s "$BACKUP_FILE" ]] && grep -q '<opnsense>' "$BACKUP_FILE" 2>/dev/null; then
    size="$(du -h "$BACKUP_FILE" | cut -f1)"
    version="$(grep -o '<version>[^<]*</version>' "$BACKUP_FILE" | head -1 | sed 's/<[^>]*>//g')"
    echo "Backup created: $BACKUP_FILE ($size)"
    [[ -n "$version" ]] && echo "Version: $version"
else
    echo "Backup response did not look like OPNsense XML" >&2
    rm -f "$BACKUP_FILE"
    exit 1
fi

if [[ "$KEEP_DAYS" =~ ^[0-9]+$ && "$KEEP_DAYS" -gt 0 ]]; then
    find "$BACKUP_DIR" -name "opnsense_backup_*.xml" -mtime +"$KEEP_DAYS" -delete
fi

echo "Recent backups:"
ls -lh "$BACKUP_DIR"/opnsense_backup_*.xml 2>/dev/null | tail -5 || true
