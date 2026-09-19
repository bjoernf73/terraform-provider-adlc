# A Terraform translation of ref/dry.module.ad/example/domain-config.
# The reference JSON remains the source data; this configuration does not modify ref/.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    adlc = {
      source  = "henrikhalt/adlc"
      version = "0.0.0-ci"
    }
  }
}

data "adlc_domain" "current" {}

locals {
  reference_dir = coalesce(var.reference_dir, "${path.module}/../../ref/dry.module.ad/example/domain-config")

  # The original module accepts ###name### replacement patterns. Keep the reference
  # files intact and resolve their known variables at the Terraform boundary.
  ou_source       = jsondecode(file("${local.reference_dir}/dc_ou_schema.json")).ou_schema
  gpo_source      = jsondecode(file("${local.reference_dir}/dc_gpos.json"))
  json_filenames  = fileset(local.reference_dir, "*.json")
  group_documents = [for filename in local.json_filenames : jsondecode(file("${local.reference_dir}/${filename}")) if can(jsondecode(file("${local.reference_dir}/${filename}")).security_groups)]
  raw_groups      = flatten([for document in local.group_documents : document.security_groups])

  replacement_values = {
    "###org###"           = var.organization
    "###RoleShortName###" = var.role_short_name
    "###DomainFQDN###"    = data.adlc_domain.current.dns_root
    "###DomainNB###"      = data.adlc_domain.current.netbios_name
    "###ADSite###"        = var.ad_site_name
  }

  # Direct paths are used by the source's parent_alias/child_path entries.
  ou_direct_paths = {
    for ou in local.ou_source : ou.alias => replace(replace(try(ou.path, ""), "###org###", var.organization), "###RoleShortName###", var.role_short_name)
    if try(ou.path, null) != null
  }
  ou_paths = {
    for ou in local.ou_source : ou.alias => replace(replace(try(ou.path, "${local.ou_direct_paths[ou.parent_alias]}/${ou.child_path}"), "###org###", var.organization), "###RoleShortName###", var.role_short_name)
  }
  ous = {
    for ou in local.ou_source : ou.alias => {
      path        = local.ou_paths[ou.alias]
      description = try(ou.description, "")
    }
    if local.ou_paths[ou.alias] != ""
  }

  groups = {
    for group in local.raw_groups : try(group.Name, group.name) => {
      name        = try(group.Name, group.name)
      alias       = try(group.alias, group.Alias)
      path        = local.ou_paths[try(group.alias, group.Alias)]
      description = replace(replace(replace(try(group.Description, group.description, ""), "###DomainFQDN###", data.adlc_domain.current.dns_root), "###DomainNB###", data.adlc_domain.current.netbios_name), "###RoleShortName###", var.role_short_name)
      scope       = lookup({ global = "Global", domainlocal = "DomainLocal", universal = "Universal" }, lower(try(group.GroupScope, group.groupscope, "global")))
      member_of   = [for target in try(group.MemberOf, group.memberof, []) : replace(replace(target, "###DomainFQDN###", data.adlc_domain.current.dns_root), "###DomainNB###", data.adlc_domain.current.netbios_name)]
      rights      = try(group.Rights, group.rights, [])
    }
  }

  group_memberships = {
    for membership in flatten([
      for group in values(local.groups) : [
        for target in group.member_of : { member = group.name, group = target }
      ]
    ]) : "${membership.member}|${membership.group}" => membership
  }

  access_rules = {
    for entry in flatten([
      for group in values(local.groups) : [
        for index, rule in group.rights : {
          key                   = "${group.name}|${index}"
          trustee               = group.name
          target_alias          = try(rule.alias, null)
          target_path           = try(rule.Path, rule.path, null)
          rights                = [for right in split(",", try(rule.ActiveDirectoryRights, rule.activeDirectoryRights)) : trimspace(right)]
          access                = try(rule.AccessControlType, rule.accessControlType, "Allow")
          object_type           = try(rule.ObjectType, rule.objectType, null)
          inherited_object_type = try(rule.InheritedObjectType, rule.inheritedObjectType, null)
          inheritance           = try(rule.ActiveDirectorySecurityInheritance, rule.activeDirectorySecurityInheritance, null)
        }
      ]
    ]) : entry.key => entry
  }

  gpo_imports = {
    for gpo in local.gpo_source.gpo_imports : gpo.name => {
      source_name = gpo.name
      target_name = replace(replace(try(gpo.targetname, gpo.name), "###DomainNB###", data.adlc_domain.current.netbios_name), "###DomainFQDN###", data.adlc_domain.current.dns_root)
    }
  }
  gpo_links = {
    for link_set in local.gpo_source.gpo_links : link_set.alias => {
      target = link_set.alias == "DomainRoot" ? data.adlc_domain.current.distinguished_name : (
        link_set.alias == "DomainControllers" ? data.adlc_domain.current.domain_controllers_container : local.ou_paths[link_set.alias]
      )
      links = [
        for link in link_set.gplinks : {
          gpo      = replace(link.name, "###DomainNB###", data.adlc_domain.current.netbios_name)
          enabled  = try(link.enabled, true)
          enforced = try(link.enforced, false)
        }
      ]
    }
  }

  wmi_filters = {
    for filter in local.gpo_source.wmi_filters : replace(replace(filter.name, "###DomainFQDN###", data.adlc_domain.current.dns_root), "###ADSite###", var.ad_site_name) => {
      name        = replace(replace(filter.name, "###DomainFQDN###", data.adlc_domain.current.dns_root), "###ADSite###", var.ad_site_name)
      description = replace(replace(filter.description, "###DomainFQDN###", data.adlc_domain.current.dns_root), "###ADSite###", var.ad_site_name)
      queries     = [for query in filter.queries : replace(replace(query, "###DomainFQDN###", data.adlc_domain.current.dns_root), "###ADSite###", var.ad_site_name)]
      links       = [for gpo in try(filter.links, []) : replace(gpo, "###DomainNB###", data.adlc_domain.current.netbios_name)]
    }
  }
  wmi_filter_links = {
    for link in flatten([
      for filter in values(local.wmi_filters) : [for gpo in filter.links : { filter = filter.name, gpo = gpo }]
    ]) : "${link.filter}|${link.gpo}" => link
  }
}

