# AGENTS

## Purpose

This directory contains a local QEMU-based OPNsense lab on Apple Silicon.

The VM is installed to disk and should be managed as a persistent local appliance, not a live installer.

## VM layout

- VM name: `opnsense-install`
- Disk: `./vm/opnsense-install.qcow2`
- PID file: `./vm/opnsense-install.pid`
- Log file: `./vm/opnsense-install.log`
- API key file: `./secrets/OPNsense.internal_root_apikey.txt`

## Networking

QEMU NIC order is intentionally arranged as:

- `em0 = LAN`
- `em1 = WAN`
- `em2 = PORTAL`

QEMU networking:

- LAN subnet: `192.168.60.0/24`
- WAN subnet: `10.0.2.0/24`
- PORTAL subnet: `192.168.70.0/24`
- LAN backend: `vmnet-host`
- LAN OPNsense IP: `192.168.60.254`
- PORTAL backend: `vmnet-host`
- PORTAL OPNsense IP: `192.168.70.254`

Forwarded ports:

- `https://192.168.60.254`
- `http://192.168.60.254`
- `vnc://127.0.0.1:5902`

## Operational rules

- Prefer `make start`, `make stop`, `make restart`, and `make status` instead of manually retyping QEMU flags.
- Do not switch back to the raw `.img` boot flow unless explicitly requested.
- Do not use live mode for normal operation.
- Preserve the `em0/em1` ordering because it avoids repeated interface reassignment in OPNsense.
- Treat `OPNsense.internal_root_apikey.txt` and downloaded config XML as sensitive.
- Never commit API keys, secrets, or exported configuration files.

## Useful commands

```bash
make start
make stop
make restart
make status
make open-vnc
make open-web
make open-portal
make curl-health
make portal-health
make config
make backups
```

## API

Read current config:

```bash
curl -sk -u "$KEY:$SECRET" \
  "https://127.0.0.1:10443/api/core/backup/download/this"
```

List backups:

```bash
curl -sk -u "$KEY:$SECRET" \
  "https://127.0.0.1:10443/api/core/backup/backups/this"
```
