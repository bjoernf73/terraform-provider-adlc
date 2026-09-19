resource "dryad_backup_gpo" "servers_baseline" {
  backup_name = "Servers Baseline"
  target_name = "Servers Baseline"
  path        = "backup_gpo"
}

resource "dryad_wmi_filter" "windows_server_2022" {
  name = "Windows Server 2022 only"

  queries = [
    {
      query = "SELECT * FROM Win32_OperatingSystem WHERE Version LIKE \"10.0.20348%\" AND ProductType = \"3\""
    }
  ]
}

resource "dryad_gpo_wmi_filter" "servers_baseline" {
  gpo        = dryad_backup_gpo.servers_baseline.target_name
  wmi_filter = dryad_wmi_filter.windows_server_2022.name
}
