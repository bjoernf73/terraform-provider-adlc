terraform {
  required_providers {
    dryad = {
      source = "henrikhalt/dryad"
    }
  }
}

# WinRM with NTLM authentication.
provider "dryad" {
  transport       = "winrm"
  host            = "dc1.contoso.local"
  username        = "CONTOSO\\terraform"
  password        = var.password
  winrm_auth      = "ntlm"
  powershell_path = "pwsh"
}

# SSH with password authentication.
provider "dryad" {
  alias           = "ssh"
  transport       = "ssh"
  host            = "dc1.contoso.local"
  username        = "terraform"
  password        = var.password
  powershell_path = "pwsh"
}
