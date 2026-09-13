variable "host" {
  type        = string
  description = "IP address or hostname of the target domain controller."
}

variable "port" {
  type        = number
  description = "WinRM port."
  default     = 5985
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
