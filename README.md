# terraform-provider-adlc (Deprecated)

## Status: Provider Renamed

This provider has been renamed.  
All future development, releases, and issue tracking have moved to the new repository:

**https://github.com/bjoernf73/terraform-provider-adds**

The `adlc` provider is deprecated and archived. No further updates will be published under this name.

---

## Why the Rename

The provider has been renamed to better reflect its purpose and long-term direction.  
Terraform does not support renaming providers in place, so migration requires a manual state update.

All new features and fixes will be released under the new provider name: **adds**.

---

# Migration Guide

Follow the steps below to migrate safely from `adlc` to `adds`.

## 1. Update Terraform Configuration

Replace any existing `adlc` provider configuration:

```hcl
terraform {
  required_providers {
    adlc = {
      source  = "bjoernf73/adlc"
      version = "~> 0.0.35"
    }
  }
}

provider "adlc" {
  # ...
}
```

with the new provider:

```hcl
terraform {
  required_providers {
    adds = {
      source  = "bjoernf73/adds"
      version = "~> 0.0.36"
    }
  }
}

provider "adds" {
  # ...
}

## 2. Update Terraform State

Terraform/OpenTofu must be told that resources previously managed by adlc are now managed by adds.

Terraform:

```hcl
terraform state replace-provider \
  registry.terraform.io/bjoernf73/adlc \
  registry.terraform.io/bjoernf73/adds

```

OpenTofu:

```hcl
tofu state replace-provider \
  registry.opentofu.org/bjoernf73/adlc \
  registry.opentofu.org/bjoernf73/adds

```

## 3. Reinitialize Terraform

```hcl
terraform init -upgrade
```

Terraform will now download the new provider and continue managing existing resources under the new name.

# What Happens If You Do Not Migrate

Existing configurations referencing adlc will continue to work only as long as you do not upgrade.
The deprecated provider will not receive updates and may stop working with future Terraform/OpenTofu versions.

# Support and Issues

All issues, discussions, and feature requests should now be created in the new repository:

https://github.com/bjoernf73/terraform-provider-adds