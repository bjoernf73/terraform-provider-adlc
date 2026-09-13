resource "dryad_organizational_unit" "servers" {
  path = "Contoso/Servers"
}

resource "dryad_group" "server_admins" {
  name  = "Server Admins"
  path  = "Contoso/Groups"
  scope = "DomainLocal"
}

# Create and delete computer objects in child OUs.
resource "dryad_access_rule" "create_delete_computers" {
  target                = dryad_organizational_unit.servers.distinguished_name
  trustee               = dryad_group.server_admins.sid
  rights                = ["CreateChild", "DeleteChild"]
  object_type           = "computer"
  inherited_object_type = "organizationalUnit"
  inheritance           = "Descendents"
}

# Write any property on the computer objects themselves.
resource "dryad_access_rule" "write_computer_properties" {
  target                = dryad_organizational_unit.servers.distinguished_name
  trustee               = dryad_group.server_admins.sid
  rights                = ["WriteProperty"]
  object_type           = "All"
  inherited_object_type = "computer"
  inheritance           = "Descendents"
}

# Built-in principals do not need to be managed by Terraform.
resource "dryad_access_rule" "authenticated_read" {
  target      = dryad_organizational_unit.servers.distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["GenericRead"]
  inheritance = "All"
}

# Deny an extended right.
resource "dryad_access_rule" "deny_password_reset" {
  target                = dryad_organizational_unit.servers.distinguished_name
  trustee               = "Authenticated Users"
  rights                = ["ExtendedRight"]
  access                = "Deny"
  object_type           = "Reset Password"
  inherited_object_type = "user"
  inheritance           = "Descendents"
}
