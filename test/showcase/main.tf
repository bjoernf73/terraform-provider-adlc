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

  enabled                            = false
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
