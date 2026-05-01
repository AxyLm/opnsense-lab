# OPNsense Bootstrap Plan

## Goal

Provide a near one-click bootstrap flow that:

1. creates a fresh VM disk
2. boots from the OPNsense ISO
3. installs OPNsense onto the new disk
4. waits for the installed system to come up
5. provisions an API key
6. writes the key and secret to `./secrets/OPNsense.internal_root_apikey.txt`

## Bottom line

A near one-click workflow is realistic.
A pure stock-ISO zero-touch install is not something this repo should assume without additional installer automation.
The practical solution is to orchestrate QEMU plus installer automation plus post-install API bootstrap.

## Automation boundary

### Fully automatable

- create a fresh qcow2 disk
- boot QEMU from `./images/OPNsense-26.1.6-dvd-amd64.iso`
- attach the target disk
- reuse the existing LAN/WAN topology
- wait for the VM to become reachable
- persist the generated API key on the host
- switch back to the installed runtime disk for normal operations

### Semi-automatable

- installer interaction through serial console automation
- installer interaction through VNC automation
- first-login workflow used to create the API key
- readiness checks for first boot and web UI availability

### Not realistically guaranteed as pure zero-touch

- unattended install using only a stock ISO and no console/UI automation
- API key creation before the installed system is fully initialized and reachable

## Recommended approach

Use `Makefile` as the operator entrypoint and add a dedicated bootstrap workflow.

Primary entrypoint:

```bash
make bootstrap
```

## Proposed flow

1. create a fresh install disk under `./vm/`
2. boot a temporary installer VM from `./images/OPNsense-26.1.6-dvd-amd64.iso`
3. attach the new qcow2 disk as the install target
4. automate the installer through serial console or VNC
5. reboot into the installed system
6. wait for `https://127.0.0.1:10443` to become reachable
7. authenticate with bootstrap credentials
8. create an API key for backup/config access
9. write the key and secret to `./secrets/OPNsense.internal_root_apikey.txt`
10. stop the installer mode and continue using the installed disk with the normal runtime targets

## Smallest viable implementation

### Phase 1

- add a `make bootstrap` target
- create a fresh qcow2 disk for install
- add QEMU flags for ISO boot
- keep the same LAN/WAN NIC ordering
- wait for the installer to come up

### Phase 2

- add installer automation
- prefer serial console automation if stable
- fall back to VNC automation if needed

### Phase 3

- add post-install API bootstrap
- verify web UI readiness
- create the API key
- write `key=...` and `secret=...` to the host file

### Phase 4

- verify with existing commands:
  - `make start`
  - `make status`
  - `make curl-health`
  - `make config`
  - `make backups`

## Repo impact

Likely files to update:

- `Makefile`
- `docs/OPNsense-QEMU.md`
- `AGENTS.md`
- optionally `terrform/` if bootstrap parameters should be modeled there

Likely new artifacts:

- bootstrap script for installer automation
- temporary install disk or temporary installer runtime files under `./vm/`

## Risks

### Installer automation fragility

The installer UI or boot timing may vary across versions.
Mitigation: keep the automation version-scoped and avoid over-generalizing.

### First-boot timing

The web UI may take time to become reachable after install.
Mitigation: use explicit readiness polling before API setup.

### API bootstrap dependency

API key creation depends on a working initial login path.
Mitigation: treat post-install login automation as a separate, testable step.

### Secret handling

The generated key file is sensitive.
Mitigation: write only to `./secrets/OPNsense.internal_root_apikey.txt` and never commit it.

## Decision

Proceed with a near one-click bootstrap flow.
Do not assume a pure unattended stock-ISO install without installer automation.
