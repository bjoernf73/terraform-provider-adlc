resource "adlc_json_gpo" "server_baseline" {
  path        = "${path.module}/json_gpo/Servers Baseline.json"
  target_name = "Servers Baseline"
}

resource "adlc_group" "server_policy_readers" {
  name = "Server Policy Readers"
  path = "Groups"
}

# Lets the group read this GPO without applying it.
resource "adlc_gpo_permission" "server_policy_readers" {
  gpo        = adlc_json_gpo.server_baseline.target_name
  trustee    = adlc_group.server_policy_readers.distinguished_name
  permission = "GpoRead"
}
