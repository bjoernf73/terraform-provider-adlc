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

data "dryad_domain" "current" {}

resource "dryad_organizational_unit" "smoke" {
  path           = var.ou_path
  description    = var.ou_description
  delete_subtree = true
}

resource "dryad_group" "smoke" {
  name         = var.group_name
  path         = dryad_organizational_unit.smoke.path
  description  = var.ou_description
  display_name = "${var.group_name} (CI)"
  info         = "Created by the terraform-provider-dryad pipeline."
  managed_by   = "Administrator"
  category     = "Security"
  scope        = "Global"
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

output "group_managed_by_dn" {
  value = dryad_group.smoke.managed_by_dn
}

# Delegates computer management on the OU to the group stored inside it, which is the
# dependency shape that a nested acl attribute could not express without a cycle.
# Constructor 6: object_type + inheritance + inherited_object_type.
resource "dryad_access_rule" "smoke" {
  target                = dryad_organizational_unit.smoke.distinguished_name
  trustee               = dryad_group.smoke.sid
  rights                = ["CreateChild", "DeleteChild"]
  access                = "Allow"
  object_type           = "computer"
  inherited_object_type = "organizationalUnit"
  inheritance           = "Descendents"
}

output "access_rule_id" {
  value = dryad_access_rule.smoke.id
}

output "access_rule_trustee_sid" {
  value = dryad_access_rule.smoke.trustee_sid
}

# A second group, nested into the first, exercises group membership.
resource "dryad_group" "smoke_member" {
  name  = "${var.group_name}-member"
  path  = dryad_organizational_unit.smoke.path
  scope = "Global"
}

resource "dryad_group_member" "smoke" {
  group  = dryad_group.smoke.id
  member = dryad_group.smoke_member.id
}

output "group_member_id" {
  value = dryad_group_member.smoke.id
}

output "domain_dn" {
  value = data.dryad_domain.current.distinguished_name
}

output "domain_netbios_name" {
  value = data.dryad_domain.current.netbios_name
}

# A relative DN target: the well-known Computers container is a CN, not an OU.
# Constructor 5: object_type + inheritance, no inherited_object_type.
resource "dryad_access_rule" "smoke_container" {
  target      = "CN=Computers"
  trustee     = dryad_group.smoke.sid
  rights      = ["ReadProperty"]
  object_type = "All"
  inheritance = "Descendents"
}

output "access_rule_container_target_dn" {
  value = dryad_access_rule.smoke_container.target_dn
}

# The remaining four constructors from the access rules guide, exercised against the
# second group so every ACE key stays unique alongside dryad_access_rule.smoke above.

# Constructor 1: rights on the object itself. Uses a different trustee than constructor 2:
# the same trustee + same rights with inheritance=All would make this ACE a strict subset
# of that one (All already covers the object itself, not just descendants), and Windows
# canonicalizes the redundant narrower ACE away.
resource "dryad_access_rule" "constructor1_object_only" {
  target  = dryad_organizational_unit.smoke.distinguished_name
  trustee = dryad_group.smoke.sid
  rights  = ["GenericRead"]
}

# Constructor 2: rights inherited by every descendant.
resource "dryad_access_rule" "constructor2_all_descendants" {
  target      = dryad_organizational_unit.smoke.distinguished_name
  trustee     = dryad_group.smoke_member.sid
  rights      = ["GenericRead"]
  inheritance = "All"
}

# Constructor 3: rights inherited by one class of descendant.
resource "dryad_access_rule" "constructor3_one_class_descendants" {
  target                = dryad_organizational_unit.smoke.distinguished_name
  trustee               = dryad_group.smoke_member.sid
  rights                = ["GenericRead"]
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

# Constructor 4: rights on one class of child object, this object only.
resource "dryad_access_rule" "constructor4_one_class_here" {
  target      = dryad_organizational_unit.smoke.distinguished_name
  trustee     = dryad_group.smoke_member.sid
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
}

output "access_rule_constructors" {
  value = {
    "1_object_only"           = dryad_access_rule.constructor1_object_only.id
    "2_all_descendants"       = dryad_access_rule.constructor2_all_descendants.id
    "3_one_class_descendants" = dryad_access_rule.constructor3_one_class_descendants.id
    "4_one_class_here"        = dryad_access_rule.constructor4_one_class_here.id
    "5_one_class_propagated"  = dryad_access_rule.smoke_container.id
    "6_extended_right"        = dryad_access_rule.smoke.id
  }
}
