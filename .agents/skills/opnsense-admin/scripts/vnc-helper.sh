#!/bin/bash
# VNC helper for this Terraform-managed QEMU OPNsense lab.

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

tf_output() {
    "$TERRAFORM" -chdir="$TF_DIR" output -raw "$1" 2>/dev/null || true
}

vnc_url() {
    local url
    url="$(tf_output vnc_url)"
    if [[ -n "$url" ]]; then
        printf '%s\n' "$url"
    else
        printf '%s\n' "vnc://127.0.0.1:5902"
    fi
}

vnc_port() {
    vnc_url | sed -E 's#^vnc://[^:]+:([0-9]+).*#\1#'
}

vm_status() {
    local pidfile vm_name pid port
    pidfile="$(tf_output pidfile_path)"
    vm_name="$(tf_output vm_name)"
    port="$(vnc_port)"
    pid=""

    if [[ -n "$pidfile" && -f "$pidfile" ]]; then
        pid="$(cat "$pidfile" 2>/dev/null || true)"
    fi
    if [[ -z "$pid" && -n "$vm_name" ]]; then
        pid="$(pgrep -f "qemu-system.*-name $vm_name" | head -1 || true)"
    fi

    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
        printf 'vm=running pid=%s\n' "$pid"
    else
        printf 'vm=stopped\n'
    fi

    if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
        printf 'vnc=reachable port=%s\n' "$port"
    else
        printf 'vnc=closed port=%s\n' "$port"
    fi
}

show_guide() {
    cat << 'EOF'
OPNsense VNC guide

Open the viewer:

  scripts/vnc-helper.sh open

Take a screenshot:

  Use the vnc-operator skill: scripts/vncctl.py screenshot ./opnsense-vnc.png

Type into the console:

  Use the vnc-operator skill: scripts/vncctl.py type "installer\n"

Runtime console:

  The installed appliance should boot to the normal OPNsense console menu.
  Use the Web UI and API for administration after the menu appears.

Installer screen:

  Login as installer to start installation.

Importer detour:

  Prompt: Select device to import from (e.g. ada0) or leave blank to exit:
  Error: The file /conf/config.xml could not be found.

  Leave the importer and return to the live-media login prompt, then login as installer.

Project commands:

  make start
  make status
  make open-vnc
EOF
}

show_help() {
    cat << EOF
OPNsense VNC Helper

Usage: $0 <command>

Commands:
    url        Print Terraform VNC URL
    open       Open VNC viewer with Terraform VNC URL
    status     Show QEMU process and local VNC port status
    guide      Show OPNsense VNC installer/runtime guide
    help       Show this help

Defaults:
    TF_DIR     $TF_DIR
    fallback   vnc://127.0.0.1:5902
EOF
}

case "${1:-help}" in
    url)
        vnc_url
        ;;
    open)
        open "$(vnc_url)"
        ;;
    status)
        vm_status
        ;;
    guide)
        show_guide
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1" >&2
        show_help
        exit 1
        ;;
esac
