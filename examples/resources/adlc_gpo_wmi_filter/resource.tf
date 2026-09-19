resource "adlc_backup_gpo" "servers_baseline" {
  backup_name = "Servers Baseline"
  target_name = "Servers Baseline"
  path        = "backup_gpo"
}

resource "adlc_wmi_filter" "windows_server_2022" {
  name = "Windows Server 2022 only"

  queries = [
    {
      query = "SELECT * FROM Win32_OperatingSystem WHERE Version LIKE \"10.0.20348%\" AND ProductType = \"3\""
    }
  ]
}

resource "adlc_gpo_wmi_filter" "servers_baseline" {
  gpo        = adlc_backup_gpo.servers_baseline.target_name
  wmi_filter = adlc_wmi_filter.windows_server_2022.name
}
