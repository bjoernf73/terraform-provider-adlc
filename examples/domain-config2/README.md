# Static Domain Configuration

This is a self-contained Terraform translation of the `dry.module.ad`
`domain-config` example. Unlike [../domain-config](../domain-config), it has no
runtime `jsondecode`, `fileset`, or `ref/` dependency:

- all 25 OU definitions, 71 group definitions, memberships, and 50 ACL rules are
  explicit Terraform locals in `main.tf`;
- the 15 GPO JSON files and NETLOGON assets are copied into this directory;
- GPO links, 24 WMI filters, and WMI assignments are explicit Terraform locals.

The source configuration did not contain subnet or Administrative Template data.
`site_subnets` therefore remains an optional Terraform input, and schema extensions
remain out of scope until the provider gains a schema-extension resource.

Every mutating component is disabled by default. Enable each component deliberately:

```hcl
# terraform.tfvars
organization             = "CONTOSO"
role_short_name          = "DC"
ad_site_name             = "HeadOffice"
enable_directory_objects = true
enable_access_rules      = true
enable_gpo_imports       = true
enable_gpo_links         = true
enable_wmi_filters       = true
enable_wmi_filter_links  = true
enable_netlogon_files    = true
```

GPO links are authoritative. Inspect the plan carefully before enabling them on an
existing domain.

The copied `Domain - Domain Policy - v0r2.json` normalizes the source fixture's old
three-hash token delimiters to the provider's four-hash convention. Configure the
provider in a root module or add a suitable `provider "adlc"` block; credentials are
intentionally absent from this example.
