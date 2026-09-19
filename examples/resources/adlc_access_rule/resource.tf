resource "adlc_organizational_unit" "servers" {
  path = "Contoso/Servers"
}

resource "adlc_group" "server_admins" {
  name  = "Server Admins"
  path  = "Contoso/Groups"
  scope = "DomainLocal"
}

# Create and delete computer objects in child OUs.
resource "adlc_access_rule" "create_delete_computers" {
  target                = adlc_organizational_unit.servers.distinguished_name
  trustee               = adlc_group.server_admins.sid
  rights                = ["CreateChild", "DeleteChild"]
  object_type           = "computer"
  inherited_object_type = "organizationalUnit"
  inheritance           = "Descendents"
}

# Write any property on the computer objects themselves.
resource "adlc_access_rule" "write_computer_properties" {
  target                = adlc_organizational_unit.servers.distinguished_name
  trustee               = adlc_group.server_admins.sid
  rights                = ["WriteProperty"]
  object_type           = "All"
  inherited_object_type = "computer"
  inheritance           = "Descendents"
}

# Built-in principals do not need to be managed by Terraform.
resource "adlc_access_rule" "authenticated_read" {
  target      = adlc_organizational_unit.servers.distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["GenericRead"]
  inheritance = "All"
}

# Deny an extended right.
resource "adlc_access_rule" "deny_password_reset" {
  target                = adlc_organizational_unit.servers.distinguished_name
  trustee               = "Authenticated Users"
  rights                = ["ExtendedRight"]
  access                = "Deny"
  object_type           = "Reset Password"
  inherited_object_type = "user"
  inheritance           = "Descendents"
}
