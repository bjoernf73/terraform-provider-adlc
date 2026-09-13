resource "dryad_group" "server_admins" {
  name             = "Server Admins"
  sam_account_name = "SERVER-ADMINS"
  path             = "Contoso/Groups"
  description      = "Administrators of all servers"
  display_name     = "Server Administrators"
  info             = "Reviewed quarterly by the platform team."
  homepage         = "https://wiki.contoso.local/groups/server-admins"
  managed_by       = "Administrator"
  category         = "Security"
  scope            = "Global"

  protected_from_accidental_deletion = true
}

# A mail-enabled distribution group.
resource "dryad_group" "announcements" {
  name     = "Announcements"
  path     = "Contoso/Groups"
  mail     = "announcements@contoso.local"
  category = "Distribution"
  scope    = "Universal"
}

# path also accepts a DN relative to the domain root, for containers that are not OUs.
resource "dryad_group" "legacy_readers" {
  name  = "Legacy Readers"
  path  = "CN=Users"
  scope = "DomainLocal"
}
