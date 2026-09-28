# Look up an existing group that Terraform does not manage, for example a built-in or
# a group created by another team.
data "adlc_group" "help_desk" {
  identity = "Help Desk"
}

# Use its SID where a security principal is expected.
resource "adlc_access_rule" "help_desk_reset_passwords" {
  target                = "Contoso/Staff"
  trustee               = data.adlc_group.help_desk.sid
  rights                = ["ExtendedRight"]
  object_type           = "Reset Password"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

output "help_desk" {
  value = {
    distinguished_name = data.adlc_group.help_desk.distinguished_name
    sid                = data.adlc_group.help_desk.sid
    scope              = data.adlc_group.help_desk.scope
  }
}
