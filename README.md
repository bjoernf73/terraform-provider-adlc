# terraform-provider-adlc

A Terraform **Active Directory Lifecycle** provider that manages Active Directory
objects and policy through **PowerShell 7** on a remote Windows host over **WinRM**
or **SSH**.

There is no LDAP client. Every operation is a PowerShell script that runs on a host with
the `ActiveDirectory` module — normally a domain controller — and returns a single JSON
document that the provider decodes.

## Resources

| Resource | Manages |
| --- | --- |
| `adlc_organizational_unit` | Organizational units, creating missing parents on demand |
| `adlc_group` | Groups, including rename and move |
| `adlc_group_member` | A single group membership |
| `adlc_user` | User accounts, including rename and move. Passwords are not managed here. |
| `adlc_user_password` | Sets a user's initial password, generated or supplied |
| `adlc_access_rule` | A single access control entry (ACE) on any directory object |
| `adlc_backup_gpo` | Imports a `Backup-GPO` folder into a GPO |
| `adlc_json_gpo` | Imports a JSON-described GPO |
| `adlc_gpo_links` | The full, ordered set of GPO links on an OU, domain or site |
| `adlc_wmi_filter` | A WMI filter (`msWMI-Som` object) |
| `adlc_gpo_wmi_filter` | The WMI filter assigned to a single GPO |
| `adlc_gpo_permission` | One trustee's named Group Policy permission |
| `adlc_gpo_security_filter` | The complete set of principals allowed to apply one GPO |
| `adlc_netlogon_files` | A Terraform-owned file tree below NETLOGON |
| `adlc_administrative_templates` | A Terraform-owned file tree at the Central Store root |
| `adlc_site` | An Active Directory replication site |
| `adlc_subnet` | A CIDR network assigned to an Active Directory site |

## Data sources

| Data source | Reads |
| --- | --- |
| `adlc_domain` | The connected domain: DN, DNS root, NetBIOS name, well-known containers |
| `adlc_json_gpo_export` | A live GPO's SYSVOL content, as JSON |

## Documentation

Full documentation lives in [docs/](docs/) and is published to the Terraform Registry:

- [Provider configuration and authentication](docs/index.md)
- [Paths and distinguished names](docs/guides/paths.md) — how object locations are resolved
- [Access rules and delegation](docs/guides/access-rules.md) — all six ACE constructors
- [Managing Group Policy Objects](docs/guides/gpos.md) — backup vs. JSON GPOs, migration, links, drift
- [Managing SYSVOL files](docs/guides/sysvol-files.md) — NETLOGON scripts and Administrative Templates
- [Managing Active Directory Sites](docs/guides/sites-and-subnets.md) — replication sites and subnet assignment
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
    adlc = {
      source = "bjoernf73/adlc"
    }
  }
}

provider "adlc" {
  transport       = "winrm"
  host            = "dc1.contoso.local"
  username        = "CONTOSO\\terraform"
  password        = var.password
  winrm_auth      = "ntlm"
  powershell_path = "pwsh"
}

resource "adlc_organizational_unit" "servers" {
  path        = "Contoso/Servers/Windows"
  description = "Windows server OU"
}

resource "adlc_group" "server_admins" {
  name  = "Server Admins"
  path  = "Contoso/Groups"
  scope = "DomainLocal"
}

resource "adlc_access_rule" "delegate_computers" {
  target                = adlc_organizational_unit.servers.distinguished_name
  trustee               = adlc_group.server_admins.sid
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
ADLC_HOST=10.0.13.6 ADLC_USERNAME='CONTOSO\Administrator' ADLC_PASSWORD=... \
  go test ./internal/transport -run TestWinRMSmoke -v
```
