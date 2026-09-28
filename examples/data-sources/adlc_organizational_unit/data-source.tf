# Look up an existing organizational unit that Terraform does not manage, for example one
# created during the domain build, and place new objects inside it.
data "adlc_organizational_unit" "servers" {
  path = "Contoso/Servers"
}

resource "adlc_group" "server_admins" {
  name  = "Server Admins"
  path  = data.adlc_organizational_unit.servers.distinguished_name
  scope = "DomainLocal"
}

output "servers_ou" {
  value = {
    distinguished_name = data.adlc_organizational_unit.servers.distinguished_name
    name               = data.adlc_organizational_unit.servers.name
  }
}
