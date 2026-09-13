terraform {
  required_providers {
    dryad = {
      source = "bjoernf73/dryad"
    }
  }
}

provider "dryad" {
  transport       = "winrm"
  host            = var.host
  port            = var.port
  username        = var.username
  password        = var.password
  winrm_auth      = var.winrm_auth
  powershell_path = "pwsh"
}

resource "dryad_organizational_unit" "groups" {
  path        = "Contoso/Groups"
  description = "Application groups"
}

resource "dryad_group" "app_admins" {
  name             = "App Admins"
  sam_account_name = "APP-ADMINS"
  path             = dryad_organizational_unit.groups.path
  description      = "Administrators of the example application"
  category         = "Security"
  scope            = "Global"
}

# A group placed directly in a well-known container rather than an OU.
resource "dryad_group" "legacy" {
  name  = "Legacy Readers"
  path  = "CN=Users,${var.domain_dn}"
  scope = "DomainLocal"
}

output "app_admins_sid" {
  value = dryad_group.app_admins.sid
}
