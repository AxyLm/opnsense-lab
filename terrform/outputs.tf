output "workspace_paths" {
  description = "Canonical paths for the local OPNsense lab"
  value = {
    root    = local.root_dir
    docs    = local.docs_dir
    images  = local.images_dir
    vm      = local.vm_dir
    secrets = local.secrets_dir
  }
}

output "runtime_files" {
  description = "Primary runtime files for the active VM"
  value = {
    disk    = local.disk_path
    pidfile = local.pidfile_path
    logfile = local.logfile_path
    apikey  = local.apikey_path
  }
}

output "vm_name" {
  description = "Persistent OPNsense VM name"
  value       = var.vm_name
}

output "pidfile_path" {
  description = "PID file path for the active VM"
  value       = local.pidfile_path
}

output "logfile_path" {
  description = "Log file path for the active VM"
  value       = local.logfile_path
}

output "apikey_path" {
  description = "API key file path"
  value       = local.apikey_path
  sensitive   = true
}

output "network_layout" {
  description = "Modeled LAN/WAN/PORTAL network settings for the local OPNsense lab"
  value = {
    lan = {
      backend       = var.lan_backend
      subnet        = local.networks.lan.subnet
      gateway_ip    = local.networks.lan.gateway_ip
      dhcp_start    = local.networks.lan.dhcp_start
      mac           = local.networks.lan.mac
      https_forward = var.lan_backend == "user" ? "127.0.0.1:${var.https_port} -> ${local.networks.lan.gateway_ip}:443" : null
      http_forward  = var.lan_backend == "user" ? "127.0.0.1:${var.http_port} -> ${local.networks.lan.gateway_ip}:80" : null
    }
    wan = {
      backend    = var.wan_backend
      subnet     = local.networks.wan.subnet
      gateway_ip = local.networks.wan.gateway_ip
      dhcp_start = local.networks.wan.dhcp_start
      mac        = local.networks.wan.mac
    }
    portal = {
      backend       = var.portal_backend
      subnet        = local.networks.portal.subnet
      gateway_ip    = local.networks.portal.gateway_ip
      dhcp_start    = local.networks.portal.dhcp_start
      mac           = local.networks.portal.mac
      http_forward  = var.portal_backend == "user" ? "127.0.0.1:${var.portal_http_port} -> ${local.networks.portal.gateway_ip}:80" : null
      https_forward = var.portal_backend == "user" ? "127.0.0.1:${var.portal_https_port} -> ${local.networks.portal.gateway_ip}:443" : null
      login_forward = var.portal_backend == "user" ? "127.0.0.1:${var.portal_login_port} -> ${local.networks.portal.gateway_ip}:8000" : null
    }
  }
}

output "management_urls" {
  description = "Local endpoints for the OPNsense lab"
  value = {
    web_ui       = var.lan_backend == "vmnet-host" ? "https://${local.networks.lan.gateway_ip}" : "https://127.0.0.1:${var.https_port}"
    http         = var.lan_backend == "vmnet-host" ? "http://${local.networks.lan.gateway_ip}" : "http://127.0.0.1:${var.http_port}"
    portal_http  = var.portal_backend == "vmnet-host" ? "http://${local.networks.portal.gateway_ip}" : "http://127.0.0.1:${var.portal_http_port}"
    portal_https = var.portal_backend == "vmnet-host" ? "https://${local.networks.portal.gateway_ip}" : "https://127.0.0.1:${var.portal_https_port}"
    portal_login = var.portal_backend == "vmnet-host" ? "http://${local.networks.portal.gateway_ip}:${var.portal_login_port}" : "http://127.0.0.1:${var.portal_login_port}"
    vnc          = "vnc://127.0.0.1:${5900 + var.vnc_display}"
  }
}

output "web_ui_url" {
  description = "Local Web UI URL"
  value       = var.lan_backend == "vmnet-host" ? "https://${local.networks.lan.gateway_ip}" : "https://127.0.0.1:${var.https_port}"
}

output "api_base_url" {
  description = "Local API base URL"
  value       = var.lan_backend == "vmnet-host" ? "https://${local.networks.lan.gateway_ip}" : "https://127.0.0.1:${var.https_port}"
}

output "portal_http_url" {
  description = "Local captive portal HTTP test URL"
  value       = var.portal_backend == "vmnet-host" ? "http://${local.networks.portal.gateway_ip}" : "http://127.0.0.1:${var.portal_http_port}"
}

output "portal_login_url" {
  description = "Local captive portal login service URL"
  value       = var.portal_backend == "vmnet-host" ? "http://${local.networks.portal.gateway_ip}:${var.portal_login_port}" : "http://127.0.0.1:${var.portal_login_port}"
}

output "vnc_url" {
  description = "Local VNC URL"
  value       = "vnc://127.0.0.1:${5900 + var.vnc_display}"
}

output "qemu_command" {
  description = "Equivalent QEMU command assembled from Terraform locals"
  value       = join(" \\\n  ", concat(["qemu-system-x86_64"], local.qemu_args))
}

output "qemu_command_exec" {
  description = "Single-line QEMU command for Makefile execution"
  value       = join(" ", concat(["qemu-system-x86_64"], local.qemu_args))
}

output "qemu_requires_root" {
  description = "Whether the generated QEMU command uses a macOS vmnet backend"
  value       = local.qemu_requires_root
}

output "recommended_make_targets" {
  description = "Convenience commands for daily VM operations"
  value = [
    "make start",
    "make stop",
    "make restart",
    "make status",
    "make open-web",
    "make open-portal",
    "make curl-health",
    "make portal-health",
    "make config",
    "make backups",
  ]
}
