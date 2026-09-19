---
page_title: "Paths and distinguished names"
subcategory: "Guides"
description: |-
  How adlc resolves object locations, so configurations avoid repeating the domain
  component of every distinguished name.
---

# Paths and distinguished names

Active Directory identifies objects by distinguished name, which is verbose, written
leaf-first, and carries the domain in every single value:

```
OU=Windows,OU=Servers,OU=Contoso,DC=contoso,DC=local
```

Written out in every resource, that is noise — and it hardcodes the domain, so the same
configuration cannot be applied to a test domain without editing every string.

The provider therefore accepts several forms wherever an object location is expected,
and appends the domain component itself.

## The forms

| Form | Example | Resolves to |
| --- | --- | --- |
| Slash path | `Contoso/Servers/Windows` | `OU=Windows,OU=Servers,OU=Contoso,DC=contoso,DC=local` |
| Relative DN | `CN=Computers` | `CN=Computers,DC=contoso,DC=local` |
| Relative DN, nested | `CN=Services,CN=Configuration` | `CN=Services,CN=Configuration,DC=contoso,DC=local` |
| Full DN | `OU=Servers,DC=contoso,DC=local` | used unchanged |
| Empty string | `""` | the domain root, `DC=contoso,DC=local` |

Which form is used is detected from the shape of the value:

1. Ends with the domain DN, or starts with `DC=` → already absolute, used as-is.
2. Contains no `/` and starts with an RDN prefix such as `CN=` or `OU=` → a DN relative
   to the domain root; the domain DN is appended.
3. Anything else → a slash path.

## Slash paths

A slash path reads in the natural direction, parent first, and every segment is assumed
to be an organizational unit below the connected domain root:

```hcl
resource "adlc_organizational_unit" "windows" {
  path = "Contoso/Servers/Windows"
}
```

Slash segments are always OU names. If a segment happens to match the connected domain's
NetBIOS name or DNS label, it is still treated as an OU, not as a domain component. For
example, with the domain `Contoso.local`:

```text
Contoso/Servers       -> OU=Servers,OU=Contoso,DC=Contoso,DC=local
Contoso.local/Servers -> OU=Servers,OU=Contoso.local,DC=Contoso,DC=local
```

Use a relative or full DN when you need a non-OU RDN or want to spell out the domain:

```hcl
path = "OU=Servers"
path = "OU=Servers,DC=contoso,DC=local"
```

Nothing in the relative path names the domain, so the same module applies unchanged to
`contoso.local` and `test.contoso.local`.

~> `adlc_organizational_unit` **creates missing parents** along the path. `adlc_group`
and `adlc_access_rule` do not — they expect the container to exist, and fail if it does
not.

## Relative distinguished names

Slash paths imply `OU=`, which covers most of a directory but not all of it. Several
important locations are containers (`CN=`) rather than organizational units:

- `CN=Users` and `CN=Computers`, the well-known default containers
- `CN=Managed Service Accounts`
- `CN=Public Key Services,CN=Services,CN=Configuration`, where PKI is configured
- `CN=System`, holding DNS and other infrastructure objects

For these, write the distinguished name but leave off the domain:

```hcl
resource "adlc_group" "legacy_readers" {
  name  = "Legacy Readers"
  path  = "CN=Users"
  scope = "DomainLocal"
}

resource "adlc_access_rule" "manage_pki" {
  target      = "CN=Public Key Services,CN=Services,CN=Configuration"
  trustee     = "PKI Admins"
  rights      = ["GenericAll"]
  inheritance = "All"
}
```

A relative DN is written leaf-first, exactly like a real distinguished name — only the
`DC=` components are omitted.

## Mixing the two

When a branch mixes organizational units and containers, a slash segment may carry its
own prefix. Only segments without one default to `OU=`:

```hcl
# OU=Contoso -> CN=LegacyContainer
target = "Contoso/CN=LegacyContainer"
```

## The domain root

An empty string means the domain root, which is where forest-wide delegations such as
directory replication are granted:

```hcl
resource "adlc_access_rule" "replicate_directory_changes" {
  target      = ""
  trustee     = "Entra Connect"
  rights      = ["ExtendedRight"]
  object_type = "Replicating Directory Changes"
}
```

## Where each form is accepted

| Attribute | Meaning |
| --- | --- |
| `adlc_organizational_unit.path` | The OU itself, with parents created as needed |
| `adlc_group.path` | The container holding the group |
| `adlc_access_rule.target` | The object the ACE is applied to |

Each resource also publishes the resolved distinguished name, which is what you pass to
anything that needs a real DN:

| Attribute | Contains |
| --- | --- |
| `adlc_organizational_unit.distinguished_name` | DN of the OU |
| `adlc_group.distinguished_name` | DN of the group |
| `adlc_group.path` | Container, in the form it was configured |
| `adlc_access_rule.target_dn` | Resolved DN of the target |

```hcl
resource "adlc_access_rule" "delegate" {
  target  = adlc_organizational_unit.servers.distinguished_name
  trustee = adlc_group.admins.sid
  rights  = ["CreateChild"]
}
```

Referring to `distinguished_name` rather than repeating the path also creates the
dependency edge, so Terraform creates the OU before the ACE that needs it.

## Equivalent spellings do not cause drift

`CN=Users` and `CN=Users,DC=contoso,DC=local` denote the same container. The provider
compares **resolved** distinguished names rather than the strings you wrote, so either
spelling is stable across plans:

```
No changes. Your infrastructure matches the configuration.
```

A genuine move still produces a real diff, because the resolved DN actually differs.

## When you do need the domain

Use the `adlc_domain` data source rather than a literal, so configurations stay portable:

```hcl
data "adlc_domain" "current" {}

output "users_container" {
  value = data.adlc_domain.current.users_container
}

resource "adlc_group" "example" {
  name = "Example"
  path = data.adlc_domain.current.computers_container
}
```

It also exposes `distinguished_name`, `dns_root`, `netbios_name` and
`domain_controllers_container`.

## Limits worth knowing

**A slash path cannot contain a literal `/`.** An organizational unit named `Sales/Marketing`
is legal in Active Directory but ambiguous as a path segment. Use the DN form for it:

```hcl
path = "OU=Sales/Marketing,OU=Contoso"
```

**Commas inside a name must be escaped in the DN form**, as in any distinguished name:

```hcl
path = "OU=Contoso\\, Inc,OU=Companies"
```

**Matching is case-insensitive**, as Active Directory is. `cn=users` and `CN=Users`
resolve identically, but the value is stored as written.

**The relative form appends the domain DN, not the forest root.** The configuration
naming context belongs to the forest root domain, so
`CN=Public Key Services,CN=Services,CN=Configuration` resolves correctly only when the
provider is connected to the forest root. From a child domain, give the full DN.
