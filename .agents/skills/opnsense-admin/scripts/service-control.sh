#!/bin/bash
# OPNsense service control for this Terraform-managed QEMU lab.

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

SSH_USER="${SSH_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
OPNSENSE_SSH_HOST="${OPNSENSE_SSH_HOST:-}"

tf_output() {
    "$TERRAFORM" -chdir="$TF_DIR" output -raw "$1" 2>/dev/null || true
}

url_host() {
    sed -E 's#^[a-zA-Z]+://([^/:]+).*#\1#'
}

load_lab_defaults() {
    if [[ -z "$OPNSENSE_SSH_HOST" ]]; then
        local web_url
        web_url="$(tf_output web_ui_url)"
        if [[ -n "$web_url" ]]; then
            OPNSENSE_SSH_HOST="$(printf '%s' "$web_url" | url_host)"
        fi
    fi
    if [[ -z "$OPNSENSE_SSH_HOST" ]]; then
        OPNSENSE_SSH_HOST="192.168.60.254"
    fi
}

show_help() {
    cat << EOF
OPNsense Service Control

Usage: $0 <service> <action> [options]

Services:
    unbound         DNS Resolver
    suricata        Intrusion Detection/Prevention
    dhcpd           DHCP Server
    dpinger         Gateway Monitoring
    ssh             SSH Server
    webgui          Web Interface (nginx)
    syslogd         System Logging
    cron            Cron Daemon
    all             All services

Actions:
    start           Start service
    stop            Stop service
    restart         Restart service
    status          Check service status
    reload          Reload configuration

Options:
    -h, --host      OPNsense SSH host (default: Terraform output web_ui_url host)
    -p, --port      SSH port (default: 22)
    -u, --user      SSH user (default: root)
    --help          Show this help

Examples:
    $0 unbound restart
    $0 suricata status
    $0 dhcpd reload
    $0 all status
EOF
}

SERVICE="${1:-}"
ACTION="${2:-}"
shift $(( $# >= 2 ? 2 : $# ))

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host)
            OPNSENSE_SSH_HOST="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -u|--user)
            SSH_USER="$2"
            shift 2
            ;;
        --help)
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

if [[ -z "$SERVICE" || -z "$ACTION" ]]; then
    show_help
    exit 1
fi

case "$ACTION" in
    start|stop|restart|status|reload)
        ;;
    *)
        echo "Invalid action: $ACTION" >&2
        show_help
        exit 1
        ;;
esac

case "$SERVICE" in
    unbound)
        SERVICE_NAME="unbound"
        ;;
    suricata|ids|ips)
        SERVICE_NAME="suricata"
        ;;
    dhcpd|dhcp)
        SERVICE_NAME="dhcpd"
        ;;
    dpinger)
        SERVICE_NAME="dpinger"
        ;;
    ssh)
        SERVICE_NAME="sshd"
        ;;
    webgui|nginx)
        SERVICE_NAME="nginx"
        ;;
    syslogd|syslog)
        SERVICE_NAME="syslogd"
        ;;
    cron)
        SERVICE_NAME="cron"
        ;;
    all)
        SERVICE_NAME="all"
        ;;
    *)
        echo "Unknown service: $SERVICE" >&2
        show_help
        exit 1
        ;;
esac

load_lab_defaults

ssh_run() {
    ssh -p "$SSH_PORT" "${SSH_USER}@${OPNSENSE_SSH_HOST}" "$1"
}

echo "Host: ${SSH_USER}@${OPNSENSE_SSH_HOST}:${SSH_PORT}"

if [[ "$ACTION" == "status" ]]; then
    echo "Checking status of $SERVICE_NAME..."
    if [[ "$SERVICE_NAME" == "all" ]]; then
        ssh_run "service -e | head -20"
    else
        ssh_run "
            echo '=== Service Status ===' && \
            service $SERVICE_NAME status 2>&1 && \
            echo '' && \
            echo '=== Process Info ===' && \
            pgrep -lf $SERVICE_NAME 2>/dev/null || echo 'No running processes' && \
            echo '' && \
            echo '=== Recent Log Entries ===' && \
            tail -5 /var/log/system/latest.log 2>/dev/null | grep -i $SERVICE_NAME || echo 'No recent log entries'
        "
    fi
else
    echo "Executing: $ACTION $SERVICE_NAME"
    if [[ "$SERVICE_NAME" == "all" ]]; then
        ssh_run "service -e | while read svc; do echo \"=== \$svc ===\"; service \$(basename \$svc) $ACTION 2>&1; done"
    else
        ssh_run "service $SERVICE_NAME $ACTION 2>&1"
    fi
fi

echo "Done."
