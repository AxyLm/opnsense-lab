# OPNsense lab

Local OPNsense lab on QEMU.

## Layout

```text
.
├── AGENTS.md
├── CLAUDE.md
├── Makefile
├── README.md
├── docs/
│   └── OPNsense-QEMU.md
├── images/
│   ├── OPNsense-26.1.6-dvd-amd64.iso
│   ├── OPNsense-26.1.6-dvd-amd64.iso.bz2
│   ├── OPNsense-26.1.6-vga-amd64.img
│   └── OPNsense-26.1.6-vga-amd64.img.bz2
├── secrets/
│   └── OPNsense.internal_root_apikey.txt
├── terrform/
│   ├── .gitignore
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
└── vm/
    ├── opnsense-2616.log
    ├── opnsense-2616.qcow2
    ├── opnsense-install.log
    ├── opnsense-install.pid
    └── opnsense-install.qcow2
```

## Runtime

- Active VM: `opnsense-install`
- Active disk: `./vm/opnsense-install.qcow2`
- PID file: `./vm/opnsense-install.pid`
- Log file: `./vm/opnsense-install.log`
- API key file: `./secrets/OPNsense.internal_root_apikey.txt`

## Networking

- `em0 = LAN`
- `em1 = WAN`
- `em2 = PORTAL`
- LAN subnet: `192.168.60.0/24`
- WAN subnet: `10.0.2.0/24`
- PORTAL subnet: `192.168.70.0/24`
- LAN backend: `vmnet-host`
- LAN OPNsense IP: `192.168.60.254`
- Web UI: `https://192.168.60.254`
- PORTAL backend: `vmnet-host`
- PORTAL OPNsense IP: `192.168.70.254`
- PORTAL HTTP: `http://192.168.70.254`
- PORTAL login: `http://192.168.70.254:8000`
- VNC: `127.0.0.1:5902`

## Makefile

`make` targets read Terraform outputs from `terrform/`. Edit VM networking and port values in Terraform, then use `make restart` to run the generated QEMU command.

Common commands:

```bash
make start
make stop
make restart
make status
make logs
make open-vnc
make open-web
make open-portal
make curl-health
make portal-health
make config
make backups
```

## Terraform

The `terrform/` directory models:

- workspace paths
- runtime files
- LAN/WAN/PORTAL network settings
- host port forwards and macOS vmnet-host settings
- the equivalent QEMU command

Useful files:

- `terrform/variables.tf`
- `terrform/main.tf`
- `terrform/outputs.tf`
- `terrform/terraform.tfvars.example`

Example:

```bash
cd terrform
terraform init
terraform plan
terraform output
```

To customize the internal network, start from:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit values like:

```hcl
lan_network    = "192.168.60.0/24"
lan_gateway_ip = "192.168.60.254"
lan_dhcp_start = "192.168.60.10"
lan_backend = "vmnet-host"
wan_network    = "10.0.2.0/24"
wan_dhcp_start = "10.0.2.15"
portal_network = "192.168.70.0/24"
portal_gateway_ip = "192.168.70.254"
portal_backend = "vmnet-host"
```

## Fresh install from ISO

### Current status

This repo currently manages an already-installed OPNsense disk.
It does **not** yet perform a full fresh install from the ISO automatically.

### Can this become one-click?

**Mostly yes, but not as a pure stock-ISO zero-touch flow without automation around the installer.**

What is realistically automatable:

1. create a new qcow2 disk
2. boot QEMU from `./images/OPNsense-26.1.6-dvd-amd64.iso`
3. attach the empty target disk
4. wait for the installer to become reachable
5. drive the installer through serial/VNC automation
6. wait for OPNsense web UI on `https://127.0.0.1:10443`
7. log in with the bootstrap credentials
8. create an API user/key
9. write the generated key and secret to `./secrets/OPNsense.internal_root_apikey.txt`

What is **not** realistically guaranteed from the current repo alone:

- a documented stock-ISO unattended install path with no console or UI automation at all
- automatic API key creation before the installed system is reachable and initialized

### Recommended implementation path

The smallest practical approach is:

1. keep `Makefile` as the operator entrypoint
2. add a new target such as `make bootstrap`
3. create a fresh install disk under `./vm/`
4. boot from ISO with the same LAN/WAN topology
5. automate the installer through serial console or VNC/browser automation
6. after first boot, automate API key creation and save it to `./secrets/OPNsense.internal_root_apikey.txt`
7. switch the VM to the installed disk and reuse the existing `make start/stop/status/config/backups`

### Safety notes

- `./secrets/OPNsense.internal_root_apikey.txt` is sensitive
- exported configs are sensitive
- do not commit secrets or exported configuration files
- old experimental disks in `./vm/` are kept for now and should be deleted only after confirmation

## Bootstrap

- `./docs/OPNsense-bootstrap-plan.md`
