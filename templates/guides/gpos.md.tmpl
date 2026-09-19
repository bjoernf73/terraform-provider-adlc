---
page_title: "Managing Group Policy Objects"
subcategory: "Guides"
description: |-
  The two ways this provider imports GPOs, how migration/token replacement works for
  each, and how links, ACLs and drift are handled.
---

# Managing Group Policy Objects

This provider has two independent ways to get a GPO into Active Directory. Both import
into an ordinary GPO by name and both re-import in place on every apply, preserving the
target's GUID and any links or ACLs already on it - neither one ever deletes and
recreates the GPO.

| | `dryad_backup_gpo` | `dryad_json_gpo` |
| --- | --- | --- |
| Source | A `Backup-GPO` folder (or the GPMC UI's backup) | A JSON description |
| Underlying mechanism | `Import-GPO` | Rewrites SYSVOL files directly, using an embedded copy of Microsoft's `GPRegistryPolicyParser` for `Registry.pol` |
| Migrating principals/paths | An explicit, typed `migrations` list | Automatic, by name, for every SID the export found |
| Free-text substitution | Not supported | `replacements`, a plain string map |
| Coverage | Everything `Import-GPO` supports | Registry settings, security template, audit settings, comments, scripts, Group Policy Preferences - not links, ACLs or WMI filters |

GPO links and ACLs are managed by separate resources either way: [`dryad_gpo_links`](../resources/gpo_links.md)
for links, [`dryad_access_rule`](../resources/access_rule.md) for permissions on the GPO
container itself (its distinguished name is `CN={guid},CN=Policies,CN=System,<domain DN>`,
published as `distinguished_name` on both resources).

## `dryad_backup_gpo`: importing a `Backup-GPO` folder

Each backup gets its own dedicated folder, matching `backup_name`, so the folder itself
is exactly what you'd pass to `Backup-GPO -Path`:

```powershell
Backup-GPO -Name "Domain - GPO1" -Path ".\backup_gpo\Domain - GPO1"
```

```hcl
resource "dryad_backup_gpo" "domain_gpo1" {
  backup_name = "Domain - GPO1"
  path        = "${path.module}/backup_gpo"
  target_name = "Domain - GPO1"
}
```

### Migrating principals across domains

`migrations` mirrors GPMC's own migration table concept, one entry per principal or UNC
path baked into the backup. `source` always reflects the *source* domain - it identifies
what's actually recorded in the backup and never changes based on where you're
importing to. Each entry needs exactly one of `destination` or `same_as_source`:

```hcl
migrations = [
  # Re-resolve "AnotherGroup" by name in the target domain, instead of a fixed value.
  { type = "GlobalGroup", source = "AnotherGroup@utv.local", same_as_source = true },

  # Or redirect explicitly, e.g. to a differently-named group in the target domain.
  { type = "LocalGroup", source = "Right-ADM-BuiltinGroup-RemoteDesktopUsers@utv.local",
    destination = "Right-ADM-BuiltinGroup-RemoteDesktopUsers@${data.dryad_domain.current.dns_root}" },
]
```

Whichever principals you reference must already exist, by name, in the target domain -
Terraform doesn't create them for you; a `dryad_group` alongside the import is the usual
pattern.

## `dryad_json_gpo`: importing a JSON description

```hcl
resource "dryad_json_gpo" "domain_gpo5" {
  path        = "${path.module}/json_gpo/Domain - GPO5.json"
  target_name = "Domain - GPO5"
}
```

Every security principal a JSON GPO references was recorded as a portable
`####Replace[DOMAIN\Name]` token when it was exported, and each one is resolved by name
in the target domain automatically - no `migrations` list to maintain. As with
`dryad_backup_gpo`, the referenced principals must already exist in the target domain.

### Free-text replacements

Some values in an export are free text an export can't classify automatically - a domain
FQDN embedded in a registry value, for example - marked with a `####key####` token of
their own. `replacements` fills these in; keys are bare names, with the `####` delimiters
implied - the same way Ansible implies double curly braces around a variable name:

```hcl
replacements = {
  DomainFQDN = data.dryad_domain.current.dns_root
}
```

### Exporting a GPO to JSON

`dryad_json_gpo_export` is the read-only mirror of the import: it reads a live GPO's
SYSVOL content and renders it as JSON, converting SIDs to `####Replace[DOMAIN\Name]`
tokens instead of resolving them from one. Pair it with the `local_file` resource from
the `hashicorp/local` provider to write the result to disk - the same way `Backup-GPO`'s
output isn't itself a Terraform concept for `dryad_backup_gpo`:

```hcl
data "dryad_json_gpo_export" "domain_gpo5" {
  name = "Domain - GPO5"
}

resource "local_file" "domain_gpo5" {
  filename = "${path.module}/json_gpo/Domain - GPO5.json"
  content  = data.dryad_json_gpo_export.domain_gpo5.json
}
```

Export, commit the resulting file, then `dryad_json_gpo` imports it elsewhere - a full
round trip between two domains without ever running GPMC by hand on the target.

## Detecting a changed source (the JSON file or backup folder)

Neither resource stores the backup folder or JSON file itself in Terraform state - only
a fingerprint, `content_hash`, computed from local disk every plan (not cached: it's
recomputed fresh each time, not just read back from state). `dryad_backup_gpo` hashes
every file under `path/backup_name/` plus `migrations`; `dryad_json_gpo` hashes the JSON
file's raw bytes plus `replacements`.

So if you edit the JSON file, or re-export a backup into the same `path`/`backup_name` -
`target_name` unchanged, nothing else in the `.tf` file touched either - the next
`terraform plan` reads the now-different file, computes a different hash, sees it
doesn't match what's recorded in state, and shows `content_hash` changing. That's what
triggers `Update()` (a re-import), independent of anything happening in Active Directory.

## Detecting drift made outside Terraform

A GPO exposes no content to diff against directly, so both resources detect edits made
outside Terraform (someone editing the GPO in GPMC) the same way: through its AD/SysVol
version counters, which GPMC increments on every settings change regardless of which
tool made it. Every plan re-checks the live version against the one recorded at the last
apply, and re-imports the backup or JSON to overwrite the drift when they no longer
match.
