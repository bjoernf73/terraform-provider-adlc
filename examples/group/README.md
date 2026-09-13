# dryad_group example

Creates an OU, two groups inside it, and a domain-local group in the built-in
`CN=Users` container.

```sh
terraform init
terraform apply \
  -var host=10.0.13.6 \
  -var 'username=CONTOSO\Administrator' \
  -var password=... \
  -var domain_dn=DC=contoso,DC=local
```

Notes:

- `path` accepts either a slash-delimited OU path relative to the domain root
  (`Contoso/Groups`) or a full container DN (`CN=Users,DC=contoso,DC=local`).
  Missing parent OUs are **not** created by this resource; use
  `dryad_organizational_unit` for that.
- `id` is the group `objectGUID`, so renames and moves are in-place updates
  rather than replacements.
- Import with the GUID:

  ```sh
  terraform import dryad_group.app_admins 9cb8219c-31ff-4a85-a7a3-9bcbb6a41d02
  ```
