resource "dryad_group" "server_admins" {
  name  = "Server Admins"
  path  = "Contoso/Groups"
  scope = "DomainLocal"
}

resource "dryad_group" "windows_admins" {
  name  = "Windows Admins"
  path  = "Contoso/Groups"
  scope = "Global"
}

# Nest one managed group inside another.
resource "dryad_group_member" "windows_admins_in_server_admins" {
  group  = dryad_group.server_admins.id
  member = dryad_group.windows_admins.id
}

# Members that are not managed by Terraform are referenced by name.
resource "dryad_group_member" "svc_backup" {
  group  = dryad_group.server_admins.id
  member = "svc-backup"
}

# One resource per membership composes with for_each.
resource "dryad_group_member" "operators" {
  for_each = toset(["alice", "bob", "carol"])

  group  = dryad_group.windows_admins.id
  member = each.value
}
