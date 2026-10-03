# Enterprise "Systems" layout. A parent Systems OU, then the per-system module (modules/system)
# invoked once per short name. Each invocation builds a full system subtree - Groups,
# ServiceAccounts and Servers OUs, six groups, two server computer accounts, a gMSA per server,
# and a per-system JSON GPO linked onto Servers - so the showcase exercises the provider at the
# scale a real directory reaches (~16 objects per system).

locals {
  systems = [
    "CRM", "ERP", "HRM", "FIN", "LOGI", "MES", "SCM", "BISY",
  ]
}

resource "adlc_organizational_unit" "systems" {
  path        = "${var.showcase_path}/Systems"
  description = "Parent OU for per-system subtrees"
}

module "system" {
  for_each = toset(local.systems)
  source   = "./modules/system"

  system         = each.value
  systems_path   = adlc_organizational_unit.systems.path
  domain_netbios = data.adlc_domain.current.netbios_name
  dns_root       = data.adlc_domain.current.dns_root

  # gMSAs need the forest KDS root key to already exist and be effective.
  depends_on = [
    adlc_organizational_unit.systems,
    adlc_kds_root_key.showcase,
  ]
}
