resource "adlc_json_gpo" "server_baseline" {
  path        = "${path.module}/json_gpo/Servers Baseline.json"
  target_name = "Servers Baseline"
}

resource "adlc_group" "server_computers" {
  name = "Server Computers"
  path = "Groups"
}

# Only members of this group can apply the GPO. Authenticated Users retains GpoRead.
resource "adlc_gpo_security_filter" "server_baseline" {
  gpo        = adlc_json_gpo.server_baseline.target_name
  principals = [adlc_group.server_computers.distinguished_name]
}
