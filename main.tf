terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}

variable "proxmox_endpoint" {
  description = "URL of your Proxmox API, e.g. https://192.168.1.10:8006 or magic dns from tailscale vpn"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in the form 'user@realm!tokenid=uuid'"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Set true if using a self-signed cert on your PVE host"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user used by the provider for file uploads (usually root)"
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Name of the Proxmox node to deploy on"
  type        = string
  default     = "pve"
}

variable "ct_template" {
  description = "Volume ID of the Ubuntu 26.04 LXC template already present on storage"
  type        = string
  default     = "local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
}

variable "container_count" {
  description = "Number of LXC containers to create"
  type        = number
  default     = 3
}

variable "ct_password" {
  description = "Root password for the containers"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to inject into each container"
  type        = string
  default     = ""
}

resource "proxmox_virtual_environment_container" "ubuntu" {
  count     = var.container_count
  node_name = var.proxmox_node
  vm_id     = 9000 + count.index

  initialization {
    hostname = "ubuntu26-${count.index + 1}"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      password = var.ct_password
      keys     = var.ssh_public_key != "" ? [var.ssh_public_key] : []
    }
  }

  operating_system {
    template_file_id = var.ct_template
    type              = "ubuntu"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 3072
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  unprivileged = true
  start_on_boot = true

  features {
    nesting = true
  }
}

output "container_ids" {
  value = proxmox_virtual_environment_container.ubuntu[*].vm_id
}

output "container_hostnames" {
  value = proxmox_virtual_environment_container.ubuntu[*].initialization[0].hostname
}
