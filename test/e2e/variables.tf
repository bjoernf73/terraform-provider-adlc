variable "host" {
  type        = string
  description = "IP address or hostname of the target domain controller."
}

variable "transport" {
  type        = string
  description = "Connection transport: winrm or ssh."
  default     = "winrm"
}

variable "port" {
  type        = number
  description = "Remote port. Null lets the provider pick 5985/5986 for WinRM and 22 for SSH."
  default     = null
  nullable    = true
}

variable "username" {
  type        = string
  description = "Remote account, for example CONTOSO\\Administrator."
}

variable "password" {
  type        = string
  description = "Remote account password."
  sensitive   = true
}

variable "winrm_use_tls" {
  type        = bool
  description = "Use HTTPS for WinRM."
  default     = false
}

variable "winrm_auth" {
  type        = string
  description = "WinRM authentication mechanism: basic, ntlm or kerberos."
  default     = "ntlm"
}

variable "insecure" {
  type        = bool
  description = "Skip TLS certificate validation. Only for throwaway CI targets."
  default     = true
}

variable "powershell_path" {
  type        = string
  description = "PowerShell 7 executable on the target."
  default     = "pwsh"
}

variable "timeout_seconds" {
  type        = number
  description = "Connection timeout in seconds."
  default     = 60
}

variable "ou_path" {
  type        = string
  description = "Slash-delimited OU path created by the smoke test."
  default     = "TerraformCI/Smoke"
}

variable "ou_description" {
  type        = string
  description = "Description set on the leaf OU."
  default     = "terraform-provider-dryad CI smoke test"
}
