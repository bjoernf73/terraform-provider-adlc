terraform {
  required_version = ">= 1.6.0"

  required_providers {
    dryad = {
      source  = "henrikhalt/dryad"
      version = "0.0.0-ci"
    }
  }
}

provider "dryad" {
  transport     = "winrm"
  host          = var.host
  port          = var.port
  username      = var.username
  password      = var.password
  winrm_use_tls = true
  winrm_auth    = var.winrm_auth
  # False validates the listener certificate; true is only for self-signed certificates.
  insecure        = var.insecure
  powershell_path = var.powershell_path
  timeout_seconds = var.timeout_seconds
}

data "dryad_domain" "current" {}

# Fixed names: this configuration is applied repeatedly without a persisted state and
# without a destroy, so every run must reconcile the same objects rather than create
# new ones.

resource "dryad_organizational_unit" "root" {
  path        = var.showcase_path
  description = "terraform-provider-dryad showcase, applied over WinRM/HTTPS"
}

resource "dryad_organizational_unit" "child" {
  for_each = toset(["Servers", "Groups", "ServiceAccounts"])

  path        = "${var.showcase_path}/${each.value}"
  description = "${each.value} for the showcase"
}

# Every settable property populated, so the result can be inspected in ADUC.
resource "dryad_group" "admins" {
  name             = "dryad-showcase-admins"
  sam_account_name = "DRYAD-SHOWCASE-ADM"
  path             = dryad_organizational_unit.child["Groups"].path
  description      = "Showcase administrators"
  display_name     = "Dryad Showcase Administrators"
  mail             = "dryad-showcase-admins@${data.dryad_domain.current.dns_root}"
  info             = "Every property on this group is set by Terraform."
  homepage         = "https://example.invalid/dryad-showcase"
  managed_by       = "Administrator"
  category         = "Security"
  scope            = "DomainLocal"

  manager_can_update_membership      = true
  protected_from_accidental_deletion = true
}

resource "dryad_group" "operators" {
  name         = "dryad-showcase-operators"
  path         = dryad_organizational_unit.child["Groups"].path
  description  = "Showcase operators"
  display_name = "Dryad Showcase Operators"
  category     = "Security"
  scope        = "Global"
}

# Every settable property populated, disabled since no password is set here.
resource "dryad_user" "showcase" {
  name                = "Dryad Showcase User"
  sam_account_name    = "dryad-showcase-user"
  user_principal_name = "dryad-showcase-user@${data.dryad_domain.current.dns_root}"
  path                = dryad_organizational_unit.root.path

  given_name              = "Dryad"
  surname                 = "Showcase"
  display_name            = "Dryad Showcase User"
  initials                = "DS"
  other_name              = "Terraform"
  description             = "Every property on this user is set by Terraform."
  email                   = "dryad-showcase-user@${data.dryad_domain.current.dns_root}"
  office                  = "Remote"
  office_phone            = "+1 555 0100"
  home_phone              = "+1 555 0101"
  mobile_phone            = "+1 555 0102"
  fax                     = "+1 555 0103"
  home_page               = "https://example.invalid/dryad-showcase-user"
  street_address          = "1 Showcase Way"
  po_box                  = "PO Box 1"
  city                    = "Showcase City"
  state                   = "Showcase State"
  postal_code             = "00000"
  country                 = "US"
  company                 = "Contoso"
  department              = "Platform Engineering"
  division                = "Engineering"
  organization            = "Contoso"
  employee_id             = "E-0001"
  employee_number         = "0001"
  title                   = "Showcase Engineer"
  home_directory          = "\\\\fileserver\\home\\dryad-showcase-user"
  home_drive              = "H:"
  logon_workstations      = "WORKSTATION1,WORKSTATION2"
  script_path             = "logon.bat"
  profile_path            = "\\\\fileserver\\profiles\\dryad-showcase-user"
  account_expiration_date = "2099-12-31"
  manager                 = "Administrator"

  enabled                            = true
  password_never_expires             = true
  cannot_change_password             = false
  smart_card_logon_required          = false
  trusted_for_delegation             = false
  protected_from_accidental_deletion = true
}

