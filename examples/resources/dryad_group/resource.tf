resource "dryad_group" "server_admins" {
  name             = "Server Admins"
  sam_account_name = "SERVER-ADMINS"
  path             = "Contoso/Groups"
  description      = "Administrators of all servers"
  category         = "Security"
  scope            = "Global"
}

# path also accepts a full container DN, for containers that are not OUs.
resource "dryad_group" "legacy_readers" {
  name  = "Legacy Readers"
  path  = "CN=Users,DC=contoso,DC=local"
  scope = "DomainLocal"
}
