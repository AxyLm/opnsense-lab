variable "vm_name" {
  type        = string
  description = "Persistent OPNsense VM name"
  default     = "opnsense-install"
}

variable "https_port" {
  type        = number
  description = "Forwarded HTTPS port on localhost"
  default     = 10443
}

variable "http_port" {
  type        = number
  description = "Forwarded HTTP port on localhost"
  default     = 10080
}

variable "portal_http_port" {
  type        = number
  description = "Forwarded captive portal HTTP test port on localhost"
  default     = 18080
}

variable "portal_https_port" {
  type        = number
  description = "Forwarded captive portal HTTPS test port on localhost"
  default     = 18443
}

variable "portal_login_port" {
  type        = number
  description = "Forwarded captive portal login service port on localhost"
  default     = 8000
}

variable "lan_backend" {
  type        = string
  description = "QEMU netdev backend for LAN: user for localhost port forwards, vmnet-host for direct host subnet access"
  default     = "vmnet-host"

  validation {
    condition     = contains(["vmnet-host", "user"], var.lan_backend)
    error_message = "lan_backend must be vmnet-host or user."
  }
}

variable "wan_backend" {
  type        = string
  description = "QEMU netdev backend for WAN: user for QEMU NAT, vmnet-host for direct host subnet access"
  default     = "user"

  validation {
    condition     = contains(["vmnet-host", "user"], var.wan_backend)
    error_message = "wan_backend must be vmnet-host or user."
  }
}

variable "portal_backend" {
  type        = string
  description = "QEMU netdev backend for the captive portal network: vmnet-host for direct host subnet access, user for localhost port forwards"
  default     = "vmnet-host"

  validation {
    condition     = contains(["vmnet-host", "user"], var.portal_backend)
    error_message = "portal_backend must be vmnet-host or user."
  }
}

variable "vnc_display" {
  type        = number
  description = "QEMU VNC display number"
  default     = 2
}

variable "lan_network" {
  type        = string
  description = "QEMU user-mode LAN subnet"
  default     = "192.168.60.0/24"
}

variable "lan_gateway_ip" {
  type        = string
  description = "Expected OPNsense LAN address behind the forwarded ports"
  default     = "192.168.60.254"
}

variable "lan_dhcp_start" {
  type        = string
  description = "LAN DHCP start address provided by QEMU user networking"
  default     = "192.168.60.10"
}

variable "lan_host_start" {
  type        = string
  description = "vmnet-host start address for the host-side LAN network"
  default     = "192.168.60.2"
}

variable "lan_host_end" {
  type        = string
  description = "vmnet-host end address for the host-side LAN network"
  default     = "192.168.60.253"
}

variable "lan_subnet_mask" {
  type        = string
  description = "vmnet-host subnet mask for the LAN network"
  default     = "255.255.255.0"
}

variable "lan_mac" {
  type        = string
  description = "Static MAC address for the LAN NIC"
  default     = "52:54:00:22:34:56"
}

variable "wan_network" {
  type        = string
  description = "QEMU user-mode WAN subnet"
  default     = "10.0.2.0/24"
}

variable "wan_gateway_ip" {
  type        = string
  description = "Expected WAN-side gateway address in the QEMU network"
  default     = "10.0.2.2"
}

variable "wan_dhcp_start" {
  type        = string
  description = "WAN DHCP start address provided by QEMU user networking"
  default     = "10.0.2.15"
}

variable "wan_host_start" {
  type        = string
  description = "vmnet-host start address for the host-side WAN network"
  default     = "10.0.2.2"
}

variable "wan_host_end" {
  type        = string
  description = "vmnet-host end address for the host-side WAN network"
  default     = "10.0.2.253"
}

variable "wan_subnet_mask" {
  type        = string
  description = "vmnet-host subnet mask for the WAN network"
  default     = "255.255.255.0"
}

variable "wan_mac" {
  type        = string
  description = "Static MAC address for the WAN NIC"
  default     = "52:54:00:22:34:57"
}

variable "portal_network" {
  type        = string
  description = "QEMU user-mode captive portal subnet"
  default     = "192.168.70.0/24"
}

variable "portal_gateway_ip" {
  type        = string
  description = "Expected OPNsense captive portal address behind the forwarded ports"
  default     = "192.168.70.254"
}

variable "portal_dhcp_start" {
  type        = string
  description = "Captive portal network DHCP start address provided by QEMU user networking"
  default     = "192.168.70.10"
}

variable "portal_host_start" {
  type        = string
  description = "vmnet-host start address for the host-side captive portal network"
  default     = "192.168.70.2"
}

variable "portal_host_end" {
  type        = string
  description = "vmnet-host end address for the host-side captive portal network"
  default     = "192.168.70.253"
}

variable "portal_subnet_mask" {
  type        = string
  description = "vmnet-host subnet mask for the captive portal network"
  default     = "255.255.255.0"
}

variable "portal_mac" {
  type        = string
  description = "Static MAC address for the captive portal NIC"
  default     = "52:54:00:22:34:58"
}