resource "adlc_site" "reference" {
  count       = var.enable_site ? 1 : 0
  name        = var.ad_site_name
  description = "Site named by the ADSite variable in the reference configuration"
}

resource "adlc_subnet" "reference" {
  for_each = var.enable_site ? var.site_subnets : {}
  name     = each.key
  site     = adlc_site.reference[0].name
  location = each.value
}

resource "adlc_organizational_unit" "ou" {
  for_each    = var.enable_directory_objects ? local.ous : {}
  path        = each.value.path
  description = each.value.description
}

resource "adlc_group" "group" {
  for_each = var.enable_directory_objects ? local.groups : {}

  depends_on = [adlc_organizational_unit.ou]

  name = each.value.name
  # The reference does not provide sAMAccountName values. Keep long group names valid
  # with a stable, collision-resistant 20-character value.
  sam_account_name = length(each.value.name) <= 20 ? each.value.name : "adlc-${substr(md5(each.value.name), 0, 14)}"
  path             = each.value.path
  description      = each.value.description
  scope            = each.value.scope
}

resource "adlc_group_member" "nested" {
  for_each = var.enable_directory_objects ? local.group_memberships : {}

  group  = contains(keys(local.groups), each.value.group) ? adlc_group.group[each.value.group].distinguished_name : each.value.group
  member = adlc_group.group[each.value.member].distinguished_name
}

resource "adlc_access_rule" "reference" {
  for_each = var.enable_access_rules ? local.access_rules : {}

  depends_on = [adlc_organizational_unit.ou, adlc_group.group]

  target = each.value.target_alias == "DomainRoot" ? data.adlc_domain.current.distinguished_name : (
    each.value.target_alias != null ? local.ou_paths[each.value.target_alias] : each.value.target_path
  )
  trustee               = adlc_group.group[each.value.trustee].distinguished_name
  rights                = toset(each.value.rights)
  access                = each.value.access
  object_type           = each.value.object_type
  inherited_object_type = each.value.inherited_object_type
  inheritance           = each.value.inheritance
}

resource "adlc_json_gpo" "reference" {
  for_each = var.enable_gpo_imports ? local.gpo_imports : {}

  path        = "${local.reference_dir}/gpo_imports/${each.value.source_name}.json"
  target_name = each.value.target_name
  replacements = {
    DomainFQDN = data.adlc_domain.current.dns_root
    DomainNB   = data.adlc_domain.current.netbios_name
  }
}

resource "adlc_gpo_links" "reference" {
  for_each = var.enable_gpo_links ? local.gpo_links : {}

  depends_on = [adlc_json_gpo.reference]

  target = each.value.target
  links  = each.value.links
}

resource "adlc_wmi_filter" "reference" {
  for_each = var.enable_wmi_filters ? local.wmi_filters : {}

  name        = each.value.name
  description = each.value.description
  queries     = [for query in each.value.queries : { namespace = "root\\CIMv2", query = query }]
}

resource "adlc_gpo_wmi_filter" "reference" {
  for_each = var.enable_gpo_imports && var.enable_wmi_filter_links ? local.wmi_filter_links : {}

  gpo        = adlc_json_gpo.reference[each.value.gpo].target_name
  wmi_filter = adlc_wmi_filter.reference[each.value.filter].name
}

resource "adlc_netlogon_files" "reference" {
  count       = var.enable_netlogon_files ? 1 : 0
  source_path = "${local.reference_dir}/netlogon"
}
