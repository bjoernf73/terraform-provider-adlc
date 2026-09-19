resource "dryad_json_gpo" "server_baseline" {
  path        = "${path.module}/json_gpo/Servers Baseline.json"
  target_name = "Servers Baseline"
}

resource "dryad_group" "server_policy_readers" {
  name = "Server Policy Readers"
  path = "Groups"
}

# Lets the group read this GPO without applying it.
resource "dryad_gpo_permission" "server_policy_readers" {
  gpo        = dryad_json_gpo.server_baseline.target_name
  trustee    = dryad_group.server_policy_readers.distinguished_name
  permission = "GpoRead"
}
