resource "adlc_user" "jdoe" {
  name                = "John Doe"
  sam_account_name    = "jdoe"
  user_principal_name = "jdoe@contoso.local"
  path                = "Contoso/Users"

  given_name   = "John"
  surname      = "Doe"
  display_name = "John Doe"
  email        = "john.doe@contoso.local"
  title        = "Systems Engineer"
  department   = "IT"
  company      = "Contoso"
  manager      = adlc_user.jsmith.id

  # Left disabled: no password is set here. Set one with a password-management
  # resource (or manually) before enabling the account.
  enabled = false
}

resource "adlc_user" "jsmith" {
  name                = "Jane Smith"
  sam_account_name    = "jsmith"
  user_principal_name = "jsmith@contoso.local"
  path                = "Contoso/Users"

  given_name   = "Jane"
  surname      = "Smith"
  display_name = "Jane Smith"
  title        = "IT Manager"
  department   = "IT"
  company      = "Contoso"
}
