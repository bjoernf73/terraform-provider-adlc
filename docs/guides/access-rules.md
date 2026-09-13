---
page_title: "Access rules and delegation"
subcategory: "Guides"
description: |-
  How dryad_access_rule maps onto Active Directory ACEs, including all six
  ActiveDirectoryAccessRule constructors.
---

# Access rules and delegation

`dryad_access_rule` manages a single access control entry (ACE) in the DACL of an
Active Directory object. It is a separate resource rather than an attribute of the
objects it protects, for reasons covered in [Why a separate resource](#why-a-separate-resource).

## The model

One resource is one ACE. `rights` is a set of `ActiveDirectoryRights` values that are
combined into a single entry using the flags enum, so this creates **one** ACE, not two:

```hcl
resource "dryad_access_rule" "example" {
  target  = "OU=Servers,DC=contoso,DC=local"
  trustee = "Server Admins"
  rights  = ["CreateChild", "DeleteChild"]
}
```

An ACE is identified by everything except its rights: the target, the trustee SID, the
access type, the object type GUIDs and the inheritance flags. Changing any of those
replaces the resource; changing only `rights` updates it in place with a single write.

## The six constructors

`System.DirectoryServices.ActiveDirectoryAccessRule` has six constructors. Which one is
used depends on which of `object_type`, `inheritance` and `inherited_object_type` you
set:

| # | object_type | inheritance | inherited_object_type | Constructor |
| --- | --- | --- | --- | --- |
| 1 | – | – | – | `(identity, rights, type)` |
| 2 | – | set | – | `(identity, rights, type, inheritance)` |
| 3 | – | set | set | `(identity, rights, type, inheritance, inheritedObjectType)` |
| 4 | set | – | – | `(identity, rights, type, objectType)` |
| 5 | set | set | – | `(identity, rights, type, objectType, inheritance)` |
| 6 | set | set | set | `(identity, rights, type, objectType, inheritance, inheritedObjectType)` |

`inherited_object_type` without `inheritance` has no corresponding constructor and is
rejected during `terraform plan`.

### 1. Rights on the object itself

No object type, no inheritance. The ACE applies to the target and nothing else.

```hcl
resource "dryad_access_rule" "full_control_on_ou" {
  target  = dryad_organizational_unit.servers.distinguished_name
  trustee = "Server Admins"
  rights  = ["GenericAll"]
}
```

### 2. Rights inherited by descendants

Adding `inheritance` propagates the ACE. `All` covers the object and every descendant;
`Descendents` covers descendants only; `Children` covers immediate children.

```hcl
resource "dryad_access_rule" "read_everything_below" {
  target      = dryad_organizational_unit.servers.distinguished_name
  trustee     = "Authenticated Users"
  rights      = ["GenericRead"]
  inheritance = "All"
}
```

### 3. Rights on descendants of one class

`inherited_object_type` narrows inheritance to a single object class. Here, full control
over user objects anywhere below the OU — but not over the OU or any other class.

```hcl
resource "dryad_access_rule" "manage_users" {
  target                = dryad_organizational_unit.staff.distinguished_name
  trustee               = "Helpdesk"
  rights                = ["GenericAll"]
  inheritance           = "Descendents"
  inherited_object_type = "user"
}
```

### 4. Rights on one class of child object

`object_type` without inheritance. With `CreateChild` and `DeleteChild`, `object_type`
names the class that may be created or deleted — here, computer objects directly in this
OU only.

```hcl
resource "dryad_access_rule" "join_computers" {
  target      = dryad_organizational_unit.servers.distinguished_name
  trustee     = "Server Admins"
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
}
```

### 5. Rights on one class, propagated

The same, but propagated to child OUs so the delegation survives future OU structure.

```hcl
resource "dryad_access_rule" "join_computers_anywhere" {
  target      = dryad_organizational_unit.servers.distinguished_name
  trustee     = "Server Admins"
  rights      = ["CreateChild", "DeleteChild"]
  object_type = "computer"
  inheritance = "Descendents"
}
```

### 6. One attribute, on one class, propagated

All three set. `object_type` is the attribute being written, `inherited_object_type` is
the class it is written on. This is the classic "let the helpdesk reset passwords on user
objects" delegation.

```hcl
resource "dryad_access_rule" "reset_passwords" {
  target                = dryad_organizational_unit.staff.distinguished_name
  trustee               = "Helpdesk"
  rights                = ["ExtendedRight"]
  object_type           = "Reset Password"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}

resource "dryad_access_rule" "write_description" {
  target                = dryad_organizational_unit.staff.distinguished_name
  trustee               = "Helpdesk"
  rights                = ["ReadProperty", "WriteProperty"]
  object_type           = "description"
  inheritance           = "Descendents"
  inherited_object_type = "user"
}
```

## Object types

`object_type` and `inherited_object_type` accept:

| Kind | Example | Resolved from |
| --- | --- | --- |
| Schema class | `computer`, `user`, `organizationalUnit` | `lDAPDisplayName` in the schema NC |
| Attribute | `description`, `unicodePwd` | `lDAPDisplayName` in the schema NC |
| Property set | `User-Account-Restrictions` | `displayName` of a `controlAccessRight` |
| Extended right | `Reset Password`, `Send As` | `displayName` of a `controlAccessRight` |
| GUID | `bf967a86-0de6-11d0-a285-00aa003049e2` | used as-is |
| `All` | `All` | the empty GUID |

Lookups are targeted LDAP queries, not a full schema enumeration.

## Trustees

`trustee` accepts a SID, a distinguished name, `DOMAIN\name`, a `sAMAccountName`, or a
well-known name such as `Authenticated Users` or `Everyone`. It is resolved to a SID
when the resource is applied and the SID is stored in state, so renaming a group does
not cause drift.

Because well-known principals resolve without being directory objects, they can be used
without declaring a `dryad_group` for them:

```hcl
resource "dryad_access_rule" "deny_everyone" {
  target      = dryad_organizational_unit.secret.distinguished_name
  trustee     = "Everyone"
  rights      = ["GenericRead"]
  access      = "Deny"
  inheritance = "All"
}
```

~> **Deny ACEs take precedence over allow ACEs.** A `Deny` entry that matches a broad
principal such as `Everyone` will override delegations granted elsewhere.

## What this resource does not touch

`dryad_access_rule` is deliberately non-authoritative:

- **Inherited ACEs are never modified or removed.** Only explicit, non-inherited entries
  on the target are considered.
- **Inheritance is never enabled or disabled.** Blocking inheritance on an object is a
  destructive operation that must be performed deliberately, never as a side effect of
  adding a delegation.
- **ACEs belonging to other trustees are left alone**, including the defaults Active
  Directory creates.
- **Destroying the resource removes only the ACE it created.**

This means an object can carry a mix of Terraform-managed and externally-managed
permissions without either side reverting the other.

## Why a separate resource

Permissions are not modelled as an `acl` attribute on `dryad_organizational_unit` and
friends. Four reasons:

1. **Partial ownership.** A nested attribute implies Terraform owns the whole DACL. Real
   objects carry inherited and default ACEs that no one wants to declare, and that change
   with schema updates.
2. **Unmanaged targets.** `target` is a plain DN, so rights can be granted on the domain
   root, `CN=Users`, or any OU that predates Terraform.
3. **Canonical ordering.** Windows reorders ACEs (deny before allow, explicit before
   inherited). A list-shaped attribute would produce permanent diffs.
4. **Dependency cycles.** Delegating rights on an OU to a group that lives inside that
   same OU is routine:

   ```hcl
   resource "dryad_organizational_unit" "servers" {
     path = "Contoso/Servers"
   }

   resource "dryad_group" "server_admins" {
     path = dryad_organizational_unit.servers.path # group depends on OU
   }

   resource "dryad_access_rule" "delegate" {
     target  = dryad_organizational_unit.servers.distinguished_name
     trustee = dryad_group.server_admins.sid # rule depends on both
     rights  = ["CreateChild", "DeleteChild"]
   }
   ```

   As an attribute of the OU, the OU would depend on the group and the group on the OU,
   and Terraform would refuse to plan. A third resource depending on both breaks the
   cycle.

## Rights reference

Common `ActiveDirectoryRights` values:

| Right | Meaning |
| --- | --- |
| `GenericAll` | Full control |
| `GenericRead` | Read permissions, properties and object list |
| `GenericWrite` | Write properties and validated writes |
| `CreateChild` / `DeleteChild` | Create or delete child objects of `object_type` |
| `ReadProperty` / `WriteProperty` | Read or write the attribute named by `object_type` |
| `DeleteTree` | Delete an object and its whole subtree |
| `ExtendedRight` | Exercise the extended right named by `object_type` |
| `ReadControl` / `WriteDacl` / `WriteOwner` | Read or modify the security descriptor |
| `Self` | Validated write |

-> Some combinations are rendered by .NET under a composite name — configuring
`ReadControl`, `ListChildren`, `ReadProperty` and `ListObject` reads back as
`GenericRead`. The provider compares the numeric access mask and keeps your spelling when
the effective rights are unchanged, so this does not produce a diff.
