terraform {
  required_version = ">= 1.6.0"

  required_providers {
    dryad = {
      source  = "bjoernf73/dryad"
      version = "0.0.0-ci"
    }
  }
}

provider "dryad" {
  transport       = var.transport
  host            = var.host
  port            = var.port
  username        = var.username
  password        = var.password
  winrm_use_tls   = var.winrm_use_tls
  winrm_auth      = var.winrm_auth
  insecure        = var.insecure
  powershell_path = var.powershell_path
  timeout_seconds = var.timeout_seconds
}

resource "dryad_organizational_unit" "smoke" {
  path           = var.ou_path
  description    = var.ou_description
  delete_subtree = true
}

resource "dryad_group" "smoke" {
  name        = var.group_name
  path        = dryad_organizational_unit.smoke.path
  description = var.ou_description
  category    = "Security"
  scope       = "Global"
}

output "id" {
  value = dryad_organizational_unit.smoke.id
}

output "distinguished_name" {
  value = dryad_organizational_unit.smoke.distinguished_name
}

output "name" {
  value = dryad_organizational_unit.smoke.name
}

output "group_id" {
  value = dryad_group.smoke.id
}

output "group_distinguished_name" {
  value = dryad_group.smoke.distinguished_name
}

output "group_sid" {
  value = dryad_group.smoke.sid
}
