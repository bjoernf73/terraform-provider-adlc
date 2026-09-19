resource "dryad_json_gpo" "server_baseline" {
  path        = "${path.module}/json_gpo/Servers Baseline.json"
  target_name = "Servers Baseline"
}

resource "dryad_group" "server_computers" {
  name = "Server Computers"
  path = "Groups"
}

# Only members of this group can apply the GPO. Authenticated Users retains GpoRead.
resource "dryad_gpo_security_filter" "server_baseline" {
  gpo        = dryad_json_gpo.server_baseline.target_name
  principals = [dryad_group.server_computers.distinguished_name]
}
