data "adlc_domain" "current" {}

# Build container DNs without hardcoding the domain component.
resource "adlc_group" "legacy_readers" {
  name  = "Legacy Readers"
  path  = data.adlc_domain.current.users_container
  scope = "DomainLocal"
}

resource "adlc_access_rule" "delegate_on_domain_root" {
  target      = data.adlc_domain.current.distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["GenericRead"]
  inheritance = "All"
}

output "domain" {
  value = {
    dns_root     = data.adlc_domain.current.dns_root
    netbios_name = data.adlc_domain.current.netbios_name
    mode         = data.adlc_domain.current.domain_mode
  }
}
