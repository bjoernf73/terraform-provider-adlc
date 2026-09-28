# terraform-provider-adlc

A Terraform **Active Directory Lifecycle** provider that manages Active Directory
objects and policy through **PowerShell 7** on a remote Windows host over **WinRM**
or **SSH**.

> [!WARNING]
> This is an **experimental** provider. It is not yet listed in the Terraform Registry,
> and a full test suite exercising complete CRUD operations across every resource is
> still being built. Use it with care and expect breaking changes.

## Resources

| Resource | Manages |
| --- | --- |
| `adlc_organizational_unit` | Organizational units, creating missing parents on demand |
| `adlc_group` | Groups: `Security` or `Distribution` category, `DomainLocal`, `Global` or `Universal` scope |
| `adlc_group_member` | A single group membership |
| `adlc_user` | User accounts. Passwords are not managed here. |
| `adlc_user_password` | Sets a user's initial password, generated or supplied |
| `adlc_gmsa` | Group managed service accounts |
| `adlc_computer` | Computer accounts, for pre-staging or reconciling machine objects |
| `adlc_kds_root_key` | Ensures a forest KDS root key exists (the gMSA prerequisite) |
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

Full documentation lives in [docs/](docs/):

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

Until the provider is published to the Terraform Registry, install it from a GitHub
release into the local Terraform plugin mirror. Run this PowerShell script on the machine
that runs Terraform (save it as `install-adlc.ps1`):

```powershell
# install-adlc.ps1 — install the adlc provider from a GitHub release into the local
# Terraform plugin mirror. Usage: .\install-adlc.ps1 -Version 0.0.15
param(
    [Parameter(Mandatory)] [string] $Version,   # release version without the leading "v", e.g. 0.0.15
    [string] $Arch = 'amd64'
)

$ErrorActionPreference = 'Stop'
$repo    = 'bjoernf73/terraform-provider-adlc'
$os      = 'windows'
$archive = "terraform-provider-adlc_${Version}_${os}_${Arch}.zip"
$sums    = "terraform-provider-adlc_${Version}_SHA256SUMS"
$baseUrl = "https://github.com/$repo/releases/download/v$Version"

$temp = Join-Path ([System.IO.Path]::GetTempPath()) "adlc-$Version"
New-Item -ItemType Directory -Force -Path $temp | Out-Null
$zipPath = Join-Path $temp $archive
$sumPath = Join-Path $temp $sums

Write-Host "Downloading $archive ..."
Invoke-WebRequest -Uri "$baseUrl/$archive" -OutFile $zipPath
Invoke-WebRequest -Uri "$baseUrl/$sums"    -OutFile $sumPath

# Verify the archive against the published checksum before trusting it.
$expected = ((Select-String -Path $sumPath -Pattern ([regex]::Escape($archive)) | Select-Object -First 1).Line -split '\s+')[0]
$actual   = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()
if (-not $expected -or $actual -ne $expected.ToLower()) {
    throw "checksum mismatch for $archive (expected '$expected', got '$actual')"
}

# Terraform's unpacked plugin-mirror layout:
#   <plugins>\registry.terraform.io\bjoernf73\adlc\<version>\<os>_<arch>\
$dest = Join-Path $env:APPDATA "terraform.d\plugins\registry.terraform.io\bjoernf73\adlc\$Version\${os}_${Arch}"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $dest -Force

Write-Host "Installed adlc $Version to $dest"
Write-Host "Declare it with source = 'bjoernf73/adlc', version = '$Version'."
```

With the provider installed, `terraform init` resolves it from the mirror without contacting
the network. A minimal configuration:

