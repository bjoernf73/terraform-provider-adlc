terraform {
  required_providers {
    adlc = {
      source = "henrikhalt/adlc"
    }
  }
}

# WinRM with NTLM authentication.
provider "adlc" {
  transport       = "winrm"
  host            = "dc1.contoso.local"
  username        = "CONTOSO\\terraform"
  password        = var.password
  winrm_auth      = "ntlm"
  powershell_path = "pwsh"
}

# SSH with password authentication.
provider "adlc" {
  alias           = "ssh"
  transport       = "ssh"
  host            = "dc1.contoso.local"
  username        = "terraform"
  password        = var.password
  powershell_path = "pwsh"
}
