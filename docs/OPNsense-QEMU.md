# OPNsense on QEMU

## Current VM

- Disk: `./vm/opnsense-install.qcow2`
- PID file: `./vm/opnsense-install.pid`
- Log file: `./vm/opnsense-install.log`
- API key file: `./secrets/OPNsense.internal_root_apikey.txt`

## Network layout

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

Port forwarding:

- `https://192.168.60.254`
- `http://192.168.60.254`
- `vnc://127.0.0.1:5902`

## Access

- Web UI: `https://192.168.60.254`
- Captive portal test HTTP: `http://192.168.70.254`
- Captive portal login service: `http://192.168.70.254:8000`
- VNC: `vnc://127.0.0.1:5902`

## Start command

The Makefile reads this command from the Terraform `qemu_command_exec` output.

```bash
qemu-system-x86_64 \
  -name opnsense-install \
  -machine q35 \
  -cpu max \
  -smp 2 \
  -m 4096 \
  -boot order=c,menu=on \
  -drive file="./vm/opnsense-install.qcow2",if=virtio,format=qcow2 \
  -netdev vmnet-host,id=lan,start-address=192.168.60.2,end-address=192.168.60.253,subnet-mask=255.255.255.0 \
  -device e1000,netdev=lan,mac=52:54:00:22:34:56 \
  -netdev user,id=wan,net=10.0.2.0/24,dhcpstart=10.0.2.15 \
  -device e1000,netdev=wan,mac=52:54:00:22:34:57 \
  -netdev vmnet-host,id=portal,start-address=192.168.70.2,end-address=192.168.70.253,subnet-mask=255.255.255.0 \
  -device e1000,netdev=portal,mac=52:54:00:22:34:58 \
  -vnc 127.0.0.1:2 \
  -daemonize \
  -pidfile "./vm/opnsense-install.pid" \
  -D "./vm/opnsense-install.log"
```

## Stop command

```bash
kill "$(cat ./vm/opnsense-install.pid)"
```

## Restart command

```bash
kill "$(cat ./vm/opnsense-install.pid)" && \
qemu-system-x86_64 \
  -name opnsense-install \
  -machine q35 \
  -cpu max \
  -smp 2 \
  -m 4096 \
  -boot order=c,menu=on \
  -drive file="./vm/opnsense-install.qcow2",if=virtio,format=qcow2 \
  -netdev vmnet-host,id=lan,start-address=192.168.60.2,end-address=192.168.60.253,subnet-mask=255.255.255.0 \
  -device e1000,netdev=lan,mac=52:54:00:22:34:56 \
  -netdev user,id=wan,net=10.0.2.0/24,dhcpstart=10.0.2.15 \
  -device e1000,netdev=wan,mac=52:54:00:22:34:57 \
  -netdev vmnet-host,id=portal,start-address=192.168.70.2,end-address=192.168.70.253,subnet-mask=255.255.255.0 \
  -device e1000,netdev=portal,mac=52:54:00:22:34:58 \
  -vnc 127.0.0.1:2 \
  -daemonize \
  -pidfile "./vm/opnsense-install.pid" \
  -D "./vm/opnsense-install.log"
```

## Read current config via API

```bash
KEY="$(grep '^key=' ./secrets/OPNsense.internal_root_apikey.txt | cut -d= -f2-)"
SECRET="$(grep '^secret=' ./secrets/OPNsense.internal_root_apikey.txt | cut -d= -f2-)"

curl -sk -u "$KEY:$SECRET" \
  "https://192.168.60.254/api/core/backup/download/this" \
  -o current-config.xml
```

## List config backups via API

```bash
KEY="$(grep '^key=' ./secrets/OPNsense.internal_root_apikey.txt | cut -d= -f2-)"
SECRET="$(grep '^secret=' ./secrets/OPNsense.internal_root_apikey.txt | cut -d= -f2-)"

curl -sk -u "$KEY:$SECRET" \
  "https://192.168.60.254/api/core/backup/backups/this"
```

## Notes

- This VM is installed to disk, not running in live mode.
- `em0/em1` order is intentionally flipped in QEMU so OPNsense maps them as `LAN/WAN` more naturally.
- `em2` is reserved for captive portal experiments.
- The exported config contains sensitive data. Do not commit it to git.
