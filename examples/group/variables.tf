variable "host" {
  type = string
}

variable "port" {
  type    = number
  default = 5985
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "winrm_auth" {
  type    = string
  default = "ntlm"
}

variable "domain_dn" {
  type    = string
  default = "DC=contoso,DC=local"
}