resource "dryad_group" "announcements" {
  name         = "dryad-showcase-announcements"
  path         = dryad_organizational_unit.child["Groups"].path
  description  = "Showcase distribution group"
  display_name = "Dryad Showcase Announcements"
  mail         = "dryad-showcase@${data.dryad_domain.current.dns_root}"
  category     = "Distribution"
  scope        = "Universal"
}

# Security principal referenced by the "Domain - GPO1" backup's migration table (see
# dryad_backup_gpo.domain_gpo1 below); the GPO's restricted groups setting resolves this
# by name in the target domain.
resource "dryad_group" "another_group" {
  name     = "AnotherGroup"
  path     = dryad_organizational_unit.child["Groups"].path
  category = "Security"
  scope    = "Global"
}

resource "dryad_group" "right_dc_ura_sesystemprofileprivilege" {
  name     = "Right-DC-URA-SeSystemProfilePrivilege"
  path     = dryad_organizational_unit.child["Groups"].path
  category = "Security"
  scope    = "Global"
}

# Security principals referenced by the json_gpo fixtures under test/showcase/json_gpo/
# (see dry.module.ad's ####Replace[DOMAIN\Name] token convention): these GPOs resolve
# each name automatically on import, so the groups just need to exist by name here.
# Right-DC-URA-SeSystemProfilePrivilege above is already one of these; the rest follow.
locals {
  json_gpo_principal_groups = toset([
    "Right-DC-BuiltinGroup-AccessControlAssistanceOperators",
    "Right-DC-BuiltinGroup-BackupOperators",
    "Right-DC-BuiltinGroup-CertificateServiceDCOMAccess",
    "Right-DC-BuiltinGroup-CryptographicOperators",
    "Right-DC-BuiltinGroup-DistributedCOMUsers",
    "Right-DC-BuiltinGroup-EventLogReaders",
    "Right-DC-BuiltinGroup-PerformanceLogUsers",
    "Right-DC-BuiltinGroup-PerformanceMonitorUsers",
    "Right-DC-BuiltinGroup-RemoteDesktopUsers",
    "Right-DC-BuiltinGroup-RemoteManagementUsers",
    "Right-DC-BuiltinGroup-Replicator",
    "Right-DC-BuiltinGroup-TerminalServerLicenseServers",
    "Right-DC-BuiltinGroup-WindowsAuthorizationAccessGroup",
    "Right-DC-URA-SeAssignPrimaryTokenPrivilege",
    "Right-DC-URA-SeDelegateSessionUserImpersonatePrivilege",
    "Right-DC-URA-SeIncreaseQuotaPrivilege",
    "Right-DC-URA-SeIncreaseWorkingSetPrivilege",
    "Right-DC-URA-SeRelabelPrivilege",
    "Right-DC-URA-SeRemoteShutdownPrivilege",
    "Right-DC-URA-SeSecurityPrivilege",
    "Right-DC-URA-SeShutdownPrivilege",
  ])
}

resource "dryad_group" "json_gpo_principals" {
  for_each = local.json_gpo_principal_groups

  name     = each.value
  path     = dryad_organizational_unit.child["Groups"].path
  category = "Security"
  scope    = "Global"
}

# Imported from a real GPMC backup (test/showcase/backup_gpo/Domain - GPO1); the
# migration table entries map security principals baked into the backup by name, so
# they resolve fresh in this domain instead of carrying over the source's SIDs.
resource "dryad_backup_gpo" "domain_gpo1" {
  backup_name = "Domain - GPO1"
  path        = "${path.module}/backup_gpo"
  target_name = "Domain - GPO1"

  migrations = [
    { type = "GlobalGroup", source = "AnotherGroup@utv.local", same_as_source = true },
    { type = "LocalGroup", source = "Right-DC-URA-SeSystemProfilePrivilege@utv.local", same_as_source = true },
    { type = "UniversalGroup", source = "Enterprise Admins@utv.local", same_as_source = true },
    { type = "GlobalGroup", source = "Domain Admins@utv.local", same_as_source = true },
  ]

  depends_on = [
    dryad_group.another_group,
    dryad_group.right_dc_ura_sesystemprofileprivilege,
  ]
}

