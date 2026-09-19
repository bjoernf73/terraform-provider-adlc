variable "organization" {
  type        = string
  default     = "TEST"
  description = "Value formerly supplied as the dry.module.ad ###org### variable."
}

variable "role_short_name" {
  type        = string
  default     = "DC"
  description = "Value formerly supplied as the dry.module.ad ###RoleShortName### variable."
}

variable "ad_site_name" {
  type        = string
  default     = "SiteA"
  description = "Value formerly supplied as the dry.module.ad ###ADSite### variable."
}

variable "site_subnets" {
  type        = map(string)
  default     = {}
  description = "Optional CIDR-to-location map for the AD site; the source fixture has no subnet declarations."
}

variable "enable_site" {
  type        = bool
  default     = false
  description = "Create the optional AD site and subnets."
}

variable "enable_directory_objects" {
  type        = bool
  default     = false
  description = "Create the explicit OU hierarchy, groups, and nested memberships."
}

variable "enable_access_rules" {
  type        = bool
  default     = false
  description = "Apply the explicit delegated ACL rules. Requires enable_directory_objects."
}

variable "enable_gpo_imports" {
  type        = bool
  default     = false
  description = "Import the copied JSON GPO files."
}

variable "enable_gpo_links" {
  type        = bool
  default     = false
  description = "Authoritatively manage the copied GPO link sets. Requires enable_gpo_imports."
}

variable "enable_wmi_filters" {
  type        = bool
  default     = false
  description = "Create the explicit WMI filters."
}

variable "enable_wmi_filter_links" {
  type        = bool
  default     = false
  description = "Assign WMI filters to imported GPOs. Requires enable_gpo_imports and enable_wmi_filters."
}

variable "enable_netlogon_files" {
  type        = bool
  default     = false
  description = "Deploy the copied NETLOGON file tree."
}
