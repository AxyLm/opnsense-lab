locals {
  root_dir    = abspath("${path.module}/..")
  docs_dir    = "${local.root_dir}/docs"
  images_dir  = "${local.root_dir}/images"
  vm_dir      = "${local.root_dir}/vm"
  secrets_dir = "${local.root_dir}/secrets"

  disk_path     = "${local.vm_dir}/${var.vm_name}.qcow2"
  pidfile_path  = "${local.vm_dir}/${var.vm_name}.pid"
  logfile_path  = "${local.vm_dir}/${var.vm_name}.log"
  apikey_path   = "${local.secrets_dir}/OPNsense.internal_root_apikey.txt"
  makefile_path = "${local.root_dir}/Makefile"
  agents_path   = "${local.root_dir}/AGENTS.md"
  guide_path    = "${local.docs_dir}/OPNsense-QEMU.md"

  image_paths = {
    dvd_iso  = "${local.images_dir}/OPNsense-26.1.6-dvd-amd64.iso"
    dvd_bz2  = "${local.images_dir}/OPNsense-26.1.6-dvd-amd64.iso.bz2"
    vga_img  = "${local.images_dir}/OPNsense-26.1.6-vga-amd64.img"
    vga_bz2  = "${local.images_dir}/OPNsense-26.1.6-vga-amd64.img.bz2"
    old_disk = "${local.vm_dir}/opnsense-2616.qcow2"
    old_log  = "${local.vm_dir}/opnsense-2616.log"
  }

  networks = {
    lan = {
      subnet     = var.lan_network
      gateway_ip = var.lan_gateway_ip
      dhcp_start = var.lan_dhcp_start
      mac        = var.lan_mac
      host_forwards = [
        "hostfwd=tcp:127.0.0.1:${var.https_port}-${var.lan_gateway_ip}:443",
        "hostfwd=tcp:127.0.0.1:${var.http_port}-${var.lan_gateway_ip}:80",
      ]
    }
    wan = {
      subnet        = var.wan_network
      gateway_ip    = var.wan_gateway_ip
      dhcp_start    = var.wan_dhcp_start
      mac           = var.wan_mac
      host_forwards = []
    }
    portal = {
      subnet     = var.portal_network
      gateway_ip = var.portal_gateway_ip
      dhcp_start = var.portal_dhcp_start
      mac        = var.portal_mac
      host_forwards = [
        "hostfwd=tcp:127.0.0.1:${var.portal_http_port}-${var.portal_gateway_ip}:80",
        "hostfwd=tcp:127.0.0.1:${var.portal_https_port}-${var.portal_gateway_ip}:443",
        "hostfwd=tcp:127.0.0.1:${var.portal_login_port}-${var.portal_gateway_ip}:8000",
      ]
    }
  }

  lan_user_netdev = "-netdev user,id=lan,net=${local.networks.lan.subnet},dhcpstart=${local.networks.lan.dhcp_start},${join(",", local.networks.lan.host_forwards)}"
  lan_vmnet_netdev = join(",", [
    "-netdev vmnet-host",
    "id=lan",
    "start-address=${var.lan_host_start}",
    "end-address=${var.lan_host_end}",
    "subnet-mask=${var.lan_subnet_mask}",
  ])
  lan_netdev = var.lan_backend == "vmnet-host" ? local.lan_vmnet_netdev : local.lan_user_netdev

  wan_user_netdev = "-netdev user,id=wan,net=${local.networks.wan.subnet},dhcpstart=${local.networks.wan.dhcp_start}"
  wan_vmnet_netdev = join(",", [
    "-netdev vmnet-host",
    "id=wan",
    "start-address=${var.wan_host_start}",
    "end-address=${var.wan_host_end}",
    "subnet-mask=${var.wan_subnet_mask}",
  ])
  wan_netdev = var.wan_backend == "vmnet-host" ? local.wan_vmnet_netdev : local.wan_user_netdev

  portal_user_netdev = "-netdev user,id=portal,net=${local.networks.portal.subnet},dhcpstart=${local.networks.portal.dhcp_start},${join(",", local.networks.portal.host_forwards)}"
  portal_vmnet_netdev = join(",", [
    "-netdev vmnet-host",
    "id=portal",
    "start-address=${var.portal_host_start}",
    "end-address=${var.portal_host_end}",
    "subnet-mask=${var.portal_subnet_mask}",
  ])
  portal_netdev      = var.portal_backend == "vmnet-host" ? local.portal_vmnet_netdev : local.portal_user_netdev
  qemu_requires_root = contains([var.lan_backend, var.wan_backend, var.portal_backend], "vmnet-host")

  qemu_args = [
    "-name ${var.vm_name}",
    "-machine q35",
    "-cpu max",
    "-smp 2",
    "-m 4096",
    "-boot order=c,menu=on",
    "-drive file=\"${local.disk_path}\",if=virtio,format=qcow2",
    local.lan_netdev,
    "-device e1000,netdev=lan,mac=${local.networks.lan.mac}",
    local.wan_netdev,
    "-device e1000,netdev=wan,mac=${local.networks.wan.mac}",
    local.portal_netdev,
    "-device e1000,netdev=portal,mac=${local.networks.portal.mac}",
    "-vnc 127.0.0.1:${var.vnc_display}",
    "-daemonize",
    "-pidfile \"${local.pidfile_path}\"",
    "-D \"${local.logfile_path}\"",
  ]
}

resource "terraform_data" "lab_layout" {
  input = {
    root_dir      = local.root_dir
    docs_dir      = local.docs_dir
    images_dir    = local.images_dir
    vm_dir        = local.vm_dir
    secrets_dir   = local.secrets_dir
    disk_path     = local.disk_path
    pidfile_path  = local.pidfile_path
    logfile_path  = local.logfile_path
    apikey_path   = local.apikey_path
    makefile_path = local.makefile_path
    agents_path   = local.agents_path
    guide_path    = local.guide_path
    image_paths   = local.image_paths
    networks      = local.networks
  }

  lifecycle {
    precondition {
      condition     = fileexists(local.makefile_path)
      error_message = "Makefile is missing from the workspace root."
    }

    precondition {
      condition     = fileexists(local.agents_path)
      error_message = "AGENTS.md is missing from the workspace root."
    }

    precondition {
      condition     = fileexists(local.guide_path)
      error_message = "docs/OPNsense-QEMU.md is missing."
    }

    precondition {
      condition     = fileexists(local.disk_path)
      error_message = "The active VM disk is missing from vm/."
    }

    precondition {
      condition     = fileexists(local.apikey_path)
      error_message = "The API key file is missing from secrets/."
    }

    precondition {
      condition     = can(cidrhost(var.lan_network, 1)) && can(cidrhost(var.wan_network, 1)) && can(cidrhost(var.portal_network, 1))
      error_message = "LAN/WAN/PORTAL subnet values must be valid CIDR blocks."
    }
  }
}