# Imported as-is: no migration table for "Domain - GPO4".
resource "dryad_backup_gpo" "domain_gpo4" {
  backup_name = "Domain - GPO4"
  path        = "${path.module}/backup_gpo"
  target_name = "Domain - GPO4"
}

# Real DoD STIG baselines and custom Domain/DC hardening GPOs, exported from a separate
# source domain as JSON (test/showcase/json_gpo/*.json). Every security principal they
# reference resolves automatically by name, via dryad_group.right_dc_ura_sesystemprofileprivilege
# and .json_gpo_principals above; json_gpo_replacements below is only for the handful of
# free-text ####key#### tokens (a "migtable" in the same sense as backup_gpo's migrations,
# just plain text instead of typed entries) that automatic resolution can't cover.
locals {
  json_gpo_files = fileset("${path.module}/json_gpo", "*.json")

  json_gpo_replacements = {
    "Domain - Domain Policy - v0r2.json" = {
      DomainFQDN = data.dryad_domain.current.dns_root
      DomainNB   = data.dryad_domain.current.netbios_name
    }
  }
}

resource "dryad_json_gpo" "imports" {
  for_each = local.json_gpo_files

  path         = "${path.module}/json_gpo/${each.value}"
  target_name  = trimsuffix(each.value, ".json")
  replacements = lookup(local.json_gpo_replacements, each.value, {})

  depends_on = [
    dryad_group.json_gpo_principals,
    dryad_group.right_dc_ura_sesystemprofileprivilege,
  ]
}

# Nested membership.
resource "dryad_group_member" "operators_in_admins" {
  group  = dryad_group.admins.id
  member = dryad_group.operators.id
}

# Constructor 1: rights on the object itself.
resource "dryad_access_rule" "constructor1_full_control" {
  target  = dryad_organizational_unit.root.distinguished_name
  trustee = dryad_group.admins.sid
  rights  = ["GenericAll"]
}

# Constructor 2: inherited by every descendant.
resource "dryad_access_rule" "constructor2_read_all" {
  target      = dryad_organizational_unit.root.distinguished_name
  trustee     = dryad_group.operators.sid
  rights      = ["GenericRead"]
  inheritance = "All"
}

