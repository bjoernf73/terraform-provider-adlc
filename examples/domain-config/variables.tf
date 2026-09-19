variable "reference_dir" {
  type        = string
  default     = null
  nullable    = true
  description = "Path to the dry.module.ad domain-config directory. Defaults to the checked-in reference fixture."
}

variable "organization" {
  type        = string
  default     = "TEST"
  description = "Value for the reference configuration's ###org### replacement pattern."
}

variable "role_short_name" {
  type        = string
  default     = "DC"
  description = "Value for the reference configuration's ###RoleShortName### replacement pattern."
}

variable "ad_site_name" {
  type        = string
  default     = "SiteA"
  description = "Value for the reference configuration's ###ADSite### replacement pattern."
}

variable "site_subnets" {
  type        = map(string)
  default     = {}
  description = "Optional CIDR-to-location map for the reference AD site. The source configuration declares a site name but no networks."
}

variable "enable_site" {
  type        = bool
  default     = false
  description = "Create the optional adlc_site and site_subnets resources."
}

variable "enable_directory_objects" {
  type        = bool
  default     = false
  description = "Create the OU hierarchy, groups, and nested memberships from the reference JSON."
}

variable "enable_access_rules" {
  type        = bool
  default     = false
  description = "Apply delegated ACLs from the reference JSON. Requires enable_directory_objects."
}

variable "enable_gpo_imports" {
  type        = bool
  default     = false
  description = "Import the reference JSON GPO files."
}

variable "enable_gpo_links" {
  type        = bool
  default     = false
  description = "Authoritatively manage the GPO link sets from the reference JSON. Requires enable_gpo_imports."
}

variable "enable_wmi_filters" {
  type        = bool
  default     = false
  description = "Create the WMI filters from the reference JSON."
}

variable "enable_wmi_filter_links" {
  type        = bool
  default     = false
  description = "Assign reference WMI filters to the imported GPOs. Requires enable_gpo_imports and enable_wmi_filters."
}

variable "enable_netlogon_files" {
  type        = bool
  default     = false
  description = "Deploy the reference netlogon directory using adlc_netlogon_files."
}
