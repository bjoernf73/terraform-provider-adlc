# dry.module.ad Domain Configuration Translation

This is a comprehensive Terraform translation of the configuration data in
`ref/dry.module.ad/example/domain-config`. The reference material is read directly with
`jsondecode(file(...))`; it is not copied or modified.

The configuration translates these source concepts:

- `dc_ou_schema.json`: organizational units, excluding `DomainRoot`, which maps to the
  connected domain's distinguished name rather than an OU resource.
- all `security_groups` arrays: security groups, built-in group membership, nested
  reference-group membership, and the delegated ACLs declared under `Rights`.
- `dc_gpos.json` and `gpo_imports/`: JSON GPO imports, authoritative GPO link lists,
  WMI filters, and WMI-filter assignments.
- `netlogon/`: NETLOGON files, managed without touching unrelated remote files.
- `ADSite`: an optional AD site. The original configuration does not provide subnets,
  so `site_subnets` accepts CIDR/location pairs instead of inventing a network.

`ad_schema/` is intentionally not translated: schema-extension management is not yet a
provider resource. The reference also has no Administrative Templates directory.

## Apply deliberately

Every mutating component is disabled by default. Enable only the parts appropriate for
the target domain, then inspect the plan carefully. GPO links are authoritative and can
remove existing links that are absent from the source configuration.

```hcl
# terraform.tfvars
organization              = "CONTOSO"
role_short_name           = "DC"
ad_site_name              = "HeadOffice"
enable_directory_objects  = true
enable_wmi_filters        = true
enable_gpo_imports        = true
enable_gpo_links          = true
enable_wmi_filter_links   = true
enable_netlogon_files     = true
```

The GPO fixture `Domain - Domain Policy - v0r2.json` uses the old three-hash
`###name###` convention inherited from dry.module.ad. Normalize it to the provider's
four-hash token convention before enabling GPO imports, or point `reference_dir` at a
prepared copy with that file corrected. The target-name and WMI-filter replacements are
translated directly by this example.

## Provider configuration

Configure the provider in a root module or add a `provider "adlc"` block appropriate
for the target environment. This example intentionally does not contain credentials.