# Constructor 3: inherited by one class of descendant.
resource "dryad_access_rule" "constructor3_manage_users" {
  target                = dryad_organizational_unit.root.distinguished_name
  trustee               = dryad_group.admins.sid
  rights                = ["GenericAll"]
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# Constructor 4: one class of child object, this object only.
resource "dryad_access_rule" "constructor4_create_computers_here" {
  target      = dryad_organizational_unit.child["Servers"].distinguished_name
  trustee     = dryad_group.operators.sid
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
}

# Constructor 5: one class of child object, propagated.
resource "dryad_access_rule" "constructor5_create_computers_below" {
  target      = dryad_organizational_unit.child["Servers"].distinguished_name
  trustee     = dryad_group.admins.sid
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
  inheritance = "Descendents"
}

# Constructor 6: an extended right, on one class, propagated.
resource "dryad_access_rule" "constructor6_reset_passwords" {
  target                = dryad_organizational_unit.child["ServiceAccounts"].distinguished_name
  trustee               = dryad_group.admins.sid
  rights                = ["ExtendedRight"]
  object_type           = "Reset Password"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# A property set, which is a control access right used with ReadProperty/WriteProperty.
resource "dryad_access_rule" "personal_information" {
  target                = dryad_organizational_unit.child["ServiceAccounts"].distinguished_name
  trustee               = dryad_group.operators.sid
  rights                = ["ReadProperty", "WriteProperty"]
  object_type           = "Personal Information"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# A Deny entry.
resource "dryad_access_rule" "deny_delete_tree" {
  target      = dryad_organizational_unit.child["Servers"].distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["DeleteTree"]
  access      = "Deny"
  inheritance = "All"
}

# A well-known principal, and a relative DN target outside the showcase OU.
resource "dryad_access_rule" "read_computers_container" {
  target      = "CN=Computers"
  trustee     = dryad_group.operators.sid
  rights      = ["ReadProperty"]
  object_type = "All"
  inheritance = "Descendents"
}

output "domain" {
  value = {
    distinguished_name = data.dryad_domain.current.distinguished_name
    dns_root           = data.dryad_domain.current.dns_root
    netbios_name       = data.dryad_domain.current.netbios_name
    domain_mode        = data.dryad_domain.current.domain_mode
  }
}

output "organizational_units" {
  value = merge(
    { root = dryad_organizational_unit.root.distinguished_name },
    { for key, ou in dryad_organizational_unit.child : key => ou.distinguished_name }
  )
}

output "groups" {
  value = {
    admins = {
      dn            = dryad_group.admins.distinguished_name
      sid           = dryad_group.admins.sid
      managed_by_dn = dryad_group.admins.managed_by_dn
    }
    operators     = { dn = dryad_group.operators.distinguished_name, sid = dryad_group.operators.sid }
    announcements = { dn = dryad_group.announcements.distinguished_name, sid = dryad_group.announcements.sid }
    another_group = { dn = dryad_group.another_group.distinguished_name, sid = dryad_group.another_group.sid }
    right_dc_ura_sesystemprofileprivilege = {
      dn  = dryad_group.right_dc_ura_sesystemprofileprivilege.distinguished_name
      sid = dryad_group.right_dc_ura_sesystemprofileprivilege.sid
    }
  }
}

output "user" {
  value = {
    dn         = dryad_user.showcase.distinguished_name
    sid        = dryad_user.showcase.sid
    manager_dn = dryad_user.showcase.manager_dn
  }
}

# Sets a password each apply. keepers pins it to a fixed value so the same fixed-name
# showcase run does not generate a new password (and re-enable the account) every time.
resource "dryad_user_password" "showcase" {
  user   = dryad_user.showcase.id
  length = 28

  keepers = {
    generation = "1"
  }
}

output "user_password_id" {
  value = dryad_user_password.showcase.id
}

output "backup_gpos" {
  value = {
    domain_gpo1 = { id = dryad_backup_gpo.domain_gpo1.id, dn = dryad_backup_gpo.domain_gpo1.distinguished_name }
    domain_gpo4 = { id = dryad_backup_gpo.domain_gpo4.id, dn = dryad_backup_gpo.domain_gpo4.distinguished_name }
  }
}

output "json_gpos" {
  value = {
    for key, gpo in dryad_json_gpo.imports : key => { id = gpo.id, dn = gpo.distinguished_name }
  }
}

output "access_rules" {
  value = {
    full_control         = dryad_access_rule.constructor1_full_control.id
    reset_passwords      = dryad_access_rule.constructor6_reset_passwords.id
    personal_information = dryad_access_rule.personal_information.id
    computers_container  = dryad_access_rule.read_computers_container.target_dn
  }
}

output "access_rule_constructors" {
  value = {
    "1_object_only"           = dryad_access_rule.constructor1_full_control.id
    "2_all_descendants"       = dryad_access_rule.constructor2_read_all.id
    "3_one_class_descendants" = dryad_access_rule.constructor3_manage_users.id
    "4_one_class_here"        = dryad_access_rule.constructor4_create_computers_here.id
    "5_one_class_propagated"  = dryad_access_rule.constructor5_create_computers_below.id
    "6_extended_right"        = dryad_access_rule.constructor6_reset_passwords.id
  }
}
