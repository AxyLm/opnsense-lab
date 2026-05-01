---
name: vnc-operator
description: Operate a local NoAuth RFB/VNC endpoint by typing text and capturing PNG screenshots. Use for QEMU VNC consoles and installer screens exposed on localhost.
---

# VNC Operator

Small standalone VNC operation tool for local QEMU/RFB consoles.

## Commands

```bash
scripts/vncctl.py screenshot ./vnc.png
scripts/vncctl.py type "installer\n"
```

## Defaults

- Host: `127.0.0.1`
- Port: `VNC_PORT`, then Terraform `vnc_url` when run inside a project, then `5902`
- Auth: RFB NoAuth
- Screenshot output: PNG

## Options

```bash
scripts/vncctl.py screenshot ./vnc.png --host 127.0.0.1 --port 5902
scripts/vncctl.py type "root\n" --delay 0.03
```

For OPNsense installer screens, take a screenshot first, inspect the visible state, then type the exact next input.
