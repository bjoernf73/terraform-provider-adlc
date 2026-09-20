terraform {
  required_version = ">= 1.6.0"

  required_providers {
    adlc = {
      source  = "bjoernf73/adlc"
      version = "0.0.0-ci"
    }
  }
}

provider "adlc" {
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

data "adlc_domain" "current" {}

# Fixed names: this configuration is applied repeatedly without a persisted state and
# without a destroy, so every run must reconcile the same objects rather than create
# new ones.

resource "adlc_organizational_unit" "root" {
  path        = var.showcase_path
  description = "terraform-provider-adlc showcase, applied over WinRM/HTTPS"
}

resource "adlc_organizational_unit" "child" {
  for_each = toset(["Servers", "Groups", "ServiceAccounts"])

  path        = "${var.showcase_path}/${each.value}"
  description = "${each.value} for the showcase"
}

# Every settable property populated, so the result can be inspected in ADUC.
resource "adlc_group" "admins" {
  name             = "adlc-showcase-admins"
  sam_account_name = "ADLC-SHOWCASE-ADM"
  path             = adlc_organizational_unit.child["Groups"].path
  description      = "Showcase administrators"
  display_name     = "ADLC Showcase Administrators"
  mail             = "adlc-showcase-admins@${data.adlc_domain.current.dns_root}"
  info             = "Every property on this group is set by Terraform."
  homepage         = "https://example.invalid/adlc-showcase"
  managed_by       = "Administrator"
  category         = "Security"
  scope            = "DomainLocal"

  manager_can_update_membership      = true
  protected_from_accidental_deletion = true
}

resource "adlc_group" "operators" {
  name         = "adlc-showcase-operators"
  path         = adlc_organizational_unit.child["Groups"].path
  description  = "Showcase operators"
  display_name = "ADLC Showcase Operators"
  category     = "Security"
  scope        = "Global"
}

# Every settable property populated, disabled since no password is set here.
resource "adlc_user" "showcase" {
  name                = "ADLC Showcase User"
  sam_account_name    = "adlc-showcase-user"
  user_principal_name = "adlc-showcase-user@${data.adlc_domain.current.dns_root}"
  path                = adlc_organizational_unit.root.path

  given_name              = "ADLC"
  surname                 = "Showcase"
  display_name            = "ADLC Showcase User"
  initials                = "DS"
  other_name              = "Terraform"
  description             = "Every property on this user is set by Terraform."
  email                   = "adlc-showcase-user@${data.adlc_domain.current.dns_root}"
  office                  = "Remote"
  office_phone            = "+1 555 0100"
  home_phone              = "+1 555 0101"
  mobile_phone            = "+1 555 0102"
  fax                     = "+1 555 0103"
  home_page               = "https://example.invalid/adlc-showcase-user"
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
  home_directory          = "\\\\fileserver\\home\\adlc-showcase-user"
  home_drive              = "H:"
  logon_workstations      = "WORKSTATION1,WORKSTATION2"
  script_path             = "logon.bat"
  profile_path            = "\\\\fileserver\\profiles\\adlc-showcase-user"
  account_expiration_date = "2099-12-31"
  manager                 = "Administrator"

  # Created disabled: no password is set here, and New-ADUser rejects an empty password
  # once Enabled is true. adlc_user_password.showcase sets the real password and enables it.
  enabled                            = false
  password_never_expires             = true
  cannot_change_password             = false
  smart_card_logon_required          = false
  trusted_for_delegation             = false
  protected_from_accidental_deletion = true
}

resource "adlc_group" "announcements" {
  name         = "adlc-showcase-announcements"
  path         = adlc_organizational_unit.child["Groups"].path
  description  = "Showcase distribution group"
  display_name = "ADLC Showcase Announcements"
  mail         = "adlc-showcase@${data.adlc_domain.current.dns_root}"
  category     = "Distribution"
  scope        = "Universal"
}

# Security principal referenced by the "Domain - GPO1" backup's migration table (see
# adlc_backup_gpo.domain_gpo1 below); the GPO's restricted groups setting resolves this
# by name in the target domain.
resource "adlc_group" "another_group" {
  name     = "AnotherGroup"
  path     = adlc_organizational_unit.child["Groups"].path
  category = "Security"
  scope    = "Global"
}

resource "adlc_group" "right_dc_ura_sesystemprofileprivilege" {
  name     = "Right-DC-URA-SeSystemProfilePrivilege"
  path     = adlc_organizational_unit.child["Groups"].path
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

resource "adlc_group" "json_gpo_principals" {
  for_each = local.json_gpo_principal_groups

  name     = each.value
  path     = adlc_organizational_unit.child["Groups"].path
  category = "Security"
  scope    = "Global"
}

# Imported from a real GPMC backup (test/showcase/backup_gpo/Domain - GPO1); the
# migration table entries map security principals baked into the backup by name, so
# they resolve fresh in this domain instead of carrying over the source's SIDs.
resource "adlc_backup_gpo" "domain_gpo1" {
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
    adlc_group.another_group,
    adlc_group.right_dc_ura_sesystemprofileprivilege,
  ]
}

# Imported as-is: no migration table for "Domain - GPO4".
resource "adlc_backup_gpo" "domain_gpo4" {
  backup_name = "Domain - GPO4"
  path        = "${path.module}/backup_gpo"
  target_name = "Domain - GPO4"
}

# Real DoD STIG baselines and custom Domain/DC hardening GPOs, exported from a separate
# source domain as JSON (test/showcase/json_gpo/*.json). Every security principal they
# reference resolves automatically by name, via adlc_group.right_dc_ura_sesystemprofileprivilege
# and .json_gpo_principals above; json_gpo_replacements below is only for the handful of
# free-text ####key#### tokens (a "migtable" in the same sense as backup_gpo's migrations,
# just plain text instead of typed entries) that automatic resolution can't cover.
locals {
  json_gpo_files = fileset("${path.module}/json_gpo", "*.json")

  json_gpo_replacements = {
    "Domain - Domain Policy - v0r2.json" = {
      DomainFQDN = data.adlc_domain.current.dns_root
      DomainNB   = data.adlc_domain.current.netbios_name
    }
  }
}

resource "adlc_json_gpo" "imports" {
  for_each = local.json_gpo_files

  path         = "${path.module}/json_gpo/${each.value}"
  target_name  = trimsuffix(each.value, ".json")
  replacements = lookup(local.json_gpo_replacements, each.value, {})

  depends_on = [
    adlc_group.json_gpo_principals,
    adlc_group.right_dc_ura_sesystemprofileprivilege,
  ]
}

# Nested membership.
resource "adlc_group_member" "operators_in_admins" {
  group  = adlc_group.admins.id
  member = adlc_group.operators.id
}

# Constructor 1: rights on the object itself.
resource "adlc_access_rule" "constructor1_full_control" {
  target  = adlc_organizational_unit.root.distinguished_name
  trustee = adlc_group.admins.sid
  rights  = ["GenericAll"]
}

# Constructor 2: inherited by every descendant.
resource "adlc_access_rule" "constructor2_read_all" {
  target      = adlc_organizational_unit.root.distinguished_name
  trustee     = adlc_group.operators.sid
  rights      = ["GenericRead"]
  inheritance = "All"
}

# Constructor 3: inherited by one class of descendant.
resource "adlc_access_rule" "constructor3_manage_users" {
  target                = adlc_organizational_unit.root.distinguished_name
  trustee               = adlc_group.admins.sid
  rights                = ["GenericAll"]
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# Constructor 4: one class of child object, this object only.
resource "adlc_access_rule" "constructor4_create_computers_here" {
  target      = adlc_organizational_unit.child["Servers"].distinguished_name
  trustee     = adlc_group.operators.sid
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
}

# Constructor 5: one class of child object, propagated.
resource "adlc_access_rule" "constructor5_create_computers_below" {
  target      = adlc_organizational_unit.child["Servers"].distinguished_name
  trustee     = adlc_group.admins.sid
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
  inheritance = "Descendents"
}

# Constructor 6: an extended right, on one class, propagated.
resource "adlc_access_rule" "constructor6_reset_passwords" {
  target                = adlc_organizational_unit.child["ServiceAccounts"].distinguished_name
  trustee               = adlc_group.admins.sid
  rights                = ["ExtendedRight"]
  object_type           = "Reset Password"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# A property set, which is a control access right used with ReadProperty/WriteProperty.
resource "adlc_access_rule" "personal_information" {
  target                = adlc_organizational_unit.child["ServiceAccounts"].distinguished_name
  trustee               = adlc_group.operators.sid
  rights                = ["ReadProperty", "WriteProperty"]
  object_type           = "Personal Information"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# A Deny entry.
resource "adlc_access_rule" "deny_delete_tree" {
  target      = adlc_organizational_unit.child["Servers"].distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["DeleteTree"]
  access      = "Deny"
  inheritance = "All"
}

# A well-known principal, and a relative DN target outside the showcase OU.
resource "adlc_access_rule" "read_computers_container" {
  target      = "CN=Computers"
  trustee     = adlc_group.operators.sid
  rights      = ["ReadProperty"]
  object_type = "All"
  inheritance = "Descendents"
}

output "domain" {
  value = {
    distinguished_name = data.adlc_domain.current.distinguished_name
    dns_root           = data.adlc_domain.current.dns_root
    netbios_name       = data.adlc_domain.current.netbios_name
    domain_mode        = data.adlc_domain.current.domain_mode
  }
}

output "organizational_units" {
  value = merge(
    { root = adlc_organizational_unit.root.distinguished_name },
    { for key, ou in adlc_organizational_unit.child : key => ou.distinguished_name }
  )
}

output "groups" {
  value = {
    admins = {
      dn            = adlc_group.admins.distinguished_name
      sid           = adlc_group.admins.sid
      managed_by_dn = adlc_group.admins.managed_by_dn
    }
    operators     = { dn = adlc_group.operators.distinguished_name, sid = adlc_group.operators.sid }
    announcements = { dn = adlc_group.announcements.distinguished_name, sid = adlc_group.announcements.sid }
    another_group = { dn = adlc_group.another_group.distinguished_name, sid = adlc_group.another_group.sid }
    right_dc_ura_sesystemprofileprivilege = {
      dn  = adlc_group.right_dc_ura_sesystemprofileprivilege.distinguished_name
      sid = adlc_group.right_dc_ura_sesystemprofileprivilege.sid
    }
  }
}

output "user" {
  value = {
    dn         = adlc_user.showcase.distinguished_name
    sid        = adlc_user.showcase.sid
    manager_dn = adlc_user.showcase.manager_dn
  }
}

# Sets a password each apply. keepers pins it to a fixed value so the same fixed-name
# showcase run does not generate a new password (and re-enable the account) every time.
resource "adlc_user_password" "showcase" {
  user   = adlc_user.showcase.id
  length = 28

  keepers = {
    generation = "1"
  }
}

output "user_password_id" {
  value = adlc_user_password.showcase.id
}

output "backup_gpos" {
  value = {
    domain_gpo1 = { id = adlc_backup_gpo.domain_gpo1.id, dn = adlc_backup_gpo.domain_gpo1.distinguished_name }
    domain_gpo4 = { id = adlc_backup_gpo.domain_gpo4.id, dn = adlc_backup_gpo.domain_gpo4.distinguished_name }
  }
}

output "json_gpos" {
  value = {
    for key, gpo in adlc_json_gpo.imports : key => { id = gpo.id, dn = gpo.distinguished_name }
  }
}

output "access_rules" {
  value = {
    full_control         = adlc_access_rule.constructor1_full_control.id
    reset_passwords      = adlc_access_rule.constructor6_reset_passwords.id
    personal_information = adlc_access_rule.personal_information.id
    computers_container  = adlc_access_rule.read_computers_container.target_dn
  }
}

output "access_rule_constructors" {
  value = {
    "1_object_only"           = adlc_access_rule.constructor1_full_control.id
    "2_all_descendants"       = adlc_access_rule.constructor2_read_all.id
    "3_one_class_descendants" = adlc_access_rule.constructor3_manage_users.id
    "4_one_class_here"        = adlc_access_rule.constructor4_create_computers_here.id
    "5_one_class_propagated"  = adlc_access_rule.constructor5_create_computers_below.id
    "6_extended_right"        = adlc_access_rule.constructor6_reset_passwords.id
  }
}
