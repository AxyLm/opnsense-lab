---
name: opnsense-admin
description: Manage the local Terraform-driven QEMU OPNsense lab. Use for OPNsense API checks, config backups, service inspection, Suricata/Unbound diagnostics, and explicit firewall administration against the persistent VM in this repository.
---

# OPNsense Admin

This project skill is tailored for this repository.

## Lab Truth

- VM lifecycle: `make start`, `make stop`, `make restart`, `make status`
- Terraform directory: `terrform/`
- Active VM: `opnsense-install`
- API key file: `secrets/OPNsense.internal_root_apikey.txt`
- API base URL: `terraform -chdir=terrform output -raw api_base_url`
- Web UI: `terraform -chdir=terrform output -raw web_ui_url`
- VNC: `terraform -chdir=terrform output -raw vnc_url`
- LAN IP: `192.168.60.254`
- PORTAL IP: `192.168.70.254`

The scripts resolve Terraform outputs automatically from the repository root.

## Safety Rules

- Treat API keys, config XML, and backup files as sensitive.
- Use `make` targets for VM lifecycle.
- Take a config backup before firewall, NAT, DNS, IDS/IPS, or service changes.
- Run read-only API checks before write operations.
- Use `service-control.sh` only for explicit service actions.

## Scripts

Run scripts from the skill folder.

API checks:

```bash
scripts/opnsense-api.sh lab
scripts/opnsense-api.sh status
scripts/opnsense-api.sh firmware-status
scripts/opnsense-api.sh interfaces
scripts/opnsense-api.sh suricata-status
scripts/opnsense-api.sh unbound-stats
```

Custom API calls:

```bash
scripts/opnsense-api.sh get /api/core/system/status
scripts/opnsense-api.sh post /api/core/system/reboot
```

Config backups:

```bash
scripts/backup-config.sh
scripts/backup-config.sh --config-only
scripts/backup-config.sh --dir ./backups --keep 90
```

Service inspection and control:

```bash
scripts/service-control.sh unbound status
scripts/service-control.sh suricata status
scripts/service-control.sh webgui restart
```

VNC helper:

```bash
scripts/vnc-helper.sh url
scripts/vnc-helper.sh open
scripts/vnc-helper.sh status
scripts/vnc-helper.sh guide
```

For raw VNC typing and screenshots, use the `vnc-operator` skill.

Lab config patch for OPNsense shell:

```bash
php scripts/opnsense-lab-config.php
```

## Environment Overrides

| Variable | Default |
| --- | --- |
| `TERRAFORM` | `terraform` |
| `TF_DIR` | `<project>/terrform` |
| `OPNSENSE_API_BASE_URL` | Terraform output `api_base_url` |
| `OPNSENSE_API_KEY_FILE` | Terraform output `apikey_path` |
| `OPNSENSE_INSECURE` | `true` |
| `BACKUP_DIR` | `backups` under this skill |
| `KEEP_DAYS` | `30` |
| `OPNSENSE_SSH_HOST` | host parsed from Terraform output `web_ui_url` |
| `SSH_PORT` | `22` |
| `SSH_USER` | `root` |
| `OPNSENSE_CONFIG_PATH` | `/conf/config.xml` |
| `OPNSENSE_LAN_DEVICE` | `em0` |
| `OPNSENSE_LAN_INTERFACE` | `lan` |
| `OPNSENSE_LAN_IP` | `192.168.60.254` |
| `OPNSENSE_LAN_SUBNET` | `24` |
| `OPNSENSE_PORTAL_DEVICE` | `em2` |
| `OPNSENSE_PORTAL_INTERFACE` | `opt1` |
| `OPNSENSE_PORTAL_IP` | `192.168.70.254` |
| `OPNSENSE_PORTAL_SUBNET` | `24` |
| `OPNSENSE_PORTAL_SERVERNAME` | `192.168.70.254` |

## VNC Screen Guidance

For the persistent installed VM, expect the normal OPNsense console menu. Use the Web UI and API once that menu is visible.

For installer workflows, the live-media banner asks for `installer` to start installation. Use that login for disk installation.

The config importer prompt `Select device to import from (e.g. ada0) or leave blank to exit:` plus `The file /conf/config.xml could not be found.` means the screen is in the restore/import path. Leave that prompt and return to the live-media login prompt, then use `installer`.

## Common API Endpoints

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/api/core/system/status` | GET | System health |
| `/api/core/firmware/status` | GET | Firmware info |
| `/api/ids/service/status` | GET | Suricata status |
| `/api/unbound/diagnostics/stats` | GET | DNS stats |
| `/api/diagnostics/interface/getInterfaceConfig` | GET | Interface config |
| `/api/diagnostics/firewall/pfstatists` | GET | Firewall stats |
| `/api/core/backup/backup` | GET | Download config backup |

## Troubleshooting

Check Terraform outputs:

```bash
terraform -chdir=terrform output
```

Check VM state:

```bash
make status
make curl-health
```

Check API credentials:

```bash
grep '^key=' secrets/OPNsense.internal_root_apikey.txt
grep '^secret=' secrets/OPNsense.internal_root_apikey.txt
```

Inspect script defaults:

```bash
scripts/opnsense-api.sh lab
```

Take a VNC screenshot:

Use the `vnc-operator` skill with `scripts/vncctl.py screenshot ./opnsense-vnc.png`.