```hcl
terraform {
  required_providers {
    adlc = {
      source  = "bjoernf73/adlc"
      version = "0.0.15"
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
- The `ActiveDirectory` and `GroupPolicy` PowerShell modules on the target host
- WinRM or OpenSSH reachable from wherever Terraform runs

## Transports

You should be able to use this provider on linux and windows, and probably mac. It is (sporadically) tested on gitlab runners running in a kubernetes cluster and virtual windows core and linux boxes. Mac and freebsd probably works, but then again, might not. SSH-transport is a priority, winrm over https also.  

> [!WARNING]
> A full guide on connecting — WinRM over HTTPS, Kerberos requirements and SSH with keys —
> will eventually surface in [docs/](docs/). Until then the notes below are the short version. I will strongly urge you to do winrm over https for now.

| Transport | Authentication |
| --- | --- |
| `winrm` | `basic`, `ntlm`, `kerberos` |
| `ssh` | password, private key |

Notes that save time:

- plain HTTP (5985) is very difficult to achieve if your runner is outside of AD domain - there are multiple default settings in the Windows OS to prevent you from using that, at least in later versions. Even just for testing, rather enable winrm over https on 5986 using a self-signed certificate - it is done in minutes. Trying to make a domain controller allow authentication over http (5985) will terraform destroy your life and willpower - it's not worth it.
- `kerberos` of course needs the target FQDN, not an IP address, because the SPN is derived from
  the host name. There are other requirements as well.

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

## Releasing

### Building releases

Releases are **automatically built** via GitHub Actions when you push a tag to the `github` remote:

```sh
# Create and push a new version
git tag v0.0.15
git push github v0.0.15       # Triggers GitHub Actions build and release       # (Optional) Also push to local GitLab
```

The GitHub Actions workflow ([.github/workflows/release.yml](.github/workflows/release.yml)):
- Builds binaries for **linux_amd64**, **darwin_amd64**, **darwin_arm64**, **windows_amd64**
- Creates ZIP archives with proper Terraform naming (`terraform-provider-adlc_0.0.15_linux_amd64.zip`)
- Generates SHA256 checksums
- Creates a GitHub release with all artifacts

### In a CI pipeline

You probably already have a pipeline running Terraform. The filesystem-mirror idea from
Quick Start works there as well: download the release into a **packed** mirror and point
Terraform at it with a generated CLI config, so `terraform init` installs the provider
from the mirror instead of the public registry. The GitLab job (Windows runner) below
does that. Note that the required_provider section of this example config uses
`version = "__PROVIDER_VERSION__"` which is replaced by the pipeline's variable
`PROVIDER_VERSION` at runtime.

```yaml
prepare:
  stage: prepare
  variables:
    PROVIDER_VERSION: "0.0.15"
    PROVIDER_MIRROR: "$CI_PROJECT_DIR/.provider-mirror"
    TF_CLI_CONFIG_FILE: "$CI_PROJECT_DIR/.terraformrc"
  script:
    # Pin the provider version in main.tf (Terraform forbids variables in required_providers).
    - (Get-Content main.tf) -replace '__PROVIDER_VERSION__', $env:PROVIDER_VERSION | Set-Content main.tf -Encoding ascii
    # Packed layout: <mirror>/<host>/<namespace>/<type>/terraform-provider-<type>_<version>_<os>_<arch>.zip
    - $Mirror = "$env:PROVIDER_MIRROR/registry.terraform.io/bjoernf73/adlc"
    - New-Item -ItemType Directory -Force -Path $Mirror | Out-Null
    - $Zip = "$Mirror/terraform-provider-adlc_$($env:PROVIDER_VERSION)_windows_amd64.zip"
    - $Url = "https://github.com/bjoernf73/terraform-provider-adlc/releases/download/v$($env:PROVIDER_VERSION)/terraform-provider-adlc_$($env:PROVIDER_VERSION)_windows_amd64.zip"
    - Invoke-WebRequest -Uri $Url -OutFile $Zip
    # Point terraform at the mirror instead of the public registry (the provider isn't published there).
    # HCL treats backslashes as escapes, so use forward slashes for the Windows path.
    - $MirrorHcl = $env:PROVIDER_MIRROR -replace '\\','/'
    - |
      @"
      provider_installation {
        filesystem_mirror {
          path    = "$MirrorHcl"
          include = ["registry.terraform.io/bjoernf73/adlc"]
        }
        direct {
          exclude = ["registry.terraform.io/bjoernf73/adlc"]
        }
      }
      "@ | Set-Content -Path $env:TF_CLI_CONFIG_FILE -Encoding ascii
    # Provider-only init: install from the mirror without touching a backend/state yet.
    - terraform init -backend=false
  artifacts:
    paths:
      - .provider-mirror/
      - .terraformrc
      - .terraform.lock.hcl
      - main.tf
```

Later stages inherit `TF_CLI_CONFIG_FILE` and the artifacts above, so their own
`terraform init` (with the real backend) resolves the provider from the mirror rather than
the network.

### Future: Publishing to Terraform Registry

The provider is currently not published to Terraform Registry. At some point, when it becomes stable, it may.
