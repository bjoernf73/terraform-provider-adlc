resource "dryad_user" "jdoe" {
  name                = "John Doe"
  sam_account_name    = "jdoe"
  user_principal_name = "jdoe@contoso.local"
  path                = "Contoso/Users"
  given_name          = "John"
  surname             = "Doe"

  # Left unmanaged here: dryad_user_password enables the account once the password
  # is set, avoiding "New-ADUser -Enabled $true" failing because no password exists yet.
  enabled = false
}

# Generates a random password and sets it on the account, then pushes it to Vault.
# Nothing in this provider talks to Vault: the vault_kv_secret_v2 resource below is
# part of the separate hashicorp/vault provider.
resource "dryad_user_password" "jdoe" {
  user = dryad_user.jdoe.id
}

resource "vault_kv_secret_v2" "jdoe" {
  mount = "secret"
  name  = "ad/users/jdoe"
  data_json = jsonencode({
    username = dryad_user.jdoe.sam_account_name
    password = dryad_user_password.jdoe.password
  })
}

# Reuses a password already stored in Vault, without ever writing it to Terraform
# state. Requires Terraform 1.11+. Bump password_wo_version to rotate the password —
# password_wo itself cannot be diffed, since it is never persisted anywhere.
data "vault_kv_secret_v2" "jsmith" {
  mount = "secret"
  name  = "ad/users/jsmith"
}

resource "dryad_user" "jsmith" {
  name                = "Jane Smith"
  sam_account_name    = "jsmith"
  user_principal_name = "jsmith@contoso.local"
  path                = "Contoso/Users"
  enabled             = false
}

resource "dryad_user_password" "jsmith" {
  user                = dryad_user.jsmith.id
  password_wo         = data.vault_kv_secret_v2.jsmith.data["password"]
  password_wo_version = 1
}

# Forces the password to be regenerated (and the account re-enabled) whenever
# var.rotation_marker changes, without touching any other attribute.
resource "dryad_user_password" "rotating" {
  user = dryad_user.jdoe.id

  keepers = {
    rotation = var.rotation_marker
  }
}
