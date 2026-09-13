data "dryad_domain" "current" {}

# Build container DNs without hardcoding the domain component.
resource "dryad_group" "legacy_readers" {
  name  = "Legacy Readers"
  path  = data.dryad_domain.current.users_container
  scope = "DomainLocal"
}

resource "dryad_access_rule" "delegate_on_domain_root" {
  target      = data.dryad_domain.current.distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["GenericRead"]
  inheritance = "All"
}

output "domain" {
  value = {
    dns_root     = data.dryad_domain.current.dns_root
    netbios_name = data.dryad_domain.current.netbios_name
    mode         = data.dryad_domain.current.domain_mode
  }
}
