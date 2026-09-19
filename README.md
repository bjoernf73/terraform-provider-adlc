# terraform-provider-dryad

A Terraform provider that manages **Active Directory** objects by executing
**PowerShell 7** on a remote Windows host over **WinRM** or **SSH**.

There is no LDAP client. Every operation is a PowerShell script that runs on a host with
the `ActiveDirectory` module — normally a domain controller — and returns a single JSON
document that the provider decodes.

## Resources

| Resource | Manages |
| --- | --- |
| `dryad_organizational_unit` | Organizational units, creating missing parents on demand |
| `dryad_group` | Groups, including rename and move |
| `dryad_group_member` | A single group membership |
| `dryad_user` | User accounts, including rename and move. Passwords are not managed here. |
| `dryad_user_password` | Sets a user's initial password, generated or supplied |
| `dryad_access_rule` | A single access control entry (ACE) on any directory object |
| `dryad_backup_gpo` | Imports a `Backup-GPO` folder into a GPO |
| `dryad_json_gpo` | Imports a JSON-described GPO |
| `dryad_gpo_links` | The full, ordered set of GPO links on an OU, domain or site |

## Data sources 

| Data source | Reads |
| --- | --- |
| `dryad_domain` | The connected domain: DN, DNS root, NetBIOS name, well-known containers |
| `dryad_json_gpo_export` | A live GPO's SYSVOL content, as JSON |

## Documentation

Full documentation lives in [docs/](docs/) and is published to the Terraform Registry:

- [Provider configuration and authentication](docs/index.md)
- [Paths and distinguished names](docs/guides/paths.md) — how object locations are resolved
- [Access rules and delegation](docs/guides/access-rules.md) — all six ACE constructors
- [Managing Group Policy Objects](docs/guides/gpos.md) — backup vs. JSON GPOs, migration, links, drift
- [Dependencies and ordering](docs/guides/dependencies.md) — references, `depends_on` and cycles
- [User passwords and secret storage](docs/guides/passwords.md) — generation, rotation, Vault composition
- [Repeating object patterns across systems](docs/guides/repeating-patterns.md) — `for_each` and modules
- Resource reference under [docs/resources/](docs/resources/)

`docs/` is generated — edit the schema `MarkdownDescription` strings, the snippets in
[examples/](examples/), or the page templates in [templates/](templates/), then run:


```sh
make docs
```

## Quick start

```hcl
terraform {
  required_providers {
    dryad = {
      source = "henrikhalt/dryad"
    }
  }
}

provider "dryad" {
  transport       = "winrm"
  host            = "dc1.contoso.local"
  username        = "CONTOSO\\terraform"
  password        = var.password
  winrm_auth      = "ntlm"
  powershell_path = "pwsh"
}

resource "dryad_organizational_unit" "servers" {
  path        = "Contoso/Servers/Windows"
  description = "Windows server OU"
}

resource "dryad_group" "server_admins" {
  name  = "Server Admins"
  path  = "Contoso/Groups"
  scope = "DomainLocal"
}

resource "dryad_access_rule" "delegate_computers" {
  target                = dryad_organizational_unit.servers.distinguished_name
  trustee               = dryad_group.server_admins.sid
  rights                = ["CreateChild", "DeleteChild"]
  object_type           = "computer"
  inherited_object_type = "organizationalUnit"
  inheritance           = "Descendents"
}
```

## Requirements

- PowerShell 7 (`pwsh`) on the target host
- The `ActiveDirectory` PowerShell module
- WinRM or OpenSSH reachable from wherever Terraform runs

## Transports

| Transport | Authentication |
| --- | --- |
| `winrm` | `basic`, `ntlm`, `kerberos` |
| `ssh` | password, private key |

Notes that save time:

- WinRM `basic` accepts **local accounts only**, so it cannot authenticate a domain
  account against a domain controller.
- `ntlm` over plain HTTP (5985) needs `AllowUnencrypted = true` on the WinRM service,
  because the library applies no NTLM message encryption. HTTPS on 5986 avoids this.
- `kerberos` needs the target FQDN, not an IP address, because the SPN is derived from
  the host name.

## Development

```sh
make build       # go build ./...
make vet
make test
make docs        # regenerate docs/ (needs the terraform CLI)
```

End-to-end tests live in [test/e2e/](test/e2e/) and run against a real domain controller
from CI over both transports. See [.gitlab-ci.yml](.gitlab-ci.yml).

A manual transport check, for when CI is too slow a feedback loop:

```sh
DRYAD_HOST=10.0.13.6 DRYAD_USERNAME='CONTOSO\Administrator' DRYAD_PASSWORD=... \
  go test ./internal/transport -run TestWinRMSmoke -v
```
